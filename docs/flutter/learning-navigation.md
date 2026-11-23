# Learning navigation

Date: 2026-11-18 (Phase 8). Chain: **Home → Subject → Learning path → Course → Island (lesson) → Activity**, plus Learn, the course list and Me. Screens in `lib/features/learning/presentation/screens/`; screenshots in `screens/`.

## 1. Screens and routes

| screen | route | design | contents |
| --- | --- | --- | --- |
| Home | `/kids` | K07 | `home-screen.md` |
| Subjects | `/kids/subjects` | K21 (explore part) | all subjects as bubbles |
| Subject | `/kids/subjects/:key` | K08 | learning paths that contain the subject's courses, its courses, then its activities with All / Games / Videos / Songs / Stories filters |
| Learn (rail) | `/kids/learn` | K09 area | "My path" (the one for the child's age, marked "Just right for you"), other paths, courses |
| Course list | `/kids/courses` | — | every course as a grid, filter by stage (Tiny … Super) |
| Learning path | `/kids/paths/:id` | — | the path's courses in order on a dotted trail, Nova at the end |
| Course | `/kids/courses/:id` | K09 | description, island count, minutes, % ring, Start / Continue: Island N / Play again, island cards |
| Island | `/kids/courses/:id/lessons/:lessonId` | K10 | steps as stepping stones on a winding trail (a zig-zag downwards on narrow screens), Pip bouncing at the current step, the prize at the end |
| Activity | `/kids/activities/:id?course=&step=` | — | big art, type, minutes, "Play together", "Played before", what it practises (skills), description, Play |
| Me (rail) | `/kids/me` | K17 | buddy, name, stage, treasures, badges, switch player, saved games, change my buddy |
| Watch / Listen (rail) | `/kids/watch`, `/kids/listen` | K12 / K14 area | the collections of that section as rows |
| Change buddy | `/kids/me/buddy` | K06 | the buddy picker; saves through `PATCH /children/:id` |

All `/kids…` routes need a chosen child (else "Who's playing?"). Subject, path, course, island and activity open with `push`, so Back returns along the way the child came. On the web the address bar follows (`GoRouter.optionURLReflectsImperativeAPIs`).

## 2. States

The rules are pure Dart in `lib/features/learning/domain/progress_rules.dart`, unit-tested in `test/unit/progress_rules_test.dart`.

| level | locked ("Later", lock icon) | available ("Start") | in progress ("Now") | completed ("Done", green) |
| --- | --- | --- | --- | --- |
| island | the island before isn't done | first island, or the one before is done | some of its steps done | every required step done |
| step | an earlier required step isn't done, or the island is locked | optional steps of an open island | the first required step not done ("play next", Pip stands here) | done (can be replayed) |
| course | — | nothing started | enrolled, or any step done | enrolment completed, or every island done |
| course in a path | the course before isn't done (and this one isn't started) | first, or the one before is done | as course | as course |

**"Ask a grown-up"** is a separate flag, not a state: Plus courses and Plus activities in a family without Plus show a dark lock chip. Tapping Play or Start opens the K30 sheet, which leads to the parental gate. Children never see a price.

Locked things explain themselves instead of doing nothing: a locked island shakes and says "Finish island 2 first!"; a locked step says "Do the step before this one first!"; an activity opened from a locked step shows "Not yet".

A course opened from the course list or a subject is never path-locked: a path suggests an order but doesn't forbid a course. Only the path screen shows "Later".

The progress ring and bars count **required** steps. "Keep going" picks the first required step not done in the first open island.

## 3. Data

| what | source (RLS) |
| --- | --- |
| subjects, published activities, courses with island counts, learning paths with their ordered courses, live collections | `CatalogRepository.loadCatalog()`: 5 Data API reads in parallel |
| one course's modules → lessons → steps → activities | `CatalogRepository.courseTree(id)`: one embedded select |
| an activity's skills | `activity_skills` + `skills` |
| the child's progress | `ProgressRepository.childProgress(childId)`: step completions, enrolments, the last 40 sessions, daily stars, rewards, favourites, section switches (7 reads in parallel; RLS returns only the parent's own children) |
| Plus | `entitlements` (active `plus`) |

Riverpod: `catalogProvider`, `courseTreeProvider(id)`, `courseTreesProvider(ids)`, `childProgressProvider(childId)`, `familyPlusProvider`, combined in `kidsDataProvider` for the selected child. All are reset on sign-out.

**The app writes nothing here.** Starting a game, earning a star and unlocking a step are server operations (`play/launch`, `play/sync`, `apply_session`, M2); these screens only display what the server recorded. A tampered client can show a lock as open but can't unlock anything.

**Demo mode** has the same content in `lib/demo/demo_catalog.dart`, mirrored from the seed. Keep the two in step.

## 4. Development content (seed)

`supabase/seed.sql` §13 adds, for development only:
- 9 activities;
- 3 courses: Counting to 10 (Plus), Shapes around us (free), Big feelings (Plus), with 5 islands and 10 steps between them;
- a second path, "Little steps" (24–48 months), and Counting to 10 added to "Starting school";
- more collection items;
- Mia's first island completed, and two stickers and a badge for her.

Leo has no progress, so switching between them shows every difference. `supabase/tests/01` T4 now counts published activities instead of expecting 9. All SQL suites pass.

## 5. Tests

`test/widget/learning_navigation_test.dart` (11):
- the whole chain with every state;
- a locked island and a locked step;
- a step opened from an island when it isn't open yet;
- player switching (name, progress, Keep going, both directions);
- the empty database (Home, Learn, Watch, Me);
- an empty subject;
- an error, then "Try again";
- the loading skeleton;
- a Basic family's Plus lock leading to the gate;
- Me and changing the buddy;
- Watch and Listen;
- a section switched off;
- phone portrait.

Plus the accessibility walk over all 11 kid screens at four window sizes.

## 6. Not built yet

Games (Play shows "Almost ready!"); search (K21 search field); Together row and K25; Learn Together courses (K26); check-ins (K27); certificates (K28); the gift and sticker book (K23, K24); the garden (K18); adding and removing favourites; the Basic daily free allocation (10 a day, F-033); screen-time limits (K29); video and audio players.
