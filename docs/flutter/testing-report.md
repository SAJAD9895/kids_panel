# Testing report: learning engine (Phase 9)

Date: 2026-11-18. All results are from this machine (macOS, Flutter 3.47.4, Postgres 17).

## 1. Summary

| check | result |
| --- | --- |
| `flutter analyze` | 0 issues |
| `flutter test` | **134 / 134 passed** (54 new in Phase 9) |
| SQL suites (`scripts/db-verify.sh`): T1–T8, A1–A12, S1–S4, C1, **P1** (new) | all pass |
| Edge Functions type-check (`deno check`): onboarding, children, **play** | pass |
| `scripts/check-secrets.sh` | no secrets |
| `tool/gen_tokens.py --check` | tokens up to date |
| web release build + manual run in a browser | intro, question, try again, hint, correct: works (screenshots in `screens/K11-*`) |
| against a real Supabase project | **not run**: no dev project exists yet |

## 2. What the brief asked to test

| brief | where | how |
| --- | --- | --- |
| every activity type | `test/widget/player_test.dart` (all 13 played through the real player in one session), `test/unit/activity_kinds_test.dart` (each type's parsing, judging, hints, solution) | widget walks a child's taps, drops, swaps and a finger trace; unit tests right, wrong, partial and malformed answers |
| answer validation | `activity_kinds_test.dart` | multi-answer, look-alike letters, interchangeable letters, place mistakes, memory flips, tracing (every built-in glyph passes; wobble passes; half a letter, a shifted letter, a dot and a scribble fail) |
| progress saving | `player_test.dart` (session reported started + completed with score 13/13, item log, outbox empty), `sync_and_demo_server_test.dart`, `session_engine_test.dart` (report contract, quiz responses per attempt, metrics < 8 KB), SQL **P1** | the same rules tested in SQL against `apply_session` and in Dart against the demo server |
| retry | `player_test.dart` (wrong → "Try again" → hint → answer shown after the last try), `session_engine_test.dart` (points per try, can't skip a try-again, nothing accepted after the reveal) | |
| navigation | `player_test.dart` ("Next step" from a lesson opens the next step; Back from "Almost ready!"), `learning_navigation_test.dart` (Play opens the player) | |
| interrupted sessions | `player_test.dart` (stop for now → reopen → "Keep going?" → same session finishes with 3/3; "Start over" reports the old run as abandoned), `session_engine_test.dart` (snapshot round trip, same option order, skip finished item, refuse changed content, pauses don't count as time) | |
| offline | `player_test.dart`, `sync_and_demo_server_test.dart` | outbox keeps the report, next flush delivers it; starts before ends; two flushes don't double-send; rejected reports are dropped |
| extensibility | `test/widget/engine_extension_test.dart` | a new "drum" type, defined only in the test, plays in the unchanged player and is reported |
| accessibility and sizes | `accessibility_responsive_test.dart` (3 new) | every item of every type at phone landscape, tablet and desktop: 44 dp tap targets, labelled buttons, text contrast, no overflow |
| seed = demo content | `session_engine_test.dart` | `seed.sql` §14 parsed and compared with the Dart content; all content parses for ages 2, 4, 6, 9 |

SQL **P1** (`supabase/tests/05_apply_session.sql`):
- started then completed (same id): one star, step completed, enrolment moved to the next required step, daily roll-up;
- replay → duplicate, nothing changed;
- same activity again today → no second star;
- abandoned → time counted, no star;
- another family's child → 404;
- Plus content in a Basic family → recorded, no star;
- future time, bad status, a step of another activity, a draft activity → refused;
- a session id reused for another child → 409;
- quiz answers stored per question;
- not executable by clients.

## 3. Bugs found by these tests and fixed

| bug | found by | fix |
| --- | --- | --- |
| a scribble over the whole box passed the tracing check | unit test | ink-length limit (≤ 2.2× the path) and a stricter stray limit |
| an answer naming an unknown piece crashed the ordering judge | unit test | unknown ids are wrong |
| the answer view was rebuilt when an answer was judged, so the wrong tile wasn't shown | widget test | one view per item, cleared on "Try again" |
| the player read a provider while closing (Riverpod error at teardown) | widget test | the voice service is kept in the screen's state |
| the intro showed the title twice when the intro line matched it | widget test | a matching intro line is hidden |
| on a phone held sideways the memory board didn't fit and scrolled half out of view | accessibility test | the board picks its columns from the screen height |
| the home header showed "0" stars while loading | browser | the counter appears once the number is known |
| `Evaluation` clashed with a `flutter_test` class | compile | renamed `Verdict` |

## 4. Not covered yet

- A live Supabase project: `/play/sync` over HTTP, the real `games` / `questions` embedded reads, RLS on them. The SQL function is tested; the Edge Function is type-checked only.
- Device runs (iOS, Android), real text-to-speech output, a screen reader pass (VoiceOver, TalkBack) through a whole activity.
- The app being killed mid-game on a device (simulated in tests by leaving and reopening).
- Golden images of each type.
