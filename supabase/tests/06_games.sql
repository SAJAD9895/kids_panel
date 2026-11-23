-- =============================================================================
-- G1 The game collection (Phase 10): content shape, catalogue placement, and a level-based
-- game session saved through private.apply_session like any other activity.
-- =============================================================================
\set ON_ERROR_STOP on
begin;

do $$
declare
  alice uuid := '00000000-0000-4000-a000-0000000000a1';
  mia uuid; memory uuid; s1 uuid := gen_random_uuid(); r jsonb; n int;
begin
  -- the engine template: runtime 'flutter' (migration 20261119000100), schema stored for the CMS
  select count(*) into n from game_templates
   where key = 'learning_engine' and runtime = 'flutter' and status = 'active'
     and config_schema->'$defs'->'item'->'properties'->'kind'->'enum' ? 'jigsaw';
  if n <> 1 then raise exception 'G1 FAIL: learning_engine template missing or incomplete'; end if;
  begin
    insert into game_templates (key, version, runtime) values ('x', '1.0.0', 'cocos');
    raise exception 'G1 FAIL: unknown runtime accepted';
  exception when check_violation then null;
  end;

  -- eight published games, each with three levels of items, all in the Game room row
  select count(*) into n from activities a join games g on g.activity_id = a.id
    join game_templates t on t.id = g.template_id
   where t.key = 'learning_engine' and a.status = 'published'
     and jsonb_array_length(g.config->'levels') = 3
     and not exists (select 1 from jsonb_array_elements(g.config->'levels') l
                     where jsonb_array_length(l->'items') = 0);
  if n <> 8 then raise exception 'G1 FAIL: expected 8 level-based games, found %', n; end if;
  select count(*) into n from collection_items ci join collections c on c.id = ci.collection_id
   where c.slug = 'game-room';
  if n <> 8 then raise exception 'G1 FAIL: game room has % games', n; end if;
  raise notice 'G1 ok: 8 games x 3 levels on the learning_engine template (runtime flutter), in the Game room';

  -- a Memory match session on the hard level: saved, starred, level and moves kept in metrics
  select id into mia from child_profiles where nickname = 'Mia';
  select id into memory from activities where slug = 'memory-match';
  r := private.apply_session(alice, jsonb_build_object(
        'session', jsonb_build_object('id', s1, 'childId', mia, 'activityId', memory, 'source', 'feed',
          'platform', 'web', 'appVersion', '1.0.0', 'contentVersion', 1, 'status', 'completed',
          'startedAt', now() - interval '2 minutes', 'endedAt', now() - interval '10 seconds'),
        'result', jsonb_build_object('completed', true, 'score', 90, 'correctCount', 1, 'totalCount', 1,
          'durationMs', 95000, 'metrics', jsonb_build_object('level', 'hard', 'run', 1,
            'items', jsonb_build_array(jsonb_build_object('k', 'memory', 'ok', true, 'm', 3))))));
  if r->>'status' <> 'accepted' or not (r->>'starAwarded')::boolean then
    raise exception 'G1 FAIL: game session %', r;
  end if;
  if (select metrics->>'level' from activity_results where session_id = s1) <> 'hard' then
    raise exception 'G1 FAIL: level not kept';
  end if;
  raise notice 'G1 ok: a level-based game session is saved with its level, and earns the daily star';
end $$;

rollback;
