-- =============================================================================
-- R1 Rewards (migration 20261121000100): stars ledger, rules, goals, streaks, badges, the
-- summary and the goals API. Sessions go through private.apply_session exactly as POST
-- /play/sync sends them. Runs in one transaction and ROLLS BACK.
-- Alice's household is in Asia/Dubai (Mia, Leo; Plus); Bob's in Europe/London (Sam; Basic).
-- =============================================================================
\set ON_ERROR_STOP on
begin;

-- A finished session, as the app reports it (a lesson step when p_step is given).
create function pg_temp.play(p_user uuid, p_child uuid, p_slug text, p_at timestamptz,
                             p_step uuid default null, p_id uuid default gen_random_uuid())
returns jsonb language sql as $$
  select private.apply_session(p_user, jsonb_build_object('session', jsonb_build_object(
    'id', p_id, 'childId', p_child,
    'activityId', coalesce((select activity_id from public.lesson_steps where id = p_step),
                           (select id from public.activities where slug = p_slug)),
    'lessonStepId', p_step, 'source', case when p_step is null then 'feed' else 'course' end,
    'platform', 'ios', 'appVersion', '1.0.0', 'contentVersion', 1, 'status', 'completed',
    'startedAt', p_at, 'endedAt', p_at + interval '2 minutes'),
    'result', jsonb_build_object('completed', true, 'score', 100, 'durationMs', 120000)))
$$;

-- Noon on a household day, as an instant.
create function pg_temp.noon(p_day date, p_tz text) returns timestamptz language sql as $$
  select (p_day + time '12:00') at time zone p_tz
$$;

create function pg_temp.tx(p_child uuid) returns int language sql as $$
  select count(*)::int from public.star_transactions where child_id = p_child
$$;

do $$
declare
  alice uuid := '00000000-0000-4000-a000-0000000000a1';
  bob   uuid := '00000000-0000-4000-a000-0000000000b1';
  leo uuid; sam uuid; today date; sam_today date; r jsonb; rw jsonb; n int; m int;
  sid uuid := gen_random_uuid(); mid timestamptz; st record; bal_before int; k int;
