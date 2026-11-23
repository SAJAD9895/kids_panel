# Activity types

The 13 built-in types of the learning engine (`kids_app/lib/features/play/domain/kinds/`). Content lives in `games.config.items` as JSON. Text fields accept a plain string (English) or `{"en": …, "es": …}`. Pictures are references: `shape:circle|square|triangle|star|heart`, `icon:<name>` (cat, dog, cow, duck, fish, bird, apple, banana, carrot, sailboat, car, ball, sun, moon, flower, tree, house, cake, water, pets), `char:pip|bolt|nova`, `glyph:<letter>`, `count:<n>:<icon>` (n of an icon). Real artwork will add `asset:<media id>`.

Every item may also have `"prompt"` (text, `speak`, `picture`) and `"hint"`.

| type | brief name | answer | view | hint level 2 |
| --- | --- | --- | --- | --- |
| `multiple_choice` | multiple-choice | pick option(s) | answer tiles (words or pictures); several right answers → toggles + Done | half the wrong options greyed out |
| `image_choice` | image-based | pick a picture | picture tiles, optional prompt picture | as above |
| `audio_choice` | audio-based | pick after listening | big listen button instead of text | as above |
| `letter_recognition` | letter recognition | pick the letter | big glyph tiles; look-alike letters by default (b/d/p/q …) | as above |
| `number_recognition` | number recognition | count, then pick the number; or find the number you hear | a group of N pictures + number tiles | as above |
| `fill_blank` | fill in the blanks | pick the missing word | the sentence with a blank that fills as you choose | as above |
| `drag_to_target` | drag and drop | put each token on its target | drag, or tap then tap; wrong drops bounce back | shows where the first token goes |
| `sort` | sorting and classification | put each thing in its group | bins that collect what's put in them | as above |
| `match_pairs` | matching pairs | join each left item to its partner | two columns, matched pairs turn green | as above |
| `word_build` | word building | tap letters in order | picture, letter slots, letter tiles; tap the last slot to undo | lights up the next letter |
| `puzzle` | simple puzzles | swap pieces until whole | a picture cut into 2×2 to 4×4, or labelled pieces to order | highlights the first piece |
| `memory` | memory | find every pair | face-down cards; misses turn back | shows one pair |
| `trace` | tracing | follow the path with a finger | dotted guide, green start dot, Check / Clear | the start dot pulses |

## Added in Phase 10

`arithmetic` (adding and taking away with pictures), `shape_complete` (pick the half that finishes a shape), `jigsaw` (pieces from a tray onto a board), `letter_recognition` modes `sound` and `case`, capitals to trace, pictures with `?color=` and `&size=`, memory `timer`, and game **levels**. Fields and rules: `docs/games/content-requirements.md`; JSON Schema: `supabase/schemas/game-config.schema.json`.

## Examples

```json
{"kind": "multiple_choice", "prompt": "Which one is a fruit?",
 "options": [{"id": "banana", "label": "banana"}, {"id": "car", "label": "car"}], "correct": ["banana"],
 "hint": "You can eat it!"}

{"kind": "image_choice", "prompt": {"text": "Which has more?", "speak": "Which basket has more apples?"},
 "options": [{"id": "three", "picture": "count:3:apple"}, {"id": "five", "picture": "count:5:apple"}],
 "correct": ["five"]}

{"kind": "audio_choice", "prompt": {"speak": "Find the cat."},
 "options": [{"id": "cat", "picture": "icon:cat", "label": "cat"}, {"id": "dog", "picture": "icon:dog", "label": "dog"}],
 "correct": ["cat"]}

{"kind": "letter_recognition", "target": "b"}                     // distractors optional
{"kind": "number_recognition", "count": 4, "picture": "icon:sailboat"}
{"kind": "number_recognition", "target": 7, "distractors": [1, 4, 9]}
{"kind": "fill_blank", "sentence": "The cow says ___", "picture": "icon:cow",
 "options": ["moo", "quack", "woof"], "correct": "moo"}

{"kind": "drag_to_target",
 "tokens":  [{"id": "circle", "picture": "shape:circle"}],
 "targets": [{"id": "home-circle", "picture": "shape:circle", "label": "circle"}],
 "solution": {"circle": "home-circle"}}

{"kind": "sort", "bins": [{"id": "round", "label": "Round"}, {"id": "corners", "label": "Corners"}],
 "items": [{"id": "ball", "picture": "icon:ball", "bin": "round"}, {"id": "house", "picture": "icon:house", "bin": "corners"}]}

{"kind": "match_pairs", "pairs": [{"left": {"label": "cat"}, "right": {"picture": "icon:cat"}},
                                  {"left": {"label": "sun"}, "right": {"picture": "icon:sun"}}]}

{"kind": "word_build", "word": "cat", "picture": "icon:cat", "extra": "o"}
{"kind": "puzzle", "picture": "char:pip", "grid": 2}
{"kind": "puzzle", "pieces": ["plant", "water", "grow"]}           // put the story in order
{"kind": "memory", "cards": [{"id": "sun", "picture": "icon:sun"}, {"id": "moon", "picture": "icon:moon"}]}
{"kind": "trace", "glyph": "a"}                                   // built in: a–h, o, l, x, 0–9
{"kind": "trace", "strokes": [[[0.2, 0.5], [0.8, 0.5]]]}          // or your own, unit square
```

## Judging rules

| type | right when | notes |
| --- | --- | --- |
| choice types | the picked set equals the right set | a multi-answer item reports how close a wrong answer was |
| place types | every token is on its target | wrong drops are refused on the spot and counted as mistakes |
| `word_build` | letters in the right order | pieces with the same letter are interchangeable ("moon"); unknown ids are wrong, not a crash |
| `puzzle` | pieces in the right order | swaps beyond the minimum count as mistakes |
| `memory` | every pair found | flips beyond 2 per pair count as mistakes |
| `trace` | ≥ 75 % of the path covered within the tolerance, ≤ 30 % of the ink off the path, and no more than 2.2× the path's length in ink | the tolerance is wider for younger children (0.16 / 0.12 / 0.09 of the box). A scribble over the whole box fails; this was found by a test and fixed |

## Age

`DifficultyPolicy.forChild(ageMonths, difficulty)`:

| | < 4 years | 4–5 | 6+ |
| --- | --- | --- | --- |
| options shown (choice) / memory pairs | 3 | 3 (4 if difficulty ≥ 3) | 4 (6 if difficulty ≥ 3) |
| tries before the answer is shown | 3 | 3 | 2 |
| voice reads automatically | yes | yes | no (listen buttons still there) |
| hint offered after a wrong answer | yes | under 5 | no |
| trace tolerance | 0.16 | 0.12 | 0.09 |

The right option is always kept when options are trimmed.

## Development content

`kids_app/lib/demo/demo_activity_content.dart`, mirrored into `supabase/seed.sql` §14 by `dart run tool/seed_content_sql.dart`. A test fails if they differ. It holds 3 items each for find-the-b, count-the-boats, trace-a-to-h and number-trace-1-5; one or two for shape-homes, shape-sort and more-or-less; and **"Try everything!"** (`engine-sampler`), one item of every type. The quiz "Letters check-in" plays from the `questions` table. Small on purpose: authoring comes with the admin CMS.
