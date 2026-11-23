# Architecture: Kids Learning Platform (a rebuild of Lingokids' core features)

> **Superseded on 2026-11-17** by `docs/architecture/` (the Flutter + Supabase Edge Functions stack from the architecture brief). Kept for history only. Don't build from this file.

Status: **plan only. No application code until you approve this document.**
Date: 2026-11-17. Inputs: `replica/recon.md`, `replica/features.csv` (141 rows), `docs/reconnaissance/*` (incl. 18 screenshots).
Scope decision (2026-11-17): **families first, schools later.** v1 = parent accounts, child profiles, subscriptions. The school layer arrives as an additive migration (`0002_schools`, sketched at the end of `schema.sql`). No v1 table changes for it.

## The shape in one picture

```
            ┌───────────── one monorepo (pnpm + Turborepo) ─────────────┐
            │                                                            │
 iOS ┐      │  apps/mobile   Expo (React Native) ── WebView ─┐           │
 Android ┘  │                                                │           │
            │  apps/web      Next.js (kids player + parent   │           │
 Web ───────│                dashboard + /admin CMS + API) ──┤           │
            │                                                ▼           │
            │  packages/games   ONE HTML5 game runtime (PixiJS) + 12 engines
            │  packages/core    types, zod schemas, API client, rules    │
            │  packages/ui      design tokens (from /replica-design)     │
            └────────────────────────────────────────────────────────────┘
                         │ HTTPS (JWT)                 │ signed URLs
                         ▼                             ▼
     Next.js route handlers (Vercel)  ──►  Supabase Postgres (RLS) + Auth
              │      │       │                Cloudflare R2 (content packs)
              │      │       └──► Mux (video, HLS + offline renditions)
              │      └──► RevenueCat (Apple + Google + Stripe entitlements)
              └──► Inngest (jobs) · Resend (email) · Expo Push
```

**The one decision that shapes everything:** games are written **once** as an HTML5 runtime (`packages/games`) that runs directly in the browser and inside a WebView on iOS and Android. Lingokids publishes activity IDs of the form `game_<mechanic>_<theme>` (recon: game-inventory.md), so their games are templates plus content. We copy that *pattern*: 12 engines, and thousands of activities as data. Native UI (feeds, parent area, players) stays native per platform; only the game canvas is shared.

## Stack

| layer | choice | why |
| --- | --- | --- |
| repo | pnpm workspaces + Turborepo | one repo, shared types and game runtime across 3 apps |
| web | Next.js 15 (App Router) + TypeScript | kids web player, parent dashboard, `/admin` CMS and the API in one deploy |
| mobile | Expo SDK (React Native) + Expo Router, TypeScript | one codebase for iOS and Android; EAS Build, Submit and over-the-air Update |
| games | PixiJS v8 + TypeScript, built as static bundles | fast 2D WebGL with a Canvas fallback; the same bundle runs on web and in `react-native-webview`; small download |
| styling | Tailwind (web), NativeWind (mobile), tokens from `/replica-design` | one token set for both |
| database | Postgres on **Supabase** | managed, RLS built in, cheap at zero users, EU region available |
| ORM | Drizzle | typed SQL, migrations as plain SQL files (`schema.sql` is migration 0001) |
| auth | **Supabase Auth**: email magic link + 6-digit OTP, password, Sign in with Apple, Google | magic link is the original's main login [R16]; OTP fixes "link opened on the wrong device"; Apple is required on iOS once Google is offered |
| payments | **RevenueCat** (App Store + Google Play) + **Stripe Billing** (web), RevenueCat as the single entitlement source | store rules force IAP in the apps; RevenueCat merges Apple, Google and Stripe into one "plus" entitlement, which fixes the original's "paid but no access" [R41] |
| video | **Mux** | HLS streaming, signed playback, static MP4 renditions for offline download |
| files / CDN | **Cloudflare R2** (+ CDN) | content packs (art, audio, config zips); zero egress fees matter with thousands of downloads |
| email | **Resend**, on our own domain with SPF/DKIM/DMARC | login depends on email arriving; deliverability is a must, not a nice-to-have |
| push | Expo Push (APNs/FCM); Web Push later | one API for both stores |
| jobs | **Inngest** | durable, retried jobs for webhooks, deletion, digests; no worker to run |
| search | Postgres full-text + `pg_trgm` | ~5k items doesn't need a search service |
| errors | Sentry with PII scrubbing, **no analytics SDKs in kid screens** | store Kids-category rules and COPPA; product analytics come from our own `activity_completions` |
| hosting | Vercel (web + API), Supabase (DB), EAS (mobile builds) | all managed |