begin
  select id into leo from child_profiles where nickname = 'Leo';
  select id into sam from child_profiles where nickname = 'Sam';
  today := private.local_date((select account_id from child_profiles where id = leo), now());
  sam_today := private.local_date((select account_id from child_profiles where id = sam), now());

  -- 1. one star per activity per day, a ledger row for it, the first-game badge (+1 bonus)
  r := pg_temp.play(alice, leo, 'shape-homes', now() - interval '20 minutes', null, sid);
  rw := r->'rewards';
  if not (r->>'starAwarded')::boolean or (rw->>'stars')::int <> 2
     or rw->'badges'->0->>'key' <> 'badge-first-game' or rw->'badges'->0->>'art' not like 'badges/first-game/%' then
    raise exception 'R1 FAIL: first game %', r;
  end if;
  if pg_temp.tx(leo) <> 2 or (select sum(amount) from star_transactions where child_id = leo) <> 2 then
    raise exception 'R1 FAIL: ledger after first game';
  end if;

  -- 2. duplicates: the same upload again, the same activity again today, rewards re-run
  r := pg_temp.play(alice, leo, 'shape-homes', now() - interval '20 minutes', null, sid);
  if r->>'status' <> 'duplicate' or r ? 'rewards' then raise exception 'R1 FAIL: replay %', r; end if;
  r := pg_temp.play(alice, leo, 'shape-homes', now() - interval '15 minutes');
  if (r->>'starAwarded')::boolean or (r->'rewards'->>'stars')::int <> 0 then raise exception 'R1 FAIL: same activity twice %', r; end if;
  rw := private.apply_rewards(sid);
  if (rw->>'stars')::int <> 0 or jsonb_array_length(rw->'badges') <> 0 or pg_temp.tx(leo) <> 2 then
    raise exception 'R1 FAIL: apply_rewards is not idempotent %', rw;
  end if;
  raise notice 'R1 ok: one star per activity per day, a ledger row each; replays and re-runs pay nothing';

  -- 3. the daily goal (default 3 different activities): once, with its bonus star and badge
  perform pg_temp.play(alice, leo, 'memory-match', now() - interval '14 minutes');
  r := pg_temp.play(alice, leo, 'puzzle-time', now() - interval '13 minutes');
  rw := r->'rewards';
  if not exists (select 1 from jsonb_array_elements(rw->'goals') g where g->>'period' = 'day' and (g->>'justCompleted')::boolean)
     or not exists (select 1 from jsonb_array_elements(rw->'badges') b where b->>'key' = 'badge-goal-1') then
    raise exception 'R1 FAIL: daily goal %', rw;
  end if;
  r := pg_temp.play(alice, leo, 'word-builder', now() - interval '12 minutes');
  if exists (select 1 from jsonb_array_elements(r->'rewards'->'goals') g where (g->>'justCompleted')::boolean) then
    raise exception 'R1 FAIL: goal celebrated twice %', r;
  end if;
  select count(*) into n from star_transactions where child_id = leo and reason = 'daily_goal_met';
  if n <> 1 then raise exception 'R1 FAIL: % daily-goal bonuses', n; end if;
  if (select progress from goal_progress where child_id = leo and period = 'day' and period_start = today) <> 4 then
    raise exception 'R1 FAIL: goal progress';
  end if;
  raise notice 'R1 ok: daily goal reached once (bonus star, badge), progress keeps counting';

  -- 4. configurable rules: an admin changes the activity star to 3, then switches it off
  update reward_rules set stars = 3 where key = 'activity_completed';
  perform pg_temp.play(alice, leo, 'sort-it-out', now() - interval '11 minutes');
  if (select amount from star_transactions where child_id = leo and ref_key like 'activity:%'
        and ref_key like '%' || (select id from activities where slug = 'sort-it-out') || '%') <> 3 then
    raise exception 'R1 FAIL: rule amount not used';
  end if;
  update reward_rules set active = false where key = 'activity_completed';
  n := pg_temp.tx(leo);
  r := pg_temp.play(alice, leo, 'picture-match', now() - interval '10 minutes');
  if not (r->>'starAwarded')::boolean or pg_temp.tx(leo) <> n then
    raise exception 'R1 FAIL: inactive rule still paid';
  end if;
  update reward_rules set stars = 1, active = true where key = 'activity_completed';
  raise notice 'R1 ok: reward rules are configurable (amount, on/off)';

  -- 5. streak: learning days -6 -5 . -3 -1 0, then day -2 arrives late (offline): 6 days, one
  --    rest day (-4) doesn't break it; one streak row per child; three-day badge
  for k in select unnest(array[6, 5, 3, 1]) loop
    perform pg_temp.play(alice, leo, 'number-fun', pg_temp.noon(today - k, 'Asia/Dubai'));
  end loop;
  select current_days, longest_days into st from learning_streaks where child_id = leo;
  if st.current_days <> 5 then raise exception 'R1 FAIL: streak before late day %', st; end if;
  perform pg_temp.play(alice, leo, 'quiz-time', pg_temp.noon(today - 2, 'Asia/Dubai'));
  select current_days, longest_days into st from learning_streaks where child_id = leo;
  if st.current_days <> 6 or st.longest_days <> 6 then raise exception 'R1 FAIL: streak after late day %', st; end if;
  if (select count(*) from learning_streaks where child_id = leo) <> 1 then raise exception 'R1 FAIL: streak rows'; end if;
  if not exists (select 1 from child_rewards cr join rewards b on b.id = cr.reward_id
                 where cr.child_id = leo and b.key = 'badge-streak-3') then
    raise exception 'R1 FAIL: streak badge';
  end if;
  raise notice 'R1 ok: streak counts learning days, forgives one rest day, accepts late offline days';

  -- 6. two rest days in a row start a new streak; the best is kept; nothing is taken away
  for k in select unnest(array[10, 9, 8, 5]) loop
    perform pg_temp.play(bob, sam, 'shape-sort', pg_temp.noon(sam_today - k, 'Europe/London'));
  end loop;
  r := private.rewards_summary(bob, sam);
  if (r->'streak'->>'current')::int <> 0 or (r->'streak'->>'longest')::int <> 3 then
    raise exception 'R1 FAIL: broken streak %', r->'streak';
  end if;
  bal_before := (r->>'balance')::int;
  perform pg_temp.play(bob, sam, 'shape-homes', now() - interval '5 minutes');
  r := private.rewards_summary(bob, sam);
  if (r->'streak'->>'current')::int <> 1 or (r->'streak'->>'longest')::int <> 3 or (r->>'balance')::int <= bal_before then
    raise exception 'R1 FAIL: new streak %', r;
  end if;
  if exists (select 1 from star_transactions where amount <= 0) then raise exception 'R1 FAIL: negative stars'; end if;
  raise notice 'R1 ok: two rest days start a new streak, the best is kept, stars only go up';

  -- 7. household time zones at midnight: Dubai's midnight starting yesterday
  mid := (today - 1)::timestamp at time zone 'Asia/Dubai';
  r := pg_temp.play(alice, leo, 'engine-sampler', mid - interval '3 minutes');
  if (r->>'localDate')::date <> today - 2 or not (r->>'starAwarded')::boolean then raise exception 'R1 FAIL: before midnight %', r; end if;
  r := pg_temp.play(alice, leo, 'engine-sampler', mid + interval '1 minute');
  if (r->>'localDate')::date <> today - 1 or not (r->>'starAwarded')::boolean then raise exception 'R1 FAIL: after midnight %', r; end if;
  -- the same instant is a different day in London (20:01 the evening before)
  r := pg_temp.play(bob, sam, 'engine-sampler', mid + interval '1 minute');
  if (r->>'localDate')::date <> ((mid + interval '1 minute') at time zone 'Europe/London')::date
     or (r->>'localDate')::date = today - 1 then
    raise exception 'R1 FAIL: London day %', r;
  end if;
  if (select count(*) from star_transactions where child_id = leo and reason = 'activity_completed'
        and ref_key like 'activity:' || (select id from activities where slug = 'engine-sampler') || ':%') <> 2 then
    raise exception 'R1 FAIL: midnight stars';
  end if;
  if exists (select 1 from goal_progress where period = 'week' and extract(isodow from period_start) <> 1) then
    raise exception 'R1 FAIL: weeks start on Monday';
  end if;
  raise notice 'R1 ok: days and weeks follow the household time zone (midnight, Monday)';

  -- 8. islands and a course: bonus once each, certificate, badges
  n := 0;
  for st in select s.id, l.position as lp, l.id as lesson
            from lesson_steps s join lessons l on l.id = s.lesson_id join course_modules cm on cm.id = l.module_id
            join courses c on c.id = cm.course_id
            where c.slug = 'letters-a-to-h' and s.required order by cm.position, l.position, s.position loop
    r := pg_temp.play(alice, leo, null, now() - interval '9 minutes', st.id);
    if (r->'rewards'->>'lessonCompleted')::boolean then n := n + 1; end if;
  end loop;
  if n <> 3 or not (r->'rewards'->>'courseCompleted')::boolean then raise exception 'R1 FAIL: islands % / course %', n, r; end if;
  select count(*) into n from star_transactions where child_id = leo and reason = 'lesson_completed';
  select count(*) into m from star_transactions where child_id = leo and reason = 'course_completed';
  if n <> 3 or m <> 1 or not exists (select 1 from certificates where child_id = leo) then
    raise exception 'R1 FAIL: lesson % course % bonuses', n, m;
  end if;
  -- doing a step again pays no island bonus again
  r := pg_temp.play(alice, leo, null, now() - interval '8 minutes',
         (select s.id from lesson_steps s join lessons l on l.id = s.lesson_id join course_modules cm on cm.id = l.module_id
          join courses c on c.id = cm.course_id where c.slug = 'letters-a-to-h' and l.position = 0 and s.position = 0));
  if (r->'rewards'->>'lessonCompleted')::boolean or (select count(*) from star_transactions where child_id = leo and reason = 'lesson_completed') <> 3 then
    raise exception 'R1 FAIL: island bonus twice';
  end if;
  if (select count(*) from child_rewards cr join rewards b on b.id = cr.reward_id
      where cr.child_id = leo and b.key in ('badge-first-island', 'badge-first-course', 'badge-letters')) <> 3 then
    raise exception 'R1 FAIL: island / course / explorer badges';
  end if;
  raise notice 'R1 ok: islands and courses give their bonus once; certificate; badges';

  -- 9. parent goals: household only, validated, partial; a reached goal stays reached
  begin perform private.set_learning_goals(bob, leo, '{"dailyActivities": 5}');
        raise exception 'R1 FAIL: another family set goals';
  exception when sqlstate 'KL404' then null; end;
  begin perform private.set_learning_goals(alice, leo, '{"dailyActivities": 11}');
        raise exception 'R1 FAIL: goal out of range';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.set_learning_goals(alice, leo, '{"weeklyDays": "lots"}');
        raise exception 'R1 FAIL: goal not a number';
  exception when sqlstate 'KL400' then null; end;
  r := private.set_learning_goals(alice, leo, '{"dailyActivities": 5}');
  if (r->>'dailyActivities')::int <> 5 or (r->>'weeklyDays')::int <> 4 or not (r->>'enabled')::boolean then
    raise exception 'R1 FAIL: goals saved %', r;
  end if;
  if (select completed_at from goal_progress where child_id = leo and period = 'day' and period_start = today) is null then
    raise exception 'R1 FAIL: a reached goal was un-reached';
  end if;
  perform private.set_learning_goals(bob, sam, '{"enabled": false}');
  perform pg_temp.play(bob, sam, 'puzzle-time', pg_temp.noon(sam_today - 3, 'Europe/London'));
  if exists (select 1 from goal_progress where child_id = sam and period_start = sam_today - 3) then
    raise exception 'R1 FAIL: goals off but tracked';
  end if;
  raise notice 'R1 ok: parent goals are household-only, validated, partial, and can be switched off';

  -- 10. the summary: household day, balance = ledger, every badge, earned dates, counts
  r := private.rewards_summary(alice, leo);
  if (r->>'today')::date <> today or (r->>'balance')::int <> (select sum(amount) from star_transactions where child_id = leo)
     or jsonb_array_length(r->'badges') <> (select count(*) from rewards where type = 'badge' and status = 'active')
     or (select count(*) from jsonb_array_elements(r->'badges') b where b->>'earnedAt' is not null)
        <> (select count(*) from child_rewards cr join rewards b on b.id = cr.reward_id where cr.child_id = leo and b.type = 'badge')
     or (r->'counts'->>'islands')::int <> 3 or (r->'counts'->>'courses')::int <> 1
     or (r->'goals'->>'dailyActivities')::int <> 5 or (r->'streak'->>'current')::int < 6
     or not (r->'learningDays') ? today::text then
    raise exception 'R1 FAIL: summary %', r - 'badges' - 'transactions' - 'rules';
  end if;
  begin perform private.rewards_summary(bob, leo); raise exception 'R1 FAIL: another family''s summary';
  exception when sqlstate 'KL404' then null; end;
  raise notice 'R1 ok: summary (household day, balance, badges with dates, counts); household only';
