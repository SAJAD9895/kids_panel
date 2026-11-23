# Admin CMS: architecture

Phase 14, 2026-11-21. The staff web app is in `admin_panel/`. It is built with:
- Next.js 15 (App Router, server components and server actions);
- TypeScript, Tailwind 4 and `@supabase/ssr`.

It runs on the **existing Supabase backend**: the same tables, RLS policies, live-content guard, audit triggers and admin roles as Phases 5–13. It adds one migration (`20261123000100_admin_cms.sql`) and one Edge Function (`admin`).

## 1. The one rule: the admin's own session

```
browser ──cookie──▶ Next.js server (pages, server actions)
                          │   admin's JWT (anon/publishable key + session)
                          ▼
             Supabase Data API (PostgREST)                    Supabase Storage
             ├─ public.*     content tables, under RLS        admin-staging/<uid>/… (upload policy)
             └─ admin_api.*  security-definer functions,           │
                             each checks the permission            ▼
                                                    Edge Function `admin` (service role, server)
                                                    ├─ POST /admin/media/finalize
                                                    └─ POST /admin/exports/:id/run
```

**Keys.**
- The Next.js app holds **only** the public URL and the publishable (anon) key. `src/lib/env.ts` refuses to start with a service-role or `sb_secret_` key, and a unit test checks this.
- There is no database URL and no service key anywhere in `admin_panel/`.

**Checks.** Every query runs as the signed-in admin. The checks happen in three places:

| layer | what it checks | can it be bypassed from the browser? |
| --- | --- | --- |
| middleware | a session exists, else `/login` | the next two layers still apply |
| page and action (`lib/auth.ts` `requireAdmin`) | admin row, MFA (`aal2`), not suspended, the page's permissions | the database still applies |
| **database** | RLS on every table (`has_permission`, which requires `aal2`); the live-content guard; `admin_api` functions call `private.require(permission)` first; triggers write the audit log | **no**: this is the enforcement |

**Privileged work.** Work that needs the service role, such as moving files between buckets or building a family's export, is done by the `admin` Edge Function:
1. The function verifies the admin's JWT.
2. It checks `aal2` and `private.admin_can(user, permission)` itself.
3. It writes the acting admin into the audit log.

## 2. Data paths per module

| module | reads | writes |
| --- | --- | --- |
| dashboard | `admin_api.dashboard()` (counts) and `admin_api.activity()` | — |
| subjects, categories | tables | tables (RLS `content.write`; enabling a category needs `content.publish`) |
| activities, games, quizzes | tables (drafts visible with `content.read`) | `activities`, `games.config`, `questions`/`answers`, `activity_media` |
| courses, modules, lessons, steps | one embedded select | tables; ordering by swapping positions |
| workflow | `admin_api.validate()` | `admin_api.transition()` |
| media | `media_assets` | Storage `admin-staging` → `admin` function → `media_assets` |
| rewards | `rewards` (badges), `reward_rules` | the same tables |
| families | `admin_api.families()` / `family()`: minimum data | `set_account_status`, `grant_stars`, `cancel_deletion` |
| data requests | `admin_api.privacy_requests()` | `admin` function `exports/:id/run` |
| subscriptions | `subscription_plans`, `subscriptions`, `payments` (RLS `billing.read`) | plan metadata only (`billing.manage`) |
| admin users | `admin_api.users_list()` | `admin_api.set_roles()` / `set_admin_status()` |
| settings | `app_config` | `app_config` (`admin.manage`, values validated by a trigger) |
| audit log | `admin_api.activity()` (`audit.read` for everything; `content.read` for the content feed) | append-only, triggers only |

## 3. How published content reaches the Flutter app

Nothing new is needed. The app already reads the catalogue through the Data API under the parent's session. RLS shows parents **only `status = 'published'`** rows and their child rows: games, questions, media and lessons. The steps from the CMS to a child:

1. The editor saves a game. This writes `games.config` in the learning engine's own format (`game-builder.md`).
2. A content manager approves. This locks the content.
3. A content manager publishes. This sets `published_at` and `published_by`, and bumps `content_version` if it was published before.
4. The app's next catalogue fetch includes it. `private.launch` lets children open it, and media are served through short-lived links.

