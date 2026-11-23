# Kids home (K07) and the Kids Area shell

Date: 2026-11-18 (Phase 8). Design: `docs/design/README.md` §2 and §4, mockup `docs/design/screens/K07.png`, states `docs/design/states.md`. Screenshots of the build: `screens/K07-home.png`, `screens/K07-home-rows.png`.

## 1. Shell

`lib/features/kids_home/presentation/widgets/kids_shell.dart`, a GoRouter `ShellRoute` around every `/kids…` route.

| | wide or landscape windows | narrow portrait windows (< 600, taller than wide) |
| --- | --- | --- |
| navigation | left rail, 112 dp with labels (≥ 840) or 88 dp icons only | bottom bar with icons and labels |
| player | the child's buddy at the top of the rail | buddy button at the left of the page header |
| items | Home, Learn, Watch, Listen, Me (design v1.0) | same |

- Rail items for sections the parent switched off (`screen_time_rules.*_enabled`) are hidden. Games (Home) and Me always stay.
- System back on a rail root does nothing, so a child can't leave by accident. Inner pages have a big back button.
- Phones are held in landscape in the Kids Area (`OrientationScope`); tablets and the web are free.
- Page changes fade and rise slightly (`Motion.base`); with "reduce motion" there is no transition.

**Player switcher.** Tapping the buddy opens a sheet with every child's buddy and name. Picking one switches the whole Kids Area: every progress provider is keyed by child id, the page scrolls back to the top, and skeletons show until the new child's data has arrived. The previous child's progress is never shown under the new child's name; a test caught exactly that during the build.

## 2. Home sections, top to bottom

| section | what it shows | data | states |
| --- | --- | --- | --- |
| header | "Hi, Mia!", stars collected, Grown-ups button | `selectedChildProvider`, `daily_progress` | — |
| Keep going | the course the child is in, the current island and next step, a % ring and Bolt; "Continue" opens the island. Without a course: the first course of the path for their age, labelled "Start here" | `course_enrollments`, `lesson_step_completions`, course tree | skeleton block while the tree loads |
| Today's stars | the daily goal: 3 stars (one per different activity per day, the server's rule), filled stars and how many games are left; "You did it today!" when full | `daily_progress` for today | — |
| Explore | subject bubbles (subjects with content first), "all subjects" button | `subjects`, activity and course subject ids | — |
| Games for today | recommendations: the home "daily picks" collection first, then other games for the child's age; ones not played lately before ones played; open before Plus-locked | `collections`, `activities`, `activity_sessions`, entitlement | hidden when empty |
| Played lately | last activities played, newest first, one per activity | `activity_sessions` | "Games you play will show up here." |
| My treasures | stars, stickers, badges; "See all" opens Me | `daily_progress`, `child_rewards` | zeros are shown as zeros |

Page states: skeletons while loading; Bolt with "Try again" on error (no error text for children); with an empty catalogue: "New games are on their way!".

## 3. Cards and controls (shared, `features/learning/presentation/widgets/kid_widgets.dart`)

| widget | notes |
| --- | --- |
| `ActivityCard` | 240 dp, art on the section's soft colour (games orange, videos teal, songs and stories yellow), type chip, title (2 lines then …), star when saved, dark "Ask a grown-up" chip when Plus-locked. One button for screen readers ("Game, Shape homes, ask a grown-up") |
| `CourseCard` | subject colour and icon, island count, Start / Now / Done / Later or "Ask a grown-up", progress bar when started |
| `SubjectBubble`, `TileWithCaption` | 108 dp tile; the name below is tappable too but kept out of the button's node |
| `ProgressRing` | animates to its value (`Motion.celebrate`), announced as "38 percent done" |
| `StarCounter`, `TypeChip`, `StateBadge`, `ShelfTitle`, `Shelf` | rows scroll sideways and never wrap; the next card peeks |
| `PopIn` | cards spring in, staggered; skipped with "reduce motion" |
| `showAskGrownUpSheet` (K30) | Nova, "Ask a grown-up!", "Get a grown-up" → parental gate. No prices, no "buy" |
| `showComingSoonSheet` | the Play button until games exist ("Almost ready!") |

Art is ours and drawn in code: characters for some activities, a large type icon for others, chosen from the slug so a card always looks the same. Subject icons are Material Symbols (Apache 2.0) in the token colours. Thumbnails from Storage replace the placeholders when real media exists.

## 4. Accessibility

- Every control is its own screen-reader node with a spoken label. Building this found the header's title, stars and Grown-ups button merged into one node; fixed.
- Touch targets: kid controls ≥ 56 dp (64 for main buttons); cards are whole-card buttons.
- Tested at 390 × 844, 844 × 390, 1180 × 820 and 1440 × 900 for tap targets, labels, text contrast and overflow (`test/widget/accessibility_responsive_test.dart`).
- "Reduce motion" stops the bouncing, pulsing and pop-ins.

## 5. Interim decisions (to revisit)

| decision | why | later |
| --- | --- | --- |
| Home is composed in the app from Data API reads, not `GET /catalog/home` | the reads are allowed by RLS and enough for display; no Edge Function exists yet | move composition (entitlement, free allocation, screen time) server-side with `catalog/home` (M2) |
| The daily goal is a fixed 3 stars | the schema has no per-child goal | a parent setting, if wanted (open question) |
| "Today" is the device's date | the household day is server-side; the device is normally in the same timezone | read `local_date` from the server with `catalog/home` |
| The whole published catalogue is loaded once per session | tens of rows today | page it, or move to `catalog/home`, before the catalogue grows past a few hundred items |
