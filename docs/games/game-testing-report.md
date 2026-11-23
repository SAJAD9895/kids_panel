# Game testing report (Phase 10)

Date: 2026-11-19. Machine: macOS, Flutter 3.47, Postgres 17. All results below are from this run.

## 1. Summary

| check | result |
| --- | --- |
| `flutter analyze` | 0 issues |
| `flutter test` | **173 / 173 passed** (39 new: `test/unit/games_test.dart` 22, `test/widget/games_test.dart` 17) |
| SQL suites (`scripts/db-verify.sh`): T1–T8, A1–A12, S1–S4, C1, P1, **G1** (new) | all pass, including the new migration and the generated seed §15 |
| `tool/gen_tokens.py --check`, `tool/gen_sfx.py --check`, seed generated from the app's content | up to date |
| `scripts/check-secrets.sh` | no secrets |
| web release build + manual run in a browser | Game room, level picker, Memory Hard (4 × 4, moves, clock), sorting by colour, jigsaw, adding, pause sheet with "Sounds on": work (`screens/`) |
| live Supabase project | **not run**: none exists yet |
| real devices (iOS, Android), real audio output, screen reader pass | **not run** |

## 2. Every game, against the brief

The widget tests play each game through the real app (sign-in → Mia → player), on the demo backend, with the same taps, drags and finger traces a child would use. A shared helper (`test/helpers/game_walker.dart`) answers any item from its content alone, so no game is special-cased.

| brief | how it is tested | games |
| --- | --- | --- |
| **correct answers** | every item of **every level** of **every game** answered right: 8 games × 3 levels, each level judged "Great job!" or "You did it!" | all 8 |
| **incorrect answers** | a wrong pick → "Almost! Try again." + the try-again sound + 1 wrong attempt counted → Try again → right. Where a wrong move is caught on the spot (placing, jigsaw, memory), the wrong drop bounces back ("Not there…") or the cards turn back, it counts as a mistake, and the round still ends right | choice games, Word builder, tracing / Picture match, Sort, Puzzle, Memory |
| **restart and retry** | Try again; **Play again** (new session, `run` 2, same level); "Start over" from Phase 9; Next level | all 8 |
| **progress saving** | each level reported `started` then `completed` with `level`, score, counts; 3 separate sessions per game; outbox empty, no snapshot left; offline finish → "Saved on this device" → sent with the next game; SQL G1 saves a Hard Memory session through `apply_session` (star, level kept) | all 8 |
| **navigation** | Home → Game room → game → activity screen → Play → level picker; Easy → Medium → Hard with **Next level**; no Next level after Hard; Home from the completion screen; pause → Stop for now → reopen → **Keep going** on the same level | all 8 |
| **pause and resume** | the clock stops while paused (`resumedAt` cleared); Sounds off silences effects but keeps the voice; leaving keeps a snapshot with the level and reports nothing as abandoned | Memory (and the shared player) |
| **responsive layout** | the Hard level of every game, every item, at **phone held sideways (844 × 390), tablet (1180 × 820), desktop (1440 × 900)**: tap targets ≥ 44 dp, every control labelled, text contrast, no overflow or exceptions; the 16-card board fits a phone sideways without scrolling (each card ≥ 64 dp) | all 8 |
| **sounds** | the recorded sounds include tap, flip, match, correct, try again and complete at the right moments | all 8 |
| **content** | every level of every game parses for ages 2–10; each game uses the mechanics the brief lists (checked per game); the CMS schema's type list equals the app's registry; the seed equals the app's content (§14, §15) | all 8 |

Unit tests for the new rules: levels (age default, next level, level overrides the age's option count, level in snapshot and report, an Easy board refused for a saved Hard run); adding and taking away (answers, near-miss options, spoken words, invalid sums refused); letter sounds and cases; capitals traced and a different letter rejected; jigsaw (one place per piece, mistakes, hints, invalid grids); shape completion; picture colour and size parsing and descriptions; completion summary.

## 3. Performance and memory

| measure | result | limit in the test |
| --- | --- | --- |
| building all 24 levels × 100 sessions (parse + shuffle) | well under the limit (≈ 2 400 items) | < 2 s |
| judging 10 000 answers (sums + tracing a capital M) | under the limit | < 1 s |
| saved run (snapshot) of the biggest level of each game | under 4 KB each | < 4 KB |
| a session report's metrics | under the server's 8 KB cap (Phase 9 test) | < 8 KB |
| sound assets | 104 KB in all (7 short WAVs) | — |
| widget lifetime | players are `autoDispose`; timers (memory clock, close delay) are cancelled in `dispose`; every widget test fails on a pending timer or a leaked exception, and none did | — |

Frame rate and memory on devices (architecture §8.7: 60 fps, ≤ 250 MB) **need a profile run on real hardware**. These boards are static widgets, not a game loop, so the main risk is image decoding once real artwork arrives. Recommended: `flutter run --profile` on the floor device (Android 10, 4 GB), with DevTools memory and performance views, playing the Hard levels.

## 4. Bugs found by these tests and fixed

| bug | found by | fix |
| --- | --- | --- |
| A stroke starting straight up or down scrolled the page instead of drawing (affects every vertical line: L, T, M, 1…) | phone layout test | the tracing box takes the finger on touch-down |
| The tracing box didn't fit a phone held sideways, so a child had to scroll mid-letter | phone layout test | the box fits the height left, with buttons beside it |
| A new question opened at the previous question's scroll position (the "listen" button half off-screen) | phone layout test | each question starts at the top |
| Memory cards at 64 dp with a word overflowed by 4 px | phone layout test | tile content scales down |
| 16 memory cards wrapped 9 + 7 | browser | the board is exactly *n* columns wide |
| Hard levels showed the same 3 options as Medium for a 4-year-old | browser | Hard levels set 4 options |
| A wrongly dropped token is labelled "cat, not this one", so the next tap targeted the wrong element | widget test | the test helper matches labels by prefix |

## 5. Not covered yet

- A live Supabase project: `play/sync` over HTTP, `games.config` read through the Data API, and the `learning_engine` template row via the CMS.
- Real devices:
  - the frame rate and memory profiling above;
  - `audioplayers` on iOS, Android and Safari (sound may wait for the first tap on web);
  - text-to-speech of the letter sounds ("buh"), which needs a listening check and is best replaced by recorded audio;
  - VoiceOver and TalkBack through a whole game.
- Golden images per game and level.