Two tests check this:
- The integration test "the kids app sees it only then" checks visibility as `anon` at each step.
- `kids_app/test/unit/admin_cms_contract_test.dart` parses a game built by the CMS with the app's own `ActivitySource.fromConfig` and `KindRegistry`.

**Lesson prerequisites** (new) are read by the app: `supabase_learning_repositories.dart` selects `prerequisite_lesson_ids`, and `progress_rules.dart` keeps a lesson locked until they're done.

## 4. The migration (`20261123000100_admin_cms.sql`)

The full list is in `docs/backend/database-schema.md` §5, items 22–29. In short:

| # | change |
| --- | --- |
| 22 | `approved` status on activities and courses. `is_live` treats approved as live (locked) |
| 23 | courses: category, difficulty, objectives. Lessons: description, objectives, instructions, estimated minutes, prerequisite lessons (trigger: same course, not itself) |
| 24 | `app_config` table (settings), with a validation trigger, audit and admin-only RLS. `private.goal_default()` is used by the rewards and report functions |
| 25 | `star_transactions.reason` gains `admin_adjustment`, with an audit trigger for those rows |
| 26 | a suspended household can't record play (`apply_session`) or open media (`launch`): `ACCOUNT_SUSPENDED` |
| 27 | schema `admin_api` with 14 functions (security definer, permission first) |
| 28 | write grants for `app_config` and `reward_rules` (RLS decides) |
| 29 | the audit trigger records `games` rows under their activity id |

No table was duplicated. Everything else reuses Phase 5 structures: the RBAC tables, `audit_logs`, the `admin-staging` bucket and policy, and the content tables.

## 5. Code layout (`admin_panel/`)

| path | purpose |
| --- | --- |
| `src/lib/env.ts`, `supabase/{server,browser}.ts` | configuration and clients (public key only) |
| `src/lib/auth.ts`, `permissions.ts` | session state (signed out, needs MFA, not admin, suspended, ok), `requireAdmin`, navigation by permission |
| `src/lib/data/*.ts` | **the data layer**: every read and write, the same functions the pages and integration tests call |
| `src/lib/validation.ts`, `actions.ts`, `errors.ts` | zod input schemas, form-action wrapper, database error → sentence (`must`, `mustOne`) |
| `src/lib/game/*` | game builder: kinds, form ↔ item, Ajv validation against the engine's JSON Schema |
| `src/components/*` | UI primitives (tokens only), forms, workflow, game builder, quiz editor, uploader |
| `src/app/(admin)/…` | 19 pages (see `content-management.md`, `permissions.md`) |
| `scripts/sync-tokens.mjs` | generates `src/app/theme.css` from `docs/design/tokens/tokens.css` and copies the engine schema |
| `test/` | unit, integration (local stack), e2e (Playwright), see `testing-report.md` |

**Design tokens.** Every colour, space, radius, size and type style is a token class, such as `bg-ui-primary`, `p-s5` or `text-ui-h1`. A unit test fails on any hex colour, px value or arbitrary Tailwind value in a component.

**Responsive layout.**
- **Desktop (≥ 1024 px):** a sticky sidebar.
- **Tablet and phone:** a top bar with a Menu button.
- Forms use one column on narrow screens and two on wide ones. Tables scroll inside their card.

## 6. Running it

```bash
cd admin_panel
cp .env.example .env.local   # NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
npm install
npm run dev                  # http://localhost:3000
npm run lint && npm run typecheck && npm test && npm run e2e
```

`node test/stack/stack.mjs` starts the local stack, described in `testing-report.md`. It prints the two variables to run the app against local data with no Supabase project.

**Project setup** (manual, once; also in `docs/backend/integration-readiness.md`):
1. Add `admin_api` to the Data API's exposed schemas: Dashboard → API settings.
2. Enable TOTP MFA: Auth → MFA.
3. Deploy the `admin` function.
4. Create the first super admin with SQL:

```sql
insert into admin_users (user_id) select id from auth.users where email = '<your staff email>';
insert into admin_user_roles (user_id, role_key) select id, 'super_admin' from auth.users where email = '<your staff email>';
```

After that, every other admin is added in the app (Settings → Admin users).
