-- =============================================================================
-- D1 Parent dashboard (migration 20261122000100): family overview, progress reports, skill
-- mastery, notifications (preferences, dedupe, weekly job, subscription and account events),
-- data export, account deletion, isolation. Runs in one transaction and ROLLS BACK.
-- Alice (Asia/Dubai): Mia, Leo. Bob (Europe/London): Sam.
-- =============================================================================
\set ON_ERROR_STOP on
begin;

-- A finished session, as the app reports it.
create function pg_temp.play(p_user uuid, p_child uuid, p_slug text, p_at timestamptz, p_minutes int,
                             p_score numeric default null, p_correct int default null, p_total int default null,
                             p_level text default null, p_status text default 'completed')
returns jsonb language sql as $$
  select private.apply_session(p_user, jsonb_build_object('session', jsonb_build_object(
    'id', gen_random_uuid(), 'childId', p_child, 'activityId', (select id from public.activities where slug = p_slug),
    'source', 'feed', 'platform', 'ios', 'appVersion', '1.0.0', 'contentVersion', 1, 'status', p_status,
    'startedAt', p_at, 'endedAt', p_at + make_interval(mins => p_minutes)),
    'result', jsonb_build_object('completed', p_status = 'completed', 'score', p_score, 'correctCount', p_correct,
      'totalCount', p_total, 'durationMs', p_minutes * 60000,
      'metrics', case when p_level is null then '{}'::jsonb else jsonb_build_object('level', p_level) end)))
$$;
create function pg_temp.at(p_day date, p_hour int) returns timestamptz language sql as $$
  select (p_day + make_time(p_hour, 0, 0)) at time zone 'Asia/Dubai'
$$;

do $$
declare
  alice uuid := '00000000-0000-4000-a000-0000000000a1';
  bob   uuid := '00000000-0000-4000-a000-0000000000b1';
  leo uuid; mia uuid; sam uuid; acc_a uuid; acc_b uuid; today date; wk date; r jsonb; o jsonb; x jsonb;
  n int; m0 numeric; c0 int; w numeric; expect numeric; sk uuid; req jsonb; mon timestamptz;
