-- Phase 14: admin CMS (admin_panel/, docs/admin-cms/). Reuses the content tables, RLS policies,
-- live-content guard, audit triggers and admin RBAC from Phases 5–6. Additions (documented in
-- docs/backend/database-schema.md §5 #22–#29):
--   #22 'approved' status for activities and courses (draft → in_review → approved → published →
--       retired). Approved content is LOCKED like published (is_live): editing it needs
--       content.publish or sending it back to draft. Kids still see only 'published'.
--   #23 course metadata (category, difficulty, learning objectives) and lesson details (description,
--       objectives, instructions, estimated minutes, prerequisite lessons — the app enforces them).
--   #24 app_config: system settings an admin edits (goal defaults used by the rewards engine,
--       content and media limits). Read by admins, written with admin.manage; server code reads it.
--   #25 star_transactions reason 'admin_adjustment': stars added by support, audited, positive only.
--   #26 a suspended household can't record play or open media (account restriction).
--   #27 admin_api.* functions: security definer, each checks the caller's permission (and MFA,
--       through private.has_permission) before doing anything; granted to authenticated only.
--   #28 write grants for app_config and reward_rules (admin-edited with the admin's JWT; RLS
--       decides). reward_rules had content.write policies since Phase 12 but no grant.
--   #29 the generic audit trigger records a games row under its activity_id, so game-config edits
--       show in the activity's history and count as edits for the four-eyes rule.
-- The admin app uses the admin's own session (never the service role key).

-- ---------------------------------------------------------------------------------------------
-- 1. Publishing workflow
-- ---------------------------------------------------------------------------------------------
alter table activities drop constraint activities_status_check;
alter table activities add constraint activities_status_check
  check (status in ('draft','in_review','approved','published','retired'));
alter table courses drop constraint courses_status_check;
alter table courses add constraint courses_status_check
  check (status in ('draft','in_review','approved','published','retired'));

create or replace function private.is_live(tbl text, r jsonb) returns boolean
language sql stable security definer set search_path = '' as $$
  select case tbl
    when 'activities'     then r->>'status' in ('published','approved')
    when 'courses'        then r->>'status' in ('published','approved')
    when 'collections'    then r->>'status' = 'published'
    when 'learning_paths' then r->>'status' = 'published'
    when 'categories'     then r->>'status' = 'published'
    when 'rewards'        then r->>'status' = 'active'
    when 'reward_sets'    then coalesce((r->>'active')::boolean, false)
    when 'avatars'        then coalesce((r->>'active')::boolean, false)
    when 'media_assets'   then r->>'status' = 'ready'
    when 'games'               then exists (select 1 from public.activities a where a.id = (r->>'activity_id')::uuid and a.status in ('published','approved'))
    when 'questions'           then exists (select 1 from public.activities a where a.id = (r->>'activity_id')::uuid and a.status in ('published','approved'))
    when 'activity_media'      then exists (select 1 from public.activities a where a.id = (r->>'activity_id')::uuid and a.status in ('published','approved'))
    when 'activity_skills'     then exists (select 1 from public.activities a where a.id = (r->>'activity_id')::uuid and a.status in ('published','approved'))
    when 'activity_categories' then exists (select 1 from public.activities a where a.id = (r->>'activity_id')::uuid and a.status in ('published','approved'))
    when 'answers' then exists (select 1 from public.questions q join public.activities a on a.id = q.activity_id
                                where q.id = (r->>'question_id')::uuid and a.status in ('published','approved'))
    when 'course_modules' then exists (select 1 from public.courses c where c.id = (r->>'course_id')::uuid and c.status in ('published','approved'))
    when 'lessons' then exists (select 1 from public.course_modules m join public.courses c on c.id = m.course_id
                                where m.id = (r->>'module_id')::uuid and c.status in ('published','approved'))
    when 'lesson_steps' then exists (select 1 from public.lessons l join public.course_modules m on m.id = l.module_id
                                     join public.courses c on c.id = m.course_id
                                     where l.id = (r->>'lesson_id')::uuid and c.status in ('published','approved'))
    when 'collection_items' then exists (select 1 from public.collections c where c.id = (r->>'collection_id')::uuid and c.status = 'published')
    when 'learning_path_courses' then exists (select 1 from public.learning_paths p where p.id = (r->>'path_id')::uuid and p.status = 'published')
    else false end;
$$;

-- ---------------------------------------------------------------------------------------------
-- 2. Course and lesson fields
-- ---------------------------------------------------------------------------------------------
alter table courses
  add column category_id uuid references categories(id) on delete set null,
  add column difficulty smallint not null default 1 check (difficulty between 1 and 5),
  add column objectives jsonb not null default '[]' check (jsonb_typeof(objectives) = 'array');
create index on courses (category_id);
alter table lessons
  add column description jsonb not null default '{}',
  add column objectives jsonb not null default '[]' check (jsonb_typeof(objectives) = 'array'),
  add column instructions jsonb not null default '{}',
  add column estimated_minutes smallint check (estimated_minutes between 1 and 120),
  add column prerequisite_lesson_ids uuid[] not null default '{}'
    check (cardinality(prerequisite_lesson_ids) <= 10);

-- Prerequisites must be lessons of the same course, not the lesson itself.
create or replace function private.check_prerequisites() returns trigger
language plpgsql set search_path = '' as $$
declare course uuid; bad int;
begin
  if cardinality(new.prerequisite_lesson_ids) = 0 then return new; end if;
  if new.id = any (new.prerequisite_lesson_ids) then
    raise exception 'a lesson can''t be its own prerequisite' using errcode = '23514';
  end if;
  select m.course_id into course from public.course_modules m where m.id = new.module_id;
  select count(*) into bad from unnest(new.prerequisite_lesson_ids) p
   where not exists (select 1 from public.lessons l join public.course_modules m on m.id = l.module_id
                     where l.id = p and m.course_id = course);
  if bad > 0 then raise exception 'prerequisites must be lessons of the same course' using errcode = '23514'; end if;
  return new;
end $$;
create trigger check_prerequisites before insert or update of prerequisite_lesson_ids, module_id on lessons
  for each row execute function private.check_prerequisites();

