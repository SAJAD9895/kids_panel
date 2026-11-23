# Admin CMS testing report (Phase 14)

Date: 2026-11-21. Machine: macOS, Node 22, Postgres 17, PostgREST 16.6, Deno 2, Chrome, Flutter 3.47.

## 1. Summary

| check | result |
| --- | --- |
| `npm run lint` (ESLint, Next rules) | 0 problems |
| `npm run typecheck` (`tsc --noEmit`, strict) | 0 errors |
| `next build` (production) | builds; 22 routes + middleware |
| Vitest **unit**: `test/unit/game.test.ts`, `rules.test.ts` | **33 / 33** |
| Vitest **integration**: `test/integration/cms.test.ts`, the data layer against the local stack | **30 / 30** |
| Playwright **e2e**: `test/e2e/cms.spec.ts`, the built app in Chrome against the local stack (desktop 1440×900 + tablet 820×1180) | **11 / 11**, three consecutive clean runs after the last fix |
| SQL suites (`scripts/db-verify.sh`), including **X1** (new, `supabase/tests/10_admin_cms.sql`) and the updated schema audit T1 | all pass |
| Flutter `analyze` / `test` (including the new contract and prerequisite tests) | 0 issues / **297 / 297** |
| `deno check` on all Edge Functions (admin, play, children, account, progress, onboarding) | pass |
| design tokens: no hex, px or arbitrary values in components (unit test) | pass |
| `scripts/check-secrets.sh` | no secrets |
| live Supabase project | **not run** (see §5) |

**Intermittent test (not from this phase).** The Phase 10 widget test "pause, sounds off, leave mid-game…" (`kids_app/test/widget/games_test.dart`) failed in two full runs on a busy machine. It passed alone, and the next two full runs passed 297/297. The Phase 13 report noted the same test. It looks timing-dependent and still hasn't been investigated.

## 2. The local stack (how the integration and e2e tests run)

There's no Docker or Supabase CLI on this machine, so `admin_panel/test/stack/stack.mjs` assembles a stand-in for a Supabase project:

| piece | real or stub |
| --- | --- |
| Postgres 17 with **every migration**, `seed.sql`, and `test/stack/seed_admins.sql` (one staff account per role) | **real**: schema, RLS, triggers, functions, storage policies |
| PostgREST 16.6 (schemas `public`, `admin_api`; JWTs checked with a local secret) | **real** Data API |
| the `admin` Edge Function (Deno) | **real** code; service role against the local gateway |
| auth endpoints: password sign-in, refresh, user, TOTP enrol / challenge / verify, sign-out | **stub**. HS256 JWTs with `aal1`, then `aal2` after the code (fixed test code `123456`, password `Admin-pass-123`) |
| storage endpoints: upload (raw or multipart), download, remove | **stub**, but each upload is inserted into `storage.objects` **as the user**, so the real bucket policies (`admin-staging` own-folder, content.write + aal2), size limits and MIME limits decide; files go in a temp folder |

The supabase-js and `@supabase/ssr` clients in the app are unmodified; they talk to the gateway as they would to Supabase.

**What this proves.** The app, the database rules and the Edge Function work together. **What it can't prove** is the behaviour of Supabase's own Auth and Storage servers (§5).

## 3. What the brief asked to test

| brief | tests |
| --- | --- |
| **admin authentication** | e2e:<br>• signed out → `/login` for every admin page;<br>• wrong password; wrong code (no aal2);<br>• first sign-in enrols an authenticator, then gets in;<br>• a **parent account is refused before the factor step**.<br>Integration: aal2 session gets roles and permissions; wrong code gives no aal2 |
| **role permissions** | Integration, as each role:<br>• editor can't approve, can't touch families or billing;<br>• support and finance can't change content;<br>• support can't see the content feed;<br>• finance can't read the audit log;<br>• only super admin changes roles and settings.<br>X1: the same at the SQL level. e2e: support has no content menu and is sent to no-access. Unit: navigation per role |
| **CRUD** | Integration:<br>• activities, games, quizzes (questions and answers);<br>• courses → modules → lessons (ordering, objectives, duration, instructions, prerequisites);<br>• subjects, categories (sub-categories, enable, delete only if unused);<br>• badges, reward rules, plans, settings, admin roles;<br>• search and pagination.<br>e2e: create a game with the builder; a course, module and two lessons with a prerequisite |
| **file uploads** | Integration:<br>• editor's staged PNG is checked, hashed, stored in `public-assets`, registered (`created_by`), staging copy removed.<br>Refused:<br>• another admin's folder (Storage RLS);<br>• a fake PNG (magic bytes; staging removed);<br>• no MFA;<br>• support;<br>• someone else's path in finalize.<br>e2e: upload through the page. Unit: client checks (type, size, `../` names) |
| **content publishing** | Integration:<br>• draft → review → approve (manager) → publish → archive;<br>• anon (the app) sees it **only when published**;<br>• validation blocks an empty game and a course with unpublished activities;<br>• send-back needs a note (audited with it);<br>• impossible moves refused;<br>• **four-eyes**;<br>• approved and published locked for editors.<br>X1: the same, plus a game-config edit counting as the last edit. e2e: editor → review → manager approves and publishes |
| **Flutter content compatibility** | `kids_app/test/unit/admin_cms_contract_test.dart` parses the CMS-built game (every kind, two levels, written by `game.test.ts`) with the app's `ActivitySource.fromConfig` and `KindRegistry`. Unit: every kind round-trips form ↔ item and passes the engine schema. Flutter: lesson prerequisites lock lessons (`progress_rules_prereq_test.dart`, 3) |
| **unauthorized access** | aal1 sessions get nothing (dashboard, writes, uploads, drafts invisible). A parent: `me()` null, families refused. Direct table writes refused:<br>• star ledger;<br>• `admin_user_roles` self-grant;<br>• `subscriptions` status;<br>• `audit_logs` delete.<br>X1: `admin_api` not reachable by anon; service-only functions not client-callable |
| **audit logging** | Integration:<br>• workflow moves with actor and note;<br>• account suspension with reason;<br>• role grants with actor;<br>• star grants;<br>• export runs with the acting admin;<br>• the log can't be deleted.<br>X1: one ledger audit row and one note per star grant; game edits logged under the activity |
| families and privacy | Integration:<br>• search by email;<br>• children show nickname and age only (no birth month or analytics id in the payload);<br>• suspension blocks `launch` and `apply_session` (`ACCOUNT_SUSPENDED`) and lifting it restores them;<br>• star grants bounded, reasoned, once per request;<br>• privacy officer builds a requested export (file stored, status ready), support can't |
| subscriptions | Integration: finance edits plan metadata; editors can't (now an error, not a silent no-op); subscriptions read-only; non-billing staff see none (RLS) |
| responsive | e2e tablet project (820 px): dashboard with the menu bar. Screenshots at 1440 px |

