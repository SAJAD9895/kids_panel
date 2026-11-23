# Parent dashboard testing report (Phase 13)

Date: 2026-11-22. Machine: macOS, Flutter 3.47, Postgres 17.

## 1. Summary

| check | result |
| --- | --- |
| `flutter analyze` | 0 issues |
| `flutter test` | **293 / 293 passed**; 33 new: `test/unit/parent_dashboard_test.dart` 22, `test/widget/parent_dashboard_test.dart` 11 |
| SQL suites (`scripts/db-verify.sh`), incl. **D1** (new, `supabase/tests/09_parent_dashboard.sql`) | all pass, with migration `20261122000100_parent_dashboard.sql` |
| Edge Functions type-check (`deno check`): progress, account (new), children, play, onboarding | pass |
| design tokens (`tool/gen_tokens.py --check`); no raw colours in the new UI | pass |
| `scripts/check-secrets.sh` | no secrets |
| screenshots | `screens/D01`–`D07`, rendered from the real app on the demo backend (`flutter test --update-goldens tool/screens/parent_screens_test.dart`) |
| live Supabase project, devices | **not run** |

**Flaky test.** In one full run, an existing Phase 10 games test failed ("pause, sounds off, leave mid-game…"). It passed alone and in the next two full runs. It isn't related to this phase and wasn't investigated further. It is noted here so it isn't lost.

## 2. What the brief asked to test

| brief | tests |
| --- | --- |
| **multiple children** | the dashboard shows both of Alice's children, with Leo's empty state; the report's child picker switches to Leo; Bob's overview has only Sam (D1); separate goals, exports and notices per child |
| **progress calculations** | D1 plays known sessions for Leo (minutes, scores, right answers, levels, one stopped early) in a past week and checks every number. Unit: the demo report adds up from Mia's sessions (the seed's numbers) |
| **report accuracy** | D1 checks:<br>• time 1440 s; 5 sessions; 4 finished; 3 different activities; 3 learning days;<br>• the daily series sums to the total;<br>• the previous week;<br>• the game's average, best, right answers and levels;<br>• completion by kind; the quiz's last score; scored sessions;<br>• 8 weeks of consistency;<br>• the day and month windows; a bad period is refused.<br><br>The dashboard's numbers equal the source tables. Unit: JSON parsing of every block; a period that hasn't started has no goal rate (not 0 %); strengths and practice only with enough evidence |
| skill mastery | D1: the first evidence moves halfway towards the score (weighted); a same-day repeat counts half. Unit: the same in the demo |
| **parental controls** | Widget:<br>• Learn switched off is saved, and the kid zone follows;<br>• notification settings saved;<br>• a child export;<br>• account deletion scheduled, then kept.<br><br>Existing tests cover the rest: child add, edit, avatar and delete; media switches, categories and limit; goals |
| **authorization** | Widget: every new parent route opened from the kid zone shows the grown-up gate. Widget: account deletion after 15 minutes asks for a fresh email code. Unit: export needs a recent sign-in, 5 a day. D1: another household's report, export or file → 404; account deletion is owner-only (SQL from Phase 5) |
| **database access permissions** | D1, as a signed-in parent:<br>• sees only their own notices and export requests;<br>• can't update notices, create exports or write preferences directly;<br>• can't run the report, overview or notification job.<br><br>A8: no new function is callable by clients. T1: new tables keep RLS and no client writes. T2: isolation on every `child_id` table |
| notifications | D1:<br>• a goal reached gives exactly one notice, only for that household;<br>• switched off → none;<br>• unknown types refused; mark read;<br>• the weekly summary on the household's Monday, once (re-run → no duplicate), not for a parent who switched it off;<br>• billing issue on a status change; trial ending;<br>• export ready; deletion scheduled.<br><br>Unit: each type's wording; nicknames filled in on the device |
| export | D1: a child's export holds only that child; the account export holds the account, consents and both children; no file before it's ready; another household → 404; the sixth export of the day → 429 |
| subscription | Widget: Plus from a code ("ends by itself", test tag, restore says not connected); Basic shows the plans, and choosing one says not connected; no link opened. Unit: store links per provider; Plus expiry |
| **responsive layouts** | Widget: dashboard (top and a child card), report (top and tables), notifications, privacy, subscription at **phone, phone sideways, tablet, desktop**: tap targets ≥ 48 dp, labelled buttons, text contrast, no overflow |
| loading, empty, error | Widget: an empty report period ("No activity in this week"); Leo with nothing played. The error and loading views are the shared ones |

The contrast check is skipped on the report's scrolled table view only. Rows scrolled under the app bar are misread as low contrast; the same page passes at the top.

## 3. Bugs found and fixed

| bug | found by | fix |
| --- | --- | --- |
| **unscored activities were saved with score 0** (Phase 9: `greatest(null, 0)` is 0), so a video counted as 0 % in subject averages | D1 (report accuracy) | `apply_session_core` redefined with no score kept as null |
| `progress_report` marked `stable` but writes a temp table | first run | made volatile |
| an export payload read in the same statement as its request didn't see the request | D1 | `export_payload` volatile; the test calls them separately |
| a new SQL helper was callable by clients | A8 (schema audit) | revoked |
| "Manage children" and "Sign out" were pushed below the child cards | existing widget tests | "Manage children" moved into the children header; the test scrolls to Sign out |
| child-card tiles stacked one per row on phones | screenshots | two to four per row depending on width |

## 4. Not covered

- Live Supabase: the Edge routes end to end, Storage upload of exports, pg_cron.
- Email and push delivery (not connected).
- Store and Stripe flows (not connected, see `subscriptions.md`).
