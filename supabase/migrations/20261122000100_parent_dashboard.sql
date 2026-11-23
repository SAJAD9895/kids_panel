-- Phase 13: parent dashboard, reports, notifications, privacy requests. docs/parent-dashboard/.
--
-- Reuses the existing tables (sessions, results, daily_progress, skill_mastery, rewards tables,
-- notifications, notification_preferences, data_export_requests, deletion_requests,
-- subscriptions, entitlements, parental_consents). Changes, each documented in
-- docs/backend/database-schema.md §5 (#18–#21):
--   #18 skill_mastery is now WRITTEN (private.update_mastery, the 09 §9.3 model) after each
--       completed session; until now nothing computed it, so a "skill mastery" chart would have
--       had no honest data.
--   #19 notifications: types 'goal_reached' and 'subscription_changed'; dedupe_key (unique per
--       user) so a job or a retried trigger never sends the same notice twice.
--   #20 data_export_requests.child_id: a parent can export one child's data (null = account).
--   #21 the exports bucket also accepts application/json (exports are JSON documents).
-- Nothing is invented for reports: every number is a count or sum of recorded sessions,
-- results, stars and goals (definitions in docs/parent-dashboard/analytics.md).

-- ---------------------------------------------------------------------------------------------
-- 1. Skill mastery (09-learning-progress-engine.md §9.3)
--    e = correct/total when the result has counts, else score/100, else 0.7 (completed, unscored)
--    α = max(0.1, 1/(n+2)), halved when the same activity was already completed that day
--    mastery ← mastery + α·w·(e − mastery)        w = activity_skills.weight
-- ---------------------------------------------------------------------------------------------
create or replace function private.update_mastery(p_session uuid) returns int
language plpgsql security definer set search_path = '' as $$
declare s public.activity_sessions; res public.activity_results; e numeric; again boolean; k record; n int := 0;
  a numeric;
begin
  select * into s from public.activity_sessions where id = p_session and status = 'completed';
  if s.id is null then return 0; end if;
  select * into res from public.activity_results where session_id = s.id;
  e := case
    when res.total_count is not null and res.total_count > 0 then least(res.correct_count::numeric / res.total_count, 1)
    when res.score is not null then res.score / 100
    else 0.7 end;
  again := exists (select 1 from public.activity_sessions o
                   where o.child_id = s.child_id and o.activity_id = s.activity_id and o.local_date = s.local_date
                     and o.status = 'completed' and o.id <> s.id and o.started_at < s.started_at);
  for k in select sk.skill_id, sk.weight from public.activity_skills sk where sk.activity_id = s.activity_id loop
    insert into public.skill_mastery as m (child_id, skill_id, mastery, evidence_count, last_practiced_at)
    values (s.child_id, k.skill_id, 0, 0, s.ended_at)
    on conflict (child_id, skill_id) do nothing;
    select greatest(0.1, 1.0 / (m.evidence_count + 2)) * case when again then 0.5 else 1 end into a
      from public.skill_mastery m where m.child_id = s.child_id and m.skill_id = k.skill_id;
    update public.skill_mastery m
       set mastery = least(greatest(m.mastery + a * k.weight * (e - m.mastery), 0), 1),
           evidence_count = m.evidence_count + 1,
           last_practiced_at = greatest(coalesce(m.last_practiced_at, s.ended_at), s.ended_at),
           updated_at = now()
     where m.child_id = s.child_id and m.skill_id = k.skill_id;
    n := n + 1;
  end loop;
  return n;
end $$;

-- ---------------------------------------------------------------------------------------------
-- 2. Notifications (parents only; in-app delivery; preferences respected)
-- ---------------------------------------------------------------------------------------------
alter table notifications drop constraint if exists notifications_type_check;
alter table notifications add constraint notifications_type_check check (type in
  ('weekly_progress','certificate_earned','trial_ending','billing_issue','new_content','account_security',
   'export_ready','deletion_scheduled','goal_reached','subscription_changed'));
