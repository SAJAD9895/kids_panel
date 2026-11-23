-- Phase 12: rewards and gamification. docs/gamification/.
--
-- Builds on what exists instead of a second system:
--   * star_awards (one star per distinct activity per household day) stays THE activity-star rule;
--   * rewards (type 'badge', unlock_rule) stays the achievement catalogue; child_rewards stays
--     "this child earned it" (first_earned_at = the earned date);
--   * daily_progress stays the daily roll-up; apply_session stays the only place that awards.
-- New (each documented in database-schema.md §5 #13–#17):
--   reward_rules       configurable star amounts per event (admins edit; clients read)
--   star_transactions  the star ledger: every star with its reason; UNIQUE (child, reason, ref)
--                      makes every reward once-only, whatever retries or offline replays happen
--   learning_goals     per-child daily / weekly goals set by a parent
--   goal_progress      progress per child per day / week (once completed, stays completed)
--   learning_streaks   current and longest learning-day streak, recomputed from learning days
--   rewards.*          description, how_to_earn, rule_params, bonus_stars, sort (badge details)
-- No negative transactions exist: stars are never taken away or spent, and nothing is lost by
-- skipping a day.

-- ---------------------------------------------------------------------------------------------
-- 1. Catalogue: rules and badge details
-- ---------------------------------------------------------------------------------------------
create table reward_rules (
  key          text primary key check (key in
                 ('activity_completed','lesson_completed','course_completed','daily_goal_met','weekly_goal_met')),
  stars        smallint not null check (stars between 0 and 10),
  active       boolean not null default true,
  description  jsonb not null default '{}',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
insert into reward_rules (key, stars, description) values
  ('activity_completed', 1, '{"en":"Finish a game, video, song or story: 1 star (once a day for each one)"}'),
  ('lesson_completed',   2, '{"en":"Finish every step of an island: 2 bonus stars"}'),
  ('course_completed',   5, '{"en":"Finish a whole course: 5 bonus stars"}'),
  ('daily_goal_met',     1, '{"en":"Reach the daily goal: 1 bonus star"}'),
  ('weekly_goal_met',    2, '{"en":"Reach the weekly goal: 2 bonus stars"}')
on conflict (key) do nothing;

alter table rewards
  add column description  jsonb not null default '{}',
  add column how_to_earn  jsonb not null default '{}',
  add column rule_params  jsonb not null default '{}' check (jsonb_typeof(rule_params) = 'object'),
  add column bonus_stars  smallint not null default 0 check (bonus_stars between 0 and 10),
  add column sort         smallint not null default 0;
alter table rewards add constraint badge_rule_known check (unlock_rule is null or unlock_rule in
  ('first_lesson','first_game','first_course','daily_goals','weekly_goals','streak','subject_explorer','stars','stars_100'));

-- ---------------------------------------------------------------------------------------------
-- 2. Child data
-- ---------------------------------------------------------------------------------------------
create table star_transactions (
  id          uuid primary key default gen_random_uuid(),
  child_id    uuid not null references child_profiles(id) on delete cascade,
  amount      smallint not null check (amount between 1 and 20),
  reason      text not null check (reason in
                ('activity_completed','lesson_completed','course_completed','daily_goal_met','weekly_goal_met','badge')),
  ref_key     text not null check (length(ref_key) between 1 and 120),
  local_date  date not null,
  session_id  uuid references activity_sessions(id) on delete set null,
  reward_id   uuid references rewards(id) on delete restrict,
  created_at  timestamptz not null default clock_timestamp(),  -- keeps order within one sync
  unique (child_id, reason, ref_key)
);
create index on star_transactions (child_id, created_at desc);
create index on star_transactions (session_id);
create index on star_transactions (reward_id);

create table learning_goals (
  child_id          uuid primary key references child_profiles(id) on delete cascade,
  enabled           boolean not null default true,
  daily_activities  smallint not null default 3 check (daily_activities between 1 and 10),
  weekly_days       smallint not null default 4 check (weekly_days between 1 and 7),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create table goal_progress (
  child_id      uuid not null references child_profiles(id) on delete cascade,
  period        text not null check (period in ('day','week')),
  period_start  date not null,                     -- the household day, or the Monday of the week
  target        smallint not null check (target between 1 and 10),
  progress      smallint not null default 0 check (progress >= 0),
  completed_at  timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  primary key (child_id, period, period_start),
  constraint week_starts_monday check (period <> 'week' or extract(isodow from period_start) = 1)
);

create table learning_streaks (
  child_id           uuid primary key references child_profiles(id) on delete cascade,
  current_days       integer not null default 0 check (current_days >= 0),
  longest_days       integer not null default 0 check (longest_days >= 0),
  last_learning_day  date,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- Star balance per child (security invoker: RLS on star_transactions applies).
create view child_star_totals with (security_invoker = true) as
  select child_id, sum(amount)::int as stars, count(*)::int as transactions
  from star_transactions group by child_id;

-- RLS: parents of the child read; nobody writes from a client (service functions only).
alter table reward_rules enable row level security;
alter table star_transactions enable row level security;
alter table learning_goals enable row level security;
alter table goal_progress enable row level security;
alter table learning_streaks enable row level security;

create policy active_read on reward_rules for select using (active or private.has_permission('content.read'));
create policy admin_insert on reward_rules for insert with check (private.has_permission('content.write'));
create policy admin_update on reward_rules for update
  using (private.has_permission('content.write')) with check (private.has_permission('content.write'));
create policy admin_delete on reward_rules for delete using (private.has_permission('content.write'));

do $$
declare t text;
begin
  foreach t in array array['star_transactions','learning_goals','goal_progress','learning_streaks'] loop
    execute format('create policy child_read on %I for select
                    using (private.can_access_child(child_id) or private.has_permission(''support.read''))', t);
    execute format('revoke insert, update, delete, truncate, references, trigger on public.%I from anon, authenticated', t);
  end loop;
end $$;
revoke insert, update, delete, truncate, references, trigger on public.reward_rules from anon;
revoke truncate, references, trigger on public.reward_rules from authenticated;
revoke all on public.child_star_totals from anon;

do $$
declare t text;
begin
  foreach t in array array['reward_rules','learning_goals','goal_progress','learning_streaks'] loop
    execute format('create trigger set_updated_at before update on public.%I
                    for each row execute function private.set_updated_at()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------------------------
-- 3. Streaks. A learning day is a household day with at least one star. A streak continues
--    while there's never a gap of 2+ days in a row: one rest day between learning days doesn't
--    break it (children have off days), and only learning days are counted. It stays "current"
--    until the end of the day after a rest day, so a child is never told they lost it mid-day.
-- ---------------------------------------------------------------------------------------------
create or replace function private.streak_of(p_child uuid, p_today date)
returns table (current_days int, longest_days int, last_day date)
language plpgsql stable security definer set search_path = '' as $$
declare d date; prev date; run int := 0; best int := 0;
begin
  for d in
    select distinct s.local_date from public.star_awards s
    where s.child_id = p_child and s.local_date <= p_today and s.local_date > p_today - 400
    order by 1
  loop
    if prev is null or d - prev > 2 then run := 1; else run := run + 1; end if;
    best := greatest(best, run);
    prev := d;
  end loop;
  return query select case when prev is not null and p_today - prev <= 2 then run else 0 end, best, prev;
end $$;

-- ---------------------------------------------------------------------------------------------
-- 4. Badge rules (rewards.unlock_rule + rule_params). Small predicates, evaluated after each
--    rewarded session. A badge is granted once (child_rewards primary key).
-- ---------------------------------------------------------------------------------------------
create or replace function private.badge_met(p_child uuid, p_rule text, p_params jsonb)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare n int := coalesce((p_params->>'count')::int, (p_params->>'days')::int, 1);
begin
  return case p_rule
    when 'first_game' then exists (
      select 1 from public.star_awards s join public.activities a on a.id = s.activity_id
      where s.child_id = p_child and a.type = 'game')
    when 'first_lesson' then exists (
      select 1 from public.lessons l
      where exists (select 1 from public.lesson_steps st where st.lesson_id = l.id and st.required)
        and not exists (select 1 from public.lesson_steps st where st.lesson_id = l.id and st.required
                        and not exists (select 1 from public.lesson_step_completions c
                                        where c.child_id = p_child and c.step_id = st.id)))
    when 'first_course' then exists (
      select 1 from public.course_enrollments e where e.child_id = p_child and e.status = 'completed')
    when 'daily_goals' then (select count(*) from public.goal_progress g
      where g.child_id = p_child and g.period = 'day' and g.completed_at is not null) >= n
    when 'weekly_goals' then (select count(*) from public.goal_progress g
      where g.child_id = p_child and g.period = 'week' and g.completed_at is not null) >= n
    when 'streak' then coalesce((select longest_days from public.learning_streaks where child_id = p_child), 0) >= n
    when 'subject_explorer' then (select count(distinct s.activity_id) from public.star_awards s
      join public.activities a on a.id = s.activity_id join public.subjects sj on sj.id = a.subject_id
      where s.child_id = p_child and sj.key = p_params->>'subject') >= n
    when 'stars' then (select count(*) from public.star_awards s where s.child_id = p_child) >= n
    when 'stars_100' then (select count(*) from public.star_awards s where s.child_id = p_child) >= 100
    else false end;
end $$;

-- ---------------------------------------------------------------------------------------------
-- 5. private.apply_rewards: everything a completed, allowed session earns. Idempotent: every
--    insert is "on conflict do nothing" on a once-only key, so replays and late offline syncs
--    can never pay twice. Returns what's NEW from this call (for celebrations).
-- ---------------------------------------------------------------------------------------------
create or replace function private.apply_rewards(p_session uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  s public.activity_sessions;
  acc uuid; today date; wk date; lesson uuid; course uuid;
  goals public.learning_goals;
  g_daily int; g_weekly int; g_on boolean;
  n_day int; n_week int;
  earned jsonb := '[]'; badges jsonb := '[]'; goals_out jsonb := '[]';
  b record; gp_row record;
  lesson_done boolean := false; course_done boolean := false;
  day_done boolean := false; week_done boolean := false;
  rule_stars int; ins int;
  streak_before int; streak_after record;
begin
  select * into s from public.activity_sessions where id = p_session and status = 'completed';
  if s.id is null then return null; end if;
  select account_id into acc from public.child_profiles where id = s.child_id;
  today := private.local_date(acc, now());
  wk := date_trunc('week', s.local_date)::date;

  -- (a) the activity star (star_awards decided it; the ledger records it)
  if exists (select 1 from public.star_awards a where a.session_id = s.id) then
    select stars into rule_stars from public.reward_rules where key = 'activity_completed' and active;
    if coalesce(rule_stars, 0) > 0 then
      insert into public.star_transactions (child_id, amount, reason, ref_key, local_date, session_id)
      values (s.child_id, rule_stars, 'activity_completed', 'activity:' || s.activity_id || ':' || s.local_date, s.local_date, s.id)
      on conflict do nothing;
      get diagnostics ins = row_count;
      if ins > 0 then earned := earned || jsonb_build_object('reason', 'activity_completed', 'amount', rule_stars); end if;
    end if;
  end if;

  -- (b) an island (lesson) whose required steps are now all done
  if s.lesson_step_id is not null then
    select l.id, m.course_id into lesson, course from public.lesson_steps st
      join public.lessons l on l.id = st.lesson_id join public.course_modules m on m.id = l.module_id
      where st.id = s.lesson_step_id;
    lesson_done := not exists (
      select 1 from public.lesson_steps st where st.lesson_id = lesson and st.required
        and not exists (select 1 from public.lesson_step_completions c where c.child_id = s.child_id and c.step_id = st.id));
    if lesson_done then
      select stars into rule_stars from public.reward_rules where key = 'lesson_completed' and active;
      if coalesce(rule_stars, 0) > 0 then
        insert into public.star_transactions (child_id, amount, reason, ref_key, local_date, session_id)
        values (s.child_id, rule_stars, 'lesson_completed', 'lesson:' || lesson, s.local_date, s.id) on conflict do nothing;
        get diagnostics ins = row_count;
        lesson_done := ins > 0;   -- report it only the first time
        if ins > 0 then earned := earned || jsonb_build_object('reason', 'lesson_completed', 'amount', rule_stars); end if;
      else
        lesson_done := false;
      end if;
    end if;
    -- (c) the course
    if exists (select 1 from public.course_enrollments e where e.child_id = s.child_id and e.course_id = course and e.status = 'completed') then
      insert into public.certificates (child_id, course_id) values (s.child_id, course) on conflict do nothing;
      select stars into rule_stars from public.reward_rules where key = 'course_completed' and active;
      insert into public.star_transactions (child_id, amount, reason, ref_key, local_date, session_id)
      select s.child_id, rule_stars, 'course_completed', 'course:' || course, s.local_date, s.id
      where coalesce(rule_stars, 0) > 0
      on conflict do nothing;
      get diagnostics ins = row_count;
      course_done := ins > 0;
      if ins > 0 then earned := earned || jsonb_build_object('reason', 'course_completed', 'amount', rule_stars); end if;
    end if;
  end if;

  -- (d) goals (the parent's settings, or the defaults)
  select * into goals from public.learning_goals where child_id = s.child_id;
  g_on := coalesce(goals.enabled, true);
  g_daily := coalesce(goals.daily_activities, 3);
  g_weekly := coalesce(goals.weekly_days, 4);
  select count(*) into n_day from public.star_awards a where a.child_id = s.child_id and a.local_date = s.local_date;
  select count(distinct a.local_date) into n_week from public.star_awards a
    where a.child_id = s.child_id and a.local_date between wk and wk + 6;
  if g_on then
    insert into public.goal_progress as gp (child_id, period, period_start, target, progress)
    values (s.child_id, 'day', s.local_date, g_daily, n_day)
    on conflict (child_id, period, period_start) do update set progress = excluded.progress, updated_at = now();
    insert into public.goal_progress as gp (child_id, period, period_start, target, progress)
    values (s.child_id, 'week', wk, g_weekly, n_week)
    on conflict (child_id, period, period_start) do update set progress = excluded.progress, updated_at = now();
    update public.goal_progress set completed_at = now()
      where child_id = s.child_id and period = 'day' and period_start = s.local_date
        and completed_at is null and progress >= target;
    day_done := found;
    update public.goal_progress set completed_at = now()
      where child_id = s.child_id and period = 'week' and period_start = wk
        and completed_at is null and progress >= target;
    week_done := found;
    if day_done then
      select stars into rule_stars from public.reward_rules where key = 'daily_goal_met' and active;
      insert into public.star_transactions (child_id, amount, reason, ref_key, local_date, session_id)
      select s.child_id, rule_stars, 'daily_goal_met', 'day:' || s.local_date, s.local_date, s.id
      where coalesce(rule_stars, 0) > 0 on conflict do nothing;
      get diagnostics ins = row_count;
      if ins > 0 then earned := earned || jsonb_build_object('reason', 'daily_goal_met', 'amount', rule_stars); end if;
    end if;
    if week_done then
      select stars into rule_stars from public.reward_rules where key = 'weekly_goal_met' and active;
      insert into public.star_transactions (child_id, amount, reason, ref_key, local_date, session_id)
      select s.child_id, rule_stars, 'weekly_goal_met', 'week:' || wk, s.local_date, s.id
      where coalesce(rule_stars, 0) > 0 on conflict do nothing;
      get diagnostics ins = row_count;
      if ins > 0 then earned := earned || jsonb_build_object('reason', 'weekly_goal_met', 'amount', rule_stars); end if;
    end if;
  end if;
  for gp_row in select g.period, g.target, g.progress, g.completed_at from public.goal_progress g
            where g.child_id = s.child_id and ((g.period = 'day' and g.period_start = s.local_date) or (g.period = 'week' and g.period_start = wk))
  loop
    goals_out := goals_out || jsonb_build_object('period', gp_row.period, 'target', gp_row.target, 'progress', gp_row.progress,
      'completed', gp_row.completed_at is not null,
      'justCompleted', (gp_row.period = 'day' and day_done) or (gp_row.period = 'week' and week_done));
  end loop;

  -- (e) the streak, recomputed from learning days (late offline days land in the right place)
  select current_days into streak_before from public.learning_streaks where child_id = s.child_id;
  select * into streak_after from private.streak_of(s.child_id, today);
  insert into public.learning_streaks as ls (child_id, current_days, longest_days, last_learning_day)
  values (s.child_id, streak_after.current_days, streak_after.longest_days, streak_after.last_day)
  on conflict (child_id) do update set
    current_days = excluded.current_days,
    longest_days = greatest(ls.longest_days, excluded.longest_days),
    last_learning_day = excluded.last_learning_day,
    updated_at = now();

  -- (f) badges not earned yet whose rule is now met
  for b in select r.id, r.key, r.title, r.unlock_rule, r.rule_params, r.bonus_stars, m.object_path as art
           from public.rewards r join public.media_assets m on m.id = r.asset_id
           where r.type = 'badge' and r.status = 'active'
             and not exists (select 1 from public.child_rewards cr where cr.child_id = s.child_id and cr.reward_id = r.id)
           order by r.sort, r.key
  loop
    if private.badge_met(s.child_id, b.unlock_rule, b.rule_params) then
      insert into public.child_rewards (child_id, reward_id, source) values (s.child_id, b.id, 'badge_rule')
      on conflict do nothing;
      get diagnostics ins = row_count;
      if ins > 0 then
        badges := badges || jsonb_build_object('key', b.key, 'title', b.title, 'bonusStars', b.bonus_stars, 'art', b.art);
        if b.bonus_stars > 0 then
          insert into public.star_transactions (child_id, amount, reason, ref_key, local_date, session_id, reward_id)
          values (s.child_id, b.bonus_stars, 'badge', 'badge:' || b.id, s.local_date, s.id, b.id) on conflict do nothing;
          get diagnostics ins = row_count;
          if ins > 0 then earned := earned || jsonb_build_object('reason', 'badge', 'amount', b.bonus_stars, 'badge', b.key); end if;
        end if;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'stars', (select coalesce(sum(t.amount), 0) from jsonb_to_recordset(earned) as t(amount int)),
    'transactions', earned,
    'badges', badges,
    'goals', goals_out,
    'lessonCompleted', lesson_done,
    'courseCompleted', course_done,
    'streak', jsonb_build_object('current', streak_after.current_days,
                                 'longest', greatest(streak_after.longest_days,
                                   coalesce((select longest_days from public.learning_streaks where child_id = s.child_id), 0)),
                                 'grew', streak_after.current_days > coalesce(streak_before, 0)),
    'balance', (select coalesce(sum(amount), 0) from public.star_transactions where child_id = s.child_id));
end $$;

-- ---------------------------------------------------------------------------------------------
-- 6. apply_session: the Phase 9 function, unchanged, now followed by the rewards step. Renamed
--    to apply_session_core and wrapped, so session handling isn't copied.
-- ---------------------------------------------------------------------------------------------
alter function private.apply_session(uuid, jsonb) rename to apply_session_core;

create or replace function private.apply_session(p_user_id uuid, p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r jsonb; rw jsonb;
begin
  r := private.apply_session_core(p_user_id, p);
  if r->>'status' = 'accepted' and coalesce((r->>'allowed')::boolean, false) then
    rw := private.apply_rewards((r->>'sessionId')::uuid);
    if rw is not null then r := r || jsonb_build_object('rewards', rw); end if;
  end if;
  return r;
end $$;

-- ---------------------------------------------------------------------------------------------
-- 7. PUT /children/:id/goals: a parent sets (or switches off) a child's goals.
--    p = {enabled?, dailyActivities? 1..10, weeklyDays? 1..7}. Today's and this week's targets
--    follow the new setting; completion is checked at the next finished activity.
-- ---------------------------------------------------------------------------------------------
create or replace function private.set_learning_goals(p_user_id uuid, p_child uuid, p jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare acc uuid; g_row public.learning_goals; d int; w int; today date;
begin
  acc := private.household_of_child(p_user_id, p_child);
  if jsonb_typeof(p) is distinct from 'object' then perform private.fail('KL400', 'VALIDATION', 'goals are required'); end if;
  begin
    d := (p->>'dailyActivities')::int; w := (p->>'weeklyDays')::int;
  exception when invalid_text_representation then
    perform private.fail('KL400', 'VALIDATION', 'goals must be numbers');
  end;
  if d is not null and (d < 1 or d > 10) then perform private.fail('KL400', 'VALIDATION', 'daily goal must be 1..10'); end if;
  if w is not null and (w < 1 or w > 7) then perform private.fail('KL400', 'VALIDATION', 'weekly goal must be 1..7 days'); end if;
  insert into public.learning_goals as g (child_id, enabled, daily_activities, weekly_days)
  values (p_child, coalesce((p->>'enabled')::boolean, true), coalesce(d, 3), coalesce(w, 4))
  on conflict (child_id) do update set
    enabled = coalesce((p->>'enabled')::boolean, g.enabled),
    daily_activities = coalesce(d, g.daily_activities),
    weekly_days = coalesce(w, g.weekly_days),
    updated_at = now()
  returning * into g_row;
  today := private.local_date(acc, now());
  update public.goal_progress set target = g_row.daily_activities
    where child_id = p_child and period = 'day' and period_start = today and completed_at is null;
  update public.goal_progress set target = g_row.weekly_days
    where child_id = p_child and period = 'week' and period_start = date_trunc('week', today)::date and completed_at is null;
  return jsonb_build_object('childId', g_row.child_id, 'enabled', g_row.enabled,
    'dailyActivities', g_row.daily_activities, 'weeklyDays', g_row.weekly_days);
end $$;

-- ---------------------------------------------------------------------------------------------
-- 8. GET /children/:id/rewards: everything the Rewards screen and the parent page show, computed
--    here with the HOUSEHOLD's day and week (the device's clock and zone are never used).
-- ---------------------------------------------------------------------------------------------
create or replace function private.rewards_summary(p_user_id uuid, p_child uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare acc uuid; today date; wk date; g public.learning_goals; st record; stored int;
  n_day int; n_week int; day_row public.goal_progress; week_row public.goal_progress;
begin
  acc := private.household_of_child(p_user_id, p_child);
  today := private.local_date(acc, now());
  wk := date_trunc('week', today)::date;
  select * into g from public.learning_goals where child_id = p_child;
  select * into st from private.streak_of(p_child, today);
  select longest_days into stored from public.learning_streaks where child_id = p_child;
  select count(*) into n_day from public.star_awards where child_id = p_child and local_date = today;
  select count(distinct local_date) into n_week from public.star_awards
    where child_id = p_child and local_date between wk and wk + 6;
  select * into day_row from public.goal_progress where child_id = p_child and period = 'day' and period_start = today;
  select * into week_row from public.goal_progress where child_id = p_child and period = 'week' and period_start = wk;
  return jsonb_build_object(
    'today', today,
    'weekStart', wk,
    'balance', (select coalesce(sum(amount), 0) from public.star_transactions where child_id = p_child),
    'streak', jsonb_build_object('current', st.current_days, 'longest', greatest(st.longest_days, coalesce(stored, 0)),
                                 'lastDay', st.last_day),
    'goals', jsonb_build_object('enabled', coalesce(g.enabled, true),
                                'dailyActivities', coalesce(g.daily_activities, 3), 'weeklyDays', coalesce(g.weekly_days, 4)),
    'day', jsonb_build_object('target', coalesce(day_row.target, g.daily_activities, 3), 'progress', n_day,
                              'completedAt', day_row.completed_at),
    'week', jsonb_build_object('target', coalesce(week_row.target, g.weekly_days, 4), 'progress', n_week,
                               'completedAt', week_row.completed_at),
    'learningDays', coalesce((select jsonb_agg(d order by d) from (
        select distinct local_date d from public.star_awards where child_id = p_child and local_date > today - 42) x), '[]'),
    'transactions', coalesce((select jsonb_agg(t order by t.at desc) from (
        select tr.amount, tr.reason, tr.ref_key as "refKey", tr.local_date as "localDate", tr.created_at as at,
               r.key as "badgeKey", r.title as "badgeTitle"
        from public.star_transactions tr left join public.rewards r on r.id = tr.reward_id
        where tr.child_id = p_child order by tr.created_at desc, tr.id limit 50) t), '[]'),
    'badges', coalesce((select jsonb_agg(b order by b.sort, b.key) from (
        select r.key, r.title, r.description, r.how_to_earn as "howToEarn", r.unlock_rule as rule,
               r.rule_params as params, r.bonus_stars as "bonusStars", r.sort, m.object_path as art,
               cr.first_earned_at as "earnedAt"
        from public.rewards r join public.media_assets m on m.id = r.asset_id
        left join public.child_rewards cr on cr.reward_id = r.id and cr.child_id = p_child
        where r.type = 'badge' and (r.status = 'active' or cr.child_id is not null)) b), '[]'),
    'counts', jsonb_build_object(
        'islands', (select count(*) from public.star_transactions where child_id = p_child and reason = 'lesson_completed'),
        'courses', (select count(*) from public.course_enrollments where child_id = p_child and status = 'completed'),
        'dailyGoals', (select count(*) from public.goal_progress where child_id = p_child and period = 'day' and completed_at is not null),
        'weeklyGoals', (select count(*) from public.goal_progress where child_id = p_child and period = 'week' and completed_at is not null),
        'learningDays', (select count(distinct local_date) from public.star_awards where child_id = p_child)),
    'rules', coalesce((select jsonb_agg(jsonb_build_object('key', key, 'stars', stars, 'description', description) order by stars, key)
                       from public.reward_rules where active), '[]'));
end $$;

-- Existing data: give every completed session its rewards once (idempotent, so safe to re-run).
do $$
declare sid uuid;
begin
  for sid in select id from public.activity_sessions where status = 'completed' order by started_at loop
    perform private.apply_rewards(sid);
  end loop;
end $$;

revoke all on function private.streak_of(uuid, date) from public, anon, authenticated;
revoke all on function private.badge_met(uuid, text, jsonb) from public, anon, authenticated;
revoke all on function private.apply_rewards(uuid) from public, anon, authenticated;
revoke all on function private.apply_session_core(uuid, jsonb) from public, anon, authenticated;
revoke all on function private.apply_session(uuid, jsonb) from public, anon, authenticated;
revoke all on function private.set_learning_goals(uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function private.apply_session(uuid, jsonb) to service_role;
revoke all on function private.rewards_summary(uuid, uuid) from public, anon, authenticated;
grant execute on function private.set_learning_goals(uuid, uuid, jsonb) to service_role;
grant execute on function private.rewards_summary(uuid, uuid) to service_role;
