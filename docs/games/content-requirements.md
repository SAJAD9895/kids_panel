# Content requirements (for the admin CMS)

What a content editor (A04 / A05 in the design) needs to make or change a game without an app release. Date: 2026-11-19.

## 1. Where content lives

| what | table / file | edited by |
| --- | --- | --- |
| The game as a catalogue item: title, description, subject, ages, difficulty, estimated time, Plus or free, publish state | `activities` (type `game`) | CMS, `content.write` |
| The game's content | `games.config` (jsonb), on template `learning_engine 1.0.0` | CMS |
| The rules the content must follow | `game_templates.config_schema` = `supabase/schemas/game-config.schema.json` (JSON Schema 2020-12) | engineers (ships with the app version that supports it) |
| Quiz questions written as rows instead of JSON | `questions` + `answers` (single / multi choice, true/false, listen-and-choose, match, order), played by the same engine | CMS |
| Where a game shows | `collections` + `collection_items` (for example `game-room` on Home), course `lesson_steps` | CMS |
| Pictures | today: references to built-in shapes / icons / characters; later `asset:<media id>` from `media_assets` (Storage) | CMS + media pipeline |
| Voice | today: text-to-speech of `speak` / `text`; later recorded audio per locale | CMS + recording |

The CMS should validate `games.config` against the template's schema before saving (and the server again, `admin/content/validate`). The app re-checks every item when it plays it: content that fails shows "Almost ready!" instead of a broken game.

## 2. `games.config` shape

```json
{
  "intro": {"text": "Find the pairs", "speak": "Turn over two cards at a time…"},
  "levels": [
    {"id": "easy",   "label": "Easy",   "minAgeMonths": 0,  "options": 3, "items": [ … ]},
    {"id": "medium", "label": "Medium", "minAgeMonths": 54, "options": 6, "items": [ … ]},
    {"id": "hard",   "label": "Hard",   "minAgeMonths": 78, "options": 8, "items": [ … ]}
  ]
}
```

Or, for a game without levels, `{"intro": …, "items": [ … ]}`.

| field | rule |
| --- | --- |
| `levels` | 1–5, easiest first. `id` is lower-case (`a-z0-9-`), unique within the game, and **must not change** once published (saved sessions and reports name it) |
| `label` | shown on the level picker; short ("Easy") |
| `minAgeMonths` | the first level offered is the hardest one the child is old enough for |
| `options` | for choice items, how many options to show (the right ones are always kept); for memory, the number of pairs. Default: by age (3 / 4 / 6) |
| `attempts` | tries before the answer is shown. Default: 3 under 6 years, 2 after |
| `items` | 1–30 per level; 3–6 is the sweet spot for a 2–5 minute game |
| text | a plain string (English) or `{"en": …, "es": …}`; at most 200 characters; prompts should be **one short line** (most players can't read yet) and always have a `speak` version if the text alone isn't enough |

Changing the items of a published level resets in-progress runs of that level, which is safe: they are closed as "abandoned" and the child starts afresh. Bump `activities.content_version` when the content changes meaningfully.

## 3. Item types and their fields

Every item may also have `prompt` (`text`, `speak`, `picture`) and `hint` (spoken at hint level 1).

| type | required | optional | notes for editors |
| --- | --- | --- | --- |
| `multiple_choice` | `options` (2–8), `correct` (1+) | `shuffle: false` | several right answers → "tap all, then Done" |
| `image_choice` | same, every option has a `picture` | | |
| `audio_choice` | same + `prompt.speak` | | the question is heard, never shown |
| `letter_recognition` | `target` (one letter) | `mode`: `name` (default) / `sound` / `case`; `distractors` | without distractors, look-alike letters are used; `sound` uses the built-in letter sounds a–z; `case` shows the other case as a picture |
| `number_recognition` | `count` (1–10) + `picture`, or `target` (0–20) | `distractors` | |
| `arithmetic` | `a`, `b` (0–10) | `op` `+` / `-`, `picture` | no negative answers; with a picture, children count; without, a plain sum |
| `fill_blank` | `sentence` with `___`, `options`, `correct` | `picture` | |
| `drag_to_target` | `tokens`, `targets`, `solution` {token: target} | | |
| `sort` | `bins` (2+), `items` each with `bin` | | give items a `label` when the picture alone is ambiguous; colour / size come from the picture modifiers |
| `match_pairs` | `pairs` (2+) of `left` / `right` | | each side can be a word, a picture, or both; give `speak` for glyphs ("big A") |
| `word_build` | `word` (1–8 letters) | `extra` (decoy letters), `picture` | the picture is the hint; avoid words that read the same backwards for wrong-answer tests |
| `puzzle` | `picture` + `grid` 2–4, or labelled `pieces` | | tap two to swap |
| `jigsaw` | `picture` | `grid` 2–4 (default 2) | pieces go from a tray onto the board |
| `shape_complete` | `shape` (circle, square, triangle, star, heart) | `missing` side, `distractors`, `color` | |
| `memory` | `cards` (2–8 faces) | `timer: true` | each face appears twice; the level's `options` caps the pairs |
| `trace` | `glyph` (a built-in letter or number) or `strokes` | | built-in: a–h, o, l, x, 0–9 and the capitals A C E F H I K L M N O T U V W X Y Z |

### Pictures

`shape:<circle|square|triangle|star|heart>`, `icon:<name>` (cat, dog, cow, duck, fish, bird, apple, banana, carrot, sailboat, car, ball, sun, moon, flower, tree, house, cake, water, pets, star), `char:<pip|bolt|nova>`, `glyph:<letter or number>`, `count:<n>:<icon>`, `half:<shape>:<side>`, `gap:<shape>:<side>`; later `asset:<media id>`.

Modifiers: `?color=red|blue|yellow|green|purple|orange` and `&size=small|medium|big`. Screen readers hear "small red circle". Every picture must make sense with its spoken name.

## 4. Editorial rules (child safety and quality)

- **Original content only.** No characters, art, sounds or wording from other apps, brands or shows.
- **Ages.**
  - Under 4: 3 options, everything spoken, no reading needed.
  - 4–6: short words.
  - 6+: reading is fine, but keep it one line.
- **Kind feedback.** Wrong answers are "Almost! Try again." Never words like "wrong", "fail" or "lose"; never timers that end the game. The memory clock is a "how fast" fun fact, never a limit.
- **No personal data.** No names, photos, locations, links, ads or purchase prompts inside games.
- **Accessibility.**
  - Every picture option has a word (`label` or `speak`).
  - Colour is never the only clue unless the item is about colour, and then the bins are named.
  - Sound is never the only way to answer: audio questions have a "hear it again" button and pictures to choose from.
- **Levels must feel different.** More options or pairs, decoy letters, bigger numbers, more pieces. Not just more of the same.
- **Review.** Draft → preview in the CMS (the template playground, architecture §8.2) → a second editor approves → publish. Admin audit logging is already in place.

## 5. What the CMS needs to build (not in this phase)

1. A form per item type, generated from the schema (enums become pickers, pictures a picker over icons / shapes / media), with live validation.
2. A **preview** that runs the real player on the draft content: the Flutter web build with a draft source.
3. Level management: add, reorder, label, age, options and tries.
4. A media picker (images, recorded voice per locale) once the `media` module exists.
5. Translation fields (`es`) next to `en` for every text.
6. Content version bumping and "published since" history (the audit log has the changes).