alter table notifications add column dedupe_key text check (dedupe_key is null or length(dedupe_key) <= 200);
create unique index notifications_dedupe on notifications (user_id, dedupe_key) where dedupe_key is not null;

-- Types a parent can switch, and which channels exist. Only in-app is delivered today; email and
-- push preferences are stored for when a sender is connected (docs/parent-dashboard/dashboard.md).
create or replace function private.notification_types() returns text[]
language sql immutable as $$
  select array['weekly_progress','goal_reached','account_security','subscription_changed','billing_issue',
               'trial_ending','export_ready','deletion_scheduled','certificate_earned','new_content']
$$;

-- One in-app notice per parent of the household who hasn't switched this type off.
create or replace function private.notify(p_account uuid, p_type text, p_params jsonb, p_dedupe text)
returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  insert into public.notifications (user_id, account_id, type, channel, template_key, params, status, sent_at, dedupe_key)
  select pp.user_id, p_account, p_type, 'in_app', p_type, coalesce(p_params, '{}'), 'sent', now(), p_dedupe
  from public.parent_profiles pp
  where pp.account_id = p_account
    and coalesce((select np.enabled from public.notification_preferences np
                  where np.user_id = pp.user_id and np.type = p_type and np.channel = 'in_app'), true)
  on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

