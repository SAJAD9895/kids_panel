-- Phase 10: games built on the Flutter learning engine.
--
-- WHY (a documented change to the reviewed schema, docs/backend/database-schema.md §5 #10):
-- `game_templates.runtime` allowed only 'flame', 'rive' and 'unity'. The learning engine
-- (Phase 9) plays games with Flutter widgets: none of the v1 mechanics needs a game loop or
-- physics, so Flame would add weight and no benefit (docs/games/game-engine-integration.md).
-- Recording such templates as 'flame' would be wrong, so 'flutter' is added.
--
-- Not destructive: the check is only widened; every existing row stays valid. The template
-- row itself (key 'learning_engine') and its config JSON Schema are content and live in the
-- seed / admin CMS, not in this migration.

alter table game_templates drop constraint game_templates_runtime_check;
alter table game_templates add constraint game_templates_runtime_check
  check (runtime in ('flame', 'rive', 'unity', 'flutter'));

comment on column game_templates.runtime is
  'flutter = the in-app learning engine (games.config = {intro, items | levels}); flame/rive/unity = future templates';
