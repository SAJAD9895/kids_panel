# API design (backend view)

Full route list: `docs/architecture/07-api-specification.md` (15 Edge Functions, 64 routes). This document describes how the backend serves them and what exists **now**.

## 1. Three surfaces

| surface | used for | auth | implemented now |
| --- | --- | --- | --- |
| **Supabase Auth** (`/auth/v1`) | sign-up, magic link + code, password, Apple, Google, MFA, refresh | publishable key + PKCE | configured (`config.toml`, templates) |
| **Data API** (`/rest/v1`, schema `public` only) | reads under RLS; admin catalogue writes | user JWT | ✓ all tables + policies |
| **Edge Functions** (`/functions/v1/<fn>/<route>`) | every family write, composed reads, webhooks, jobs | user JWT, or webhook signature / job secret | contracts below; code in M1+ |

## 2. Reads clients make directly (Data API, RLS-filtered)

| client | reads |
| --- | --- |
| kids app | published catalogue (activities, games, questions/answers, courses tree, collections, rewards, avatars, subjects, skills), the selected child's favourites, stars, rewards, enrolments, daily progress |
| parent app / web | own account, profiles, children, consents, devices, subscriptions, entitlements, payments, notifications, deletion/export requests, child progress tables |
| admin web | everything its permissions allow (drafts with `content.read`, families with `support.read`, billing with `billing.read`, audit with `audit.read`) |

Composed reads (home feed with lock state, progress report, course tree with unlocks) are Edge Function routes, because they combine entitlement, screen time and age rules that clients must not compute.

## 3. How an Edge Function writes

```
request ─► verify JWT (supabase.auth.getUser / getClaims) ─► user id = sub
        ─► zod-validate the body (strip unknown fields)
        ─► rate limit (per user / IP)
        ─► single-row write: supabase-js with the service key, after an explicit can_access_child / is_account_member check
           multi-row write: ONE call to a private.* SQL function over the database connection
        ─► map errors ─► JSON problem response
```

