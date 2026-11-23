# Integration readiness (Flutter)

Date: 2026-11-18. Companion to `backend-test-report.md`.

## 1. Verdict

**Not ready for Flutter integration yet.** The database (schema, RLS, storage rules, family operations) is complete for M1–M2 and passes every local test. Two things block a Flutter developer from working against it:

1. **No development Supabase project** has the migrations applied, so there is no URL or publishable key to point the app at, and the live Auth and HTTP tests haven't run.
2. **No Edge Functions exist.** Flutter can sign in and read through RLS, but it can't complete onboarding (`POST /onboarding/complete`), and families never write directly. So sign-up stalls after the email code.

Clearing (1) is about an hour of dashboard work for you plus one test run. Clearing (2) is the first slice of M1/M2 backend work (§3). After both, Flutter integration can start with auth, onboarding and catalogue reads, while `play/*` is built alongside.

## 2. What Flutter can rely on today (once the dev project exists)

| need | ready? | how |
| --- | --- | --- |
| sign-up / sign-in (magic link + code, password) | ✓ config | `supabase_flutter` `signInWithOtp` / `verifyOTP` (PKCE), `flutter_secure_storage` |
| Apple / Google | after your keys | dashboard providers (§4) |
| read the catalogue (activities, games, courses tree, collections, rewards, avatars, subjects, skills) | ✓ | Data API under RLS (published only) |
| read the family's own data (account, children, consents, progress, favourites, stars, subscriptions) | ✓ | Data API under RLS |
| typed models | ✓ after push | `supabase gen types` (TypeScript) / hand-written Dart models from `database-schema.md`; a Dart generator (`supadart`) is optional |
| public images (thumbnails, avatars, stickers) | ✓ | `public-assets` public URLs |
| onboarding, add/delete child, account deletion | **SQL ready, Edge Function missing** | §3 |
| launch a game, upload results, stars, home feed with locks | upload, stars, unlocks: **written** (`play/sync` → `apply_session`, SQL test P1, Phase 9); `play/launch` + `play/heartbeat` **written** (Phase 11, M1); `catalog/home`: missing | §3 |
| parent dashboard, reports, notifications, exports, account deletion (Phase 13) | **written**: `progress` and `account` Edge Functions; SQL test D1 | `docs/parent-dashboard/` |
| rewards: star ledger, badges, goals, streak (Phase 12) | **written**: `apply_session` → `apply_rewards` (in `play/sync`), `GET /children/:id/rewards`, `PUT /children/:id/goals`; SQL test R1 | `docs/gamification/` |

Client rules for the Flutter app: ship only `SUPABASE_URL` + the publishable key; never the secret key or DB URL (`scripts/check-secrets.sh` will flag them under `apps/`). Send the selected child as `X-Child-Id`; the server re-checks it.

## 3. Missing backend operations

64 routes in `docs/architecture/07-api-specification.md`. Status:

| function (routes) | SQL operation | Edge Function | needed for Flutter |
| --- | --- | --- | --- |
| `onboarding` (1) | ✓ `onboard_family` | ✓ written, not deployed (Phase 7) | **M1, first** |
| `children` (4) | ✓ add, edit (0014), delete; screen-time to do | ✓ POST / PATCH / DELETE written, not deployed; screen-time ✗ | M1 |
| `account` (10) | ✓ deletion schedule/cancel; consents, export, devices, `me` to write | ✗ | M1 (`me`, `devices`) |
| `catalog` (4) | reads via RLS; home/search composition to write | ✗ | M2 (`home`) |
| `play` (3) | ✓ `apply_session` (stars, daily progress, steps); ✗ mastery, badges | `sync` ✓ written; `launch`, `heartbeat` ✗ | **M2, core loop** |
| `media` (2) | — (signed HLS playlists) | ✗ | M4 |
| `learning` (5) | ✗ enrol, tree with unlocks, next, journey | ✗ | M5 |
| `rewards` (2) | ✗ `claim_gift`, scene placements | ✗ | M6 |
| `library` (4) | ✗ favourites, downloads manifest | ✗ | M4, M9 |
| `progress` (2) | ✗ report, certificate PDF | ✗ | M7 |
| `billing` (6) + `webhooks` (2) | ✗ `apply_billing_event`, `redeem_code` | ✗ | M8 |
| `analytics` (1) | ✓ table + partitions | ✗ | M12 |
| `admin` (11) | partly via RLS | ✗ | M3 |
| `jobs` (7) | ✓ `execute_account_deletion`, `ensure_event_partitions` | ✗ (+ pg_cron, Queues) | M8–M12 |

