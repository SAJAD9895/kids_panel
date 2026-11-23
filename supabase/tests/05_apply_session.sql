-- =============================================================================
-- P1 private.apply_session (migration 0015): POST /play/sync
-- Called as the Edge Function calls it: service connection, user id from the JWT.
-- =============================================================================
\set ON_ERROR_STOP on
begin;

do $$
declare
  alice uuid := '00000000-0000-4000-a000-0000000000a1';
  bob   uuid := '00000000-0000-4000-a000-0000000000b1';
  mia uuid; leo uuid; sam uuid; snail uuid; train uuid; cloud uuid; step1 uuid; step2 uuid;
  s1 uuid := gen_random_uuid(); s2 uuid := gen_random_uuid(); s3 uuid := gen_random_uuid();
  r jsonb; day date; stars_before int; n int;
  function_body text;
begin
  select id into mia from child_profiles where nickname = 'Mia';
  select id into leo from child_profiles where nickname = 'Leo';
  select id into sam from child_profiles where nickname = 'Sam';
  select id into snail from activities where slug = 'pip-meets-a-snail';
  select id into train from activities where slug = 'counting-train';
  select id into cloud from activities where slug = 'the-sleepy-cloud';
  -- Island 2 of "Letters a to h": step 1 = pip-meets-a-snail, step 2 = counting-train
  select st.id into step1 from lesson_steps st join lessons l on l.id = st.lesson_id
    join course_modules m on m.id = l.module_id join courses c on c.id = m.course_id
    where c.slug = 'letters-a-to-h' and l.position = 1 and st.position = 0;
  select st.id into step2 from lesson_steps st join lessons l on l.id = st.lesson_id
    join course_modules m on m.id = l.module_id join courses c on c.id = m.course_id
    where c.slug = 'letters-a-to-h' and l.position = 1 and st.position = 1;

  -- 1. started, then completed (same id): star once, step done, enrolment moves on
  r := private.apply_session(alice, jsonb_build_object('session', jsonb_build_object(
        'id', s1, 'childId', leo, 'activityId', snail, 'lessonStepId', step1, 'source', 'course',
        'platform', 'ios', 'appVersion', '1.0.0', 'contentVersion', 1, 'status', 'started',
        'startedAt', now() - interval '3 minutes')));
  if r->>'status' <> 'accepted' then raise exception 'P1 FAIL: start %', r; end if;
  if (select status from activity_sessions where id = s1) <> 'started' then raise exception 'P1 FAIL: not started'; end if;

  r := private.apply_session(alice, jsonb_build_object(
        'session', jsonb_build_object('id', s1, 'childId', leo, 'activityId', snail, 'lessonStepId', step1,
          'source', 'course', 'platform', 'ios', 'appVersion', '1.0.0', 'contentVersion', 1, 'status', 'completed',
          'startedAt', now() - interval '3 minutes', 'endedAt', now() - interval '1 minute'),
        'result', jsonb_build_object('completed', true, 'score', 80, 'correctCount', 4, 'totalCount', 5,
          'durationMs', 110000, 'metrics', jsonb_build_object('items', jsonb_build_array(jsonb_build_object('k', 'choice', 'ok', true))))));
  if not (r->>'starAwarded')::boolean or not (r->>'stepCompleted')::boolean then raise exception 'P1 FAIL: complete %', r; end if;
  -- Leo hasn't done island 1, so the next required step is island 1's first
  if (r->>'nextStepId')::uuid <> (select st.id from lesson_steps st join lessons l on l.id = st.lesson_id
      join course_modules m on m.id = l.module_id join courses c on c.id = m.course_id
      where c.slug = 'letters-a-to-h' and l.position = 0 and st.position = 0) then raise exception 'P1 FAIL: next step %', r; end if;
  if (select status from activity_sessions where id = s1) <> 'completed' then raise exception 'P1 FAIL: status'; end if;
  if (select score from activity_results where session_id = s1) <> 80 then raise exception 'P1 FAIL: result'; end if;
  if not exists (select 1 from lesson_step_completions where child_id = leo and step_id = step1) then raise exception 'P1 FAIL: step completion'; end if;
  if (select current_step_id from course_enrollments ce join courses c on c.id = ce.course_id
      where ce.child_id = leo and c.slug = 'letters-a-to-h') <> (r->>'nextStepId')::uuid then raise exception 'P1 FAIL: enrolment'; end if;
  day := (r->>'localDate')::date;
  if (select stars from daily_progress where child_id = leo and local_date = day) <> 1 then raise exception 'P1 FAIL: daily stars'; end if;

  -- 2. replaying the same completed session changes nothing
  r := private.apply_session(alice, jsonb_build_object(
        'session', jsonb_build_object('id', s1, 'childId', leo, 'activityId', snail, 'status', 'completed',
          'startedAt', now() - interval '3 minutes', 'endedAt', now() - interval '1 minute'),
        'result', jsonb_build_object('completed', true, 'score', 100, 'durationMs', 1)));
  if r->>'status' <> 'duplicate' then raise exception 'P1 FAIL: replay %', r; end if;
  if (select score from activity_results where session_id = s1) <> 80 then raise exception 'P1 FAIL: replay changed the result'; end if;
  if (select sessions_completed from daily_progress where child_id = leo and local_date = day) <> 1 then raise exception 'P1 FAIL: replay counted twice'; end if;

  -- 3. the same activity again today: recorded, but no second star (one per activity per day)
  r := private.apply_session(alice, jsonb_build_object(
        'session', jsonb_build_object('id', s2, 'childId', leo, 'activityId', snail, 'status', 'completed',
          'startedAt', now() - interval '1 minute', 'endedAt', now()),
        'result', jsonb_build_object('completed', true, 'score', 100, 'durationMs', 60000)));
  if (r->>'starAwarded')::boolean then raise exception 'P1 FAIL: second star for the same activity'; end if;
  if (select stars from daily_progress where child_id = leo and local_date = day) <> 1 then raise exception 'P1 FAIL: stars'; end if;

  -- 4. abandoned: time counted, no star
  r := private.apply_session(alice, jsonb_build_object('session', jsonb_build_object('id', s3, 'childId', leo,
        'activityId', train, 'status', 'abandoned', 'startedAt', now() - interval '2 minutes', 'endedAt', now())));
  if (r->>'starAwarded')::boolean or exists (select 1 from star_awards where session_id = s3) then raise exception 'P1 FAIL: abandoned star'; end if;

  -- 5. another family's child: 404, nothing written
  begin perform private.apply_session(bob, jsonb_build_object('session', jsonb_build_object('id', gen_random_uuid(),
          'childId', leo, 'activityId', snail, 'status', 'completed', 'startedAt', now(), 'endedAt', now())));
        raise exception 'P1 FAIL: Bob wrote a session for Leo';
  exception when sqlstate 'KL404' then null; end;

  -- 6. Plus content in a Basic family: recorded honestly, but no star or unlock
  r := private.apply_session(bob, jsonb_build_object(
        'session', jsonb_build_object('id', gen_random_uuid(), 'childId', sam, 'activityId', cloud, 'status', 'completed',
          'startedAt', now() - interval '1 minute', 'endedAt', now()),
        'result', jsonb_build_object('completed', true, 'score', 100, 'durationMs', 60000)));
  if (r->>'allowed')::boolean or (r->>'starAwarded')::boolean then raise exception 'P1 FAIL: Plus without Plus %', r; end if;

  -- 7. validation: future time, bad status, wrong step, unpublished activity
  begin perform private.apply_session(alice, jsonb_build_object('session', jsonb_build_object('id', gen_random_uuid(),
          'childId', leo, 'activityId', snail, 'status', 'completed', 'startedAt', now() + interval '1 hour')));
        raise exception 'P1 FAIL: future time';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.apply_session(alice, jsonb_build_object('session', jsonb_build_object('id', gen_random_uuid(),
          'childId', leo, 'activityId', snail, 'status', 'won', 'startedAt', now())));
        raise exception 'P1 FAIL: bad status';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.apply_session(alice, jsonb_build_object('session', jsonb_build_object('id', gen_random_uuid(),
          'childId', leo, 'activityId', train, 'lessonStepId', step1, 'status', 'completed', 'startedAt', now())));
        raise exception 'P1 FAIL: step of another activity';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.apply_session(alice, jsonb_build_object('session', jsonb_build_object('id', gen_random_uuid(),
          'childId', leo, 'activityId', (select id from activities where slug = 'draft-new-game'), 'status', 'completed', 'startedAt', now())));
        raise exception 'P1 FAIL: draft activity';
  exception when sqlstate 'KL404' then null; end;

  -- 8. a session id reused for another child is a conflict
  begin perform private.apply_session(alice, jsonb_build_object('session', jsonb_build_object('id', s1,
          'childId', mia, 'activityId', snail, 'status', 'completed', 'startedAt', now())));
        raise exception 'P1 FAIL: session id reuse';
  exception when sqlstate 'KL409' then null; end;

  -- 9. quiz answers are stored per question and attempt
  r := private.apply_session(alice, jsonb_build_object(
        'session', jsonb_build_object('id', gen_random_uuid(), 'childId', mia, 'activityId',
          (select id from activities where slug = 'letters-check'), 'status', 'completed',
          'startedAt', now() - interval '1 minute', 'endedAt', now()),
        'result', jsonb_build_object('completed', true, 'score', 67, 'correctCount', 2, 'totalCount', 3, 'durationMs', 50000),
        'responses', (select jsonb_agg(jsonb_build_object('questionId', q.id, 'attempt', 1, 'isCorrect', q.position <> 2,
                        'answerId', (select a.id from answers a where a.question_id = q.id and a.is_correct), 'responseMs', 4000))
                      from questions q where q.activity_id = (select id from activities where slug = 'letters-check'))));
  select count(*) into n from question_responses where session_id = (r->>'sessionId')::uuid;
  if n <> 3 then raise exception 'P1 FAIL: % responses stored', n; end if;

  raise notice 'P1 ok: sessions are idempotent, one star per activity per day, steps unlock, households isolated, Plus honoured';
end $$;

set local role authenticated;
do $$ begin
  perform private.apply_session('00000000-0000-4000-a000-0000000000a1', '{}');
  raise exception 'P1 FAIL: authenticated can execute apply_session';
exception when insufficient_privilege then
  raise notice 'P1 ok: apply_session is service-only';
end $$;
reset role;
rollback;
