# 7. API architecture and endpoint specification

## 7.1 Three API surfaces

| surface | used for | auth | base |
| --- | --- | --- | --- |
| **Supabase Auth** | sign-up, sign-in, OTP, OAuth, MFA, refresh | anon key + PKCE | `/auth/v1/…` (Supabase SDK) |
| **Data API (PostgREST)** | reads of published catalogue and the user's own rows (RLS); admin catalogue writes (RLS + permission + aal2) | user JWT | `/rest/v1/<table>` (Supabase SDK) |
| **Edge Functions** | every family write, composed reads (feeds with lock state, reports), files, billing, webhooks, jobs | user JWT, or signature / secret | `/functions/v1/<function>/<route>` |

Custom domain: `api.<domain>` via Supabase's custom domain add-on [P], so URLs in emails and apps don't show the project ref.

## 7.2 Conventions (all Edge Function routes)

| topic | rule |
| --- | --- |
| format | JSON, UTF-8, `camelCase` fields; dates ISO 8601 UTC; `localDate` as `YYYY-MM-DD` |
| headers in | `Authorization: Bearer <JWT>`; `X-Child-Id` on child-scoped routes; `X-Request-Id` (client UUID, echoed back); `X-App-Version` + `X-Platform` (ios / android / web) |
| idempotency | writes that a retry could repeat take a client-generated id (`sessionId`, `clientOpId`) or `Idempotency-Key`; a repeat returns the first result |
| errors | RFC 9457 `application/problem+json`: `{type, title, status, code, detail, requestId}`; stable `code` values: `UNAUTHENTICATED`, `FORBIDDEN`, `CHILD_NOT_IN_ACCOUNT`, `NEEDS_PLUS`, `DAILY_FREE_LIMIT`, `SCREEN_TIME_OVER`, `SECTION_DISABLED`, `CHILD_LIMIT`, `NOT_FOUND`, `VALIDATION`, `RATE_LIMITED`, `CONFLICT`, `APP_TOO_OLD` |
| versioning | additive changes only; breaking changes get a new route; `GET /account/me` returns `minSupportedBuild` per platform so old apps are asked to update (`APP_TOO_OLD` = 426) |
| pagination | cursor-based: `?cursor=&limit=` (max 100); response `{items, nextCursor}` |
| rate limits | per user + route; `429` with `Retry-After`. Defaults in §7.5 |
| validation | zod schemas shared with the web apps (`packages/ts/supabase/api`); Dart DTOs generated from the same JSON Schema [P] |

**Who** column legend: `anon` no session · `parent` signed-in member of the account · `child` parent session + `X-Child-Id` belonging to the account · `owner` account owner · `perm:x` admin with permission x in an aal2 session · `sig` webhook signature · `job` job secret.

## 7.3 Data API reads used by clients (RLS-protected)

| resource | who | purpose |
| --- | --- | --- |
| `child_profiles`, `avatars` | parent | profile drawer [V SS-15], avatar picker |
| `subjects`, `skills`, `categories` | anon, parent | filters, labels, skill pills [V SS-01] |
| `activities` (+ `activity_skills`, `activity_media`, `games`, `questions`, `answers`) | anon, parent | activity detail, quiz content for offline play |
| `courses` → `course_modules` → `lessons` → `lesson_steps` | parent | course tree (lock state comes from `learning/courses/:id/tree`) |
| `rewards`, `reward_sets`, `child_rewards`, `scene_placements` | parent | sticker album, scene book |
| `favorites`, `certificates`, `course_enrollments` | parent | lists |
| `subscriptions`, `entitlements`, `payments`, `subscription_plans` | parent | subscription screen, receipts |
| `notifications`, `notification_preferences` | parent | inbox, settings |
| `parental_consents`, `data_export_requests`, `deletion_requests`, `devices` | parent | privacy and devices pages |
| all catalogue tables (incl. drafts) + insert/update/delete | perm:content.* | admin CMS |

## 7.4 Edge Function routes (15 functions, 64 routes)