**Minimum for Flutter to start (suggested next step, ~1 module of work):** the `_shared` Edge Function layer (JWT verification, zod, error mapping KL4xx → HTTP, Postgres client over `SUPABASE_DB_URL`) + `onboarding/complete`, `account/me`, `account/devices`, `children` (4), then `private.apply_session` + `play/launch`, `play/sync`, `catalog/home`. Each gets the same style of SQL test plus a step in the integration test.

## 4. Manual actions still required (you)

| # | action | where |
| --- | --- | --- |
| 1 | **Create a dedicated development project** for this platform (not the school app's): choose the region (Q1), Postgres 17 | Supabase dashboard |
| 2 | Do dashboard configuration rows 1–9 and 11–14 | `setup-guide.md` §4 |
| 3 | Install the Supabase CLI; `supabase link --project-ref <dev-ref>`; `supabase db push --dry-run`, inspect, then `supabase db push` (or send me the ref and I'll do the dry run for you to review) | terminal |
| 4 | Put the dev values in an untracked `.env.local`: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`, `SUPABASE_DB_URL` (pooler, transaction mode) | local |
| 5 | Run the live tests: `KL_INTEGRATION_TARGET=dev deno test -A supabase/tests/integration/backend.integration.test.ts`, then the three SQL suites against the dev DB (`psql "$SUPABASE_DB_URL" -f supabase/tests/0X_….sql`; they roll back). The SQL suites expect the seed's test users, so run them on a preview branch or a local CLI stack, which seeds; the integration test creates and deletes its own users | terminal |
| 6 | Bootstrap the first super admin by SQL | `setup-guide.md` §6 |
| 7 | `git init`, then run `scripts/check-secrets.sh` again so it also checks history; add it plus `db-verify.sh` to CI | repo |
| 8 | Apple Services ID / key and a Google OAuth client (start Google verification now) | Apple / Google consoles |
| 9 | Custom SMTP (Resend) on your domain, SPF / DKIM / DMARC | Resend + DNS |
| 10 | Legal: consent method per market (Q3), privacy policy listing processors and backup retention | counsel |
| 11 | **Admin CMS (Phase 14):** add `admin_api` to the Data API's exposed schemas; enable TOTP MFA; deploy the `admin` Edge Function; host `admin_panel/` with only the URL and publishable key (`docs/admin-cms/architecture.md` §6) | Supabase dashboard, host |
| 12 | **Edge Functions (Phase 14 fix):** JSON parameters were double-encoded in `play`, `children`, `account` and `admin` before Phase 14 (`docs/admin-cms/testing-report.md` §4). Deploy the fixed versions, never older builds | `supabase functions deploy` |
| 13 | **Web app (Phase 15):** set Auth Site URL and redirect `https://app.<domain>/auth/callback`; host `web_app/` with only the URL and publishable key (`docs/web/deployment-guide.md`) | Supabase dashboard, host |

## 5. Definition of "ready for Flutter"

- [ ] dev project exists; 19 migrations applied (review `20261121000100_rewards.sql` and `20261122000100_parent_dashboard.sql` first: they rename and redefine `apply_session_core` and backfill rewards); enable pg_cron for weekly summaries; Security and Performance Advisors clean
- [ ] integration test passes against dev; SQL suites pass on a seeded Supabase (local CLI or preview branch)
- [ ] Edge Functions: `onboarding`, `children` written (Phase 7); `account/me`, `account/devices` to write; all to deploy to dev and test
- [x] Flutter foundation: auth, onboarding, child profiles on these contracts (`docs/flutter/`)
- [ ] `apply_session` + `play/sync` (written, Phase 9), `play/launch` (written, Phase 11), rewards routes (written, Phase 12), `catalog/home` deployed (needed from the M2 vertical slice)
- [x] schema, RLS, storage rules, family operations, seed, local test suite, secret scan, auth config
