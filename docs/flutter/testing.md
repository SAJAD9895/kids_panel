# Tests

```bash
cd kids_app
flutter analyze                 # 0 issues
flutter test                    # 293 tests, ~40 s
python3 tool/gen_tokens.py --check   # tokens.g.dart matches docs/design/tokens
../scripts/check-secrets.sh          # no secrets; no server-only key names in kids_app/
```

Last run 2026-11-22 (Phase 13): analyze 0 issues, 293 / 293 passed. Phase 13 added `test/unit/parent_dashboard_test.dart` (22) and `test/widget/parent_dashboard_test.dart` (11); screenshots in `tool/screens/parent_screens_test.dart`; details in `docs/parent-dashboard/testing-report.md`.

Phase 12 run: 260 / 260 passed. Phase 12 added `test/unit/rewards_test.dart` (27) and `test/widget/rewards_test.dart` (14), the `dismissCelebrations` helper, and screenshot rendering in `tool/screens/` (`flutter test --update-goldens tool/screens/rewards_screens_test.dart`); details in `docs/gamification/testing-report.md`.

Phase 11 run: analyze 0 issues, 219 / 219 passed, web release build OK, secret scan clean. Phase 11 added `test/unit/media_test.dart` (26) and `test/widget/media_test.dart` (20) with fake players in `test/helpers/fake_media.dart`; details in `docs/multimedia/testing-report.md`.

Previous: 2026-11-19 (Phase 10): 173 / 173. Phase 10 added `test/unit/games_test.dart` (22) and `test/widget/games_test.dart` (17) with the shared `test/helpers/game_walker.dart`; details in `docs/games/game-testing-report.md`.

Previous: 2026-11-18 (Phase 9): 134 / 134.

Phase 9 added `test/unit/activity_kinds_test.dart` (20), `test/unit/session_engine_test.dart` (17), `test/unit/sync_and_demo_server_test.dart` (5), `test/widget/player_test.dart` (8), `test/widget/engine_extension_test.dart` (1) and 3 player walks in the accessibility test. Details: `testing-report.md`.

Phase 8 added `test/unit/progress_rules_test.dart` (16: island, step, course and path states, Plus locks, next step, recommendations, age) and `test/widget/learning_navigation_test.dart` (11), and extended the accessibility walk to the 11 kid screens at four sizes (4 more tests). Details: `learning-navigation.md` §5. The navigation tests run with "reduce motion" on, because the island's bouncing Pip never settles otherwise.

## Unit (`test/unit`, 35)

| file | covers |
| --- | --- |
| `child_profile_test.dart` | birth month parsing, age, the 1–12 year window (same edges as the SQL), nickname rules, stages, avatar art mapping, the child JSON |
| `auth_and_onboarding_test.dart` | email checks and masking; onboarding body matches `onboard_family` and contains no ids, roles or evidence |
| `parental_gate_test.dart` | words, 5-minute token, wrong answer → new numbers, backspace |
| `guards_test.dart` | every redirect rule, including `next` handling for the gate |
| `app_config_test.dart` | demo mode, prod needs a backend, secret / service-role keys refused, http only locally |
| `error_mapper_test.dart` | Edge Function problem types, Auth error codes, network errors → `Failure`; messages leak nothing |
| `demo_backend_test.dart` | the demo enforces the server's rules (consents, idempotency, plan limit, re-auth) |
| `architecture_test.dart` | domain layer imports; no secret keys or DB URLs in `lib/` |

## Widget flows (`test/widget/flows_test.dart`, 8)

Whole app, real router and controllers, demo backend with no delay, fixed clock and gate numbers, real fonts loaded.

- F01 sign-up end to end at tablet and phone size (including a wrong code first).
- K05 validation (empty, email as nickname, a baby under one year).
- F03 sign-in: unknown email, wrong password, then two children → K35 → switch player → gate (wrong, then right) → add a child → edit → delete → sign out.
- Delete after 15 minutes → P17 fresh code → deleted.
- Basic family adding a second child → limit dialog, nothing lost.
- Children list fails to load → error → "Try again" → list.
- Session ended elsewhere → Welcome; the previous child is not remembered.

## Accessibility and responsive (`test/widget/accessibility_responsive_test.dart`, 6)

Walks all 12 screens at phone portrait (390), phone landscape (844 × 390), tablet (1180) and desktop (1440): Flutter's tap-target (44 dp), labelled-tap-target and text-contrast guidelines, kid controls ≥ 56 dp, and no layout overflow. Plus a 20-character nickname and text at 200 %.

These found and fixed: an unlabelled tap area over the code boxes, the K03 layout overflowing on phones in landscape, and the "Who's playing?" caption sharing a node with the artwork.

## Found by running the web build

Year chips stretched to full width and the nickname field turned grey on mouse hover; both fixed. The tests don't check pixel layout, so a browser pass stays part of each screen's definition of done.

## Not covered yet

- Against a real Supabase project: the Supabase repositories, PKCE, the magic-link deep link, Edge Functions (needs the dev project; then add an `integration_test/` run).
- Golden images, iOS / Android device runs, screen-reader passes (VoiceOver, TalkBack).