### `account` (10)
| method path | does | who | input → output |
| --- | --- | --- | --- |
| GET /account/me | bootstrap: account, profile, children, entitlement, screen-time rules, feature flags, `minSupportedBuild`, server time | parent | → `MeDTO` |
| PATCH /account | timezone, locales, marketing opt-in | owner | partial → `Account` |
| POST /account/devices | register or refresh this device (install id, platform, app version, push token) | parent | `{installId, platform, appVersion, pushToken?}` → `{deviceId}` |
| POST /account/devices/:id/revoke | sign a lost or old device out: sets `revoked_at`, revokes its refresh token, drops its push token; the device's downloads lock at the next check (design P14) | owner, re-auth | → `204` |
| PUT /account/notification-preferences | set channels per type | parent | `[{type, channel, enabled}]` → `204` |
| POST /account/consents | grant or revoke a consent (versioned) | owner | `{consentType, policyVersion, granted}` → `Consent` |
| POST /account/export | request a data export (re-auth required) | owner | `{}` → `202 {requestId}` |
| GET /account/export/:id | status; a signed download link when ready | owner | → `{status, url?, expiresAt?}` |
| POST /account/deletion | schedule account or child deletion (7-day grace for accounts; re-auth) | owner | `{scope, childId?}` → `{requestId, scheduledFor, storeSubscriptionActive}` |
| DELETE /account/deletion/:id | cancel a scheduled deletion | owner | → `204` |

### `onboarding` (1)
| method path | does | who | input → output |
| --- | --- | --- | --- |
| POST /onboarding/complete | create account + owner profile + first child + consents in one transaction; idempotent per user | parent (new) | `{timezone, country, uiLocale, contentLocale, child:{nickname, avatarId, birthYearMonth, stage}, consents:[…]}` → `{account, child}` |