One database. No microservices. The API is the Next.js route handlers; the mobile app calls the same endpoints.

## Schema

**Tables: 43. Access rules: Postgres RLS for reads; all writes go through the API with the service role, after an explicit check.** Full SQL is in `replica/schema.sql`. **It was loaded and tested on Postgres 16 (2026-11-17):** 43 tables, RLS on all 43; a cross-family read was blocked; a duplicate star and a replayed offline event were absorbed; a capped code stopped at its limit; bad rows were rejected.

| group | tables | notes |
| --- | --- | --- |
| identity (5) | accounts, account_members, user_profiles, avatars, children | `accounts.kind` = family \| school; children store **birth month only**, first name only |
| catalogue (14) | subjects, skills, game_engines, activities, activity_subjects, activity_skills, collections, collection_items, lessons, lesson_workbooks, lesson_units, lesson_nodes, sticker_packs, stickers, scenes | lesson → workbook → unit → node from the screenshots [SS-07/10]; `activities.players` = 2 for PlayTogether [SS-11]; engines declare orientation [SS-12] |
| play and progress (11) | activity_completions, star_awards, reward_claims, child_stickers, scene_placements, lesson_enrollments, node_completions, certificates, favorites, daily_free_allocations | append-only events plus derived tables |
| parent controls (2) | screen_time_rules, screen_time_usage | server tally, so limits hold on the web too |
| billing (4) | entitlements, billing_events, redeem_codes, code_redemptions | RevenueCat-fed; every webhook is stored with a unique provider id |
| messaging and admin (7) | push_tokens, news_posts, announcements, announcement_dismissals, referrals, staff_users, deletion_requests | News, Invite a friend and the tooltips come from the screenshots [SS-15/16] |

**Hard rules the database enforces** (not the UI):
- one star per distinct activity per child per day: `star_awards` PK `(child_id, local_date, activity_id)`;
- a gift needs 5 stars and can't be claimed twice: `reward_claims` PK `(child_id, local_date, gift_index)` + an API check `gift_index*5 <= stars`;
- offline events can't double-count: `activity_completions` unique `(child_id, client_event_id)`;
- code over-redemption: `redeemed_count <= max_redemptions` CHECK + `update … where redeemed_count < max returning`;
- one Plus entitlement per account: `entitlements` unique `(account_id, product)`;
- each lesson node completes once: `node_completions` PK `(child_id, node_id)`; a certificate per lesson once;
- Basic allocation ≤ 10 per day: CHECK on `cardinality(activity_ids)`;
- webhooks processed once: `billing_events` unique `(provider, provider_event_id)`.

## API

All routes live under `apps/web/app/api`. Auth = the Supabase JWT in `Authorization`. **"child"** routes also need `X-Child-Id`, verified with `can_access_child`. The kid UI never sends anything to a third party. **Who:** `anon` = no session · `parent` = a member of the account · `staff` = `staff_users` · `system` = a signed webhook.

### Onboarding, auth, account (F01–F03, F19–F21)
| method path | does | who | input | output | flow |
| --- | --- | --- | --- | --- | --- |
| (Supabase Auth SDK) | magic link / OTP / password / Apple / Google sign-in | anon | email or provider token | session | F01 F03 |
| POST /api/onboarding | create the account + owner member + first child (child data held on the device until sign-up) | parent (new) | `{timezone, country, locale, child:{name, avatarId, birthMonth, level}}` | `{account, child}` | F01 |
| GET /api/me | session bootstrap: account, children, entitlement, controls, announcements | parent | — | `MeDTO` | all |
| PATCH /api/account | timezone, locale, marketing/push opt-ins | parent | partial | `account` | F20 |
| POST /api/account/email | start an email change (Supabase verifies the new address) | parent | `{email}` | `202` | F20 |
| DELETE /api/account | schedule deletion (7-day grace); warn if a store subscription is active | parent (owner) | `{confirm:true}` | `{scheduledFor, storeSubActive}` | F21 |
| POST /api/account/deletion/cancel | cancel a pending deletion | parent (owner) | — | `204` | F21 |
| POST /api/push-tokens | register a device push token | parent | `{platform, token}` | `204` | — |

