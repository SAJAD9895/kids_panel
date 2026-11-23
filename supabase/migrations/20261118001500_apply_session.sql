-- POST /play/sync → private.apply_session (Phase 9: the learning engine saves progress).
-- docs/architecture/09-learning-progress-engine.md §9.2, implemented for the parts the app uses
-- now: session + result + responses, stars, the daily roll-up, lesson steps and course completion.
-- Not yet: gifts, skill mastery, badges, certificates, the free daily allocation (later modules).
--
-- Same pattern as 0012/0014: service-only, p_user_id is the verified JWT's `sub`, the function
-- checks the child belongs to that parent, errors are KL4xx.
--
-- p = { clockOffsetMs?,
--       session: {id, childId, activityId, lessonStepId?, source, platform, appVersion,
--                 contentVersion, status: started|completed|abandoned, startedAt, endedAt?},
--       result?: {completed, score?, correctCount?, totalCount?, durationMs, metrics?},
--       responses?: [{questionId, attempt, answerId?, isCorrect, responseMs?}] }
--
-- Idempotent per session id. A session first sent as `started` may later be sent again as
-- `completed` or `abandoned` (the app reports the start, then the end); anything else is a
-- duplicate and changes nothing.

create or replace function private.apply_session(p_user_id uuid, p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  s jsonb := p->'session';
  r jsonb := p->'result';
  sid uuid; child uuid; act uuid; step uuid; acc uuid;
  a public.activities;
  existing public.activity_sessions;
  offset_ms bigint := coalesce((p->>'clockOffsetMs')::bigint, 0);
  t_start timestamptz; t_end timestamptz; v_status text; day date;
  allowed boolean;
  is_new boolean := false; finishing boolean := false;
  star boolean := false; step_done boolean := false; course_done boolean := false;
  next_step uuid; course uuid; secs integer;
  stars_today integer;
begin
  if jsonb_typeof(s) is distinct from 'object' then perform private.fail('KL400', 'VALIDATION', 'session is required'); end if;
  begin
    sid := (s->>'id')::uuid; child := (s->>'childId')::uuid; act := (s->>'activityId')::uuid;
    step := nullif(s->>'lessonStepId', '')::uuid;
  exception when invalid_text_representation then
    perform private.fail('KL400', 'VALIDATION', 'invalid id');
  end;
  if sid is null or child is null or act is null then perform private.fail('KL400', 'VALIDATION', 'ids are required'); end if;

  -- the child must belong to the caller's household (404 otherwise: ids can't be probed)
  select ch.account_id into acc
  from public.child_profiles ch
  join public.parent_profiles pp on pp.account_id = ch.account_id and pp.user_id = p_user_id
  where ch.id = child and ch.status = 'active';
  if acc is null then perform private.fail('KL404', 'NOT_FOUND', 'child'); end if;

  select * into a from public.activities where id = act and status = 'published';
  if a.id is null then perform private.fail('KL404', 'NOT_FOUND', 'activity'); end if;
  if step is not null and not exists (select 1 from public.lesson_steps where id = step and activity_id = act) then
    perform private.fail('KL400', 'VALIDATION', 'lesson step does not belong to the activity');
  end if;

  v_status := s->>'status';
  if v_status is null or v_status not in ('started', 'completed', 'abandoned') then
    perform private.fail('KL400', 'VALIDATION', 'bad status');
  end if;

  -- time: correct by the device's measured clock offset, then sanity-check (§9.2 rule 1)
  begin
    t_start := (s->>'startedAt')::timestamptz + make_interval(secs => offset_ms / 1000.0);
    t_end := (s->>'endedAt')::timestamptz + make_interval(secs => offset_ms / 1000.0);
  exception when others then
    perform private.fail('KL400', 'VALIDATION', 'bad timestamps');
  end;
  if t_start is null then perform private.fail('KL400', 'VALIDATION', 'startedAt is required'); end if;
  if t_start > now() + interval '5 minutes' or t_end > now() + interval '5 minutes' then
    perform private.fail('KL400', 'VALIDATION', 'time in the future');
  end if;
  if t_start < now() - interval '30 days' then perform private.fail('KL400', 'VALIDATION', 'too old'); end if;
  if v_status <> 'started' then
    t_end := coalesce(t_end, t_start);
    if t_end < t_start then t_end := t_start; end if;
    if t_end - t_start > interval '4 hours' then t_end := t_start + interval '4 hours'; end if;
  else
    t_end := null;
  end if;
  day := private.local_date(acc, t_start);          -- the household's day, never the device's

  -- one session at a time per id
  perform pg_advisory_xact_lock(hashtextextended('session:' || sid::text, 0));
  select * into existing from public.activity_sessions where id = sid;
  if existing.id is not null then
    if existing.child_id <> child or existing.activity_id <> act then
      perform private.fail('KL409', 'CONFLICT', 'session id reused');
    end if;
    if existing.status <> 'started' or v_status = 'started' then
      return jsonb_build_object('sessionId', sid, 'status', 'duplicate');
    end if;
    update public.activity_sessions set status = v_status, ended_at = t_end where id = sid;
    finishing := true;
  else
    insert into public.activity_sessions (id, child_id, activity_id, lesson_step_id, source, platform, app_version,
                                          content_version, status, started_at, ended_at, local_date)
    values (sid, child, act, step, coalesce(s->>'source', 'feed'), coalesce(s->>'platform', 'web'),
            left(coalesce(s->>'appVersion', '0'), 32), greatest(coalesce((s->>'contentVersion')::int, 1), 1),
            v_status, t_start, t_end, day);
    is_new := true;
    finishing := v_status <> 'started';
    insert into public.daily_progress (child_id, local_date, sessions_started) values (child, day, 1)
    on conflict (child_id, local_date) do update set sessions_started = public.daily_progress.sessions_started + 1;
  end if;

  if not finishing then
    return jsonb_build_object('sessionId', sid, 'status', 'accepted');
  end if;

  -- the result (once) and the quiz answers
  if jsonb_typeof(r) = 'object' then
    insert into public.activity_results (session_id, completed, score, correct_count, total_count, duration_ms, metrics)
    values (sid, coalesce((r->>'completed')::boolean, v_status = 'completed'),
            least(greatest((r->>'score')::numeric, 0), 100),
            (r->>'correctCount')::smallint, (r->>'totalCount')::smallint,
            least(greatest(coalesce((r->>'durationMs')::int, 0), 0), 4 * 3600 * 1000),
            coalesce(case when jsonb_typeof(r->'metrics') = 'object' then r->'metrics' end, '{}'))
    on conflict (session_id) do nothing;
  end if;
  insert into public.question_responses (session_id, question_id, attempt, answer_id, is_correct, response_ms)
  select sid, (x->>'questionId')::uuid, least(greatest(coalesce((x->>'attempt')::int, 1), 1), 20),
         (select id from public.answers an where an.id = nullif(x->>'answerId', '')::uuid and an.question_id = (x->>'questionId')::uuid),
         coalesce((x->>'isCorrect')::boolean, false), greatest((x->>'responseMs')::int, 0)
  from jsonb_array_elements(case when jsonb_typeof(p->'responses') = 'array' then p->'responses' else '[]' end) x
  where exists (select 1 from public.questions q where q.id = (x->>'questionId')::uuid and q.activity_id = act)
  on conflict do nothing;

  secs := extract(epoch from (t_end - t_start))::int;
  if v_status = 'abandoned' then
    update public.daily_progress set seconds_played = seconds_played + secs where child_id = child and local_date = day;
    return jsonb_build_object('sessionId', sid, 'status', 'accepted', 'starAwarded', false);
  end if;

  -- access at play time (§9.2 rule 3): Plus content without Plus is recorded, but earns nothing
  allowed := not a.plus_only or exists (
    select 1 from public.entitlements e
    where e.account_id = acc and e.entitlement = 'plus' and e.active_until > t_start);

  if allowed then
    insert into public.star_awards (child_id, local_date, activity_id, session_id) values (child, day, act, sid)
    on conflict do nothing;
    star := found;

    if step is not null then
      insert into public.lesson_step_completions (child_id, step_id, session_id, score, completed_at)
      values (child, step, sid, least(greatest((r->>'score')::numeric, 0), 100), t_end)
      on conflict do nothing;
      step_done := true;

      select m.course_id into course
      from public.lesson_steps st join public.lessons l on l.id = st.lesson_id
      join public.course_modules m on m.id = l.module_id where st.id = step;

      -- next required step not done yet, in (module, lesson, step) order
      select st.id into next_step
      from public.lesson_steps st join public.lessons l on l.id = st.lesson_id
      join public.course_modules m on m.id = l.module_id
      where m.course_id = course and st.required
        and not exists (select 1 from public.lesson_step_completions c where c.child_id = child and c.step_id = st.id)
      order by m.position, l.position, st.position limit 1;
      course_done := next_step is null;

      insert into public.course_enrollments (child_id, course_id, status, current_step_id, completed_at)
      values (child, course, case when course_done then 'completed' else 'in_progress' end, next_step,
              case when course_done then now() end)
      on conflict (child_id, course_id) do update
        set current_step_id = excluded.current_step_id,
            status = case when public.course_enrollments.status = 'completed' then 'completed' else excluded.status end,
            completed_at = coalesce(public.course_enrollments.completed_at, excluded.completed_at);
    end if;
  end if;

  update public.daily_progress
     set sessions_completed = sessions_completed + 1,
         seconds_played = seconds_played + secs,
         stars = stars + case when star then 1 else 0 end
   where child_id = child and local_date = day;
  if not found then
    insert into public.daily_progress (child_id, local_date, sessions_started, sessions_completed, seconds_played, stars)
    values (child, day, 1, 1, secs, case when star then 1 else 0 end);
  end if;
  select stars into stars_today from public.daily_progress where child_id = child and local_date = day;

  return jsonb_build_object(
    'sessionId', sid, 'status', 'accepted', 'allowed', allowed, 'starAwarded', star, 'starsToday', stars_today,
    'stepCompleted', step_done, 'nextStepId', next_step, 'courseCompleted', course_done, 'localDate', day);
exception
  when check_violation or not_null_violation or numeric_value_out_of_range or invalid_text_representation then
    perform private.fail('KL400', 'VALIDATION', 'invalid session: ' || sqlerrm);
    return null;
end $$;

revoke all on function private.apply_session(uuid, jsonb) from public, anon, authenticated;
grant execute on function private.apply_session(uuid, jsonb) to service_role;