-- ---------------------------------------------------------------------------------------------
-- 3. System settings
-- ---------------------------------------------------------------------------------------------
create table app_config (
  key          text primary key check (key ~ '^[a-z]+\.[a-z_]+$'),
  value        jsonb not null,
  description  text not null default '',
  updated_by   uuid references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index on app_config (updated_by);
alter table app_config enable row level security;
create policy admin_read on app_config for select
  using (private.has_permission('content.read') or private.has_permission('admin.manage'));
create policy admin_write on app_config for all
  using (private.has_permission('admin.manage')) with check (private.has_permission('admin.manage'));
revoke insert, update, delete, truncate, references, trigger on app_config from anon;
revoke truncate, references, trigger on app_config from authenticated;
-- admin-written with the admin's own JWT (RLS: admin.manage); new tables start read-only (rls.sql)
grant insert, update, delete on app_config to authenticated;
-- Phase 12 left reward_rules read-only for clients although it has content.write policies;
-- the CMS edits it, so the writes are granted (RLS still requires content.write).
grant insert, update, delete on reward_rules to authenticated;
create trigger set_updated_at before update on app_config for each row execute function private.set_updated_at();
create trigger audit after insert or update or delete on app_config for each row execute function private.audit_row();

insert into app_config (key, value, description) values
  ('goals.daily_default', '3', 'Daily goal (different activities) for children whose parent hasn''t set one, 1–10'),
  ('goals.weekly_default', '4', 'Weekly goal (learning days) for children whose parent hasn''t set one, 1–7'),
  ('content.review_required', 'true', 'Content must be approved by a second person (content.publish) before publishing'),
  ('media.max_upload_mb', '200', 'Largest file an admin can upload, in MB (the bucket limits still apply)'),
  ('media.allowed_types', '["image/webp","image/png","image/jpeg","audio/mp4","audio/mpeg","video/mp4","text/vtt","application/json"]',
     'File types the admin uploader accepts')
on conflict (key) do nothing;

-- Validated values (a bad setting must not break the rewards engine).
create or replace function private.check_app_config() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.key = 'goals.daily_default' and not (jsonb_typeof(new.value) = 'number' and (new.value)::int between 1 and 10) then
    raise exception 'goals.daily_default must be 1–10' using errcode = '23514';
  elsif new.key = 'goals.weekly_default' and not (jsonb_typeof(new.value) = 'number' and (new.value)::int between 1 and 7) then
    raise exception 'goals.weekly_default must be 1–7' using errcode = '23514';
  elsif new.key = 'media.max_upload_mb' and not (jsonb_typeof(new.value) = 'number' and (new.value)::int between 1 and 1024) then
    raise exception 'media.max_upload_mb must be 1–1024' using errcode = '23514';
  elsif new.key = 'content.review_required' and jsonb_typeof(new.value) <> 'boolean' then
    raise exception 'content.review_required must be true or false' using errcode = '23514';
  elsif new.key = 'media.allowed_types' and jsonb_typeof(new.value) <> 'array' then
    raise exception 'media.allowed_types must be a list' using errcode = '23514';
  end if;
  new.updated_by := auth.uid();
  return new;
end $$;
create trigger check_app_config before insert or update on app_config for each row execute function private.check_app_config();

create or replace function private.goal_default(p_kind text) returns int
language sql stable security definer set search_path = '' as $$
  select case p_kind
    when 'daily' then coalesce((select (value)::int from public.app_config where key = 'goals.daily_default'), 3)
    else coalesce((select (value)::int from public.app_config where key = 'goals.weekly_default'), 4) end
$$;

-- The rewards and report functions, unchanged except that the default goals come from app_config.
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
  g_daily := coalesce(goals.daily_activities, private.goal_default('daily'));
  g_weekly := coalesce(goals.weekly_days, private.goal_default('weekly'));
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
                                'dailyActivities', coalesce(g.daily_activities, private.goal_default('daily')), 'weeklyDays', coalesce(g.weekly_days, private.goal_default('weekly'))),
    'day', jsonb_build_object('target', coalesce(day_row.target, g.daily_activities, private.goal_default('daily')), 'progress', n_day,
                              'completedAt', day_row.completed_at),
    'week', jsonb_build_object('target', coalesce(week_row.target, g.weekly_days, private.goal_default('weekly')), 'progress', n_week,
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
  values (p_child, coalesce((p->>'enabled')::boolean, true), coalesce(d, private.goal_default('daily')), coalesce(w, private.goal_default('weekly')))
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

create or replace function private.progress_report(p_user_id uuid, p_child uuid, p_period text, p_date date)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare acc uuid; today date; d0 date; d1 date; p0 date; p1 date; days int; elapsed int; g public.learning_goals;
  scored int;
begin
  acc := private.household_of_child(p_user_id, p_child);
  today := private.local_date(acc, now());
  if p_period not in ('day','week','month') then perform private.fail('KL400', 'VALIDATION', 'period'); end if;
  d0 := case p_period when 'day' then coalesce(p_date, today)
                      when 'week' then date_trunc('week', coalesce(p_date, today))::date
                      else date_trunc('month', coalesce(p_date, today))::date end;
  d1 := case p_period when 'day' then d0 when 'week' then d0 + 6
                      else (d0 + interval '1 month' - interval '1 day')::date end;
  p1 := d0 - 1;
  p0 := case p_period when 'day' then p1 when 'week' then d0 - 7 else (d0 - interval '1 month')::date end;
  days := d1 - d0 + 1;
  elapsed := greatest(0, least(d1, today) - d0 + 1);
  select * into g from public.learning_goals where child_id = p_child;

  create temp table if not exists _rs (id uuid, activity_id uuid, type text, subject_id uuid, status text,
    local_date date, started_at timestamptz, secs int, score numeric, correct int, total int, level text,
    lesson_step_id uuid) on commit drop;
  truncate _rs;
  insert into _rs
  select s.id, s.activity_id, a.type, a.subject_id, s.status, s.local_date, s.started_at,
         case when s.ended_at is null then 0 else extract(epoch from (s.ended_at - s.started_at))::int end,
         r.score, r.correct_count, r.total_count, r.metrics->>'level', s.lesson_step_id
  from public.activity_sessions s join public.activities a on a.id = s.activity_id
  left join public.activity_results r on r.session_id = s.id
  where s.child_id = p_child and s.local_date between p0 and d1;

  select count(*) into scored from _rs where local_date >= d0 and status = 'completed' and score is not null;

  return jsonb_build_object(
    'childId', p_child, 'period', p_period, 'from', d0, 'to', d1, 'today', today, 'daysElapsed', elapsed,
    'totals', (select jsonb_build_object(
        'seconds', coalesce(sum(secs), 0), 'sessions', count(*),
        'completed', count(*) filter (where status = 'completed'),
        'activities', count(distinct activity_id) filter (where status = 'completed'),
        'learningDays', (select count(distinct local_date) from public.star_awards where child_id = p_child and local_date between d0 and d1),
        'stars', (select coalesce(sum(amount), 0) from public.star_transactions where child_id = p_child and local_date between d0 and d1))
      from _rs where local_date >= d0),
    'previous', (select jsonb_build_object('from', p0, 'to', p1, 'seconds', coalesce(sum(secs), 0),
        'completed', count(*) filter (where status = 'completed')) from _rs where local_date between p0 and p1),
    'daily', (select jsonb_agg(jsonb_build_object('date', dd, 'seconds', coalesce((select sum(secs) from _rs where local_date = dd), 0),
        'completed', (select count(*) from _rs where local_date = dd and status = 'completed')) order by dd)
      from generate_series(d0, d1, interval '1 day') dd),
    'byType', coalesce((select jsonb_agg(jsonb_build_object('type', type, 'started', n, 'completed', c) order by n desc, type)
      from (select type, count(*) n, count(*) filter (where status = 'completed') c from _rs where local_date >= d0 group by type) t), '[]'),
    'bySubject', coalesce((select jsonb_agg(x order by (x->>'completed')::int desc, x->>'key') from (
        select jsonb_build_object('key', sj.key, 'name', sj.name->>'en',
          'completed', count(*) filter (where rs.status = 'completed'), 'seconds', coalesce(sum(rs.secs), 0),
          'scored', count(rs.score) filter (where rs.status = 'completed'),
          'avgScore', round(avg(rs.score) filter (where rs.status = 'completed'), 1)) x
        from _rs rs join public.subjects sj on sj.id = rs.subject_id where rs.local_date >= d0 group by sj.key, sj.name) q), '[]'),
    'games', coalesce((select jsonb_agg(x order by (x->>'plays')::int desc, x->>'title') from (
        select jsonb_build_object('slug', a.slug, 'title', a.title->>'en', 'plays', count(*),
          'completed', count(*) filter (where rs.status = 'completed'),
          'avgScore', round(avg(rs.score) filter (where rs.status = 'completed'), 1),
          'bestScore', max(rs.score) filter (where rs.status = 'completed'),
          'accuracy', case when sum(rs.total) filter (where rs.status = 'completed') > 0
                      then round(100.0 * sum(rs.correct) filter (where rs.status = 'completed')
                                 / sum(rs.total) filter (where rs.status = 'completed'), 1) end,
          'levels', coalesce(jsonb_agg(distinct rs.level) filter (where rs.level is not null and rs.status = 'completed'), '[]')) x
        from _rs rs join public.activities a on a.id = rs.activity_id
        where rs.local_date >= d0 and rs.type = 'game' group by a.slug, a.title) q), '[]'),
    'quizzes', coalesce((select jsonb_agg(x order by x->>'title') from (
        select jsonb_build_object('slug', a.slug, 'title', a.title->>'en',
          'attempts', count(*) filter (where rs.status = 'completed'),
          'lastScore', (select r2.score from _rs r2 where r2.activity_id = a.id and r2.local_date >= d0 and r2.status = 'completed'
                        order by r2.started_at desc limit 1),
          'bestScore', max(rs.score) filter (where rs.status = 'completed'),
          'avgScore', round(avg(rs.score) filter (where rs.status = 'completed'), 1),
          'firstTryCorrect', (select round(100.0 * count(*) filter (where qr.is_correct) / nullif(count(*), 0), 1)
                              from public.question_responses qr join _rs r3 on r3.id = qr.session_id
                              where r3.activity_id = a.id and r3.local_date >= d0 and qr.attempt = 1)) x
        from _rs rs join public.activities a on a.id = rs.activity_id
        where rs.local_date >= d0 and rs.type = 'quiz' group by a.id, a.slug, a.title) q), '[]'),
    'lessons', jsonb_build_object(
        'stepsCompleted', (select count(*) from public.lesson_step_completions c where c.child_id = p_child
                           and private.local_date(acc, c.completed_at) between d0 and d1),
        'completedInPeriod', (select count(*) from (select l.id from public.lessons l join public.lesson_steps st on st.lesson_id = l.id and st.required
                   join public.lesson_step_completions c on c.step_id = st.id and c.child_id = p_child
                   group by l.id having count(*) = (select count(*) from public.lesson_steps x where x.lesson_id = l.id and x.required)
                      and private.local_date(acc, max(c.completed_at)) between d0 and d1) z),
        'completedTotal', (select count(*) from (select l.id from public.lessons l join public.lesson_steps st on st.lesson_id = l.id and st.required
                   join public.lesson_step_completions c on c.step_id = st.id and c.child_id = p_child
                   group by l.id having count(*) = (select count(*) from public.lesson_steps x where x.lesson_id = l.id and x.required)) z)),
    'skills', coalesce((select jsonb_agg(x order by (x->>'mastery')::numeric desc, x->>'key') from (
        select jsonb_build_object('key', k.key, 'name', k.name->>'en', 'group', k.skill_group, 'mastery', round(m.mastery, 3),
          'band', case when m.mastery > 0.75 then 'confident' when m.mastery >= 0.4 then 'practising' else 'getting_started' end,
          'evidence', m.evidence_count, 'lastPracticed', m.last_practiced_at,
          'practisedInPeriod', exists (select 1 from _rs rs join public.activity_skills ak on ak.activity_id = rs.activity_id
                                       where ak.skill_id = k.id and rs.status = 'completed' and rs.local_date >= d0)) x
        from public.skill_mastery m join public.skills k on k.id = m.skill_id
        where m.child_id = p_child and m.evidence_count > 0) q), '[]'),
    'goals', jsonb_build_object(
        'enabled', coalesce(g.enabled, true),
        'dailyTarget', coalesce(g.daily_activities, private.goal_default('daily')), 'weeklyTarget', coalesce(g.weekly_days, private.goal_default('weekly')),
        'daysReached', (select count(*) from public.goal_progress gp where gp.child_id = p_child and gp.period = 'day'
                        and gp.period_start between d0 and d1 and gp.completed_at is not null),
        'daysElapsed', elapsed,
        'weeks', coalesce((select jsonb_agg(jsonb_build_object('weekStart', w::date,
              'reached', exists (select 1 from public.goal_progress gp where gp.child_id = p_child and gp.period = 'week'
                                 and gp.period_start = w::date and gp.completed_at is not null)) order by w)
            from generate_series(date_trunc('week', d0), date_trunc('week', least(d1, today)), interval '1 week') w), '[]')),
    'consistency', (select jsonb_agg(jsonb_build_object('weekStart', w::date,
          'learningDays', (select count(distinct local_date) from public.star_awards where child_id = p_child
                           and local_date between w::date and w::date + 6)) order by w)
        from generate_series(date_trunc('week', d1) - interval '7 weeks', date_trunc('week', d1), interval '1 week') w),
    'scoredSessions', scored,
    'recent', coalesce((select jsonb_agg(x order by x->>'startedAt' desc) from (
        select jsonb_build_object('activityId', a.slug, 'title', a.title->>'en', 'type', rs.type, 'status', rs.status,
          'startedAt', rs.started_at, 'seconds', rs.secs, 'score', rs.score, 'level', rs.level) x
        from _rs rs join public.activities a on a.id = rs.activity_id where rs.local_date >= d0
        order by rs.started_at desc limit 50) q), '[]'));
end $$;

create or replace function private.apply_session(p_user_id uuid, p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r jsonb; rw jsonb; g jsonb; sid uuid; acc uuid; ch uuid;
begin
  -- a suspended household can't record play (Phase 14, admin account restrictions)
  if exists (select 1 from public.child_profiles c join public.parent_accounts a on a.id = c.account_id
             where c.id = nullif(p->'session'->>'childId', '')::uuid and a.status = 'suspended') then
    perform private.fail('KL403', 'ACCOUNT_SUSPENDED', 'account suspended');
  end if;
  r := private.apply_session_core(p_user_id, p);
  if r->>'status' = 'accepted' and coalesce((r->>'allowed')::boolean, false) then
    sid := (r->>'sessionId')::uuid;
    rw := private.apply_rewards(sid);
    if rw is not null then
      r := r || jsonb_build_object('rewards', rw);
      perform private.update_mastery(sid);
      select s.child_id, c.account_id into ch, acc from public.activity_sessions s
        join public.child_profiles c on c.id = s.child_id where s.id = sid;
      for g in select * from jsonb_array_elements(rw->'goals') loop
        if (g->>'justCompleted')::boolean then
          perform private.notify(acc, 'goal_reached', jsonb_build_object('childId', ch, 'period', g->>'period'),
            'goal:' || ch || ':' || (g->>'period') || ':' || (r->>'localDate'));
        end if;
      end loop;
    end if;
  end if;
  return r;
end $$;

-- ---------------------------------------------------------------------------------------------
-- 4. Account restrictions: a suspended household can't open media either (apply_session above
--    refuses its sessions). Parents can still sign in, see reports, export and delete.
-- ---------------------------------------------------------------------------------------------
create or replace function private.household_of_child(p_user_id uuid, p_child uuid) returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare acc uuid;
begin
  select ch.account_id into acc
  from public.child_profiles ch
  join public.parent_profiles pp on pp.account_id = ch.account_id and pp.user_id = p_user_id
  where ch.id = p_child and ch.status = 'active';
  if acc is null then perform private.fail('KL404', 'NOT_FOUND', 'child'); end if;
  return acc;
end $$;

create or replace function private.not_suspended(p_account uuid) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if exists (select 1 from public.parent_accounts where id = p_account and status = 'suspended') then
    perform private.fail('KL403', 'ACCOUNT_SUSPENDED', 'account suspended');
  end if;
end $$;

-- media launch: the Phase 11 function, renamed and wrapped so a suspended household is refused
alter function private.launch(uuid, jsonb) rename to launch_core;
revoke all on function private.launch_core(uuid, jsonb) from public, anon, authenticated, service_role;
create or replace function private.launch(p_user_id uuid, p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.not_suspended((select c.account_id from public.child_profiles c
                                 where c.id = nullif(p->>'childId', '')::uuid));
  return private.launch_core(p_user_id, p);
end $$;
revoke all on function private.launch(uuid, jsonb) from public, anon, authenticated;
grant execute on function private.launch(uuid, jsonb) to service_role;

-- The generic audit trigger (Phase 5), unchanged except that a row keyed by activity_id (games)
-- records it as the entity, so a game's config edits appear in its activity's history.
create or replace function private.audit_row() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  old_j jsonb := case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end;
  new_j jsonb := case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end;
  row_j jsonb := coalesce(new_j, old_j);
  changed text[];
  payload jsonb;
begin
  if tg_op = 'UPDATE' then
    select coalesce(array_agg(k), '{}') into changed
    from jsonb_object_keys(new_j) k
    where k <> 'updated_at' and (new_j->k) is distinct from (old_j->k);
    if cardinality(changed) = 0 then return new; end if;
  end if;

  if tg_nargs > 0 and tg_argv[0] = 'redact' then
    payload := jsonb_build_object('columns', to_jsonb(coalesce(changed, '{}'::text[])));
  elsif tg_op = 'UPDATE' then
    payload := jsonb_build_object(
      'before', (select jsonb_object_agg(k, old_j->k) from unnest(changed) k),
      'after',  (select jsonb_object_agg(k, new_j->k) from unnest(changed) k));
  else
    payload := jsonb_build_object('row', row_j);
  end if;

  insert into audit_logs (actor_type, actor_user_id, action, entity_table, entity_id, account_id, changes)
  values (
    -- classified from the JWT, not current_user (this function is a definer)
    case when coalesce(auth.jwt()->>'role', '') = 'service_role' then 'service'
         when auth.uid() is null then 'system'                -- migrations, cron
         when exists (select 1 from admin_users where user_id = auth.uid()) then 'admin'
         else 'parent' end,
    auth.uid(),
    lower(tg_op),
    tg_table_name,
    coalesce(row_j->>'id', row_j->>'user_id', row_j->>'account_id', row_j->>'key', row_j->>'activity_id'),
    -- IMPL: parent_accounts rows carry their account id in `id`; record it so a family's whole
    -- history (incl. its own deletion) is found by account_id.
    nullif(coalesce(row_j->>'account_id', case when tg_table_name = 'parent_accounts' then row_j->>'id' end, ''), '')::uuid,
    payload);
  return coalesce(new, old);
end $$;

-- ---------------------------------------------------------------------------------------------
-- 5. Audited star grants
-- ---------------------------------------------------------------------------------------------
alter table star_transactions drop constraint star_transactions_reason_check;
alter table star_transactions add constraint star_transactions_reason_check check (reason in
  ('activity_completed','lesson_completed','course_completed','daily_goal_met','weekly_goal_met','badge','admin_adjustment'));
-- Only staff adjustments are audited (stars children earn by playing are already their own ledger,
-- and logging each one would copy child activity into the audit log). The ledger is insert-only.
create trigger audit after insert on star_transactions
  for each row when (new.reason = 'admin_adjustment') execute function private.audit_row();

-- ---------------------------------------------------------------------------------------------
-- 6. Admin functions: schema admin_api (exposed to the Data API for signed-in users only; add it to
--    "Exposed schemas" in the dashboard). Security definer; each checks permission first. Nothing
--    is added to public (A7 keeps public free of RPC functions).
-- ---------------------------------------------------------------------------------------------
create schema admin_api;
revoke all on schema admin_api from public, anon;
grant usage on schema admin_api to authenticated;
create or replace function private.require(perm text) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.has_permission(perm) then
    perform private.fail('KL403', 'FORBIDDEN', perm || ' required');
  end if;
end $$;

create or replace function private.admin_note(p_action text, p_table text, p_id text, p_changes jsonb, p_account uuid default null)
returns void language sql security definer set search_path = '' as $$
  insert into public.audit_logs (actor_type, actor_user_id, action, entity_table, entity_id, account_id, changes)
  values ('admin', auth.uid(), p_action, p_table, p_id, p_account, coalesce(p_changes, '{}'))
$$;

-- Who am I: roles, permissions, MFA level. Null for a non-admin (the app shows "no access").
create or replace function admin_api.me() returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when u.user_id is null then null else jsonb_build_object(
    'userId', u.user_id, 'status', u.status,
    'email', (select email from auth.users where id = u.user_id),
    'aal', coalesce(auth.jwt()->>'aal', 'aal1'),
    'roles', coalesce((select jsonb_agg(role_key order by role_key) from public.admin_user_roles where user_id = u.user_id), '[]'),
    'permissions', case when u.status = 'active' then coalesce((select jsonb_agg(distinct rp.permission_key)
        from public.admin_user_roles ur join public.admin_role_permissions rp on rp.role_key = ur.role_key
        where ur.user_id = u.user_id), '[]') else '[]' end) end
  from (select auth.uid() as uid) me left join public.admin_users u on u.user_id = me.uid
$$;

-- Dashboard numbers (aggregates only).
create or replace function admin_api.dashboard() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (private.has_permission('content.read') or private.has_permission('support.read')
          or private.has_permission('billing.read') or private.has_permission('admin.manage')) then
    perform private.fail('KL403', 'FORBIDDEN', 'admin access required');
  end if;
  return jsonb_build_object(
    'parents', (select count(*) from public.parent_profiles),
    'families', (select count(*) from public.parent_accounts),
    'children', (select count(*) from public.child_profiles where status = 'active'),
    'activeSubscriptions', (select count(*) from public.subscriptions where status in ('trialing','active','grace_period','billing_retry')),
    'courses', (select count(*) from public.courses),
    'lessons', (select count(*) from public.lessons),
    'games', (select count(*) from public.activities where type = 'game'),
    'activities', (select count(*) from public.activities),
    'published', (select count(*) from public.activities where status = 'published') + (select count(*) from public.courses where status = 'published'),
    'inReview', (select count(*) from public.activities where status = 'in_review') + (select count(*) from public.courses where status = 'in_review'),
    'approved', (select count(*) from public.activities where status = 'approved') + (select count(*) from public.courses where status = 'approved'),
    'drafts', (select count(*) from public.activities where status = 'draft') + (select count(*) from public.courses where status = 'draft'),
    'mediaFailed', (select count(*) from public.media_assets where status = 'failed'));
end $$;

-- Recent admin activity: content changes for content.read; everything for audit.read.
create or replace function admin_api.activity(p_limit int default 20, p_offset int default 0, p_table text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare all_rows boolean := private.has_permission('audit.read');
begin
  if not (all_rows or private.has_permission('content.read')) then
    perform private.fail('KL403', 'FORBIDDEN', 'audit.read or content.read required');
  end if;
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('id', l.id, 'at', l.occurred_at, 'actorType', l.actor_type,
             'actor', (select email from auth.users where id = l.actor_user_id), 'action', l.action,
             'table', l.entity_table, 'entityId', l.entity_id,
             'changes', case when all_rows then l.changes else l.changes - 'row' end) x
    from public.audit_logs l
    where (all_rows or (l.actor_type = 'admin' and l.entity_table in
            ('activities','games','courses','course_modules','lessons','lesson_steps','questions','answers',
             'rewards','reward_rules','media_assets','categories','subjects','collections','app_config')))
      and (p_table is null or l.entity_table = p_table)
    order by l.occurred_at desc, l.id desc
    limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0)) q), '[]');
