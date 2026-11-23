# Flutter app: foundation (Phase 7)

Date: 2026-11-18. App: `kids_app/` (Android, iOS, web from one codebase).

**Status: the foundation works end to end on the demo backend and in tests. It has not run against a real Supabase project, because none exists yet** (`docs/backend/integration-readiness.md` §4).

| doc | contents |
| --- | --- |
| `architecture.md` | folders, layers, Riverpod providers, routing and guards, design tokens, deviations from `docs/architecture/02-flutter-architecture.md` |
| `environments.md` | dev / prod config, demo mode, the secret-key guard, how to run and build |
| `auth-and-child-profiles.md` | sign-up, sign-in, session, sign-out, the parental gate, child profiles: screens, flows, states, server calls |
| `home-screen.md` | Phase 8: the Kids Area shell and the home screen (K07) |
| `learning-navigation.md` | Phase 8: Home → Subject → Path → Course → Island → Activity, states, data, seed |
| `learning-engine.md` | Phase 9: the reusable activity player, engine, registries, how to add a type |
| `activity-types.md` | Phase 9: the 13 activity types, their JSON, judging rules, age settings |
| `progress-tracking.md` | Phase 9: sessions, `play/sync` → `apply_session`, outbox, interrupted runs |
| `testing-report.md` | Phase 9: what was tested, results, bugs found |
| `../parent-dashboard/` | Phase 13: dashboard, reports and analytics, parental controls, subscription, notifications, testing |
| `../gamification/` | Phase 12: stars ledger, badges, goals, learning-days streak, celebrations, K16, P18, testing |
| `../multimedia/` | Phase 11: videos, songs, stories, media architecture, parental media controls, testing |
| `../games/` | Phase 10: the game collection: catalogue, engine integration, content requirements for the CMS, testing report |
| `implementation-status.md` | every screen's status, the brief checklists, bugs found, next steps |
| `testing.md` | what the tests cover and how to run them |
| `screens/` | screenshots from the web build (demo mode, 1200 × 683) |

## What was built

| task | result |
| --- | --- |
| 1 Clean Architecture structure | `lib/app`, `lib/core`, `lib/features/<feature>/{domain,data,presentation}`; a test fails if a domain file imports Flutter, Supabase, Riverpod or `data/` |
| 2 Riverpod + GoRouter | Riverpod 3 (no code generation, see architecture §6), GoRouter 18 with one pure, unit-tested redirect function |
| 3 Supabase initialisation | `bootstrap.dart`: PKCE, the publishable key only, session in Keychain / Keystore on mobile |
| 4 Environments | `--dart-define-from-file=env/dev.json`; the app refuses to start with a secret key, http in prod, or half a config |
| 5 Auth state | `authStateProvider` (stream), family status, session reset on any user change |
| 6 Registration | K05 child → K06 buddy → K03 email + consents → K04 code → family created → kids home |
| 7 Login | email code (K04) or password (P16); "account not found" offers sign-up |
| 8 Supabase auth | `SupabaseAuthRepository`: `signInWithOtp`, `verifyOTP`, `signInWithPassword`, OAuth (hidden until keys exist), `signOut` |
| 9 Child profile management | P02 list, edit (nickname, birth month, buddy), delete (with a fresh email code after 10 min), "Who's playing?" (K35) |
| 10 Child creation | K05 for the first child (onboarding) and for each later child (Parents Area) |
| 11 Avatar selection | K06, used three ways: onboarding step, add-child step, change buddy |
| 12 Logout + persistence | sign-out with confirmation; Supabase restores and refreshes the session on start |

Backend additions needed for this (the API contracts already existed):

- `supabase/migrations/20261118001400_child_edit.sql`: `private.update_child` (PATCH), with test `supabase/tests/04_child_edit.sql`.
- `supabase/functions/_shared`, `onboarding`, `children`: the first two Edge Functions (type-checked, **not deployed**).

## Run it

```bash
cd kids_app
flutter run -d chrome                                   # demo mode: no backend, code 123456
flutter run --dart-define-from-file=env/dev.json        # against your dev project (environments.md)
flutter analyze && flutter test                         # 0 issues, 80 tests
```

Demo accounts: any new email (code `123456`); `alice@example.test` has two children (password `Demo-pass-123`).

## Not in this phase

(Phase 8 added the Kids Area, Phase 9 the learning engine: see `implementation-status.md`.) `play/launch`, video / song / story players, the plan picker P07 (M8), screen time, reports, password reset page, device registration (`POST /account/devices`), `GET /account/me` (minimum app version, new policy versions), localisation files, Sentry. See the build log `replica/build-log.md`.