### `children` (4)
| method path | does | who | input → output |
| --- | --- | --- | --- |
| POST /children | add a child (Basic 1, Plus up to `plan.max_children`) | parent | `{nickname, avatarId, birthYearMonth, stage}` → `Child` or `402 CHILD_LIMIT` |
| PATCH /children/:id | edit | parent | partial → `Child` |
| DELETE /children/:id | delete now (re-auth); a `deletion_requests` row is kept for the record | owner | → `204` |
| PUT /children/:id/screen-time | daily limit, limited sections, section toggles (Play can't be turned off [V R14]) | parent | `ScreenTimeRules` → `ScreenTimeRules` |

### `catalog` (4)
| method path | does | who | input → output |
| --- | --- | --- | --- |
| GET /catalog/home?section= | rows for one kids rail section, `home` / `learn` / `watch` / `listen` (docs/design/README.md §2): published, in window, age-matched, items of switched-off sections removed, with lock state (Plus, free allocation), favorites flags, today's stars, section switches | child | → `{rows[], starsToday, giftsAvailable, sections}` |
| GET /catalog/collections/:id | one world, topic or drop with items and lock state | child | → `Collection` |
| GET /catalog/search?q=&subject=&type= | **every activity type** (games, videos, songs, stories, audiobooks, courses) [F-043], age-filtered, switched-off sections removed; FTS + trigram | child | → `{items[]}` |
| GET /catalog/sync?since= | catalogue delta for offline: changed and retired items for the child's age band and locale | child | → `{items[], tombstones[], cursor}` |

### `play` (3)
| method path | does | who | input → output |
| --- | --- | --- | --- |
| POST /play/launch | **the gate for all content**: published, age, Plus or today's free allocation, section on, screen time left, template supported by this app build, permissions needed. Returns signed URLs (pack, media) | child | `{activityId, source, lessonStepId?}` → `{sessionHint, template:{key, version, orientation}, assets:{packUrl, sha256, bytes} \| {hlsUrl} \| {pages[]}, permissions[]}` or `402 NEEDS_PLUS` / `DAILY_FREE_LIMIT`, `423 SCREEN_TIME_OVER` / `SECTION_DISABLED`, `426 APP_TOO_OLD` |
| POST /play/sync | **batch upload of sessions, results and question responses** (live and offline). Idempotent per `session.id`. Runs the progress engine (`09-…`) per item | child | `{deviceId, clockOffsetMs, items:[{session, result?, responses[]}] (≤ 100)}` → `{results:[{sessionId, status: accepted\|duplicate\|rejected, reason?}], state:{starsToday, giftsAvailable, unlockedSteps[], certificates[], badges[]}}` |
| POST /play/heartbeat | add seconds of use to a section; returns time left | child | `{section: games\|learn\|watch\|listen\|together, seconds (≤ 120)}` → `{remainingSeconds, locked}` |

### `learning` (5)
| method path | does | who | input → output |
| --- | --- | --- | --- |
| POST /learning/courses/:id/enroll | start or resume | child | → `Enrollment` |
| GET /learning/courses/:id/tree | modules → lessons → steps with locked / current / done, progress-bar %, certificate state [V SS-07, SS-10] | child | → `CourseTree` |
| GET /learning/next | "up next": continue current step, else the path's next course, else a weak skill practice | child | → `{items[]}` |
| GET /learning/state | child state snapshot for offline (stars today, enrollments, completed steps, favorites, reward counts) | child | → `ChildState` |
| GET /learning/journey | the child-facing "my garden" view (design K17, K18): one plant per skill group with a level 0–3 from `skill_mastery` bands (`09-…` §9.3), badges, and "big moments" (first game, star milestones, lessons done). Words and pictures only, no scores or percentages | child | → `{groups:[{key, level}], badges[], moments[]}` |

### `rewards` (2)
| method path | does | who | input → output |
| --- | --- | --- | --- |
| POST /rewards/gifts/claim | open the next gift if `5 × n ≤ starsToday` (online only [P]) | child | `{clientOpId}` → `{giftIndex, rewards[]}` or `409` |
| PUT /rewards/scenes/:sceneId | replace the placements on one scene (owned stickers only) | child | `{version, placements[]}` → `{version}` or `409 CONFLICT` |

### `library` (4)
| method path | does | who | input → output |
| --- | --- | --- | --- |
| PUT /library/favorites/:activityId | add (Plus) | child | `{clientOpId, at}` → `204` or `402` |
| DELETE /library/favorites/:activityId | remove | child | `{clientOpId, at}` → `204` |
| POST /library/downloads/manifest | signed URLs, sizes, hashes for a set of activities or a whole row (Plus) | child | `{activityIds[] \| collectionId}` → `{items:[{activityId, contentVersion, files:[{url, sha256, bytes}], expiresAt}]}` |
| POST /library/downloads/report | record downloaded / removed items for this device | parent | `{deviceId, added[], removed[]}` → `204` |

### `progress` (2)
| method path | does | who | input → output |
| --- | --- | --- | --- |
| GET /progress/report?childId=&days=14 | completed count, top skill and activity, top 3 subjects, skills by group, course pre/post check scores, daily chart (default 14 days [V SS-14], 7–90) | parent | → `ProgressReport` |
| GET /progress/certificates/:id/pdf | printable certificate | parent | → `application/pdf` |

### `media` (2)
| method path | does | who | input → output |
| --- | --- | --- | --- |
| GET /media/hls/:assetId/master.m3u8?t= | master playlist with signed variant URLs; `t` = launch token (short-lived, bound to child + asset) | token | → `application/vnd.apple.mpegurl` |
| GET /media/hls/:assetId/:rendition.m3u8?t= | variant playlist with signed segment URLs | token | → playlist |

### `billing` (6)
| method path | does | who | input → output |
| --- | --- | --- | --- |
| GET /billing/plans | plans; web prices from Stripe (country-aware) | anon, parent | → `Plan[]` |
| POST /billing/checkout | Stripe Checkout session (trial supported) | owner | `{planKey}` → `{url}` |
| POST /billing/portal | Stripe customer portal | owner | → `{url}` |
| POST /billing/sync | after a store purchase or restore: re-fetch from RevenueCat, update subscriptions + entitlements | parent | `{}` → `{entitlement}` |
| POST /billing/redeem | redeem a promo code atomically (5 attempts / hour) | owner | `{code}` → `{entitlement}` or `404/409/410` |
| GET /billing/entitlement-token | signed offline entitlement token (`12-…`) | parent | → `{token, expiresAt}` |

### `webhooks` (2)
| method path | does | who |
| --- | --- | --- |
| POST /webhooks/revenuecat | store raw event (dedupe on event id) → enqueue `billing_events` → `200` fast | sig |
| POST /webhooks/stripe | store raw event (dedupe) → enqueue; `checkout.session.completed`, `invoice.paid`, `invoice.payment_failed`, `customer.subscription.*`, `charge.refunded` | sig |

### `analytics` (1)
| method path | does | who | input → output |
| --- | --- | --- | --- |
| POST /analytics/events | batch of allow-listed first-party events (`13-…`) | parent / child | `{events:[{name, occurredAt, props}] (≤ 50)}` → `202` |

### `admin` (11)
| method path | does | who |
| --- | --- | --- |
| POST /admin/media/upload-url | signed resumable upload URL into `admin-staging` | perm:content.write |
| POST /admin/media/finalize | verify the uploaded object (type sniff, size, sha256), move it to its bucket, create `media_assets` | perm:content.write |
| POST /admin/content/validate | pre-publish check: assets ready, config valid against the template's JSON Schema, quiz has a correct answer per question, locales complete, age range set | perm:content.read |
| POST /admin/promo-codes/batch | generate N codes | perm:billing.manage |
| GET /admin/support/families?email= | find a family by email (needs `auth.users`) | perm:support.read |
| POST /admin/support/resend-login | send a login email to a family | perm:support.act |
| POST /admin/entitlements/grant | time-limited Plus grant (creates a `promo` subscription) | perm:billing.manage |
| POST /admin/privacy/requests/:id/run | run an export or deletion now | perm:privacy.act |
| POST /admin/users/invite | invite an admin (company domain only) | perm:admin.manage |
| POST /admin/flags/:key | change a feature flag with a reason (audited) | perm:admin.manage |
| GET /admin/analytics/content?from=&to=&activityId= | content performance for editors (design A20): launches, completion rate, average time, drop-off step, by activity / course / collection. Reads `analytics` aggregates; groups under 10 children are suppressed (`13-…`) | perm:content.read |

### `jobs` (7, internal)
| route | trigger |
| --- | --- |
| POST /jobs/process-billing-events | queue consumer |
| POST /jobs/billing-reconcile | cron daily |
| POST /jobs/deletions | cron hourly / queue |
| POST /jobs/exports | queue |
| POST /jobs/notifications-dispatch | cron every minute |
| POST /jobs/weekly-digest | cron hourly on Sundays |
| POST /jobs/maintenance | cron daily |

Count: 10 + 1 + 4 + 4 + 3 + 5 + 2 + 4 + 2 + 2 + 6 + 2 + 1 + 11 + 7 = **64**.

## 7.5 Rate limits (defaults) [P]

| route group | limit |
| --- | --- |
| auth (Supabase) | Supabase defaults, tightened for OTP; plus Vercel firewall limits on the login pages |
| `play/launch` | 60 / min per child |
| `play/sync` | 30 / min per device; ≤ 100 items per call |
| `play/heartbeat` | 4 / min per child |
| `billing/redeem` | 5 / hour per account |
| `account/export` | 1 / day per account |
| `analytics/events` | 30 / min per device |
| `admin/*` | 120 / min per admin |

## 7.6 Key flows mapped to the API

| flow (recon) | calls |
| --- | --- |
| F01 sign-up | child setup (local) → Auth OTP → `POST /onboarding/complete` → `POST /account/devices` → `GET /account/me` |
| F04 play a game | `GET /catalog/home` → `POST /play/launch` → (download pack, play) → `POST /play/sync` → widget updates from the response |
| F05 gift | `POST /play/sync` returns `giftsAvailable` → `POST /rewards/gifts/claim` |
| F08 lesson path | `GET /learning/courses/:id/tree` → `POST /learning/courses/:id/enroll` → launch step → sync → tree refresh shows the unlock |
| F12 progress | `GET /progress/report?days=14` |
| F14 screen time | `PUT /children/:id/screen-time`; while playing `POST /play/heartbeat` every 30 s |
| F15 offline | `POST /library/downloads/manifest` → download → `POST /library/downloads/report`; offline play → later `POST /play/sync` |
| F17 subscribe (mobile) | RevenueCat SDK purchase → `POST /billing/sync` (plus the webhook as backup) |
| F17 subscribe (web) | `POST /billing/checkout` → Stripe → webhook → entitlement |
| F21 delete account | re-auth → `POST /account/deletion` → 7 days → `jobs/deletions` |