end $$;

-- What blocks publishing. An empty list = ready.
create or replace function admin_api.validate(p_table text, p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare a public.activities; c public.courses; problems text[] := '{}'; n int;
begin
  perform private.require('content.read');
  if p_table = 'activities' then
    select * into a from public.activities where id = p_id;
    if a.id is null then perform private.fail('KL404', 'NOT_FOUND', 'activity'); end if;
    if coalesce(a.title->>'en', '') = '' then problems := array_append(problems, ('An English title is required')::text); end if;
    if a.subject_id is null then problems := array_append(problems, ('Choose a subject')::text); end if;
    if a.thumbnail_asset_id is null and a.type in ('video','song','story','audiobook') then
      problems := array_append(problems, ('Add a thumbnail')::text);
    end if;
    if a.type = 'game' then
      select count(*) into n from public.games g where g.activity_id = a.id
        and (jsonb_typeof(g.config->'items') = 'array' and jsonb_array_length(g.config->'items') > 0
             or jsonb_typeof(g.config->'levels') = 'array' and jsonb_array_length(g.config->'levels') > 0);
      if n = 0 then problems := array_append(problems, ('The game has no items yet')::text); end if;
    elsif a.type = 'quiz' then
      if not exists (select 1 from public.questions q where q.activity_id = a.id) then
        problems := array_append(problems, ('The quiz has no questions')::text);
      end if;
      if exists (select 1 from public.questions q where q.activity_id = a.id
                 and not exists (select 1 from public.answers x where x.question_id = q.id and x.is_correct)) then
        problems := array_append(problems, ('Every question needs a correct answer')::text);
      end if;
    elsif a.type = 'video' and not exists (select 1 from public.activity_media m join public.media_assets ma on ma.id = m.asset_id
                                          where m.activity_id = a.id and m.role = 'video_main' and ma.status = 'ready') then
      problems := array_append(problems, ('Attach a ready video file')::text);
    elsif a.type in ('song','audiobook') and not exists (select 1 from public.activity_media m join public.media_assets ma on ma.id = m.asset_id
                                          where m.activity_id = a.id and m.role = 'audio_main' and ma.status = 'ready') then
      problems := array_append(problems, ('Attach a ready audio file')::text);
    elsif a.type = 'story' and not exists (select 1 from public.activity_media m where m.activity_id = a.id and m.role = 'page_image') then
      problems := array_append(problems, ('Add at least one story page')::text);
    end if;
    if exists (select 1 from public.activity_media m join public.media_assets ma on ma.id = m.asset_id
               where m.activity_id = a.id and ma.status <> 'ready') then
      problems := array_append(problems, ('Some attached files aren''t ready')::text);
    end if;
  elsif p_table = 'courses' then
    select * into c from public.courses where id = p_id;
    if c.id is null then perform private.fail('KL404', 'NOT_FOUND', 'course'); end if;
    if coalesce(c.title->>'en', '') = '' then problems := array_append(problems, ('An English title is required')::text); end if;
    if c.subject_id is null then problems := array_append(problems, ('Choose a subject')::text); end if;
    if not exists (select 1 from public.lesson_steps st join public.lessons l on l.id = st.lesson_id
                   join public.course_modules m on m.id = l.module_id where m.course_id = c.id) then
      problems := array_append(problems, ('The course has no lessons with activities')::text);
    end if;
    select count(*) into n from public.lesson_steps st join public.lessons l on l.id = st.lesson_id
      join public.course_modules m on m.id = l.module_id join public.activities x on x.id = st.activity_id
      where m.course_id = c.id and x.status <> 'published';
    if n > 0 then problems := array_append(problems, ((n || ' lesson activities aren''t published yet'))::text); end if;
    if exists (select 1 from public.lessons l join public.course_modules m on m.id = l.module_id
               where m.course_id = c.id and not exists (select 1 from public.lesson_steps st where st.lesson_id = l.id)) then
      problems := array_append(problems, ('Every lesson needs at least one activity')::text);
    end if;
  else
    perform private.fail('KL400', 'VALIDATION', 'unknown content table');
  end if;
  return to_jsonb(problems);
end $$;

-- The workflow. Who may do what:
--   draft → in_review          content.write  (submit)
--   in_review → draft          content.write by the author's team, or content.publish (reject, note required)
--   in_review → approved       content.publish, valid, and not the last editor when review is required
--   approved → published       content.publish, valid
--   approved → draft           content.publish (send back)
--   published → retired        content.publish (archive)
--   retired → draft            content.write  (reopen)
create or replace function admin_api.transition(p_table text, p_id uuid, p_to text, p_note text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cur text; problems jsonb; last_editor uuid; review boolean;
begin
  if p_table not in ('activities','courses') then perform private.fail('KL400', 'VALIDATION', 'unknown content table'); end if;
  execute format('select status from public.%I where id = $1 for update', p_table) into cur using p_id;
  if cur is null then perform private.fail('KL404', 'NOT_FOUND', 'content'); end if;
  if not ((cur, p_to) in (('draft','in_review'), ('in_review','draft'), ('in_review','approved'),
          ('approved','published'), ('approved','draft'), ('published','retired'), ('retired','draft'))) then
    perform private.fail('KL409', 'CONFLICT', format('can''t move from %s to %s', cur, p_to));
  end if;
  if (cur, p_to) in (('draft','in_review'), ('retired','draft')) then
    perform private.require('content.write');
  elsif (cur, p_to) = ('in_review','draft') then
    if not (private.has_permission('content.publish') or private.has_permission('content.write')) then
      perform private.fail('KL403', 'FORBIDDEN', 'content.write required');
    end if;
    if private.has_permission('content.publish') and length(coalesce(trim(p_note), '')) < 3 then
      perform private.fail('KL400', 'VALIDATION', 'say what needs changing');
    end if;
  else
    perform private.require('content.publish');
  end if;
  if p_to in ('approved','published') then
    problems := admin_api.validate(p_table, p_id);
    if jsonb_array_length(problems) > 0 then
      perform private.fail('KL400', 'VALIDATION', 'not ready: ' || (select string_agg(x, '; ') from jsonb_array_elements_text(problems) x));
    end if;
  end if;
  if p_to = 'approved' then
    review := coalesce((select (value)::boolean from public.app_config where key = 'content.review_required'), true);
    select l.actor_user_id into last_editor from public.audit_logs l
     where (l.entity_table = p_table or (p_table = 'activities' and l.entity_table = 'games'))  -- a game's config is part of it
       and l.entity_id = p_id::text and l.actor_type = 'admin'
       and l.action not like 'content.%'   -- workflow moves and their notes aren't edits
       and not (l.action = 'update' and l.changes->'after' ? 'status' and (select count(*) from jsonb_object_keys(l.changes->'after')) <= 2)
     order by l.occurred_at desc, l.id desc limit 1;
    if review and last_editor = auth.uid() then
      perform private.fail('KL403', 'FORBIDDEN', 'someone else must approve your own changes');
    end if;
  end if;
  execute format('update public.%I set status = $1, published_at = case when $1 = ''published'' then now() else published_at end %s where id = $2',
                 p_table, case when p_table = 'activities' then ', published_by = case when $1 = ''published'' then auth.uid() else published_by end, content_version = content_version + case when $1 = ''published'' and published_at is not null then 1 else 0 end' else '' end)
    using p_to, p_id;
  perform private.admin_note('content.' || p_to, p_table, p_id::text,
    jsonb_build_object('from', cur, 'to', p_to, 'note', nullif(trim(coalesce(p_note, '')), '')));
  return jsonb_build_object('id', p_id, 'from', cur, 'status', p_to);
end $$;

-- Families (support): search by parent email; children show nickname, age in years and activity
-- counts only (no birth month, no session detail).
create or replace function admin_api.families(p_query text default '', p_status text default null,
                                                 p_limit int default 25, p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare q text := lower(trim(coalesce(p_query, '')));
begin
  perform private.require('support.read');
  return jsonb_build_object(
    'total', (select count(*) from public.parent_accounts a join auth.users u on u.id = a.owner_user_id
              where (q = '' or lower(u.email) like '%' || q || '%' or a.id::text = q)
                and (p_status is null or a.status = p_status)),
    'rows', coalesce((select jsonb_agg(x) from (
      select jsonb_build_object('accountId', a.id, 'ownerEmail', u.email, 'status', a.status, 'country', a.country,
               'createdAt', a.created_at,
               'children', (select count(*) from public.child_profiles c where c.account_id = a.id and c.status = 'active'),
               'plus', exists (select 1 from public.entitlements e where e.account_id = a.id and e.active_until > now())) x
      from public.parent_accounts a join auth.users u on u.id = a.owner_user_id
      where (q = '' or lower(u.email) like '%' || q || '%' or a.id::text = q)
        and (p_status is null or a.status = p_status)
      order by a.created_at desc
      limit least(greatest(p_limit, 1), 100) offset greatest(p_offset, 0)) z), '[]'));
end $$;

create or replace function admin_api.family(p_account uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare a public.parent_accounts;
begin
  perform private.require('support.read');
  select * into a from public.parent_accounts where id = p_account;
  if a.id is null then perform private.fail('KL404', 'NOT_FOUND', 'account'); end if;
  return jsonb_build_object(
    'accountId', a.id, 'status', a.status, 'timezone', a.timezone, 'country', a.country, 'createdAt', a.created_at,
    'parents', (select jsonb_agg(jsonb_build_object('email', u.email, 'role', pp.role, 'since', pp.created_at))
                from public.parent_profiles pp join auth.users u on u.id = pp.user_id where pp.account_id = a.id),
    'children', coalesce((select jsonb_agg(jsonb_build_object('childId', c.id, 'nickname', c.nickname,
        'ageYears', extract(year from age(date_trunc('month', now()), c.birth_year_month))::int, 'status', c.status,
        'sessions30d', (select count(*) from public.activity_sessions s where s.child_id = c.id and s.started_at > now() - interval '30 days'),
        'completed30d', (select count(*) from public.activity_sessions s where s.child_id = c.id and s.status = 'completed' and s.started_at > now() - interval '30 days'),
        'lastActive', (select max(started_at) from public.activity_sessions s where s.child_id = c.id),
        'stars', (select coalesce(sum(amount), 0) from public.star_transactions t where t.child_id = c.id)) order by c.sort)
      from public.child_profiles c where c.account_id = a.id), '[]'),
    'subscriptions', coalesce((select jsonb_agg(jsonb_build_object('plan', p.key, 'provider', s.provider, 'status', s.status,
        'periodEnd', s.current_period_end, 'environment', s.environment) order by s.started_at desc)
      from public.subscriptions s join public.subscription_plans p on p.id = s.plan_id where s.account_id = a.id), '[]'),
    'exports', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'status', e.status, 'childId', e.child_id,
        'createdAt', e.created_at, 'expiresAt', e.expires_at) order by e.created_at desc)
      from public.data_export_requests e where e.account_id = a.id), '[]'),
    'deletions', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'scope', d.scope, 'status', d.status,
        'scheduledFor', d.scheduled_for) order by d.created_at desc)
      from public.deletion_requests d where d.account_id = a.id), '[]'));