## 4. Bugs found and fixed

| bug | severity | found by | fix |
| --- | --- | --- | --- |
| **Edge Functions sent JSON parameters double-encoded.** `${JSON.stringify(x)}::jsonb` with postgres.js arrives as a JSON *string*, so the SQL function saw no fields. Affected `play/launch`, `play/sync`, `children/:id/goals`, `children/:id/screen-time`, `account/notification-preferences` (Phases 9–13) and `admin/media/finalize`. Never noticed because no Edge Function had run against a database before this stack | **high** | integration (finalize 500), then confirmed with a direct postgres.js test | all six use `db().json(…)` / `jsonb(…)`; a comment in `_shared/db.ts` says why |
| `reward_rules` had content.write policies but no write **grant** (Phase 12), so no admin could change a reward rule | high | integration | grant in the Phase 14 migration (§5 #28) |
| new `app_config` table had no write grant | high | integration | grant; T1 allow-list updated |
| `admin_api.validate` failed with "malformed array literal" when there was a problem to report | high | integration | `array_append` |
| four-eyes counted workflow notes as edits, and ignored game-config edits (games audited without an entity id) | medium | integration, then X1 | notes excluded; the audit trigger records `games` under `activity_id` (§5 #29) |
| a write refused by RLS changed 0 rows and **looked like success** (e.g. an editor "saving" a plan) | medium | integration | `mustOne`: single-row updates and deletes must affect a row |
| a **parent** signing in was offered authenticator enrolment | medium | e2e | the login checks `admin_api.me()` before the factor step and signs non-admins out |
| two forms on a page gave fields the same id, so the "New module" label focused the course title input | medium (a11y and data entry) | e2e | ids from `useId()` |
| the lesson page fetched 5 pages of activities; with fewer than 100 the extra pages failed (416) | medium | e2e | one 100-row query; any page past the end shows empty |
| a missing single value ("New module") said "Check the highlighted fields" with nothing highlighted | low | e2e | the message names the problem |
| every star a child earned was copied into the audit log | low (privacy) | X1 | the trigger fires for `admin_adjustment` only |
| media launch wasn't blocked for a suspended household | medium | review while writing X1 | `private.launch` wrapper |
| the test stub's `auth.uid()` ignored `request.jwt.claims` (PostgREST 12+) | test only | stack | stub fixed |

## 5. Not covered (honestly)

- **A live Supabase project.** Real GoTrue MFA (TOTP secrets, QR codes, code timing), the real Storage API (multipart edge cases, resumable uploads, CDN URLs), Supavisor, deployed Edge Functions, and `admin_api` exposed in the dashboard. The stub reproduces their HTTP contract as supabase-js uses it, not their internals. Before launch, run the flows against a staging project. The e2e suite needs adapting for that (`admin_panel/README.md`).
- **Real authenticator apps.** The stub accepts one fixed code.
- **Large files** (hundreds of MB) and slow connections.
- **Screen readers.** Semantic HTML, labels, focus and dialogs were checked in code and by Playwright's role queries. A manual screen-reader pass hasn't been done.
- **Payments.** Nothing processes payments (by design; `docs/parent-dashboard/subscriptions.md`).

## 6. Screenshots

`docs/admin-cms/screens/`, taken by the e2e run from the real app on the local stack (re-generated on every run):

| file | page |
| --- | --- |
| A01, A02 | sign-in; authenticator enrolment |
| A03 | no access (support on a content page) |
| A04, A04-tablet | dashboard (desktop, tablet) |
| A05 | activity with the game builder, checks and preview |
| A06, A07 | review queue; published activity |
| A08 | lesson editor (prerequisite, duration) |
| A09 | media library after an upload |
| A10, A11 | family (support view); data requests |
| A12–A17 | admin users and role matrix; system settings; audit log; subscriptions; rewards; subjects and categories |
