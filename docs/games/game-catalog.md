# Game catalog

Date: 2026-11-19 (Phase 10). The eight games of the brief, all **implemented and tested** in the Flutter app on the learning engine (`docs/flutter/learning-engine.md`). Each is an activity in the catalogue with **Easy, Medium and Hard** levels, listed in the new **"Game room"** row on Home. Content: `kids_app/lib/demo/demo_games.dart`, mirrored into `supabase/seed.sql` §15.

Status words below: **done** = built, played end to end through the real player at every level in automated tests, and saved through `play/sync` → `apply_session` (demo server in the Flutter tests, SQL function in the database tests). Nothing here has run against a live Supabase project yet (none exists).

Screenshots (web build, demo data): `screens/G00-home-game-room.png`, `G01-memory-levels.png`, `G01-memory-hard-moves-timer.png`, `G04-adding.png`, `G06-sort-by-colour.png`, `G07-jigsaw.png`, `G00-pause-sounds.png`.

## Summary

| # | game (slug) | brief requirements | engine types used | levels (Easy / Medium / Hard) | status |
| --- | --- | --- | --- | --- | --- |
| 1 | Memory match (`memory-match`) | flip to find pairs ✓, difficulty levels ✓, move counter ✓, timer ✓, completion rewards ✓ | `memory` (with `timer`) | 2 boards × 3 pairs / 6 pairs / 8 pairs (16 cards) | done |
| 2 | Picture match (`picture-match`) | pictures ↔ words or objects ✓, drag-and-drop **and** tap ✓, audio pronunciation ✓ | `match_pairs`, `drag_to_target` | 2 + 2 pairs / 2 × 3 pairs / 4 pairs + "goes together" | done |
| 3 | Word builder (`word-builder`) | arrange letters ✓, picture hints ✓, letter pronunciation ✓, answer validation ✓ | `word_build` | 3-letter words / 4 letters + a decoy / 5–6 letters + a decoy | done |
| 4 | Number fun (`number-fun`) | recognition ✓, counting ✓, number matching ✓, adding and taking away ✓ | `number_recognition`, `match_pairs` (groups ↔ numerals), **`arithmetic`** (new) | numbers to 5, + with pictures / to 10, + and − with pictures / to 20, sums without pictures, 4 options | done |
| 5 | Alphabet adventure (`alphabet-adventure`) | letter recognition ✓, upper ↔ lower case ✓, tracing ✓, letter sounds ✓ | `letter_recognition` (modes `name`, **`case`**, **`sound`**), `match_pairs` (A ↔ a), `trace` (**capitals**) | a, B→b, 2 case pairs, /s/, trace L / … 3 pairs, /m/, T, E / … 4 pairs, /f/ /p/, M, Z, 4 options | done |
| 6 | Sort it out (`sort-it-out`) | by shape ✓, colour ✓, size ✓, category ✓; drag-and-drop ✓; immediate feedback ✓ | `sort` with pictures that carry **colour and size** | colour (2 bins) + big/small / shapes (3 bins) + animals/food / 3 colours + where they live | done |
| 7 | Puzzle time (`puzzle-time`) | jigsaw ✓, shape completion ✓, difficulty progression ✓ | **`jigsaw`** (new), **`shape_complete`** (new), `puzzle` | 2×2 jigsaw + 2 shapes / 3×3 + 2 shapes / 4×4 + 3×3 swap puzzle + a shape, 4 options | done |
| 8 | Quiz time (`quiz-time`) | multiple choice ✓, image ✓, audio ✓, score and feedback ✓ | `multiple_choice` (incl. "tap all"), `image_choice`, `audio_choice`, `fill_blank` | 3 / 4 / 4 questions, 4 options on Hard | done |

## Common to every game

| feature | how |
| --- | --- |
| **levels** | picker on the intro ("Easy / Medium / Hard"); the first level offered is the hardest the child is old enough for (`minAgeMonths`: 0 / 54 / 78, Word builder 0 / 60 / 78); each level is its own session, reported with `metrics.level` |
| **difficulty progression** | the completion screen offers **Next level** (straight into the harder level) until Hard; levels can also set the number of options / memory pairs and tries |
| **feedback** | immediate: right tiles turn green with a chime, wrong ones shake with a soft two-note "try again" (never a buzzer), wrong drops bounce back and are named aloud; hints in two levels; the answer is shown after the last try |
| **sounds** | tap, flip, snap, match, correct, try again, complete (`assets/sfx/`, synthesised by `tool/gen_sfx.py`, 104 KB in all); switchable in the pause sheet ("Sounds on / off"), separately from the voice |
| **animations** | cards turn with a 3D flip, tiles shake / pop, pieces snap; all reduced to fades when the device asks for less motion |
| **pause / resume / retry** | pause sheet (clock stops), "Stop for now" saves the run; reopening offers "Keep going?" on the same level; **Play again** and **Try again** |
| **rewards** | 1–3 celebration stars from the score, the daily star from the server (one per game per day), and a summary line: "8 of 10 right", "14 moves", "Time 0:42" |
| **voice** | prompts, picked words, letters, cards and feedback read aloud (text-to-speech for now) |
| **saving** | through the existing session path (`docs/flutter/progress-tracking.md`): started / completed / abandoned reports, offline outbox, snapshots |