### Children (F13, profile drawer SS-15)
| method path | does | who | input | output | flow |
| --- | --- | --- | --- | --- | --- |
| GET /api/children | list profiles with age and quick status | parent | — | `Child[]` | F13 |
| POST /api/children | add a child (Basic = 1, Plus = 4) | parent | `{name, avatarId, birthMonth, level}` | `Child` or `402 upgrade` | F13 |
| PATCH /api/children/:id | edit name, avatar, birth month, level | parent | partial | `Child` | F13 |
| DELETE /api/children/:id | delete a child and all their data | parent (owner) | — | `204` | — |

### Kids Area: feeds, discovery, play (F04, F06, F07, F16, SS-01/04/11)
| method path | does | who | input | output | flow |
| --- | --- | --- | --- | --- | --- |
| GET /api/feed?tab= | rows for play / theater / playtogether / lessons: published, in-window, age-filtered collections with lock state, favorites, today's stars, section on/off | child | tab | `{rows[], stars, sections}` | F04 F09 F11 |
| GET /api/collections/:id | one world, topic or drop | child | — | `Collection` | F07 |
| GET /api/subjects | subjects with counts | child | — | `Subject[]` | F06 |
| GET /api/search?q=&subject=&type= | full text + trigram over published, age-appropriate activities (videos *and* games) | child | query | `Activity[]` | F06 |
| GET /api/shuffle?tab= | one random eligible, not-played-today activity | child | tab | `Activity` | — |
| POST /api/activities/:id/launch | **the gate for all content.** Checks published, age, Plus or free allocation, section enabled, screen time left, permissions needed. Returns short-lived signed pack URL(s) or a Mux token + `sessionId` | child | `{source}` | `{packUrl \| playback, sessionId, orientation, permissions}` or `402/423` | F04 F09 F16 F22 |
| POST /api/events | **batch sync** of completion events (live and offline queue). Idempotent by `clientEventId`; computes `local_date` from the account timezone; awards stars, node completions, certificates; returns new state | child | `{events:[{clientEventId, activityId, startedAt, endedAt, completed, score?, nodeId?, source}]}` (≤ 200) | `{accepted, duplicates, stars, unlockedNodes, certificates}` | F04 F08 F15 |

### Rewards (F05, SS-01)
| method path | does | who | input | output | flow |
| --- | --- | --- | --- | --- | --- |
| GET /api/rewards | today's stars, gifts available and claimed | child | — | `{stars, giftsAvailable, claimed}` | F05 |
| POST /api/rewards/claim | open the next gift: pick a pack and grant its stickers | child | `{localDate}` | `{stickers[]}` | F05 |
| GET /api/stickers | the sticker album | child | — | `ChildSticker[]` | F05 |
| GET /api/scenes/:id/placements | one scene's placements | child | — | `Placement[]` | F05 |
| PUT /api/scenes/:id/placements | save the scene (full replace; owned stickers only) | child | `Placement[]` | `204` | F05 |

### Lessons (F08, F23, F25, SS-07/10/19)
| method path | does | who | input | output | flow |
| --- | --- | --- | --- | --- | --- |
| GET /api/lessons?kind= | catalogue by stage, with "recommended" first, per child | child | solo \| learn_together | `LessonCard[]` | F08 F23 |
| GET /api/lessons/:id | tree workbook → unit → node, each node with locked / current / done, plus progress-bar % and certificate state | child | — | `LessonTree` | F25 |
| POST /api/lessons/:id/enroll | start or resume; sets `current_node_id` | child | — | `Enrollment` | F08 |
| GET /api/certificates | earned certificates | child | — | `Certificate[]` | F08 |
| GET /api/certificates/:id/pdf | printable certificate (web) | parent | — | `application/pdf` | F08 |

