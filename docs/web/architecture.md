# Web platform: architecture

Phase 15, 2026-11-21. The web app is in `web_app/`: Next.js 15 (App Router, server components and server actions), TypeScript (strict), Tailwind 4 from the design tokens, and `@supabase/ssr`.

It is a separate app from the admin CMS (`admin_panel/`), with its own deployment, cookies and domain. It has one app with two zones:

| zone | who | paths |
| --- | --- | --- |
| child zone | a child, on the parent's session, with a chosen child | `/who`, `/kids/**` |
| grown-up area | the parent, behind the parental gate | `/parents/**` |
| public | anyone | `/`, `/sign-in`, `/sign-up/**`, `/forgot-password/**` |

**Change from the original plan.** The plan (`docs/architecture/03-nextjs-architecture.md`) had children using Flutter web. This phase's brief asks for the child experience in Next.js, so it is built here. Flutter web stays possible but isn't needed.

## 1. The rule: the parent's own session, the existing backend

```
browser ──httpOnly cookie──▶ Next.js server (pages, server actions, /api/play/*)
                                  │  the parent's JWT + the publishable key
            ┌─────────────────────┼──────────────────────────────┐
            ▼                     ▼                              ▼
   Data API (PostgREST)     Edge Functions                 Storage
   published catalogue,     onboarding, children, play     public thumbnails;
   own children, progress   (launch / sync / heartbeat),   video, audio and story
   — all under RLS          progress, account              pages by short-lived URL
```

**Keys and routes.**
- **No new backend.** No migration, no new table, no new Edge Function. The web app uses the same reads and the same function routes as the Flutter app (Phases 5–13).
- **No service key.** The app holds only the URL and the publishable key. `lib/env.ts` refuses a service-role or secret key, and an e2e test scans the built browser code for keys and database addresses.
- **No API of our own,** apart from one route handler: `/api/play/sync|heartbeat`. It forwards play reports to `play/sync` with the parent's session. It exists so a page that is closing can still send its last report (`fetch` with `keepalive`).

**Checks.** Three layers enforce access:

| layer | checks | from the browser? |
| --- | --- | --- |
| middleware | signed in, for `/who`, `/kids`, `/parents`, `/gate` | the next two still apply |
| page and action (`lib/session.ts`) | a family exists (else finish set-up); a chosen child that RLS returns (else `/who`); the parental gate for `/parents` | the database still applies |
| **database and Edge Functions** | RLS on every read; the household check in every function; `private.launch` (published, age, Plus, switches, daily limit) | **no**: this is the enforcement |

## 2. Data paths

| feature | reads | writes |
| --- | --- | --- |
| sign-up, sign-in, recovery | Supabase Auth (email code, password) | `POST /onboarding/complete` (family, consents, first child) |
| child choice | `child_profiles` (RLS: own household) | a `kl_child` cookie (the child's id; re-checked on every request) |
| catalogue | `subjects`, `categories`, `activities`, `courses` (+ modules, lessons, steps), `learning_paths`, `collections`: **published only**, the same selects as `supabase_learning_repositories.dart` | — |
| progress shown to the child | `lesson_step_completions`, `course_enrollments`, `activity_sessions` + results (resume points), `daily_progress`, `child_star_totals`, `screen_time_rules`, `entitlements` | — |
| games and quizzes | `activities` + `games(config)` + `questions(answers)`, the same select as `play_data.dart` | `POST /play/sync`: started, then completed or abandoned |
| video, songs, stories | `POST /play/launch` (the gate and signed URLs) | `POST /play/sync` (positions in metrics), `POST /play/heartbeat` every 30 s |
| rewards | `GET /children/:id/rewards` | `PUT /children/:id/goals` |
| buddy | `avatars` | `PATCH /children/:id` |
| parent dashboard | `GET /progress/overview`, `GET /progress/report` | — |
| controls | `screen_time_rules`, `screen_time_usage`, `categories` | `PUT /children/:id/screen-time` |
| children | `child_profiles` | `POST /children`, `PATCH` and `DELETE /children/:id` (deleting needs a recent sign-in) |
| notifications | `notifications`, `notification_preferences` | `POST /account/notifications/read`, `PUT /account/notification-preferences` |
| privacy | `parental_consents`, `data_export_requests`, `deletion_requests` | `POST /account/export`, `GET /account/exports/:id/url`, `POST` and `DELETE /account/deletion` |
| subscription | `subscriptions`, `entitlements`, `subscription_plans` | — (no purchase on the web) |

## 3. The learning engine on the web

`src/lib/engine/` is a TypeScript port of the Flutter engine's domain (`kids_app/lib/features/play/domain/`), about 2,600 lines. It covers:
- **Kinds:** all 16;
- **Rules:** levels by age, difficulty policies, judging, hints and solutions;
- **Mechanics:** the seeded shuffle, and tracing geometry;
- **Reports:** the session report and quiz mapping.

**Proven identical.** A golden file made by running the **real Dart engine** (`test/unit/engine-parity.golden.dart`) covers:
- all 16 seeded games, at three ages, at every level;
- the admin CMS fixture.

The TypeScript port reproduces it exactly (375 items):
- the same option order, for the same session id;
- the same hints;
- byte-identical `/play/sync` items.

So a game played on the web and on a phone saves the same thing.

**UI on top.** `src/components/play/` holds:
- `player.tsx`: the run, feedback, hints, sound, summary and reports;
- `views.tsx`: one view per answer type (choice, place, order, memory, trace);
- `picture.tsx`: the app's picture references drawn in SVG, with tokens.

## 4. Sessions and cookies

| cookie | set by | content | life |
| --- | --- | --- | --- |
| `sb-…` | `@supabase/ssr` | the Supabase session (access and refresh token) | refreshed by middleware; sign-out clears it (optionally on every device) |
| `kl_child` | choosing a child (server action) | a child id: not a secret, re-checked under RLS on every request | 1 year, httpOnly, SameSite=Lax |
| `kl_gate` | sign-in, or the gate question | an expiry time | 15 minutes, httpOnly; cleared when a child is chosen or "Back to playing" |

**What the gate is for.** It keeps young children out of the grown-up pages, as in the app. The data itself is protected by the parent's session and RLS, not by the gate.

## 5. Code layout

| path | purpose |
| --- | --- |
| `src/lib/session.ts`, `kid.ts` | the family, the chosen child, the gate, and the per-request child context |
| `src/lib/data/*` | catalogue, progress, launch, rewards, parent dashboard, family |
| `src/lib/rules.ts` | lesson states, visibility, resume points (ported from the app, unit-tested) |
| `src/lib/engine/*` | the learning engine port |
| `src/lib/edge.ts`, `errors.ts`, `notices.ts` | Edge Function calls with the parent's JWT, refusal wording, notice wording |
| `src/components/*` | grown-up primitives (from the admin app), kids primitives (tiles, shelves, buttons, nav), buddies, icons, charts, players |
| `src/app/(auth)`, `who`, `gate`, `kids`, `parents` | 39 routes in all |
| `test/stack/` | the local stand-in for a Supabase project used by the tests (`testing-report.md`) |
