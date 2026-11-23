# Learning interactions: games, lessons, video, audio, reading

Requirements every template (`docs/architecture/08-game-engine.md`, E1–E12) and player must meet. They are pedagogy and child-UX rules, so they belong in the shared runtime (`kl_game_runtime`), not in each game.

## 1. Every activity

| # | requirement | why |
| --- | --- | --- |
| I1 | **Spoken instruction** on start, in the content language, with a **replay button** (speaker icon, top-left, always visible) | pre-readers [F-036] |
| I2 | **Idle help ladder**: no input for 6 s → the instruction replays; 12 s → a visual hint (the buddy points, the target glows); 20 s → the hint animates the first move. Never a penalty | children freeze rather than ask |
| I3 | **Wrong answers**: gentle sound + shake, the item returns, "Try again" spoken. After 2 wrong tries on the same item, a hint; after 3, the right answer is shown and the child does it. No red X, no lost lives, no score loss for pre-schoolers | learning, not testing; UK Children's Code (no detrimental design) |
| I4 | **Right answers**: short praise (varied lines, ≥ 8 per locale so it doesn't repeat), sound, small animation ≤ 1 s | motivation without slowing play |
| I5 | **Length**: 1–5 minutes; 3–8 rounds; the end is clear | attention spans 2–8 years |
| I6 | **Completion** = the main learning bit done (template rule), then the celebration (K11-done): "+1 star", Again / Next | [F-062] |
| I7 | **Pause** on: back gesture, Esc, app backgrounded, phone call, headphones unplugged (audio), screen lock. Pause sheet (K11-pause): Keep playing / Start over / Leave | interruptions are normal |
| I8 | **Resume**: within 10 min the activity resumes where it stopped; after that it restarts | — |
| I9 | **Exit** always one tap away (close button), never blocked by an animation; leaving early saves an `abandoned` session, no star | [V SS-03] |
| I10 | **No time pressure** unless the mechanic is about timing (E7, E11), and then the speed adapts down after misses | no nudge techniques |
| I11 | **Difficulty**: the template reads `difficulty` (1–5) from config; within a session it steps down one level after 3 misses in a row | keeps children in flow |
| I12 | **Input**: drag tolerance ≥ 24 dp around targets; snap when within the tolerance; one finger only; no double-tap, no long-press required; mouse and keyboard on the web (Tab to items, Space to pick up, arrows to move, Space to drop) [W-004] | small hands, web |
| I13 | **Audio mix**: voice > SFX > music; music ducks to 30 % under voice; device-level Sound effects and Music switches (K20) are respected; voice can't be turned off (it carries the instruction) | clarity |
| I14 | **Performance**: `08-…` §8.7 budgets (≥ 30 fps on the floor device, tap-to-playable ≤ 2 s cached) | — |
| I15 | **Telemetry** per question: correct, attempts, hint level used, time → `question_responses` | mastery model `09-…` |

## 2. Lessons (courses)

- A lesson ("island") is 4–7 steps in a fixed order (K10): typically Warm-up (`intro` or pre `knowledge_check` on the first island), practice steps (`practice`, `trace`, `collect`), a `song` or `story` step, then the island prize.
- Steps unlock one at a time; a completed step can be replayed and earns a star once a day like any activity.
- The **pre check-in** is the first step of the course and the **post check-in** the last [F-053]; they show no right/wrong feedback (K27) and feed the parent's pre/post comparison (P04).
- Island prize: a sticker given once on lesson completion (`lessons.prize_reward_id`), shown with the gift animation.
- Course progress bar = completed required steps ÷ all required steps [V SS-10]; the certificate (K28) appears when the post check-in is done.
- Learn Together steps (K26) show a short grown-up script; off-screen tasks complete with "We did it!" (`offline_activity`, U06).

## 3. Video

- Plays full-screen on phones and tablets (K13), in-page with a full-screen button on the web.
- Controls appear on tap and hide after 3 s; **kid lock** hides them completely (unlock = hold the lock 2 s, or the gate when "strict lock" is on in the device settings, K20).
- Captions: available on every video in every locale it claims (publish is blocked without them, A22); off by default, switched on in K20 and remembered per device.
- Up next: 3 items; autoplay after 5 s with a visible countdown ring and a big "stop" target; grown-ups can turn autoplay off in the device settings (K20) [P].
- A video counts as complete at 90 % watched (star) [F-074].
- Skill chips (1–3) under the title [V SS-08].

## 4. Audio (songs, sing-alongs)

- K33: cover, play/pause, next/previous; lyric line highlights in time for sing-alongs (timings in the pack).
- Background audio continues when the screen locks only for Listen items, never for games.
- Calm time: slower songs and stories; the shell uses the soft colours and the reward widget is hidden [Q18].
- Completion = 90 % listened.

## 5. Reading (E10 book reader, K32)

- Two modes: **Read to me** (narration with word highlighting from word timings) and **Read myself** (no narration; tap any word to hear it) [F-081].
- Page turn: swipe or big arrow buttons; the next page waits until narration ends in Read to me (tap the arrow to skip).
- Text uses `type.kids.reading` / `reading-lg`; at least 1.5 line height; no justified text; a dyslexia-friendly option is out of scope for v1 [A].
- Hotspots on illustrations play a sound or word.
- Completion = last page reached.

## 6. Tracing and drawing (E3, E4)

- Stroke order shown with an animated start dot and arrow; the child's stroke must stay within the template's tolerance; off-path strokes fade and the guide replays.
- Stylus and finger both work; palm rejection on tablets where the platform supports it.
- Drawings never leave the device (`08-…` §8.9).

## 7. Voice and microphone (later templates)

- Only after the gate and the OS prompt (K34). If denied, the activity offers a tap alternative. No audio is stored or uploaded.
