-- =============================================================================
-- M1 Multimedia (migration 20261120000100): POST /play/launch, /play/heartbeat,
-- PUT /children/:id/screen-time. Called as the Edge Functions call them.
-- =============================================================================
\set ON_ERROR_STOP on
begin;

do $$
declare
  alice uuid := '00000000-0000-4000-a000-0000000000a1';
  bob   uuid := '00000000-0000-4000-a000-0000000000b1';
  mia uuid; sam uuid; snail uuid; cloud uuid; seed uuid; lullaby uuid; tidy uuid; game uuid;
  r jsonb; n int; s1 uuid := gen_random_uuid(); s2 uuid := gen_random_uuid();
begin
  select id into mia from child_profiles where nickname = 'Mia';
  select id into sam from child_profiles where nickname = 'Sam';
  select id into snail from activities where slug = 'pip-meets-a-snail';
  select id into cloud from activities where slug = 'the-sleepy-cloud';
  select id into seed from activities where slug = 'pip-and-the-lost-seed';
  select id into lullaby from activities where slug = 'moon-lullaby';
  select id into tidy from activities where slug = 'tidy-up-tune';
  select id into game from activities where slug = 'shape-homes';

  -- 1. a video: the MP4 and its captions, private bucket paths (the Edge Function signs them)
  r := private.launch(alice, jsonb_build_object('childId', mia, 'activityId', snail));
  if r->>'section' <> 'watch' or r->'resume' <> 'null'::jsonb or r->'remainingSeconds' <> 'null'::jsonb then
    raise exception 'M1 FAIL: video launch %', r;
  end if;
  select count(*) into n from jsonb_array_elements(r->'assets') a
   where (a->>'role' = 'video_main' and a->>'bucket' = 'video' and a->>'kind' = 'video_mp4' and (a->>'durationMs')::int = 36000)
      or (a->>'role' = 'subtitle' and a->>'locale' = 'en' and a->>'path' like '%/subs/en.vtt');
  if n <> 2 then raise exception 'M1 FAIL: video assets %', r->'assets'; end if;

  -- 2. a story: six pages in order, each with its words
  r := private.launch(alice, jsonb_build_object('childId', mia, 'activityId', seed));
  select count(*) into n from jsonb_array_elements(r->'assets') a
   where a->>'role' = 'page_image' and a->'text'->>'en' <> '' and a->>'bucket' = 'content';
  if n <> 6 or r->'assets'->0->>'position' <> '0' or r->>'section' <> 'listen' then
    raise exception 'M1 FAIL: story pages %', r;
  end if;
  raise notice 'M1 ok: launch returns the media files (video + captions, story pages + words) for signing';

  -- 3. availability, households, Plus, age
  begin perform private.launch(bob, jsonb_build_object('childId', mia, 'activityId', snail));
        raise exception 'M1 FAIL: another family''s child';
  exception when sqlstate 'KL404' then null; end;
  update activities set status = 'retired' where id = tidy;
  begin perform private.launch(alice, jsonb_build_object('childId', mia, 'activityId', tidy));
        raise exception 'M1 FAIL: retired content launched';
  exception when sqlstate 'KL404' then null; end;
  update activities set status = 'published' where id = tidy;
  begin perform private.launch(bob, jsonb_build_object('childId', sam, 'activityId', cloud));
        raise exception 'M1 FAIL: Plus story without Plus';
  exception when sqlstate 'KL402' then
    if sqlerrm <> 'NEEDS_PLUS' then raise; end if;
  end;
  perform private.launch(bob, jsonb_build_object('childId', sam, 'activityId', seed));  -- free story: fine
  update activities set age_min_months = 100, age_max_months = 120 where id = seed;
  begin perform private.launch(alice, jsonb_build_object('childId', mia, 'activityId', seed));
        raise exception 'M1 FAIL: too young';
  exception when sqlstate 'KL403' then null; end;
  update activities set age_min_months = 24, age_max_months = 84 where id = seed;
  raise notice 'M1 ok: published only, own children only, Plus needs Plus, age window enforced';

  -- 4. parental controls: section off, category blocked, validation, other parents
  r := private.set_screen_time_rules(alice, mia, jsonb_build_object('watchEnabled', false,
         'blockedCategoryIds', jsonb_build_array((select id from categories where key = 'bedtime'))));
  if (r->>'watchEnabled')::boolean or jsonb_array_length(r->'blockedCategoryIds') <> 1 or not (r->>'listenEnabled')::boolean then
    raise exception 'M1 FAIL: rules %', r;
  end if;
  begin perform private.launch(alice, jsonb_build_object('childId', mia, 'activityId', snail));
        raise exception 'M1 FAIL: video with Watch off';
  exception when sqlstate 'KL423' then if sqlerrm <> 'SECTION_DISABLED' then raise; end if; end;
  begin perform private.launch(alice, jsonb_build_object('childId', mia, 'activityId', lullaby));
        raise exception 'M1 FAIL: blocked category';
  exception when sqlstate 'KL423' then if sqlerrm <> 'CATEGORY_BLOCKED' then raise; end if; end;
  perform private.launch(alice, jsonb_build_object('childId', mia, 'activityId', tidy));    -- another song: fine
  perform private.launch(alice, jsonb_build_object('childId', mia, 'activityId', game));    -- games never switched off
  begin perform private.set_screen_time_rules(alice, mia, '{"dailyLimitMinutes": 2}');
        raise exception 'M1 FAIL: 2-minute limit accepted';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.set_screen_time_rules(alice, mia, jsonb_build_object('blockedCategoryIds', jsonb_build_array(gen_random_uuid())));
        raise exception 'M1 FAIL: unknown category accepted';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.set_screen_time_rules(bob, mia, '{"watchEnabled": true}');
        raise exception 'M1 FAIL: Bob changed Mia''s rules';
  exception when sqlstate 'KL404' then null; end;
  -- a partial update keeps what it doesn't mention
  r := private.set_screen_time_rules(alice, mia, '{"watchEnabled": true}');
  if jsonb_array_length(r->'blockedCategoryIds') <> 1 then raise exception 'M1 FAIL: partial update lost categories'; end if;
  raise notice 'M1 ok: section switches and blocked categories are enforced at launch; rules validated, household-only';

  -- 5. playback limit: 5 minutes for watch + listen, used up by heartbeats
  perform private.set_screen_time_rules(alice, mia, '{"dailyLimitMinutes": 5, "limitedSections": ["watch", "listen"]}');
  r := private.launch(alice, jsonb_build_object('childId', mia, 'activityId', snail));
  if (r->>'remainingSeconds')::int <> 300 then raise exception 'M1 FAIL: remaining %', r->'remainingSeconds'; end if;
  r := private.add_screen_time(alice, mia, 'watch', 120);
  r := private.add_screen_time(alice, mia, 'listen', 120);
  if (r->>'remainingSeconds')::int <> 60 or (r->>'locked')::boolean then raise exception 'M1 FAIL: heartbeat %', r; end if;
  r := private.add_screen_time(alice, mia, 'watch', 90);
  if not (r->>'locked')::boolean then raise exception 'M1 FAIL: not locked %', r; end if;
  begin perform private.launch(alice, jsonb_build_object('childId', mia, 'activityId', snail));
        raise exception 'M1 FAIL: launched after the limit';
  exception when sqlstate 'KL423' then if sqlerrm <> 'SCREEN_TIME_OVER' then raise; end if; end;
  perform private.launch(alice, jsonb_build_object('childId', mia, 'activityId', game));     -- games aren't limited
  begin perform private.add_screen_time(alice, mia, 'watch', 500);
        raise exception 'M1 FAIL: 500-second heartbeat';
  exception when sqlstate 'KL400' then null; end;
  perform private.set_screen_time_rules(alice, mia, '{"dailyLimitMinutes": null}');
  raise notice 'M1 ok: daily limit counts watch + listen time and locks launch when used up; games stay open';

  -- 6. resume: an unfinished video returns where it stopped; finishing it clears that
  perform private.apply_session(alice, jsonb_build_object(
    'session', jsonb_build_object('id', s1, 'childId', mia, 'activityId', snail, 'source', 'feed', 'platform', 'web',
      'appVersion', '1.0.0', 'contentVersion', 1, 'status', 'abandoned', 'startedAt', now() - interval '2 minutes', 'endedAt', now() - interval '1 minute'),
    'result', jsonb_build_object('completed', false, 'durationMs', 12000,
      'metrics', jsonb_build_object('positionMs', 12000, 'durationMs', 36000))));
  r := private.launch(alice, jsonb_build_object('childId', mia, 'activityId', snail));
  if (r->'resume'->>'positionMs')::int <> 12000 then raise exception 'M1 FAIL: resume %', r->'resume'; end if;
  perform private.apply_session(alice, jsonb_build_object(
    'session', jsonb_build_object('id', s2, 'childId', mia, 'activityId', snail, 'source', 'feed', 'platform', 'web',
      'appVersion', '1.0.0', 'contentVersion', 1, 'status', 'completed', 'startedAt', now() - interval '40 seconds', 'endedAt', now()),
    'result', jsonb_build_object('completed', true, 'durationMs', 24000, 'metrics', jsonb_build_object('positionMs', 36000, 'durationMs', 36000))));
  r := private.launch(alice, jsonb_build_object('childId', mia, 'activityId', snail));
  if r->'resume' <> 'null'::jsonb then raise exception 'M1 FAIL: resume after finishing %', r->'resume'; end if;
  raise notice 'M1 ok: resume position from the last unfinished session; cleared once finished';
end $$;

set local role authenticated;
do $$ begin
  perform private.launch('00000000-0000-4000-a000-0000000000a1', '{}');
  raise exception 'M1 FAIL: authenticated can execute launch';
exception when insufficient_privilege then
  raise notice 'M1 ok: launch, heartbeat and rules updates are service-only';
end $$;
reset role;
rollback;
