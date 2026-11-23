# Flutter implementation status

Updated 2026-11-22 after Phase 13 (parent dashboard: `docs/parent-dashboard/`). Phase 12: rewards (`docs/gamification/`). Phase 11: multimedia (`docs/multimedia/`). Phase 10: the game collection (`docs/games/`). Phase 9: the learning engine (`learning-engine.md`, `activity-types.md`, `progress-tracking.md`, `testing-report.md`). App: `kids_app/`. Checks: `flutter analyze` 0 issues; `flutter test` **293 / 293**; web release build OK and the player checked in a browser; SQL suites (T1–T8, A1–A12, S1–S4, C1, P1, G1, M1, R1, D1) pass. **Nothing has run against a real Supabase project yet**: no dev project exists (`docs/backend/integration-readiness.md` §4).

## 1. Screens

| id | screen | phase | status | notes |
| --- | --- | --- | --- | --- |
| K01 | Splash | 7 | done | |
| K02 | Welcome | 7 | done | |
| K03 | Grown-up sign-up + consents | 7 | done | Apple / Google hidden until keys |
| K04 | Code | 7 | done | |
| P16 | Password sign-in | 7 | partial | no reset page |
| K05 | Child details | 7 | done | |
| K06 | Buddy picker | 7 | done | also from Me (Phase 8) |
| K35 | Who's playing | 7 | done | plus the player switcher sheet (Phase 8) |
| K07 | Home | 8 | done | all sections from the brief; Together row and search not yet |
| — | Kids shell (rail / bottom bar) | 8 | done | sections hidden when switched off |
| K21 | Subjects (explore part) | 8 | partial | no search field yet |
| K08 | Subject | 8 | done | |
| — | Learn | 8 | done | |
| — | Course list | 8 | done | |
| — | Learning path | 8 | done | |
| K09 | Course | 8 | done | |
| K10 | Island | 8 | done | |
| — | Activity details | 8 | done | Play shows "Almost ready!" |
| K17 | Me | 8 | done | garden (K18) not yet |
| K11 | Game player | 9–10 | done | eight games with levels (docs/games/) |
| K12 / K14 / K15 | Watch / Listen (songs, stories) | 11 | done | docs/multimedia/ |
| K13 / K32 / K33 | Video player / book reader / audio player | 11 | done | |
| K29 | Time's up | 11 | done | "That's all for today!" |
| K16 | Rewards | 12 | done | stars, goals, learning days, badges (docs/gamification/); gift arc and stickers (F05) not yet |
| P03 | Screen time + sections | 11, 13 | done | all four section switches, categories, limit |
| P18 | Rewards and goals (new) | 12 | done | |
| K30 | Ask a grown-up sheet | 8 | done | |
| K20 | Parental gate | 7 | done | |
| P01 | Parent dashboard | 13 | done | every child: time, lessons, games, streak, stars, badges, goals, recent |
| P04 | Progress report + analytics | 13 | done | day / week / month, six charts with tables |
| P06 | Subscription | 13 | partial | store links; buy / restore / Stripe portal not connected |
| P11 | Notifications | 13 | partial | in-app inbox + preferences; email / push not connected |
| P12 | Privacy and data | 13 | done | consents, export, account deletion |
| P02 | Children | 7 | done | |
| P17 | Re-auth | 7 | done | |
| K18, K23–K28, K31, K34, K36, K37, P05, P07–P10, P13–P15 | garden, gifts and stickers, Together, certificate, paywall, reports, settings | — | not started | roadmap |

## 2. Brief checklist (Phase 8)

| requirement | status |
| --- | --- |
| personalised welcome | ✓ name and buddy of the selected child |
| avatar and profile switcher | ✓ rail / header buddy → switcher; switches all data |
| daily goal and progress | ✓ 3 stars a day from `daily_progress` (fixed goal, see home-screen.md §5) |
| continue learning | ✓ Keep going → current island |
| subject / category cards | ✓ subject bubbles; categories exist in the schema but aren't surfaced (no category screen in the design) |
| recommended activities | ✓ Games for today |
| recently played | ✓ Played lately |
| achievements / rewards preview | ✓ My treasures; badges on Me |
| Home → Subject → Path → Course → Lesson → Activity | ✓ |
| locked / unlocked / completed / in-progress | ✓ plus "Ask a grown-up" for Plus |
| real data from Supabase | ✓ repositories written against the schema (Data API, RLS); **untested on a live project** |
| loading / empty / error states | ✓ skeletons; friendly empty states; Bolt + Try again |
| dev seed data | ✓ seed §13 |
| tokens, big targets, original art, animations, responsive | ✓ (no new tokens were needed) |
| tests: navigation, empty DB, switching, loading / error | ✓ 11 widget tests + 16 unit tests + accessibility walks |
| no games | ✓ |

## 3. Bugs found and fixed while building

| bug | found by | fix |
| --- | --- | --- |
| after switching child, the previous child's progress showed under the new name until loading finished | navigation test | skeletons whenever the data is reloading |
| the home page kept the previous child's scroll position | navigation test | the page is keyed by child id |
| the header's title, stars and Grown-ups button were one screen-reader node | test lookup | every control is its own node |
| an animated shadow could get a negative blur (bounce curve overshoot) and crash the rail | test | standard curve where shadows animate |
| a message bar covered the buttons of a sheet | test hit-check | sheets dismiss message bars |
| subject and rail captions failed the contrast check together with their coloured tiles | accessibility walk | caption outside the button's node |
| on the web, pushed pages didn't update the address bar | browser | `optionURLReflectsImperativeAPIs` |

## 4. Known gaps and next steps

1. **Run against a real project.** Create the dev project, push the migrations and seed, then sign in as `alice@example.test` and walk the chain. The embedded selects (`courses → course_modules → lessons → lesson_steps → activities`) and the `entitlements` read are the parts most worth checking.
2. ~~Game host K11, `play/sync`, `apply_session`~~ done in Phase 9 (13 activity types, stars and unlocks server-side). Still to do: `play/launch` (Plus / free allocation / screen-time gate), `play/heartbeat`, gifts / mastery / badges in `apply_session`, video / song / story players, real artwork and recorded voice, then `catalog/home`.
3. Favourites write route; Basic free allocation (F-033); Together row; search.
4. Thumbnails from Storage instead of drawn placeholders, once media exists.