begin
  select id, account_id into leo, acc_a from child_profiles where nickname = 'Leo';
  select id into mia from child_profiles where nickname = 'Mia';
  select id, account_id into sam, acc_b from child_profiles where nickname = 'Sam';
  today := private.local_date(acc_a, now());
  wk := date_trunc('week', today)::date;

  -- 1. reports add up exactly. Leo, last week (a full past week): known sessions.
  perform pg_temp.play(alice, leo, 'memory-match', pg_temp.at(wk - 7, 9), 10, 80, 8, 10, 'easy');
  perform pg_temp.play(alice, leo, 'memory-match', pg_temp.at(wk - 7, 10), 6, 100, 10, 10, 'medium');
  perform pg_temp.play(alice, leo, 'letters-check', pg_temp.at(wk - 6, 9), 4, 50, 1, 2);
  perform pg_temp.play(alice, leo, 'pip-meets-a-snail', pg_temp.at(wk - 3, 18), 1);
  perform pg_temp.play(alice, leo, 'number-fun', pg_temp.at(wk - 3, 19), 3, null, null, null, null, 'abandoned');
  perform pg_temp.play(alice, leo, 'sort-it-out', pg_temp.at(wk - 14, 9), 5, 90);   -- the week before

  r := private.progress_report(alice, leo, 'week', wk - 7);
  if r->>'from' <> (wk - 7)::text or r->>'to' <> (wk - 1)::text then raise exception 'D1 FAIL: week window %', r->>'from'; end if;
  x := r->'totals';
  if (x->>'seconds')::int <> (10 + 6 + 4 + 1 + 3) * 60 or (x->>'sessions')::int <> 5 or (x->>'completed')::int <> 4
     or (x->>'activities')::int <> 3 or (x->>'learningDays')::int <> 3 then
    raise exception 'D1 FAIL: totals %', x;
  end if;
  if (select sum((d->>'seconds')::int) from jsonb_array_elements(r->'daily') d) <> (x->>'seconds')::int
     or jsonb_array_length(r->'daily') <> 7 then raise exception 'D1 FAIL: daily series'; end if;
  if (r->'previous'->>'seconds')::int <> 300 or (r->'previous'->>'completed')::int <> 1 then
    raise exception 'D1 FAIL: previous window %', r->'previous';
  end if;
  select d into x from jsonb_array_elements(r->'games') d where d->>'slug' = 'memory-match';
  if (x->>'plays')::int <> 2 or (x->>'avgScore')::numeric <> 90 or (x->>'bestScore')::numeric <> 100
     or (x->>'accuracy')::numeric <> 90 or x->'levels' <> '["easy", "medium"]'::jsonb then
    raise exception 'D1 FAIL: game stats %', x;
  end if;
  select d into x from jsonb_array_elements(r->'byType') d where d->>'type' = 'game';
  if (x->>'started')::int <> 3 or (x->>'completed')::int <> 2 then raise exception 'D1 FAIL: completion by type %', x; end if;
  select d into x from jsonb_array_elements(r->'quizzes') d where d->>'slug' = 'letters-check';
  if (x->>'attempts')::int <> 1 or (x->>'lastScore')::numeric <> 50 then raise exception 'D1 FAIL: quiz %', x; end if;
  if (r->>'scoredSessions')::int <> 3 then raise exception 'D1 FAIL: scored sessions %', r->>'scoredSessions'; end if;
  if jsonb_array_length(r->'consistency') <> 8 or (r->'consistency'->7->>'learningDays')::int <> 3 then
    raise exception 'D1 FAIL: consistency %', r->'consistency';
  end if;
  if jsonb_array_length(r->'recent') <> 5 then raise exception 'D1 FAIL: recent'; end if;
  -- day and month windows
  r := private.progress_report(alice, leo, 'day', wk - 3);
  if (r->'totals'->>'seconds')::int <> 240 or (r->'totals'->>'completed')::int <> 1 then raise exception 'D1 FAIL: day %', r->'totals'; end if;
  r := private.progress_report(alice, leo, 'month', today);
  if r->>'from' <> date_trunc('month', today)::date::text
     or jsonb_array_length(r->'daily') <> extract(day from (date_trunc('month', today) + interval '1 month - 1 day'))::int then
    raise exception 'D1 FAIL: month window';
  end if;
  begin perform private.progress_report(alice, leo, 'year', today); raise exception 'D1 FAIL: bad period';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.progress_report(bob, leo, 'week', today); raise exception 'D1 FAIL: another family''s report';
  exception when sqlstate 'KL404' then null; end;
  raise notice 'D1 ok: reports add up (time, sessions, completion, subjects, games, quizzes, daily, previous, windows)';

  -- 2. skill mastery (09 §9.3): first evidence moves halfway towards the score, weighted
  select ak.skill_id, ak.weight into sk, w from activity_skills ak join activities a on a.id = ak.activity_id
   where a.slug = 'shape-homes' order by ak.is_primary desc limit 1;
  select coalesce((select mastery from skill_mastery where child_id = leo and skill_id = sk), 0),
         coalesce((select evidence_count from skill_mastery where child_id = leo and skill_id = sk), 0) into m0, c0;
  perform pg_temp.play(alice, leo, 'shape-homes', now() - interval '30 minutes', 3, 60);
  expect := m0 + greatest(0.1, 1.0 / (c0 + 2)) * w * (0.6 - m0);
  if abs((select mastery from skill_mastery where child_id = leo and skill_id = sk) - expect) > 0.001
     or (select evidence_count from skill_mastery where child_id = leo and skill_id = sk) <> c0 + 1 then
    raise exception 'D1 FAIL: mastery % expected %', (select mastery from skill_mastery where child_id = leo and skill_id = sk), expect;
  end if;
  -- the same activity again the same day counts half
  select mastery, evidence_count into m0, c0 from skill_mastery where child_id = leo and skill_id = sk;
  perform pg_temp.play(alice, leo, 'shape-homes', now() - interval '20 minutes', 3, 100);
  expect := m0 + greatest(0.1, 1.0 / (c0 + 2)) * 0.5 * w * (1 - m0);
  if abs((select mastery from skill_mastery where child_id = leo and skill_id = sk) - expect) > 0.001 then
    raise exception 'D1 FAIL: repeat mastery';
  end if;
  raise notice 'D1 ok: skill mastery follows the §9.3 model (weight, learning rate, same-day repeat)';

  -- 3. the dashboard: each household sees its own children, with numbers that match the tables
  o := private.family_overview(alice);
  if jsonb_array_length(o->'children') <> 2 then raise exception 'D1 FAIL: Alice''s children'; end if;
  select c into x from jsonb_array_elements(o->'children') c where (c->>'childId')::uuid = leo;
  if (x->>'secondsTotal')::int <> (select sum(seconds_played) from daily_progress where child_id = leo)
     or (x->>'gamesCompleted')::int <> (select count(*) from activity_sessions s join activities a on a.id = s.activity_id
                                         where s.child_id = leo and s.status = 'completed' and a.type = 'game')
     or (x->'rewards'->>'balance')::int <> (select sum(amount) from star_transactions where child_id = leo)
     or jsonb_array_length(x->'recent') <> 5 then
    raise exception 'D1 FAIL: Leo''s card %', x - 'recent';
  end if;
  select c into x from jsonb_array_elements(o->'children') c where (c->>'childId')::uuid = mia;
  if (x->>'lessonsCompleted')::int <> 1 then raise exception 'D1 FAIL: Mia''s lessons'; end if;
  o := private.family_overview(bob);
  if jsonb_array_length(o->'children') <> 1 or (o->'children'->0->>'childId')::uuid <> sam then
    raise exception 'D1 FAIL: Bob''s overview';
  end if;
  raise notice 'D1 ok: family overview per household, numbers match the source tables';

  -- 4. notifications: goal reached (once), preferences, read
  if exists (select 1 from notifications where account_id = acc_a and type = 'goal_reached' and params->>'childId' = leo::text) then
    raise exception 'D1 FAIL: goal notice before any goal was reached';
  end if;
  perform pg_temp.play(alice, leo, 'memory-match', now() - interval '18 minutes', 2);
  perform pg_temp.play(alice, leo, 'picture-match', now() - interval '16 minutes', 2);  -- 3rd different today
  perform pg_temp.play(alice, leo, 'word-builder', now() - interval '14 minutes', 2);   -- a 4th: no new notice
  select count(*) into n from notifications where account_id = acc_a and type = 'goal_reached'
   and params->>'childId' = leo::text and params->>'period' = 'day';
  if n <> 1 then raise exception 'D1 FAIL: % goal notices for Leo''s day (expected 1)', n; end if;
  if (select count(*) from notifications n2 join parent_profiles pp on pp.user_id = n2.user_id
      where n2.type = 'goal_reached' and pp.account_id <> acc_a) > 0 then
    raise exception 'D1 FAIL: another household got Leo''s goal notice';
  end if;
  perform private.set_notification_preferences(alice, '[{"type":"goal_reached","channel":"in_app","enabled":false}]');
  perform private.set_learning_goals(alice, mia, '{"dailyActivities": 4}');
  perform pg_temp.play(alice, mia, 'word-builder', now() - interval '10 minutes', 2);  -- Mia's 4th today
  if exists (select 1 from notifications where account_id = acc_a and type = 'goal_reached'
             and params->>'childId' = mia::text and dedupe_key like '%:' || today) then
    raise exception 'D1 FAIL: notice sent although switched off';
  end if;
  begin perform private.set_notification_preferences(alice, '[{"type":"lottery","channel":"in_app","enabled":true}]');
        raise exception 'D1 FAIL: unknown type accepted';
  exception when sqlstate 'KL400' then null; end;
  n := private.mark_notifications_read(alice, null);
  if n = 0 or exists (select 1 from notifications where user_id = alice and read_at is null) then raise exception 'D1 FAIL: read'; end if;

  -- weekly summary on the household's Monday, once; not for a parent who switched it off
  mon := ((date_trunc('week', today) + interval '7 days')::date + time '08:00') at time zone 'Asia/Dubai';
  perform private.set_notification_preferences(bob, '[{"type":"weekly_progress","channel":"in_app","enabled":false}]');
  n := private.queue_due_notifications(mon);
  if not exists (select 1 from notifications where user_id = alice and type = 'weekly_progress'
                 and (params->>'weekStart')::date = date_trunc('week', today)::date
                 and jsonb_array_length(params->'children') = 2) then
    raise exception 'D1 FAIL: weekly summary';
  end if;
  if exists (select 1 from notifications where user_id = bob and type = 'weekly_progress') then
    raise exception 'D1 FAIL: weekly summary despite preference';
  end if;
  perform private.queue_due_notifications(mon + interval '1 hour');
  if (select count(*) from notifications where user_id = alice and type = 'weekly_progress') <> 1 then
    raise exception 'D1 FAIL: weekly summary twice';
  end if;

  -- subscription events (written by the billing service) and a trial ending
  update subscriptions set status = 'billing_retry' where account_id = acc_a;
  if not exists (select 1 from notifications where user_id = alice and type = 'billing_issue') then
    raise exception 'D1 FAIL: billing notice';
  end if;
  update subscriptions set status = 'trialing', current_period_end = now() + interval '1 day' where account_id = acc_a;
  perform private.queue_due_notifications(now());
  if not exists (select 1 from notifications where user_id = alice and type = 'trial_ending') then
    raise exception 'D1 FAIL: trial notice';
  end if;
  raise notice 'D1 ok: notices for goals, weekly summaries, billing and trials; preferences respected; no duplicates';

  -- 5. export: one child's data only; the account's; rate limit; household only
  req := private.request_export(alice, leo);
  x := private.export_payload((req->>'requestId')::uuid);
  if x->>'scope' <> 'child' or jsonb_array_length(x->'children') <> 1 or x->'children'->0->'profile'->>'nickname' <> 'Leo'
     or x->'account' <> 'null'::jsonb or jsonb_array_length(x->'children'->0->'sessions') = 0 then
    raise exception 'D1 FAIL: child export %', x->'scope';
  end if;
  if position('Mia' in x::text) > 0 then raise exception 'D1 FAIL: another child in Leo''s export'; end if;
  begin perform private.export_file(alice, (req->>'requestId')::uuid); raise exception 'D1 FAIL: file before ready';
  exception when sqlstate 'KL409' then null; end;
  perform private.finish_export((req->>'requestId')::uuid, acc_a || '/x.json', true);
  if (private.export_file(alice, (req->>'requestId')::uuid))->>'path' <> acc_a || '/x.json' then raise exception 'D1 FAIL: file'; end if;
  if not exists (select 1 from notifications where user_id = alice and type = 'export_ready') then raise exception 'D1 FAIL: export notice'; end if;
  begin perform private.export_file(bob, (req->>'requestId')::uuid); raise exception 'D1 FAIL: Bob got Alice''s export';
  exception when sqlstate 'KL404' then null; end;
  begin perform private.request_export(bob, leo); raise exception 'D1 FAIL: Bob exported Leo';
  exception when sqlstate 'KL404' then null; end;
  req := private.request_export(alice, null);
  x := private.export_payload((req->>'requestId')::uuid);
  if x->>'scope' <> 'account' or jsonb_array_length(x->'children') <> 2 or jsonb_array_length(x->'account'->'consents') = 0 then
    raise exception 'D1 FAIL: account export';
  end if;
  perform private.request_export(alice, null); perform private.request_export(alice, null); perform private.request_export(alice, null);
  begin perform private.request_export(alice, null); raise exception 'D1 FAIL: no export limit';
  exception when sqlstate 'KL429' then null; end;
  raise notice 'D1 ok: exports hold one child or the account, household only, limited to 5 a day';

  -- 6. account deletion: scheduled with a notice, cancellable
  x := private.schedule_account_deletion(bob);
  if not exists (select 1 from notifications where user_id = bob and type = 'deletion_scheduled') then
    raise exception 'D1 FAIL: deletion notice';
  end if;
  perform private.cancel_account_deletion(bob, (x->>'deletionRequestId')::uuid);
  if (select status from deletion_requests where id = (x->>'deletionRequestId')::uuid) <> 'cancelled' then
    raise exception 'D1 FAIL: cancel';
  end if;
  raise notice 'D1 ok: account deletion scheduled (7 days, notice) and cancelled';