- **Database connection:** Edge Functions receive `SUPABASE_DB_URL` from the platform. Use it through Supavisor in **transaction mode** (port 6543) with a small pool, e.g. `postgres` (postgres.js) with `prepare: false`. The `private` schema is **not** exposed through the Data API, so it can't be called with `supabase.rpc()`; that is deliberate (`database-schema.md` §5, change 9).
- **Never** pass an id from the request body as `p_user_id`. Child ids in the body (`X-Child-Id`) are always checked against the caller (`can_access_child` or the function's own ownership check).
- The service key and `SUPABASE_DB_URL` exist only in the Edge runtime. Clients ship the publishable key only.

## 4. Implemented server operations (SQL, service-only)

| route (07-api) | SQL function | input | output | errors |
| --- | --- | --- | --- | --- |
| `POST /onboarding/complete` | `private.onboard_family(user_id, payload)` | `{timezone, country?, uiLocale?, contentLocale?, marketingOptIn?, child:{nickname, birthYearMonth, avatarId?, stage?}, consents:[{type, policyVersion, method}], evidence}` | `{accountId, childId, created}` | KL400, KL403 |
| `POST /children` | `private.add_child(user_id, child)` | `{nickname, birthYearMonth, avatarId?, stage?, contentLocale?}` | `{childId}` | KL400, KL402 (plan limit: Basic 1, Plus `max_children`), KL403 |
| `PATCH /children/:id` | `private.update_child(user_id, child_id, c)` (Phase 7) | any of `{nickname, birthYearMonth, avatarId (null clears), stage, contentLocale}` | the child | KL400, KL404 |
| `DELETE /children/:id` | `private.delete_child(user_id, child_id)` | — (**re-auth must be checked by the Edge Function**; the SQL function checks ownership only) | `{deletionRequestId}` | KL404 (not the owner's child) |
| `POST /account/deletion` | `private.schedule_account_deletion(user_id)` | — (re-auth checked by the Edge Function) | `{deletionRequestId, scheduledFor}` | KL403 (not owner) |
| `DELETE /account/deletion/:id` | `private.cancel_account_deletion(user_id, request_id)` | — | `{cancelled}` | KL404 |
| `POST /play/sync` (Phase 9) | `private.apply_session(user_id, item)` per item | `{deviceId?, clockOffsetMs?, items[1..100]}`; item = `{sessionId, childId, activityId, lessonStepId?, status: started\|completed\|abandoned, startedAt, endedAt?, durationMs?, score?, correctCount?, totalCount?, metrics?, responses?[{questionId, answerId?, correct, attempt, responseMs?}], source?, platform?, appVersion?, contentVersion?}` | per item `{sessionId, status: accepted\|duplicate\|rejected, allowed, starAwarded, starsToday, stepCompleted, nextStepId, courseCompleted, localDate}` | per item KL400, KL404, KL409 (rejected, others still applied) |
| `GET /progress/overview` (Phase 13) | `private.family_overview(user_id)` | — | `{today, weekStart, plusUntil, unread, children[{childId, secondsToday, secondsWeek, secondsTotal, lessonsCompleted, gamesCompleted, rewards, badgesEarned, recent[5]}]}` | KL404 |
| `GET /progress/report` (Phase 13) | `private.progress_report(user_id, child, period, date)` | `?childId&period=day\|week\|month&date=YYYY-MM-DD` | `{from, to, today, totals, previous, daily[], byType[], bySubject[], games[], quizzes[], lessons, skills[], goals, consistency[8], scoredSessions, recent[≤50]}` (docs/parent-dashboard/analytics.md) | KL400, KL404 |
| `PUT /account/notification-preferences` (Phase 13) | `private.set_notification_preferences(user_id, prefs)` | `[{type, channel: in_app\|email\|push, enabled}]` | all preferences | KL400 |
| `POST /account/notifications/read` (Phase 13) | `private.mark_notifications_read(user_id, ids)` | `{ids?}` (none = all) | `{marked}` | — |
| `POST /account/export` (Phase 13) | `request_export` → `export_payload` → Storage upload → `finish_export` (re-auth) | `{childId?}` | `{requestId, status, expiresAt, url}` (signed, 1 h) | KL401 REAUTH_REQUIRED, KL404, KL429 RATE_LIMITED |
| `GET /account/exports/:id/url` (Phase 13) | `private.export_file(user_id, id)` + signing | — | `{url, expiresAt}` | KL404, KL409 |
| `POST /account/deletion`, `DELETE /account/deletion/:id` (Phase 13 route; Phase 5 SQL) | `schedule_account_deletion`, `cancel_account_deletion` (re-auth to schedule) | — | `{deletionRequestId, scheduledFor}` / `{cancelled}` | KL401, KL403, KL404 |
| `GET /children/:id/rewards` (Phase 12) | `private.rewards_summary(user_id, child)` | — | `{today, weekStart, balance, streak{current, longest, lastDay}, goals, day, week, learningDays[], transactions[≤50], badges[all, earnedAt], counts, rules}` | KL404 |
| `PUT /children/:id/goals` (Phase 12) | `private.set_learning_goals(user_id, child, p)` | `{enabled?, dailyActivities? 1..10, weeklyDays? 1..7}` (partial) | the goals | KL400, KL404 |
| `POST /play/sync` → `rewards` (Phase 12) | `private.apply_session` → `private.apply_rewards` | (unchanged) | each accepted item adds `rewards: {stars, transactions[], badges[{key, title, bonusStars, art}], goals[], lessonCompleted, courseCompleted, streak{current, longest, grew}, balance}`: only what's new | — |
| `POST /play/launch` (Phase 11) | `private.launch(user_id, {childId, activityId})` + Storage signing in the Edge Function | `{childId, activityId, source?}` | `{activityId, type, section, contentVersion, assets:[{role, locale, position, url, expiresAt, kind, mime, bytes, sha256, width, height, durationMs, text}], resume, remainingSeconds}` | KL400, KL402 NEEDS_PLUS, KL403 AGE_NOT_SUITABLE, KL404, KL423 SECTION_DISABLED / CATEGORY_BLOCKED / SCREEN_TIME_OVER |
| `POST /play/heartbeat` (Phase 11) | `private.add_screen_time(user_id, child, section, seconds)` | `{childId, section, seconds 1..120}` | `{remainingSeconds, locked}` | KL400, KL404 |
| `PUT /children/:id/screen-time` (Phase 11) | `private.set_screen_time_rules(user_id, child, rules)` | `{dailyLimitMinutes?, limitedSections?, learnEnabled?, watchEnabled?, listenEnabled?, togetherEnabled?, blockedCategoryIds?}` (partial) | the rules | KL400, KL404 |
| `POST /jobs/deletions` | `private.execute_account_deletion(request_id)` | — (job secret) | `{accountId, authUserIds[]}` | KL404, KL409 (not due) |

Error mapping (problem+json, `type` = the message key):

| SQLSTATE | key | HTTP |
| --- | --- | --- |
| KL400 | VALIDATION | 400 |
| KL402 | CHILD_LIMIT | 402 |
| KL403 | FORBIDDEN | 403 |
| KL404 | NOT_FOUND | 404 (also used for "not yours", so ids can't be probed) |
| KL409 | CONFLICT | 409 |
| other | INTERNAL | 500 (details to Sentry, never to the client) |

## 5. Edge Functions written (Phase 7, not deployed)

`supabase/functions/`: `_shared/` (CORS, problem+json, SQLSTATE → HTTP mapping, JWT verification with `auth.getUser`, re-auth check from the JWT `amr` times, postgres.js over `SUPABASE_DB_URL` with `prepare: false`, zod schemas), `onboarding` (`POST /onboarding/complete`, adds hashed-IP and user-agent-class evidence) and `children` (`POST`, `PATCH /:id`, `DELETE /:id` with a 10-minute re-auth window → `401 REAUTH_REQUIRED`). Type-checked with `deno check`; deploy with `supabase functions deploy onboarding children` once the dev project exists, with secret `EVIDENCE_SALT`. Still TODO in `onboarding`: the consent confirmation email (Resend).

## 5a. Admin CMS (Phase 14)

The staff app uses the admin's own session (`docs/admin-cms/`):
- **Data API, schema `admin_api`** (signed-in users; each function checks a permission, which includes MFA):
  - me, dashboard, activity, validate, transition;
  - families, family, set_account_status, privacy_requests, cancel_deletion, grant_stars;
  - users_list, set_roles, set_admin_status.
- **Content tables** written directly under RLS (`content.write`; `content.publish` for live content).
- **Edge Function `admin`** (service role, re-checks the admin):
  - `POST /admin/media/finalize`: staged upload → checked, stored, registered;
  - `POST /admin/exports/:id/run`: builds a requested export (`privacy.act`).

New error key: `ACCOUNT_SUSPENDED` (403). The household is restricted by support, so `play/launch` and `play/sync` refuse. The app shows it as `AccountSuspendedFailure`.

**JSON parameters** in Edge Functions are passed as `${jsonb(value)}::jsonb` (`_shared/db.ts`), never as `JSON.stringify`. postgres.js would encode the string again.

## 6. Still to build (by roadmap module)

| module | SQL functions to add | Edge Functions |
| --- | --- | --- |
| M1 | consent withdrawal, device registration | `account`, `onboarding`, `children` |
| M2 | ~~`apply_session`~~ (Phase 9: stars, daily progress, step unlock, enrolment); still: mastery, badges, gifts | `play/launch`, `play/heartbeat` (`play/sync` written), `catalog` (home), `media` |
| M5–M6 | enrol, `claim_gift`, scene placements | `learning`, `rewards`, `progress` |
| M8 | `redeem_code`, `apply_billing_event` (idempotent on provider event id) | `billing`, `webhooks` (Stripe signature, RevenueCat bearer) |
| M9–M10 | downloads report, notification dispatch | `library`, `notifications` |
| M12 | export builder, retention purge, partition maintenance (`ensure_event_partitions`) | `jobs` (pg_cron + pg_net, shared secret), `analytics` (`admin` built in Phase 14) |

Rules that apply to all of them: webhooks verify the signature and store the event id first (`billing_webhook_events`, unique), so a retried webhook is a no-op; every job is idempotent and retried from Supabase Queues (pgmq) with a dead-letter log; times stay in UTC and are shown in the household timezone.