## Per game

### 1. Memory match
- Cards: a picture and its word. Turn two; a pair stays open with a sparkle sound, a miss turns back after a moment.
- A bar above the board shows **moves**, **pairs left** and the **clock**. The clock starts on the first card and stops while paused.
- The board always fits the screen: 16 cards fit a phone held sideways as 2 rows of 8 cards of 64 dp, tested.
- Score: up to 2 flips per pair are free; flips beyond that cost points.
- Completion: stars, moves and time. Moves and time are also saved in the session (`answers[].f`, `answers[].ms`).

### 2. Picture match
- Each word is dragged (or tapped, then its picture tapped) onto its picture.
- Picking or dragging a word says it aloud. Tapping a picture with nothing picked says its name.
- A wrong drop bounces back with "Not there".
- Hard adds a "what goes together" round (fish → water, bird → tree, dog → house).

### 3. Word builder
- The picture is the hint. Each tapped letter is spoken, and tapping the last filled slot takes a letter back.
- Medium and Hard add one letter that doesn't belong.
- Validation: letters in order. Repeated letters are interchangeable (the two o's in "moon"), and decoy letters are wrong.

### 4. Number fun
- **Counting:** count a group, then pick the number.
- **Recognition:** hear a number, find it.
- **Number matching:** a group of N things ↔ the numeral N.
- **Adding and taking away** (new `arithmetic` type):
  - Shows `3 + 2 = ?` with two groups of pictures. In a take-away, the ones that "go away" are faded and crossed out.
  - On Hard there are only numbers.
  - The options are the answer and its neighbours (off by 1–2, the slips children really make).
  - The voice asks "three apples and two more. How many altogether?"

### 5. Alphabet adventure
- **Find the letter** (look-alikes such as b / d / p / q).
- **Big and small:**
  - `case` mode: see B, find b.
  - Matching pairs: B ↔ b, with "big A" and "small a" for screen readers.
- **Letter sounds** (`sound` mode): the question is heard only — "Which letter says buh? buh, like ball" — and the hint names the word.
- **Tracing capitals:** A E F H I K L M N O T U V W X Y Z C are new, alongside the existing a–h, o, l, x and 0–9.

### 6. Sort it out
- Pictures carry modifiers, for example `shape:star?color=red`, `icon:apple?size=small`:
  - 6 paint colours, added to the design tokens (`kids-paint-*`).
  - 3 sizes.
- Bins show a faded example and their name.
- A wrong drop bounces back on the spot and counts as a mistake; the round still ends right.

### 7. Puzzle time
- **Jigsaw** (new):
  - The picture is cut 2×2 / 3×3 / 4×4. The board shows a faint outline of the picture; pieces sit in a tray.
  - Drag a piece onto its place, or tap the piece, then the place.
  - Places are named for screen readers ("top left", "middle"…).
- **Shape completion** (new): a shape with one side missing (drawn as a pale ghost); pick the half that finishes it.
- **Swap puzzle:** the existing 3×3 swap puzzle on Hard.

### 8. Quiz time
- Read, look and listen questions, including "tap all the fruit, then Done" and fill-the-blank.
- The completion screen shows the score ("4 of 4 right") with the stars.
- Quizzes written in the admin CMS as `questions` rows play through the same player (`quiz_mapping.dart`, Phase 9).

## Where the games appear

- Home → **Game room** row: every game, filtered by the child's age. A Plus lock would show the same way as everywhere else; all eight are free in the seed.
- They are ordinary game activities, so they also show up in recommendations ("Games for today"), Played lately, favourites, search later, and can be placed in courses as lesson steps.

## Not built (deliberately)

- More content than a few rounds per level: authoring comes with the admin CMS (`content-requirements.md`).
- Real artwork and recorded voice: icons and our three characters stand in, and the voice is text-to-speech.
- Flame games: none of these mechanics needed it (`game-engine-integration.md` §2).
