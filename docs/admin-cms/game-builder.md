# Game builder

Phase 14, 2026-11-21. Component `src/components/game-builder.tsx`; logic in `src/lib/game/`.

## 1. It writes the engine's own format

There is no CMS-specific game format. The builder edits `games.config`, the JSON the Flutter learning engine plays (Phase 10). The contract is the engine's JSON Schema, `supabase/schemas/game-config.schema.json`. The admin app gets it through `npm run sync`.

**Checks.**
- **In the browser:** Ajv (draft 2020-12) validates the whole config on every change, and the page lists any problems.
- **On save (server):** the same validation runs again in the server action (`saveGameConfig`). An invalid config is never written.
- **Extra rules:** at least one item; level ids must differ.
- **Contract test** (both sides):
  1. `admin_panel/test/unit/game.test.ts` builds a game with every kind through the same form code the page uses.
  2. It validates the game and writes it to `kids_app/test/fixtures/admin_cms/every_kind.json`.
  3. `kids_app/test/unit/admin_cms_contract_test.dart` reads that file with `ActivitySource.fromConfig` and parses every item with the app's `KindRegistry.standard()`.
  4. It checks that each item (except play-only tracing and memory) has a solution the engine can show.

## 2. The brief's game types → engine kinds

| brief | kinds (form fields) |
| --- | --- |
| multiple-choice games | `multiple_choice` (question, options, correct, hint), `image_choice` (options with pictures), `audio_choice` (spoken prompt) |
| image matching | `match_pairs` (left = right pairs), `image_choice` |
| memory | `memory` (card faces with pictures, optional timer) |
| word building | `word_build` (word, extra letters, picture, hint), `fill_blank` (sentence with `___`, options) |
| number games | `number_recognition` (count a picture, or find a number), `arithmetic` (a + / − b ≤ 10, picture) |
| alphabet games | `letter_recognition` (target, by name or sound, distractors), `trace` (a glyph) |
| sorting | `sort` (groups; things → group) |
| puzzles | `puzzle` (swap), `jigsaw`, `shape_complete` |
| quizzes | activity type **quiz**: questions and answers in the `questions`/`answers` tables (the quiz editor; the app's quiz player reads them). Inside a game: `multiple_choice`, `audio_choice` |
| drag and drop | `drag_to_target` (pieces, places, solution), `sort` |

That is 16 kinds, all the engine has. A unit test fails if the schema gains a kind the builder doesn't cover.

## 3. What an editor can set

| brief | how |
| --- | --- |
| questions and answers | each item's prompt and options (one per line: `label \| picture`); quizzes have their own editor (at least two answers, exactly one correct for single choice) |
| correct answers | the **Correct** field names the option. It's stored as the option's id (`o1`…), the engine's format |
| images | `picture` fields take a built-in picture (`shape:circle`, `icon:apple`, `char:pip`, `glyph:A`, `count:3:star`) or `asset:<media id>` for an uploaded image; quiz questions take an image asset |
| audio | `audio_choice` speaks the prompt with the engine's voice; `intro` text is read aloud; quiz questions take an audio asset |
| hints | `hint` on items that support it (the engine shows hints on its own schedule after wrong tries) |
| difficulty | the activity's difficulty (1–5) and age window; **levels** (2–5, easiest first, each with `minAgeMonths` and attempts). The engine picks the hardest level the child is old enough for |
| points and reward rules | stars: **1 per activity per day** (reward rule `activity_completed`), plus goal and badge bonuses, set in Rewards. The builder shows the current rule |
| preview before publishing | the **Preview** panel shows every item as the engine reads it: level, kind, prompt, options with ✓ on the correct ones, and the hint. The workflow's validation runs before approval |

## 4. Using it

1. Create an activity of type Game. It starts with an empty config.
2. Optional: write an introduction, and switch on difficulty levels.
3. Under **Add an item**, choose a kind, fill in its form, then **Keep this item**. Items can be edited, removed or moved up and down.
4. The **Checks** panel says either "Valid for the learning engine (n items)" or lists what to fix. **Save game** stays disabled until it's valid.
5. Send for review.

## 5. Limits (honest)

- **The preview is a description, not the game.** It isn't the Flutter rendering, which has animations, voice and drag physics. To see that, play it in a debug build of the app pointed at the same project. The approved content is visible to staff there, not to families.
- **Points per game.** The platform deliberately has no per-game point values. Rewards are stars, earned once a day per activity, with configurable bonuses (Phase 12). Adding per-game points would change the reward model the app and parents see, so it wasn't done.
- **Pictures by id.** An uploaded image is referenced by its media id (copy it from the media library). There's no picture picker inside the item form yet.
- **Speech.** Spoken prompts use the engine's text-to-speech. Attaching a recorded voice clip to a single item isn't in the engine format.