-- PUT /account/notification-preferences: [{type, channel, enabled}]
create or replace function private.set_notification_preferences(p_user_id uuid, p jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare x jsonb;
begin
  if not exists (select 1 from public.parent_profiles where user_id = p_user_id) then
    perform private.fail('KL404', 'NOT_FOUND', 'account');
  end if;
  if jsonb_typeof(p) is distinct from 'array' or jsonb_array_length(p) = 0 or jsonb_array_length(p) > 40 then
    perform private.fail('KL400', 'VALIDATION', 'preferences must be a list');
  end if;
  for x in select * from jsonb_array_elements(p) loop
    if not (x->>'type' = any (private.notification_types())) or x->>'channel' not in ('in_app','email','push')
       or jsonb_typeof(x->'enabled') is distinct from 'boolean' then
      perform private.fail('KL400', 'VALIDATION', 'unknown preference ' || coalesce(x->>'type', '?'));
    end if;
    insert into public.notification_preferences as np (user_id, type, channel, enabled)
    values (p_user_id, x->>'type', x->>'channel', (x->>'enabled')::boolean)
    on conflict (user_id, type, channel) do update set enabled = excluded.enabled, updated_at = now();
  end loop;
  return coalesce((select jsonb_agg(jsonb_build_object('type', type, 'channel', channel, 'enabled', enabled) order by type, channel)
                   from public.notification_preferences where user_id = p_user_id), '[]');
end $$;

-- POST /account/notifications/read: {ids?} (none = all)
create or replace function private.mark_notifications_read(p_user_id uuid, p_ids uuid[])
returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  update public.notifications set status = 'read', read_at = now(), updated_at = now()
   where user_id = p_user_id and channel = 'in_app' and read_at is null
     and (p_ids is null or id = any (p_ids));
  get diagnostics n = row_count;
  return n;
end $$;

-- Subscription events → notices (written by the billing service; never by a client)
create or replace function private.on_subscription_change() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then return new; end if;
  perform private.notify(new.account_id,
    case when new.status in ('billing_retry','grace_period') then 'billing_issue' else 'subscription_changed' end,
    jsonb_build_object('status', new.status, 'planKey', (select key from public.subscription_plans where id = new.plan_id),
                       'provider', new.provider, 'periodEnd', new.current_period_end),
    'sub:' || new.id || ':' || new.status);
  return new;
end $$;
create trigger notify_subscription after insert or update of status on subscriptions
  for each row execute function private.on_subscription_change();

-- Account activity → notices
create or replace function private.on_deletion_request() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.scope = 'account' and new.status = 'scheduled' then
    perform private.notify(new.account_id, 'deletion_scheduled',
      jsonb_build_object('requestId', new.id, 'scheduledFor', new.scheduled_for), 'deletion:' || new.id);
  elsif new.scope = 'child' then
    perform private.notify(new.account_id, 'account_security',
      jsonb_build_object('event', 'child_deleted'), 'child-deleted:' || new.id);
  end if;
  return new;
end $$;
create trigger notify_deletion after insert on deletion_requests
  for each row execute function private.on_deletion_request();

-- ---------------------------------------------------------------------------------------------
-- 3. Data export (one child, or the whole account)
-- ---------------------------------------------------------------------------------------------
alter table data_export_requests add column child_id uuid references child_profiles(id) on delete cascade;
create index on data_export_requests (child_id);
update storage.buckets set allowed_mime_types = array['application/zip','application/json'] where id = 'exports';

create or replace function private.account_of_user(p_user_id uuid) returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare acc uuid;
begin
  select account_id into acc from public.parent_profiles where user_id = p_user_id;
  if acc is null then perform private.fail('KL404', 'NOT_FOUND', 'account'); end if;
  return acc;
end $$;

create or replace function private.request_export(p_user_id uuid, p_child uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare acc uuid; req public.data_export_requests;
begin
  acc := case when p_child is null then private.account_of_user(p_user_id)
              else private.household_of_child(p_user_id, p_child) end;
  if (select count(*) from public.data_export_requests where account_id = acc and created_at > now() - interval '1 day') >= 5 then
    perform private.fail('KL429', 'RATE_LIMITED', 'five exports a day');
  end if;
  insert into public.data_export_requests (account_id, requested_by, status, child_id)
  values (acc, p_user_id, 'processing', p_child) returning * into req;
  return jsonb_build_object('requestId', req.id, 'accountId', acc, 'childId', p_child);
end $$;

-- Everything stored about one child (no other child's data; ids of content are resolved to names).
create or replace function private.export_child(p_child uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'profile', (select jsonb_build_object('nickname', c.nickname, 'birthYearMonth', to_char(c.birth_year_month, 'YYYY-MM'),
                  'avatar', (select key from public.avatars where id = c.avatar_id), 'learningStage', c.learning_stage,
                  'contentLocale', c.content_locale, 'analyticsId', c.analytics_id, 'createdAt', c.created_at)
                from public.child_profiles c where c.id = p_child),
    'sessions', coalesce((select jsonb_agg(jsonb_build_object('activity', a.slug, 'type', a.type, 'status', s.status,
                  'startedAt', s.started_at, 'endedAt', s.ended_at, 'localDate', s.local_date, 'source', s.source,
                  'score', r.score, 'correct', r.correct_count, 'total', r.total_count, 'durationMs', r.duration_ms,
                  'level', r.metrics->>'level') order by s.started_at)
                from public.activity_sessions s join public.activities a on a.id = s.activity_id
                left join public.activity_results r on r.session_id = s.id where s.child_id = p_child), '[]'),
    'stars', coalesce((select jsonb_agg(jsonb_build_object('amount', t.amount, 'reason', t.reason, 'localDate', t.local_date,
                  'at', t.created_at) order by t.created_at) from public.star_transactions t where t.child_id = p_child), '[]'),
    'rewards', coalesce((select jsonb_agg(jsonb_build_object('key', w.key, 'type', w.type, 'earnedAt', cr.first_earned_at))
                from public.child_rewards cr join public.rewards w on w.id = cr.reward_id where cr.child_id = p_child), '[]'),
    'goals', (select to_jsonb(g) - 'child_id' from public.learning_goals g where g.child_id = p_child),
    'goalProgress', coalesce((select jsonb_agg(to_jsonb(gp) - 'child_id' order by gp.period_start) from public.goal_progress gp
                where gp.child_id = p_child), '[]'),
    'streak', (select to_jsonb(ls) - 'child_id' from public.learning_streaks ls where ls.child_id = p_child),
    'skills', coalesce((select jsonb_agg(jsonb_build_object('skill', k.key, 'mastery', m.mastery, 'evidence', m.evidence_count))
                from public.skill_mastery m join public.skills k on k.id = m.skill_id where m.child_id = p_child), '[]'),
    'courses', coalesce((select jsonb_agg(jsonb_build_object('course', co.slug, 'status', e.status, 'completedAt', e.completed_at))
                from public.course_enrollments e join public.courses co on co.id = e.course_id where e.child_id = p_child), '[]'),
    'favorites', coalesce((select jsonb_agg(a.slug) from public.favorites f join public.activities a on a.id = f.activity_id
                where f.child_id = p_child), '[]'),
    'screenTime', (select to_jsonb(st) - 'child_id' from public.screen_time_rules st where st.child_id = p_child))
$$;

create or replace function private.export_payload(p_request uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare req public.data_export_requests;
begin
  select * into req from public.data_export_requests where id = p_request;
  if req.id is null then perform private.fail('KL404', 'NOT_FOUND', 'export'); end if;
  return jsonb_build_object(
    'generatedAt', now(), 'format', 'kids-learning-export/1',
    'scope', case when req.child_id is null then 'account' else 'child' end,
    'account', case when req.child_id is null then (select jsonb_build_object(
        'timezone', a.timezone, 'country', a.country, 'createdAt', a.created_at,
        'parents', (select jsonb_agg(jsonb_build_object('email', u.email, 'role', pp.role)) from public.parent_profiles pp
                    join auth.users u on u.id = pp.user_id where pp.account_id = a.id),
        'consents', coalesce((select jsonb_agg(jsonb_build_object('type', pc.consent_type, 'version', pc.policy_version,
                    'method', pc.method, 'grantedAt', pc.granted_at, 'revokedAt', pc.revoked_at) order by pc.granted_at)
                    from public.parental_consents pc where pc.account_id = a.id), '[]'),
        'subscriptions', coalesce((select jsonb_agg(jsonb_build_object('plan', sp.key, 'provider', s.provider, 'status', s.status,
                    'start', s.started_at, 'periodEnd', s.current_period_end)) from public.subscriptions s
                    join public.subscription_plans sp on sp.id = s.plan_id where s.account_id = a.id), '[]'),
        'notificationPreferences', coalesce((select jsonb_agg(jsonb_build_object('type', np.type, 'channel', np.channel,
                    'enabled', np.enabled)) from public.notification_preferences np
                    where np.user_id in (select user_id from public.parent_profiles where account_id = a.id)), '[]'))
      from public.parent_accounts a where a.id = req.account_id) end,
    'children', coalesce((select jsonb_agg(private.export_child(c.id) order by c.sort) from public.child_profiles c
                  where c.account_id = req.account_id and (req.child_id is null or c.id = req.child_id)), '[]'));
end $$;

create or replace function private.finish_export(p_request uuid, p_path text, p_ok boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare req public.data_export_requests;
begin
  update public.data_export_requests
     set status = case when p_ok then 'ready' else 'failed' end, object_path = case when p_ok then p_path end,
         expires_at = case when p_ok then now() + interval '7 days' end, updated_at = now()
   where id = p_request and status = 'processing' returning * into req;
  if req.id is null then perform private.fail('KL409', 'CONFLICT', 'export not processing'); end if;
  if p_ok then
    perform private.notify(req.account_id, 'export_ready',
      jsonb_build_object('requestId', req.id, 'childId', req.child_id, 'expiresAt', req.expires_at), 'export:' || req.id);
  end if;
  return jsonb_build_object('requestId', req.id, 'status', req.status, 'expiresAt', req.expires_at);
end $$;

-- GET /account/exports/:id/url: the file, for a parent of the household, until it expires
create or replace function private.export_file(p_user_id uuid, p_request uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare req public.data_export_requests;
begin
  select * into req from public.data_export_requests
   where id = p_request and account_id = private.account_of_user(p_user_id);
  if req.id is null then perform private.fail('KL404', 'NOT_FOUND', 'export'); end if;
  if req.status <> 'ready' or req.expires_at <= now() then perform private.fail('KL409', 'CONFLICT', 'export not available'); end if;
  return jsonb_build_object('path', req.object_path, 'expiresAt', req.expires_at);
end $$;

-- ---------------------------------------------------------------------------------------------
-- 4. Reports
-- ---------------------------------------------------------------------------------------------
-- One child's report for a household day, ISO week or calendar month containing p_date.
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
        'dailyTarget', coalesce(g.daily_activities, 3), 'weeklyTarget', coalesce(g.weekly_days, 4),
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

-- The dashboard: every active child of the household, with the numbers the cards show.
create or replace function private.family_overview(p_user_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare acc uuid; today date; wk date;
begin
  acc := private.account_of_user(p_user_id);
  today := private.local_date(acc, now());
  wk := date_trunc('week', today)::date;
  return jsonb_build_object(
    'today', today, 'weekStart', wk,
    'plusUntil', (select active_until from public.entitlements where account_id = acc and entitlement = 'plus' and active_until > now()),
    'unread', (select count(*) from public.notifications where user_id = p_user_id and channel = 'in_app' and read_at is null),
    'children', coalesce((select jsonb_agg(jsonb_build_object(
        'childId', c.id,
        'secondsToday', (select coalesce(sum(seconds_played), 0) from public.daily_progress dp where dp.child_id = c.id and dp.local_date = today),
        'secondsWeek', (select coalesce(sum(seconds_played), 0) from public.daily_progress dp where dp.child_id = c.id and dp.local_date between wk and today),
        'secondsTotal', (select coalesce(sum(seconds_played), 0) from public.daily_progress dp where dp.child_id = c.id),
        'lessonsCompleted', (select count(*) from (select l.id from public.lessons l
            join public.lesson_steps st on st.lesson_id = l.id and st.required
            join public.lesson_step_completions lc on lc.step_id = st.id and lc.child_id = c.id
            group by l.id having count(*) = (select count(*) from public.lesson_steps x where x.lesson_id = l.id and x.required)) z),
        'gamesCompleted', (select count(*) from public.activity_sessions s join public.activities a on a.id = s.activity_id
                           where s.child_id = c.id and s.status = 'completed' and a.type = 'game'),
        'rewards', private.rewards_summary(p_user_id, c.id) - 'badges' - 'transactions' - 'rules' - 'learningDays',
        'badgesEarned', (select count(*) from public.child_rewards cr join public.rewards w on w.id = cr.reward_id
                         where cr.child_id = c.id and w.type = 'badge'),
        'recent', coalesce((select jsonb_agg(x order by x->>'startedAt' desc) from (
            select jsonb_build_object('activityId', a.slug, 'title', a.title->>'en', 'type', a.type, 'status', s.status,
              'startedAt', s.started_at) x
            from public.activity_sessions s join public.activities a on a.id = s.activity_id
            where s.child_id = c.id order by s.started_at desc limit 5) q), '[]')
      ) order by c.sort, c.created_at) from public.child_profiles c where c.account_id = acc and c.status = 'active'), '[]'));
end $$;

-- ---------------------------------------------------------------------------------------------
-- 5. Weekly summaries and trial reminders (a scheduled job; pg_cron when enabled)
--    A household gets last week's summary on its own Monday; dedupe keys make re-runs safe.
-- ---------------------------------------------------------------------------------------------
create or replace function private.queue_due_notifications(p_now timestamptz default now())
returns int language plpgsql security definer set search_path = '' as $$
declare a record; ws date; n int := 0; kids jsonb; t record;
begin
  for a in select pa.id, pa.timezone from public.parent_accounts pa loop
    if extract(isodow from (p_now at time zone a.timezone)) = 1 then
      ws := (p_now at time zone a.timezone)::date - 7;
      select jsonb_agg(jsonb_build_object('childId', c.id,
               'learningDays', (select count(distinct local_date) from public.star_awards sa where sa.child_id = c.id and sa.local_date between ws and ws + 6),
               'activities', (select coalesce(sum(sessions_completed), 0) from public.daily_progress dp where dp.child_id = c.id and dp.local_date between ws and ws + 6),
               'seconds', (select coalesce(sum(seconds_played), 0) from public.daily_progress dp where dp.child_id = c.id and dp.local_date between ws and ws + 6),
               'stars', (select coalesce(sum(amount), 0) from public.star_transactions st where st.child_id = c.id and st.local_date between ws and ws + 6))
             order by c.sort)
        into kids from public.child_profiles c where c.account_id = a.id and c.status = 'active';
      if kids is not null then
        n := n + private.notify(a.id, 'weekly_progress', jsonb_build_object('weekStart', ws, 'children', kids), 'weekly:' || ws);
      end if;
    end if;
  end loop;
  for t in select s.id, s.account_id, s.current_period_end from public.subscriptions s
           where s.status = 'trialing' and s.current_period_end between p_now and p_now + interval '2 days' loop
    n := n + private.notify(t.account_id, 'trial_ending', jsonb_build_object('endsAt', t.current_period_end), 'trial-end:' || t.id);
  end loop;
  return n;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('parent-notifications', '10 * * * *', 'select private.queue_due_notifications(now())');
  end if;
end $$;

-- ---------------------------------------------------------------------------------------------
-- 5b. Fix (found by D1): apply_session stored a MISSING score as 0, because greatest(null, 0) is 0
--     in Postgres. Unscored activities (videos, songs, stories) then counted as 0 % in averages.
--     apply_session_core is the Phase 9 body (renamed in Phase 12) with only that expression
--     changed: no score stays null. Existing 0 scores can't be told apart and are left as they are.
-- ---------------------------------------------------------------------------------------------
create or replace function private.apply_session_core(p_user_id uuid, p jsonb) returns jsonb
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
            case when r->>'score' is null then null else least(greatest((r->>'score')::numeric, 0), 100) end,
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
      values (child, step, sid, case when r->>'score' is null then null else least(greatest((r->>'score')::numeric, 0), 100) end, t_end)
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
revoke all on function private.apply_session_core(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- 6. apply_session: after the rewards step, mastery and the goal notice
-- ---------------------------------------------------------------------------------------------
create or replace function private.apply_session(p_user_id uuid, p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r jsonb; rw jsonb; g jsonb; sid uuid; acc uuid; ch uuid;
begin
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
-- 7. Privileges: service only
-- ---------------------------------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    'private.notification_types()', 'private.update_mastery(uuid)', 'private.notify(uuid,text,jsonb,text)',
    'private.set_notification_preferences(uuid,jsonb)', 'private.mark_notifications_read(uuid,uuid[])',
    'private.account_of_user(uuid)', 'private.request_export(uuid,uuid)', 'private.export_child(uuid)',
    'private.export_payload(uuid)', 'private.finish_export(uuid,text,boolean)', 'private.export_file(uuid,uuid)',
    'private.progress_report(uuid,uuid,text,date)', 'private.family_overview(uuid)',
    'private.queue_due_notifications(timestamptz)', 'private.apply_session(uuid,jsonb)',
    'private.on_subscription_change()', 'private.on_deletion_request()']
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  foreach f in array array[
    'private.set_notification_preferences(uuid,jsonb)', 'private.mark_notifications_read(uuid,uuid[])',
    'private.request_export(uuid,uuid)', 'private.export_payload(uuid)', 'private.finish_export(uuid,text,boolean)',
    'private.export_file(uuid,uuid)', 'private.progress_report(uuid,uuid,text,date)', 'private.family_overview(uuid)',
    'private.queue_due_notifications(timestamptz)', 'private.apply_session(uuid,jsonb)']
  loop
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