### Favorites and offline (F15, SS-01 row download)
| method path | does | who | input | output | flow |
| --- | --- | --- | --- | --- | --- |
| GET /api/favorites | games and videos lists, newest first | child | — | `{games[], videos[]}` | — |
| PUT /api/favorites/:activityId | add (Plus) | child | — | `204` or `402` | — |
| DELETE /api/favorites/:activityId | remove | child | — | `204` | — |
| POST /api/downloads/manifest | signed URLs + sizes for packs and Mux renditions; used by single, row and favorites downloads | child | `{activityIds[] \| collectionId}` | `{items:[{id, url, bytes, version, expiresAt}]}` | F15 |

### Parent controls and progress (F12, F14, SS-14/15/16)
| method path | does | who | input | output | flow |
| --- | --- | --- | --- | --- | --- |
| GET /api/children/:id/screen-time | rules + today's usage | parent | — | `{rules, usage}` | F14 |
| PUT /api/children/:id/screen-time | set the daily limit, limited categories, section toggles (Play always on) | parent | `ScreenTimeRules` | `ScreenTimeRules` | F14 |
| POST /api/screen-time/heartbeat | +N seconds for a category; returns time left (web and mobile, every 30 s while playing) | child | `{category, seconds}` | `{remainingSeconds, locked}` | F14 |
| GET /api/children/:id/progress?days=14 | the report: completed count, top skill + activity, top 3 subjects, top skills, lesson pre/post (**default 14 days**, as the original [SS-14]) | parent | days (7–90) | `ProgressReport` | F12 |
| GET /api/news | published News | parent | — | `NewsPost[]` | — |
| POST /api/announcements/:id/dismiss | dismiss a tooltip or red dot | parent | — | `204` | — |
| GET /api/referrals | my invite code + status | parent | — | `{code, invites[]}` | — |

### Billing (F02, F17–F19)
| method path | does | who | input | output | flow |
| --- | --- | --- | --- | --- | --- |
| (RevenueCat SDK, mobile) | buy, restore, Apple/Google sheets | parent | — | customerInfo | F02 F17 |
| GET /api/billing/offerings | web prices from Stripe (country-aware) | parent | — | `Offering[]` | F17 |
| POST /api/billing/checkout | Stripe Checkout session (trial supported) | parent | `{priceId}` | `{url}` | F17 |
| POST /api/billing/portal | Stripe customer portal (card, cancel, invoices) | parent | — | `{url}` | F19 |
| POST /api/codes/redeem | redeem a code atomically; grants entitlement source = code | parent | `{code}` | `{entitlement}` or `409/410` | F18 |

### Webhooks in (system)
| method path | does | verification |
| --- | --- | --- |
| POST /api/webhooks/revenuecat | INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, BILLING_ISSUE, TRANSFER → store in `billing_events`, enqueue `billing/process` | shared bearer secret; dedupe on event id |
| POST /api/webhooks/stripe | checkout.session.completed → forward the Stripe subscription to RevenueCat (`POST /v1/receipts`, official API); other events go to RevenueCat directly | Stripe signature; dedupe on event id |
| POST /api/webhooks/mux | video.asset.ready → set the activity's `mux_playback_id` / rendition ready | Mux signature |

**Webhooks out:** none in v1.

### Admin / CMS (staff only; Next.js server actions under `/admin`)
| action | does |
| --- | --- |
| activities.upsert / publish / retire | edit metadata, choose engine + config (validated against `game_engines.config_schema`), upload pack to R2, attach Mux asset |
| collections.upsert / schedule | build rows, worlds and weekly drops with start/end windows |
| lessons.upsert | lesson → workbooks → units → nodes editor |
| stickers / scenes / avatars | reward catalogue |
| codes.create | batches of redeem codes |
| news / announcements | Parents Area News and tooltips |

**Route count: 46 HTTP routes** (42 API, including the certificate PDF, plus 3 webhooks), plus the Supabase Auth and RevenueCat SDK calls and 6 admin action groups.

