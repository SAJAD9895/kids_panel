# Rewards testing report (Phase 12)

Date: 2026-11-21. Machine: macOS, Flutter 3.47, Postgres 17.

## 1. Summary

| check | result |
| --- | --- |
| `flutter analyze` | 0 issues |
| `flutter test` | **260 / 260 passed**; 41 new: `test/unit/rewards_test.dart` 27, `test/widget/rewards_test.dart` 14 |
| SQL suites (`scripts/db-verify.sh`), incl. **R1** (new, `supabase/tests/08_rewards.sql`) | all pass, with migration `20261121000100_rewards.sql`, seed §17 (generated) and §18 |
| Edge Functions type-check (`deno check`): children (rewards, goals), play, onboarding | pass |
| design tokens (`tool/gen_tokens.py --check`), no raw colours or sizes in the new UI | pass |
| `scripts/check-secrets.sh` | no secrets |
| screenshots | `screens/G01`–`G05`, rendered from the real app on the demo backend with the app's fonts and the badge art, by `flutter test --update-goldens tool/screens/rewards_screens_test.dart` (not part of the normal suite) |
| live Supabase project | **not run**: no project exists |
| devices | **not run** |

## 2. What the brief asked to test

| brief | tests |
| --- | --- |
| **duplicate reward prevention** | SQL: the same upload again → `duplicate`, no rewards; the same activity again the same day → no star, no ledger row; `apply_rewards` re-run → nothing; a step done again → no second island bonus; the daily goal bonus once. Unit: the ledger's once-only keys; stars only go up. Widget: a flush after the first game sends nothing, and nothing is celebrated twice |
| **achievement unlocking** | SQL: first game (+1 bonus, art path), goal getter, three learning days, first island, course champion, letter explorer, each once. Unit: the ledger grants each once with its bonus; every badge has art in both sizes, bundled, and is in the seed; the brief's achievements all exist. Widget: the badge card, the badge sheet with its earned date, a locked badge with how to earn it, Mia's 3 badges (earned by the rules from her seeded history) |
| **daily goal completion** | SQL: the third different activity completes it (bonus, badge, `justCompleted`); a fourth doesn't again; progress keeps counting; a parent raising the target keeps a reached goal reached; goals off → nothing tracked. Unit: the same in the ledger. Widget: a parent sets 2 → the second game shows the card with "Today's goal reached" and the break suggestion; P18 sets Leo's goal to 1 → Home shows "0 of 1" → the first game reaches it |
| **streak calculations** | Unit: consecutive days; the same day twice = one; one rest day keeps it; two rest days restart and keep the best; still current after yesterday or a rest day, not after two; future days ignored. SQL: 6-day streak with a rest day; two rest days → current 0, best 3 → a new day → 1; one streak row per child; badge |
| **timezone boundaries** | SQL: Dubai midnight (23:57 and 00:01 count for different days, both earn the star); the same instant in London counts for London's day; weeks start on Monday. Unit: server days are calendar dates (no zone shift); week start; day counts across DST |
| **parent/child data isolation** | SQL: Bob can't see Leo, nor any other family's stars, totals, streaks, goals or goal progress; can read Sam's; can't write stars, streaks, badges or rules (privilege / RLS); `rewards_summary` and `set_learning_goals` for another family → 404; functions are service-only. T2 also checks every new `child_id` table automatically. Unit: demo `rewards()` for another family's child → not found |
| **offline and retry** | SQL: a late (offline) day fills the streak. Unit: the sync service queues nothing while offline, queues once when the flush succeeds, and nothing on a replay. Widget: finish offline → no card, balance 0 → back online → the card once, balance 2 → flush again → nothing |
| reward rules | SQL: an admin sets the activity star to 3 → paid 3; switched off → nothing paid. Unit: amounts follow the rules |
| summary | SQL: household today, balance = ledger, every badge with its earned date, counts, goals, streak, learning days; household only. Unit: JSON parsing |
| celebrations | Unit: stars only → banner; priority (course > badge > milestone > week > day > island); lines; the break suggestion. Widget: banner closes itself, no button; the card waits in the parents area and for its own child; **reduce motion** → no running animation; motion on → it animates once and stops |
| screens | Widget: My rewards (balance, goals, learning days, calendar, new for me, achievements, badges, sheets, "How do I get stars?"), error → Try again; P18 (overview, history, how it works, Save off until a change, goals off, Leo's goal); Home hides the goal when goals are off |
| **responsive layout** | Widget: My rewards (top and badges), the celebration card and P18 at **phone, phone sideways, tablet, desktop**: tap targets ≥ 44 dp, labelled buttons, text contrast, no overflow |

## 3. Bugs found and fixed

| bug | found by | fix |
| --- | --- | --- |
| badge art not bundled with the app (pubspec) | rendering the screenshots | folders added; a unit test now checks every dev media folder is bundled |
| the celebration layer (above the router) rebuilt while being built | every widget test after wiring it in | it listens to the router, queue and child, and updates after the frame |
| Home would say "3 of 5" while My rewards said "done" after a parent raised a reached goal | review | Home uses the server's goal status |
| the celebration card's button fell below the fold on a phone held sideways | layout test | the picture shrinks on short screens |
| ledger rows written in one transaction shared a timestamp (unstable history order) | inspecting the seed | `created_at` defaults to `clock_timestamp()` |
| a first-draft badge emblem looked like a well-known video service's logo | reviewing the art | replaced by a dice |
| the seed's Mia had a badge without the facts behind it | review | §18 gives her island steps their stars and runs the real rules, so all 3 of her badges come from the rules |

## 4. Changes to existing tests

| test | change | why |
| --- | --- | --- |
| `T3` (SQL) | Mia's stars 3 → 6 | seed §18 gives her island-1 steps their stars |
| home (learning navigation) | stars = balance; 3 badges | the balance now includes bonus stars, and badges come from the rules |
| games (levels, layout) | close the celebration before "Next level" | the card covers the finish screen until "Yay!" |
| P17 flow | scroll the child page's list | the new "Rewards and goals" button moved "Delete" further down |

## 5. Not covered

- A live Supabase project: Edge routes end to end, RLS through PostgREST, the migration backfill on real data.
- Devices: celebration performance on low-end phones, screen-reader announcements on iOS and Android.
- Golden-image comparisons in CI. The screenshots are generated, not compared.
