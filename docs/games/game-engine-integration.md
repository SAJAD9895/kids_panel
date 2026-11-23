# Game engine integration

How the Phase 10 games sit on the Phase 9 learning engine. Date: 2026-11-19. Code: `kids_app/lib/features/play/`. The engine itself is described in `docs/flutter/learning-engine.md`. This page covers what Phase 10 added and why.

## 1. The rule: games are content, not code

A game is a catalogue activity whose `games.config` lists items of registered activity types. No game has its own screen, state or save logic:

```
activity (catalogue)  ──►  games.config {intro, levels:[{id, label, minAgeMonths, options?, attempts?, items:[…]}]}
                                   │
              ActivitySource.fromConfig  →  forLevel(id)  →  build(registry, policy, sessionId)
                                   │
                          SessionEngine (pure rules)  ◄──  PlayerController (Riverpod)
                                   │                                 │
                     ItemViewRegistry (views)            SyncService → POST /play/sync → apply_session
```

So the eight games share one player, one set of rules (tries, hints, scoring, time), one save path, and one set of accessibility and layout checks. Seven of the eight needed no new activity type at all. The new types (`arithmetic`, `shape_complete`, `jigsaw`) were added the documented way, a rules class plus a view registered by key, without touching the player.

## 2. Flutter Flame: not used, and why

The brief asks for Flame "only where it provides a real benefit". Architecture §8.2 had planned Flame for every template. For these eight games it would add:

- a second rendering model next to Flutter widgets, with its own accessibility gaps (Flame components have no semantics, so screen readers and keyboards would need a parallel widget layer);
- engine size on the web build;
- a game loop running 60 times a second for boards that change only when a child taps.

None of the eight needs what Flame is good at: continuous movement, physics, collision or sprite animation. Flutter widgets give these games:

- drag and drop (`Draggable` / `DragTarget`) with a tap-tap alternative;
- implicit animations (flip, shake, pop, snap) that switch off with "reduce motion";
- semantics labels for every card, piece and bin;
- layout that adapts to phone, tablet and desktop.

**Flame stays the plan** for the mechanics that do need a game loop (architecture §8.3: E7 runner / catcher, E11 rhythm, E12 stacking with physics). A Flame view can be registered in `ItemViewRegistry` like any other view.

To record this honestly in the database, migration `20261119000100_engine_runtime.sql` adds `'flutter'` to `game_templates.runtime`. The engine's template row is `learning_engine 1.0.0`, runtime `flutter`. This is the only schema change. It widens a check constraint and loses no data.

## 3. What Phase 10 added to the engine

| addition | where | used by |
| --- | --- | --- |
| **Levels**: `GameLevel` (id, label, minAgeMonths, options, attempts, items); `ActivitySource.levels / forLevel / defaultLevel / nextLevel`; level-prefixed item ids; `RunState.level` in snapshots and reports (`metrics.level`) | `domain/session_report.dart`, `domain/engine.dart` | all 8 |
| Level picker on the intro, **Next level** on the completion screen; `PlayerController.chooseLevel / playNextLevel` | `presentation/activity_player_screen.dart`, `play_providers.dart` | all 8 |
| `DifficultyPolicy.copyWith`: a level can set options / memory pairs and tries over the age default | `domain/item_spec.dart` | Memory, Number, Alphabet, Quiz, Puzzle |
| **Sound effects**: `SoundEffects` (`AudioSoundEffects` on `audioplayers`, `RecordingSoundEffects` for tests), `soundsOnProvider`, `ItemViewContext.sound` | `core/audio/sfx.dart`, `assets/sfx/`, `tool/gen_sfx.py` | all 8 |
| `ItemViewContext.paused` (clocks stop while paused) | `views/item_views.dart` | Memory |
| Memory: `timer`, move / pairs-left / clock bar (`MemoryStats`), 3D `FlipCard`, `MemoryAnswer.timeMs`, boards that fit short screens | `kinds/memory_trace_kinds.dart`, `views/item_views.dart` | Memory |
| `RunSummary` ("8 of 10 right", "14 moves", "Time 0:42") on the completion screen | `domain/run_summary.dart` | all 8 |
| Pictures with **colour and size** (`?color=red&size=small`), `half:` and `gap:` shape pictures, `PictureRef.describe()` for screen readers; paint colour tokens | `item_spec.dart`, `widgets/play_widgets.dart`, `docs/design/tokens` | Sort, Puzzle, Quiz |
| **`arithmetic`** type + `EquationView` | `kinds/choice_kinds.dart`, `views/item_views.dart` | Number |
| **`shape_complete`** type | `kinds/choice_kinds.dart` | Puzzle |
| **`jigsaw`** type + `JigsawItemView`; `PictureSlice` (shared with the swap puzzle) | `kinds/arrange_kinds.dart`, `views/jigsaw_view.dart`, `widgets/play_widgets.dart` | Puzzle |
| Letter modes **`sound`** (phonics table, heard-only question) and **`case`** (see B, find b) | `kinds/choice_kinds.dart` | Alphabet |
| Capital letters to trace (18) | `kinds/memory_trace_kinds.dart` (`Glyphs`) | Alphabet |
| Pronunciation in placing games (picked / dragged word spoken; tapping a target names it) | `views/item_views.dart` | Picture match, Sort |
| "Game room": Home shows the curated `home` rows (`kind = 'row'`) | `kids_home_screen.dart` | all 8 |

All the rules stay in `domain/`, which is pure Dart. A test fails if a domain file imports Flutter.

## 4. Fixes found while building the games

| problem | found by | fix |
| --- | --- | --- |
| A stroke that started straight up or down scrolled the page instead of drawing, because the scroll view won the gesture | layout test, phone held sideways | the tracing box claims the finger on touch-down (`_ImmediatePanRecognizer`) |
| The tracing box was taller than the visible play area on phones held sideways, so the child had to scroll mid-letter | same | the box shrinks to the height left, with the buttons beside it |
| A new question kept the scroll position of the last one, so the "listen" button was half off-screen | same | every question starts at the top |
| 64 dp memory cards with a word overflowed by 4 px | same | tile content scales down to fit |
| 16 memory cards wrapped 9 + 7 | browser | the board is exactly *n* columns wide (4 × 4) |

## 5. Saving results and progress

Nothing new on the server path. A game session is saved like any other activity:
- `activity_sessions` and `activity_results`, the level kept in `metrics.level`;
- `star_awards`: one per game per day, whatever the level;
- `daily_progress`;
- lesson steps when the game is a step in a course.

The SQL test **G1** saves a Hard Memory session through `private.apply_session` and checks all of this. Interrupted sessions resume on the **same level**: the level is in the snapshot, and item ids carry the level, so an Easy board can never be mistaken for a saved Hard one.

## 6. Adding a game

1. **Content only** (the usual case): an `activities` row of type `game` and a `games` row on the `learning_engine` template, whose `config` validates against `supabase/schemas/game-config.schema.json`. Put it in a collection (for example `game-room`). No app release is needed.
2. **A new mechanic:** a `XKind` in `domain/kinds/`, a view in `ItemViewRegistry`, and the key added to the schema's `kind` enum. A test fails if the schema and the registry disagree. The app gets a release; `game_templates.min_app_build` gates older builds (architecture §8.6, enforced by `play/launch`, not built yet).