### Jobs (Inngest)
| job | trigger / schedule | does |
| --- | --- | --- |
| billing/process | each stored billing event | upsert `entitlements` from RevenueCat state (fetch the subscriber, don't trust payload order) |
| billing/reconcile | daily 03:00 UTC | re-sync entitlements expiring in the last or next 48 h with RevenueCat |
| account/delete | daily 04:00 UTC | for due `deletion_requests`: delete the RevenueCat subscriber, the Stripe customer and the Supabase auth users, then delete the account (cascades); log completion |
| mux/renditions | on activity publish | request static renditions for offline |
| parent/weekly-digest | Sundays 09:00 in the account's timezone (*should*) | email: last week's progress |
| content/pack-validate | on pack upload | unzip, check the manifest, size limit (≤ 15 MB), engine version compatibility |
| cleanup/stale-allocations | weekly | delete `daily_free_allocations` and `screen_time_usage` older than 90 days |

## The parts that bite

- **Time zones and day boundaries:** stars, gifts, the Basic 10-a-day and screen time are all "per day". The day is the **household's** local date from `accounts.timezone` (set from the device at onboarding, editable), computed **on the server** with `(event_time at time zone tz)::date`, so changing a device's clock doesn't mint stars. DST is handled by IANA names. Never store offsets.
- **Idempotency:** devices replay their offline queue, and webhooks arrive twice. Every completion carries a device-generated `clientEventId` (unique per child). Every webhook is stored first under a unique provider event id, then processed by a job. All award writes use `insert … on conflict do nothing`.
- **Races:** two devices finishing the same activity, or claiming the same gift, at once: primary keys decide, not code. Code redemption is a single conditional `update … returning`. Entitlement writes are an upsert on `(account_id, product)`.
- **Offline (mobile):** packs and Mux MP4 renditions download to app storage with versioned manifests; the feed shows downloaded items only when offline (as the original does [R27]). Events queue in SQLite (expo-sqlite) and sync on reconnect. Signed URLs expire, so the manifest is refreshed online. Offline Plus access is honoured for up to 7 days from the last entitlement check, then locked.
- **Offline (web):** best-effort only. A service worker + Cache API for packs, a storage-quota meter, and a warning that the browser may evict it (Safari especially). Videos aren't downloadable on web in v1.
- **One game runtime in three places:** WebView performance on low-end Android (4 GB, Android 10–12 [R19]); audio unlock (browsers block sound until a tap: show a "tap to start" splash); touch latency; orientation per engine (portrait stacking [SS-12]). Bridge messages (`ready`, `progress`, `complete{score}`, `needsPermission`, `exit`) are typed and validated; the WebView loads only our bundle origin or local files.
- **Store rules:** iOS/Android digital subscriptions must use IAP inside the apps; the web uses Stripe. **Kids-category rules:** parental gate before purchases, links out and permission prompts [R20, SS-17]; no third-party analytics or ads in kid surfaces; in-app account deletion required. Don't link from the app to web checkout.
- **Child privacy (COPPA / GDPR-K):** collect the parent's email only; child = first name + birth month + avatar. Verifiable parental consent through the parent account flow. No child voice or photo stored in v1 (mic/camera engines deferred). DPA with each processor (Supabase, Vercel, Mux, R2, RevenueCat, Resend, Sentry). EU data region option.
- **Deletion:** account delete cascades in Postgres. The job also removes the RevenueCat subscriber, the Stripe customer and the auth user. Store subscriptions keep billing unless cancelled, so warn the parent (the original warns too [R30]).
- **Content protection:** Plus packs are private in R2, reached only through `launch`/`manifest` with 15-minute signed URLs. Downloaded packs can be copied off a rooted device; accepted risk.
- **Search:** `simple` config FTS + trigram, so short kid-ish queries ("abc") match titles and keywords. Search covers games *and* videos (the original's weak point [R35]).
- **File sizes:** content pack target ≤ 15 MB (validated); app binary small because packs are downloaded on demand; first web load ≤ 300 KB JS for the kids shell, engines lazy-loaded.
- **Email deliverability:** login *is* email. Own domain, DKIM/SPF/DMARC, Resend through Supabase's SMTP setting, OTP code in the same email as the link.
- **Rate limits:** Supabase Auth OTP limits; our own per-user limits on `launch`, `events` (≤ 200 events per call), `codes/redeem` (brute force: 5 per hour per account).
- **Multi-tenancy:** every child-owned row hangs off `children.account_id`; RLS + API checks both use `can_access_child`. Schools reuse the same model.

## Build order

Each milestone lists screens (S-IDs from `docs/reconnaissance/screen-inventory.md`), tables and routes. **No step starts until you approve this plan.**

### M0. Foundations (½ week)
Monorepo, CI, Supabase project, migration 0001, Vercel + EAS projects, Sentry, Resend domain.

### M1. Vertical slice: "sign up, play one game, see it in progress" (2 weeks)
Proves the riskiest bet: **one game runtime on web + iOS + Android.**
- Screens: S01, S02, S03 (no paywall yet), S09 (Play tab, 1 seeded row), S13 (1 engine: **E1 drag-to-target**, 5 seeded activities), S26 drawer (minimal), S28 gate, S32 progress (basic).
- Tables: accounts, account_members, user_profiles, avatars, children, subjects, skills, game_engines, activities, activity_subjects, activity_skills, collections, collection_items, activity_completions, star_awards.
- Routes: Supabase auth, POST /api/onboarding, GET /api/me, GET /api/feed, POST /api/activities/:id/launch, POST /api/events, GET /api/children/:id/progress.
- Exit check: the same activity completes on an iPad, a low-end Android phone and Chrome on a Chromebook; one star appears; a replayed event doesn't add a second.

### M2. Must-haves (≈ 10–12 weeks, in this order)
1. **Content pipeline + CMS:** `/admin` activities, collections, packs to R2, Mux. Engines **E2 memory/match, E3 trace/write, E5 find/hidden objects, E6 quiz** (E6 also powers Knowledge Checks). *Content production starts here, in parallel.*
2. **Theater:** S14, S15 (skill chips, up-next rail, lock) [SS-04/06/08]; Mux; video stars.
3. **Lessons:** S17, S18 (workbook → unit → node, sequential unlock, progress bar), S19, S20 [SS-07/10]; tables lessons…certificates; lesson routes.
4. **Rewards:** S23, S24 (5-star widget [SS-01]); reward routes; sticker tables.
5. **Parents Area:** S28, S31 (portrait list [SS-16]), S33, S34 + heartbeat enforcement, S30 time's-up; S26 drawer with quick actions [SS-15]; screen-time tables and routes.
6. **Billing:** S04, S29, S35, S07; RevenueCat + Stripe; webhooks; entitlements; Basic 10-a-day allocation; launch gating.
7. **Offline:** S36, download buttons (card, row, favorites), SQLite event queue, manifest route; web cache best-effort.
8. **Discovery and stories:** S10 search, S11 collections, S44 audiobook reader (E10), S16 audio; a dedicated Stories entry (fixes a known complaint).
9. **Account:** S37 (email change, delete, log out), deletion job, push tokens.
10. **Progress Report complete:** 14-day window, skeleton empty state [SS-14], lesson pre/post.

### M3. Should-haves (≈ 4–6 weeks)
Favorites (S22) · PlayTogether tab (S21) + **Learn Together lessons (S46)** + 2-player activities · Scene Book (S25) · redeem codes (S08) · engines **E7 runner/catcher, E8 tangram, E9 maze/path, E11 rhythm, E12 stacking (portrait, rotate/drop controls [SS-12])** · shuffle · notifications + weekly digest · per-tab themes · Spanish/Portuguese (and Arabic RTL if targeting the Gulf) · installable PWA.

### M4. Could-haves
Character pick (S45) · Invite a friend · News · announcements/tooltips · printables · monthly achievement cards · mic/camera engines (G32, G33, G37) after a privacy review.

### M5. Schools (after v1): migration `0002_schools`
Classrooms, teachers, roster without emails, shared-device picture-password login, assignments, teacher dashboard, Google Classroom / Clever rostering. Additive only.

### M6. Fixes from `/replica-entrepreneur`
Once it has run (review-mined complaints: free-tier frustration, findability, progress depth, price).

**Timeline honesty:** M0–M2 is roughly **one quarter of engineering for 2–3 developers**, with **content production as the critical path**. Engines are cheap compared with art, voice-over and curriculum for hundreds of activities.