end $$;

-- 7. clients: own notifications and requests only; no writes; functions are service-only
\set bob '00000000-0000-4000-a000-0000000000b1'
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'bob', 'role', 'authenticated', 'aal', 'aal1')::text, true),
       set_config('request.jwt.claim.sub', :'bob', true) \g /dev/null
do $$
begin
  if exists (select 1 from notifications where user_id <> auth.uid()) then raise exception 'D1 FAIL: Bob reads others'' notices'; end if;
  if not exists (select 1 from notifications) then raise exception 'D1 FAIL: Bob can''t read his notices'; end if;
  if exists (select 1 from data_export_requests where account_id <> (select account_id from parent_profiles where user_id = auth.uid())) then
    raise exception 'D1 FAIL: Bob reads others'' exports';
  end if;
  if exists (select 1 from skill_mastery m join child_profiles c on c.id = m.child_id) and
     exists (select 1 from skill_mastery m where m.child_id not in (select id from child_profiles)) then
    raise exception 'D1 FAIL: mastery of an invisible child';
  end if;
  begin update notifications set read_at = now(); raise exception 'D1 FAIL: client updated notices';
  exception when insufficient_privilege then null; end;
  begin insert into data_export_requests (account_id) select account_id from parent_profiles where user_id = auth.uid();
        raise exception 'D1 FAIL: client created an export';
  exception when insufficient_privilege then null; end;
  begin insert into notification_preferences (user_id, type, channel, enabled) values (auth.uid(), 'weekly_progress', 'email', true);
        raise exception 'D1 FAIL: client wrote preferences';
  exception when insufficient_privilege then null; end;
  begin perform private.progress_report(auth.uid(), gen_random_uuid(), 'week', null); raise exception 'D1 FAIL: client ran a report';
  exception when insufficient_privilege then null; end;
  begin perform private.family_overview(auth.uid()); raise exception 'D1 FAIL: client ran the overview';
  exception when insufficient_privilege then null; end;
  begin perform private.queue_due_notifications(now()); raise exception 'D1 FAIL: client ran the job';
  exception when insufficient_privilege then null; end;
  raise notice 'D1 ok: parents read only their own notices and requests; writes and functions are server-only';
end $$;
reset role;
rollback;