end $$;

create or replace function admin_api.set_account_status(p_account uuid, p_status text, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cur text;
begin
  perform private.require('support.act');
  if p_status not in ('active','suspended') then perform private.fail('KL400', 'VALIDATION', 'status'); end if;
  if length(coalesce(trim(p_reason), '')) < 5 then perform private.fail('KL400', 'VALIDATION', 'give a reason'); end if;
  select status into cur from public.parent_accounts where id = p_account for update;
  if cur is null then perform private.fail('KL404', 'NOT_FOUND', 'account'); end if;
  if cur = 'pending_deletion' then perform private.fail('KL409', 'CONFLICT', 'account is being deleted'); end if;
  update public.parent_accounts set status = p_status where id = p_account;
  perform private.admin_note('account.' || p_status, 'parent_accounts', p_account::text,
    jsonb_build_object('from', cur, 'to', p_status, 'reason', trim(p_reason)), p_account);
  return jsonb_build_object('accountId', p_account, 'status', p_status);
end $$;

-- Privacy requests across families (privacy.act or support.read).
create or replace function admin_api.privacy_requests(p_kind text, p_status text default null,
                                                         p_limit int default 25, p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not (private.has_permission('privacy.act') or private.has_permission('support.read')) then
    perform private.fail('KL403', 'FORBIDDEN', 'privacy.act or support.read required');
  end if;
  if p_kind = 'export' then
    return coalesce((select jsonb_agg(x) from (
      select jsonb_build_object('id', e.id, 'accountId', e.account_id, 'status', e.status, 'scope', case when e.child_id is null then 'account' else 'child' end,
               'createdAt', e.created_at, 'expiresAt', e.expires_at,
               'ownerEmail', (select u.email from public.parent_accounts a join auth.users u on u.id = a.owner_user_id where a.id = e.account_id)) x
      from public.data_export_requests e where p_status is null or e.status = p_status
      order by e.created_at desc limit least(greatest(p_limit, 1), 100) offset greatest(p_offset, 0)) q), '[]');
  elsif p_kind = 'deletion' then
    return coalesce((select jsonb_agg(x) from (
      select jsonb_build_object('id', d.id, 'accountId', d.account_id, 'scope', d.scope, 'status', d.status,
               'scheduledFor', d.scheduled_for, 'completedAt', d.completed_at, 'createdAt', d.created_at,
               'ownerEmail', (select u.email from public.parent_accounts a join auth.users u on u.id = a.owner_user_id where a.id = d.account_id)) x
      from public.deletion_requests d where p_status is null or d.status = p_status
      order by d.created_at desc limit least(greatest(p_limit, 1), 100) offset greatest(p_offset, 0)) q), '[]');
  end if;
  perform private.fail('KL400', 'VALIDATION', 'kind is export or deletion');
  return null;
end $$;

create or replace function admin_api.cancel_deletion(p_request uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare d public.deletion_requests;
begin
  perform private.require('support.act');
  if length(coalesce(trim(p_reason), '')) < 5 then perform private.fail('KL400', 'VALIDATION', 'give a reason'); end if;
  select * into d from public.deletion_requests where id = p_request for update;
  if d.id is null then perform private.fail('KL404', 'NOT_FOUND', 'request'); end if;
  if d.status <> 'scheduled' then perform private.fail('KL409', 'CONFLICT', 'only a scheduled deletion can be cancelled'); end if;
  update public.deletion_requests set status = 'cancelled' where id = d.id;
  if d.scope = 'account' then
    update public.parent_accounts set status = 'active' where id = d.account_id and status = 'pending_deletion';
  end if;
  perform private.admin_note('deletion.cancel', 'deletion_requests', d.id::text, jsonb_build_object('reason', trim(p_reason)), d.account_id);
  return jsonb_build_object('id', d.id, 'status', 'cancelled');
end $$;

-- Stars added by support: positive, capped, reasoned, once per request id, audited.
create or replace function admin_api.grant_stars(p_child uuid, p_amount int, p_reason text, p_request uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare acc uuid; n int;
begin
  perform private.require('support.act');
  if p_amount is null or p_amount < 1 or p_amount > 20 then perform private.fail('KL400', 'VALIDATION', 'amount must be 1–20'); end if;
  if length(coalesce(trim(p_reason), '')) < 10 then perform private.fail('KL400', 'VALIDATION', 'explain why (10+ characters)'); end if;
  select account_id into acc from public.child_profiles where id = p_child and status = 'active';
  if acc is null then perform private.fail('KL404', 'NOT_FOUND', 'child'); end if;
  insert into public.star_transactions (child_id, amount, reason, ref_key, local_date)
  values (p_child, p_amount, 'admin_adjustment', 'admin:' || p_request, private.local_date(acc, now()))
  on conflict (child_id, reason, ref_key) do nothing;
  get diagnostics n = row_count;
  if n > 0 then
    perform private.admin_note('stars.grant', 'star_transactions', p_child::text,
      jsonb_build_object('amount', p_amount, 'reason', trim(p_reason), 'request', p_request), acc);
  end if;
  return jsonb_build_object('childId', p_child, 'granted', n > 0,
    'balance', (select coalesce(sum(amount), 0) from public.star_transactions where child_id = p_child));
end $$;

-- Admin users (admin.manage). Never on yourself; the last active super admin can't be removed.
create or replace function admin_api.users_list() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require('admin.manage');
  return coalesce((select jsonb_agg(jsonb_build_object('userId', u.user_id, 'email', au.email, 'status', u.status,
           'roles', coalesce((select jsonb_agg(role_key order by role_key) from public.admin_user_roles r where r.user_id = u.user_id), '[]'),
           'since', u.created_at, 'lastSignIn', au.updated_at) order by au.email)
    from public.admin_users u join auth.users au on au.id = u.user_id), '[]');
end $$;

create or replace function private.super_admins_left(p_except uuid) returns int
language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.admin_users u join public.admin_user_roles r on r.user_id = u.user_id
  where r.role_key = 'super_admin' and u.status = 'active' and u.user_id <> p_except
$$;

create or replace function admin_api.set_roles(p_email text, p_roles text[]) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare target uuid; bad text;
begin
  perform private.require('admin.manage');
  select id into target from auth.users where lower(email) = lower(trim(p_email));
  if target is null then perform private.fail('KL404', 'NOT_FOUND', 'no user with that email (they must sign up first)'); end if;
  if target = auth.uid() then perform private.fail('KL403', 'FORBIDDEN', 'you can''t change your own roles'); end if;
  select r into bad from unnest(coalesce(p_roles, '{}')) r where not exists (select 1 from public.admin_roles where key = r) limit 1;
  if bad is not null then perform private.fail('KL400', 'VALIDATION', 'unknown role ' || bad); end if;
  if not ('super_admin' = any (coalesce(p_roles, '{}')))
     and exists (select 1 from public.admin_user_roles where user_id = target and role_key = 'super_admin')
     and private.super_admins_left(target) = 0 then
    perform private.fail('KL409', 'CONFLICT', 'keep at least one active super admin');
  end if;
  insert into public.admin_users (user_id) values (target) on conflict (user_id) do nothing;
  delete from public.admin_user_roles where user_id = target and not (role_key = any (coalesce(p_roles, '{}')));
  insert into public.admin_user_roles (user_id, role_key, granted_by)
  select target, r, auth.uid() from unnest(coalesce(p_roles, '{}')) r on conflict do nothing;
  return jsonb_build_object('userId', target, 'roles', to_jsonb(coalesce(p_roles, '{}')));
end $$;

create or replace function admin_api.set_admin_status(p_user uuid, p_status text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require('admin.manage');
  if p_status not in ('active','suspended') then perform private.fail('KL400', 'VALIDATION', 'status'); end if;
  if p_user = auth.uid() then perform private.fail('KL403', 'FORBIDDEN', 'you can''t change your own status'); end if;
  if p_status = 'suspended' and exists (select 1 from public.admin_user_roles where user_id = p_user and role_key = 'super_admin')
     and private.super_admins_left(p_user) = 0 then
    perform private.fail('KL409', 'CONFLICT', 'keep at least one active super admin');
  end if;
  update public.admin_users set status = p_status where user_id = p_user;
  if not found then perform private.fail('KL404', 'NOT_FOUND', 'admin'); end if;
  return jsonb_build_object('userId', p_user, 'status', p_status);
end $$;

-- Media registration: the admin Edge Function (service role) calls it after copying a checked
-- upload from admin-staging into its bucket. The actor's permission is checked from the tables
-- (the Edge Function has already verified the JWT and its aal2).
create or replace function private.admin_can(p_user uuid, p_perm text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admin_users u join public.admin_user_roles ur on ur.user_id = u.user_id
                 join public.admin_role_permissions rp on rp.role_key = ur.role_key
                 where u.user_id = p_user and u.status = 'active' and rp.permission_key = p_perm)
$$;

create or replace function private.admin_register_media(p_user uuid, p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare m public.media_assets; bucket text := p->>'bucket';
begin
  if not private.admin_can(p_user, 'content.write') then perform private.fail('KL403', 'FORBIDDEN', 'content.write required'); end if;
  if bucket not in ('public-assets','content','video') then perform private.fail('KL400', 'VALIDATION', 'bucket'); end if;
  insert into public.media_assets (bucket, object_path, kind, mime_type, bytes, sha256, width, height, duration_ms,
                                   locale, access, status, created_by)
  values (bucket, p->>'path', p->>'kind', p->>'mime', (p->>'bytes')::bigint, p->>'sha256',
          nullif(p->>'width', '')::int, nullif(p->>'height', '')::int, nullif(p->>'durationMs', '')::int,
          nullif(p->>'locale', ''), case when bucket = 'public-assets' then 'public' else 'gated' end,
          coalesce(p->>'status', 'ready'), p_user)
  returning * into m;
  return jsonb_build_object('id', m.id, 'bucket', m.bucket, 'path', m.object_path, 'kind', m.kind, 'status', m.status);
exception
  when unique_violation then perform private.fail('KL409', 'CONFLICT', 'a file is already registered at that path'); return null;
  when check_violation or invalid_text_representation then perform private.fail('KL400', 'VALIDATION', sqlerrm); return null;
end $$;

-- ---------------------------------------------------------------------------------------------
-- 7. Privileges
-- ---------------------------------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    'private.check_prerequisites()', 'private.check_app_config()', 'private.goal_default(text)',
    'private.not_suspended(uuid)', 'private.require(text)', 'private.admin_note(text,text,text,jsonb,uuid)',
    'private.super_admins_left(uuid)', 'private.admin_can(uuid,text)', 'private.admin_register_media(uuid,jsonb)',
    'private.apply_rewards(uuid)', 'private.rewards_summary(uuid,uuid)', 'private.set_learning_goals(uuid,uuid,jsonb)',
    'private.progress_report(uuid,uuid,text,date)', 'private.apply_session(uuid,jsonb)', 'private.household_of_child(uuid,uuid)']
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['private.admin_register_media(uuid,jsonb)', 'private.rewards_summary(uuid,uuid)',
    'private.set_learning_goals(uuid,uuid,jsonb)', 'private.progress_report(uuid,uuid,text,date)', 'private.apply_session(uuid,jsonb)']
  loop
    execute format('grant execute on function %s to service_role', f);
  end loop;
  foreach f in array array['admin_api.me()', 'admin_api.dashboard()', 'admin_api.activity(int,int,text)',
    'admin_api.validate(text,uuid)', 'admin_api.transition(text,uuid,text,text)',
    'admin_api.families(text,text,int,int)', 'admin_api.family(uuid)',
    'admin_api.set_account_status(uuid,text,text)', 'admin_api.privacy_requests(text,text,int,int)',
    'admin_api.cancel_deletion(uuid,text)', 'admin_api.grant_stars(uuid,int,text,uuid)',
    'admin_api.users_list()', 'admin_api.set_roles(text,text[])', 'admin_api.set_admin_status(uuid,text)']
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