end $$;

-- 11. clients read their own rows and write none; rules are admin-only
\set alice '00000000-0000-4000-a000-0000000000a1'
\set bob   '00000000-0000-4000-a000-0000000000b1'
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'bob', 'role', 'authenticated', 'aal', 'aal1')::text, true),
       set_config('request.jwt.claim.sub', :'bob', true) \g /dev/null
do $$
declare leo uuid; sam uuid;
begin
  select id into leo from child_profiles where nickname = 'Leo';   -- RLS: Bob can't see Leo at all
  select id into sam from child_profiles where nickname = 'Sam';
  if leo is not null then raise exception 'R1 FAIL: Bob sees Leo'; end if;
  if (select count(*) from star_transactions where child_id <> sam) > 0
     or (select count(*) from child_star_totals where child_id <> sam) > 0
     or (select count(*) from learning_streaks where child_id <> sam) > 0
     or (select count(*) from goal_progress where child_id <> sam) > 0
     or (select count(*) from learning_goals where child_id <> sam) > 0 then
    raise exception 'R1 FAIL: Bob reads another family''s rewards';
  end if;
  if (select count(*) from star_transactions where child_id = sam) = 0 then raise exception 'R1 FAIL: Bob can''t read Sam''s stars'; end if;
  begin
    insert into star_transactions (child_id, amount, reason, ref_key, local_date) values (sam, 20, 'badge', 'free', current_date);
    raise exception 'R1 FAIL: a parent gave stars';
  exception when insufficient_privilege then null; end;
  begin
    update learning_streaks set longest_days = 365 where child_id = sam;
    raise exception 'R1 FAIL: a parent edited a streak';
  exception when insufficient_privilege then null; end;
  begin
    insert into child_rewards (child_id, reward_id, source)
    select sam, id, 'badge_rule' from rewards where key = 'badge-streak-30';
    raise exception 'R1 FAIL: a parent gave a badge';
  exception when insufficient_privilege then null; end;
  begin
    update reward_rules set stars = 10 where key = 'activity_completed';
    if found then raise exception 'R1 FAIL: a parent changed a rule'; end if;
  exception when insufficient_privilege then null; end;
  begin
    perform private.apply_rewards(gen_random_uuid());
    raise exception 'R1 FAIL: client can run apply_rewards';
  exception when insufficient_privilege then null; end;
  begin
    perform private.rewards_summary(auth.uid(), sam);
    raise exception 'R1 FAIL: client can run rewards_summary';
  exception when insufficient_privilege then null; end;
  begin
    perform private.set_learning_goals(auth.uid(), sam, '{}');
    raise exception 'R1 FAIL: client can run set_learning_goals';
  exception when insufficient_privilege then null; end;
  raise notice 'R1 ok: parents read only their children''s rewards; stars, badges, streaks and rules can''t be written by clients';
end $$;
reset role;
rollback;
