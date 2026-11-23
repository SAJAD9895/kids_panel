# 4. Backend architecture (Supabase modular monolith)

One Supabase project per environment (local, staging, production) [P]. Everything server-side runs inside it: Postgres, Auth, Storage, Edge Functions, Queues and cron. The only work outside Supabase is the **content pipeline** (video transcoding and pack building in GitHub Actions) [P, D6] and the third-party services in `01-…`.

## 4.1 Components

| component | role | notes |
| --- | --- | --- |
| **Postgres** | the system of record; RLS on every table; integrity rules as constraints and primary keys | `05-database.md` |
| **Data API (PostgREST)** | reads for all clients, under RLS; admin catalogue writes | exposed schemas: `public` only. `private` and `analytics` are not exposed |
| **Edge Functions** (Deno) | every family write, every privileged read, webhooks, jobs | 15 functions, 64 routes, `07-api-specification.md` |
| **Auth** | parents (magic link + OTP, password, Apple, Google); admins (+ TOTP MFA) | `06-auth-and-authorization.md` |
| **Storage** | 5 buckets; private by default; signed URLs | `11-media-storage.md` |
| **Queues (pgmq)** | durable async work: billing events, exports, deletions, notifications | at-least-once delivery; handlers are idempotent |
| **pg_cron + pg_net** | schedules that call job routes | `4.5` |
| **Vault / function secrets** | Stripe, RevenueCat, Resend, FCM keys, entitlement-token signing key | never in client builds |

## 4.2 Edge Functions layout

```
supabase/functions/
├── _shared/
│   ├── http/            Hono app factory, CORS, problem+json errors, request id, zod validation
│   ├── auth/            getUser(jwt), requireChild(childId) → can_access_child, requirePermission(perm)
│   ├── db/              two clients: asUser(jwt) (RLS applies) and asService() (bypasses RLS, used after checks)
│   ├── ratelimit/       Postgres-backed token bucket (unlogged table) [P]
│   ├── audit/           writeAudit(actor, action, entity, changes)
│   └── modules/         one folder per business module (01-… §1.5): service.ts, schemas.ts, tests
│       ├── identity/  consent/  catalog/  media/  play/  progress/  courses/
│       ├── rewards/   controls/ billing/  offline/ notifications/ analytics/ admin/
├── account/     onboarding/  children/  catalog/  play/  learning/  rewards/  library/
├── progress/    media/       billing/   webhooks/ analytics/ admin/  jobs/
└── (each folder: index.ts = a Hono router mounting routes from _shared/modules)
```

**Why 15 functions and not 64**: each function is a deploy unit with its own cold start. Grouping routes by module keeps cold starts rare and keeps deploys independent per module. [P]

**Every handler follows the same steps:**
1. Parse and validate input with zod (reject unknown fields).
2. Authenticate: Supabase verifies the JWT at the gateway (`verify_jwt = true`), except webhooks (they check the provider signature) and job routes (they check a shared secret from Vault).
3. Authorise: `requireChild`, `requireAccountRole`, or `requirePermission`.
4. Rate-limit by user and route.
5. Run the domain logic. Multi-row changes go through **one SQL function in `private`**, so they commit or roll back together. For example, `private.apply_session(jsonb)` covers the session, result, stars, unlocks and mastery.
6. Write an audit entry for sensitive actions.
7. Return the new state (so the client doesn't need a second read) or an RFC 9457 problem+json error.

## 4.3 Where business logic lives

| logic | place | reason |
| --- | --- | --- |
| integrity rules (one star per activity per day, no double redemption, idempotent replay, birth month only) | **Postgres constraints and keys** | can't be bypassed by any code path; tested in `database/schema-draft-checks.sql` |
| access rules | **RLS + `private.*` helpers** | the same rule for Data API reads and Edge Function `asUser` calls |
| multi-table transactions (apply a session, claim a gift, redeem a code, enroll) | **SQL functions in `private`**, called from Edge Functions with the service role | atomic; one round trip |
| orchestration, external APIs, validation, rate limits | **Edge Functions** (TypeScript) | network calls don't belong in a database transaction |
| presentation, optimistic UI, offline queue | clients | never trusted for awards or access |

## 4.4 Async work: queues

| queue | producer | consumer route | idempotency key |
| --- | --- | --- | --- |
| `billing_events` | `webhooks/*` after storing the raw event | `jobs/process-billing-events` | `billing_webhook_events (provider, provider_event_id)` |
| `exports` | `account/export` | `jobs/exports` | `data_export_requests.id` |
| `deletions` | cron (due `deletion_requests`) | `jobs/deletions` | `deletion_requests.id` + each step checks "already done" |
| `notifications` | engine events (certificate earned), billing (trial ending), cron (weekly digest) | `jobs/notifications-dispatch` | `notifications.id` |

A message that fails 5 times moves to a dead-letter queue, and the failure shows in the admin web.

## 4.5 Schedules (pg_cron) [P]

| job | schedule (UTC) | does |
| --- | --- | --- |
| billing reconcile | daily 03:00 | re-fetch subscribers whose period ends within ±48 h from RevenueCat; fix drift |
| deletions | hourly | enqueue `deletion_requests` past `scheduled_for` |
| notifications dispatch | every minute | send queued notifications whose `scheduled_for` has passed |
| weekly digest | hourly on Sundays | enqueue digests for accounts where it is 09:00 local time |
| maintenance | daily 04:00 | create next month's `analytics.events` partition; drop partitions older than 13 months; purge `daily_free_allocations` and `screen_time_usage` older than 90 days; expire export files after 7 days |
| retention purge | weekly | apply the retention schedule in `14-…` (raw sessions → aggregated after 24 months [OPEN]) |

## 4.6 Limits to design around [A, verify against current Supabase docs at M0]

- Edge Functions have per-request CPU and wall-clock limits and a memory cap. So **no transcoding, no PDF rendering of large documents and no big zips inside a request**. Certificates are small PDFs (fine). Data exports are built by a job in chunks.
- The Data API has a default row limit per request; feeds paginate.
- Storage has a per-file upload limit set per project; content packs target ≤ 15 MB, videos are segmented HLS.
- Connection limits: Edge Functions use the Supabase client over HTTP (PostgREST) for single-table work, and the pooler (Supavisor, transaction mode, `SUPABASE_DB_URL`) to call `private.*` functions, since `private` is not exposed through the Data API (decided 2026-11-18, `docs/backend/database-schema.md` §5); never a direct connection per request.

## 4.7 Observability

| signal | tool |
| --- | --- |
| function logs, Postgres logs, API logs | Supabase Logs Explorer (log drains to a store of choice later [P]) |
| errors | Sentry (Edge Functions via the Deno SDK; Flutter; Next.js), PII scrubbing on |
| business health | admin web dashboard: sessions per hour, sync failures, webhook backlog, queue depth, dead letters |
| alerts | queue depth > threshold, webhook processing lag > 10 min, sync rejection rate > 2 %, 5xx rate > 1 % |
