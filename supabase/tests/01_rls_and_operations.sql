-- =============================================================================
-- Kids Learning Platform · database tests (run by scripts/db-verify.sh after the seed)
-- Every check raises an exception on failure, so psql (ON_ERROR_STOP) exits non-zero.
-- Runs in one transaction and ROLLS BACK, so the seeded database is left unchanged.
-- Identities: claims are set the way Supabase's PostgREST sets them for a signed-in user.
-- =============================================================================
\set ON_ERROR_STOP on
begin;

\set alice '00000000-0000-4000-a000-0000000000a1'
\set bob   '00000000-0000-4000-a000-0000000000b1'
\set editor '00000000-0000-4000-a000-0000000000e1'
\set publisher '00000000-0000-4000-a000-0000000000e2'
\set support '00000000-0000-4000-a000-0000000000e3'
\set root  '00000000-0000-4000-a000-0000000000e4'

-- ---------------------------------------------------------------------------
-- T1 structure: RLS everywhere, no client writes on family/child/billing tables,
--    privileged functions not callable by clients, analytics not reachable
-- ---------------------------------------------------------------------------
do $$
declare t record; n int := 0;
  admin_writable text[] := array[
    'avatars','categories','subjects','skills','game_templates','media_assets','activities',
    'activity_categories','activity_skills','activity_media','games','questions','answers',
    'courses','course_modules','lessons','lesson_steps','learning_paths','learning_path_courses',
    'collections','collection_items','reward_sets','rewards','reward_rules',
    'subscription_plans','promo_codes','admin_users','admin_user_roles','feature_flags',
    'app_config'];  -- Phase 14: system settings (RLS: admin.manage)
begin
  for t in select c.relname, c.relrowsecurity,
                  (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname) as pol
           from pg_class c join pg_namespace s on s.oid = c.relnamespace
           where s.nspname = 'public' and c.relkind in ('r','p') loop
    n := n + 1;
    if not t.relrowsecurity then raise exception 'T1 FAIL: RLS off on %', t.relname; end if;
    if t.pol = 0 then raise exception 'T1 FAIL: no policy on %', t.relname; end if;
    if has_table_privilege('anon', 'public.' || t.relname, 'INSERT,UPDATE,DELETE') then
      raise exception 'T1 FAIL: anon can write %', t.relname; end if;
    if not t.relname = any (admin_writable)
       and has_table_privilege('authenticated', 'public.' || t.relname, 'INSERT,UPDATE,DELETE') then
      raise exception 'T1 FAIL: authenticated holds write privilege on %', t.relname; end if;
  end loop;
  if n < 64 then raise exception 'T1 FAIL: expected ≥ 64 tables, found %', n; end if;
  if has_function_privilege('authenticated', 'private.onboard_family(uuid,jsonb)', 'EXECUTE')
     or has_function_privilege('anon', 'private.delete_child(uuid,uuid)', 'EXECUTE')
     or has_function_privilege('authenticated', 'private.execute_account_deletion(uuid)', 'EXECUTE') then
    raise exception 'T1 FAIL: a client role can execute a privileged function'; end if;
  if has_schema_privilege('authenticated', 'analytics', 'USAGE') then
    raise exception 'T1 FAIL: analytics schema reachable by clients'; end if;
  raise notice 'T1 ok: % tables, RLS + policies everywhere, writes and privileged functions locked', n;
end $$;

-- expected per-account row counts, computed as the superuser, for the isolation test
create temp table expect_rows as select 'x'::text t, 0::bigint n limit 0;
do $$
declare t record; bob_acc uuid; c bigint;
begin
  select account_id into bob_acc from parent_profiles where user_id = '00000000-0000-4000-a000-0000000000b1';
  for t in select table_name, column_name from information_schema.columns
           where table_schema = 'public' and column_name in ('child_id','account_id')
             and table_name in (select tablename from pg_tables where schemaname = 'public')
             and table_name not in ('audit_logs') loop
    if t.column_name = 'child_id' then
      execute format('select count(*) from public.%I x where x.child_id in (select id from child_profiles where account_id = %L)', t.table_name, bob_acc) into c;
    else
      execute format('select count(*) from public.%I x where x.account_id = %L', t.table_name, bob_acc) into c;
    end if;
    insert into expect_rows values (t.table_name, c);
  end loop;
end $$;
grant select on expect_rows to authenticated;

-- ---------------------------------------------------------------------------
-- T2 family isolation: Bob sees exactly his own rows in EVERY family / child table
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'bob', 'role', 'authenticated', 'aal', 'aal1')::text, true),
       set_config('request.jwt.claim.sub', :'bob', true) \g /dev/null
do $$
declare e record; got bigint; checked int := 0;
begin
  for e in select * from expect_rows loop
    execute format('select count(*) from public.%I', e.t) into got;
    if got <> e.n then raise exception 'T2 FAIL: Bob sees % rows in % (expected his own %)', got, e.t, e.n; end if;
    checked := checked + 1;
  end loop;
  if (select count(*) from child_profiles) <> 1 then raise exception 'T2 FAIL: Bob child count'; end if;
  if exists (select 1 from child_profiles where nickname in ('Mia','Leo')) then raise exception 'T2 FAIL: Bob sees Alice''s children'; end if;
  raise notice 'T2 ok: Bob sees only his own rows in % family/child tables', checked;
end $$;

-- ---------------------------------------------------------------------------
-- T3 client writes are blocked even on the caller's own data (writes go through Edge Functions)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', json_build_object('sub', :'alice', 'role', 'authenticated', 'aal', 'aal1')::text, true),
       set_config('request.jwt.claim.sub', :'alice', true) \g /dev/null
do $$
declare mia uuid;
begin
  select id into mia from child_profiles where nickname = 'Mia';
  if mia is null or (select count(*) from child_profiles) <> 2 then raise exception 'T3 FAIL: Alice should see 2 children'; end if;
  -- 3 activities today + island 1's 3 steps two days ago (seed §12 and §18)
  if (select count(*) from star_awards) <> 6 then raise exception 'T3 FAIL: Alice should see Mia''s 6 stars'; end if;
  if (select count(*) from star_transactions) = 0 then raise exception 'T3 FAIL: Alice should see Mia''s star history'; end if;
  begin
    insert into star_awards (child_id, local_date, activity_id, session_id)
    values (mia, current_date, (select id from activities limit 1), gen_random_uuid());
    raise exception 'T3 FAIL: client minted a star';
  exception when insufficient_privilege then null; end;
  begin
    update child_profiles set nickname = 'Hacked' where id = mia;
    raise exception 'T3 FAIL: client updated a child directly';
  exception when insufficient_privilege then null; end;
  begin
    insert into parent_accounts (owner_user_id) values ('00000000-0000-4000-a000-0000000000b1');
    raise exception 'T3 FAIL: client created an account with a spoofed owner';
  exception when insufficient_privilege then null; end;
  begin
    insert into admin_user_roles (user_id, role_key) values ('00000000-0000-4000-a000-0000000000a1', 'super_admin');
    raise exception 'T3 FAIL: parent granted themselves an admin role';
  exception when insufficient_privilege then null; end;
  raise notice 'T3 ok: parents read their own data; every direct write is refused';
end $$;

-- ---------------------------------------------------------------------------
-- T4 anonymous: published catalogue only
-- ---------------------------------------------------------------------------
reset role;
-- expected: every published activity, counted by the superuser (independent of seed size)
create temp table t4_expected as select count(*) as n from activities where status = 'published';
grant select on t4_expected to anon;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true), set_config('request.jwt.claim.sub', '', true) \g /dev/null
do $$
begin
  if (select count(*) from activities) <> (select n from t4_expected) then
    raise exception 'T4 FAIL: anon should see % published activities, saw %', (select n from t4_expected), (select count(*) from activities); end if;
  if exists (select 1 from activities where status <> 'published') then raise exception 'T4 FAIL: draft visible'; end if;
  if (select count(*) from child_profiles) + (select count(*) from parent_accounts) + (select count(*) from subscriptions) > 0 then
    raise exception 'T4 FAIL: anon sees family data'; end if;
  if exists (select 1 from media_assets where access = 'gated') then raise exception 'T4 FAIL: gated media visible'; end if;
  if exists (select 1 from admin_roles) or exists (select 1 from audit_logs) then raise exception 'T4 FAIL: admin data visible'; end if;
  raise notice 'T4 ok: anon sees the published catalogue and nothing else';
end $$;

-- ---------------------------------------------------------------------------
-- T5 admin RBAC + MFA
-- ---------------------------------------------------------------------------
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'editor', 'role', 'authenticated', 'aal', 'aal1')::text, true),
       set_config('request.jwt.claim.sub', :'editor', true) \g /dev/null
do $$
begin
  begin
    insert into activities (slug, type, title) values ('t5-no-mfa', 'game', '{"en":"x"}');
    raise exception 'T5 FAIL: editor wrote content without MFA';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims', json_build_object('sub', :'editor', 'role', 'authenticated', 'aal', 'aal2')::text, true) \g /dev/null
do $$
begin
  insert into activities (slug, type, title) values ('t5-draft', 'game', '{"en":"Draft"}');
  begin
    update activities set status = 'published', published_at = now() where slug = 't5-draft';
    raise exception 'T5 FAIL: editor published';
  exception when insufficient_privilege then null; end;
  if (select count(*) from child_profiles) > 0 then raise exception 'T5 FAIL: editor sees children'; end if;
end $$;
select set_config('request.jwt.claims', json_build_object('sub', :'publisher', 'role', 'authenticated', 'aal', 'aal2')::text, true),
       set_config('request.jwt.claim.sub', :'publisher', true) \g /dev/null
update activities set status = 'published', published_at = now() where slug = 't5-draft';
do $$ begin
  if (select status from activities where slug = 't5-draft') <> 'published' then raise exception 'T5 FAIL: publisher could not publish'; end if;
end $$;
select set_config('request.jwt.claims', json_build_object('sub', :'support', 'role', 'authenticated', 'aal', 'aal2')::text, true),
       set_config('request.jwt.claim.sub', :'support', true) \g /dev/null
do $$ begin
  if (select count(*) from child_profiles) <> 3 then raise exception 'T5 FAIL: support_agent should read families (support.read)'; end if;
  begin
    update child_profiles set nickname = 'x';
    raise exception 'T5 FAIL: support wrote child data';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims', json_build_object('sub', :'root', 'role', 'authenticated', 'aal', 'aal2')::text, true),
       set_config('request.jwt.claim.sub', :'root', true) \g /dev/null
do $$ begin
  begin
    insert into admin_user_roles (user_id, role_key) values ('00000000-0000-4000-a000-0000000000e4', 'finance');
    raise exception 'T5 FAIL: super_admin granted a role to self';
  exception when insufficient_privilege then null; end;
  raise notice 'T5 ok: MFA required, editor ≠ publisher, support read-only, no self-grant';
end $$;

-- ---------------------------------------------------------------------------
-- T6 storage: admin-staging uploads only by content.write admins into their own folder
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', json_build_object('sub', :'editor', 'role', 'authenticated', 'aal', 'aal2')::text, true),
       set_config('request.jwt.claim.sub', :'editor', true) \g /dev/null
insert into storage.objects (bucket_id, name) values ('admin-staging', '00000000-0000-4000-a000-0000000000e1/raw/clip.mov');
do $$ begin
  begin
    insert into storage.objects (bucket_id, name) values ('admin-staging', '00000000-0000-4000-a000-0000000000e2/raw/x.mov');
    raise exception 'T6 FAIL: upload into another admin''s folder';
  exception when insufficient_privilege then null; end;
  begin
    insert into storage.objects (bucket_id, name) values ('content', '00000000-0000-4000-a000-0000000000e1/pack.zip');
    raise exception 'T6 FAIL: client wrote to the content bucket';
  exception when insufficient_privilege then null; end;
  if exists (select 1 from storage.objects) then raise exception 'T6 FAIL: client can read/list objects'; end if;
end $$;
select set_config('request.jwt.claims', json_build_object('sub', :'alice', 'role', 'authenticated', 'aal', 'aal1')::text, true),
       set_config('request.jwt.claim.sub', :'alice', true) \g /dev/null
do $$ begin
  begin
    insert into storage.objects (bucket_id, name) values ('admin-staging', '00000000-0000-4000-a000-0000000000a1/x.mov');
    raise exception 'T6 FAIL: parent uploaded to admin-staging';
  exception when insufficient_privilege then null; end;
  raise notice 'T6 ok: storage writes limited to admin-staging, own folder, content.write';
end $$;

-- ---------------------------------------------------------------------------
-- T7 family operations (called as the Edge Functions call them: service connection)
-- ---------------------------------------------------------------------------
reset role;
do $$
declare r jsonb; leo uuid; bob_acc uuid; req uuid; n int;
  ok_consents jsonb := '[{"type":"terms","policyVersion":"2026-11","method":"checkbox"},
                         {"type":"privacy_policy","policyVersion":"2026-11","method":"checkbox"},
                         {"type":"child_data_collection","policyVersion":"2026-11","method":"email_plus"}]';
  u uuid := gen_random_uuid();
begin
  -- idempotent onboarding
  r := private.onboard_family('00000000-0000-4000-a000-0000000000a1', '{}');
  if (r->>'created')::boolean then raise exception 'T7 FAIL: onboarding not idempotent'; end if;

  insert into auth.users (id, email) values (u, 'new@example.test');
  begin perform private.onboard_family(u, jsonb_build_object('timezone','UTC','consents','[]'::jsonb,
          'child', jsonb_build_object('nickname','Kai','birthYearMonth','2021-05')));
        raise exception 'T7 FAIL: onboarding without consent';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.onboard_family(u, jsonb_build_object('timezone','UTC','consents', ok_consents || '[{"type":"third_party_disclosure","policyVersion":"1","method":"checkbox"}]'::jsonb,
          'child', jsonb_build_object('nickname','Kai','birthYearMonth','2021-05')));
        raise exception 'T7 FAIL: third-party disclosure consent accepted';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.onboard_family(u, jsonb_build_object('timezone','UTC','consents', ok_consents,
          'child', jsonb_build_object('nickname','Kai','birthYearMonth','1990-01')));
        raise exception 'T7 FAIL: adult birth date accepted';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.onboard_family(u, jsonb_build_object('timezone','Mars/Base','consents', ok_consents,
          'child', jsonb_build_object('nickname','Kai','birthYearMonth','2021-05')));
        raise exception 'T7 FAIL: bad timezone accepted';
  exception when sqlstate 'KL400' then null; end;
  if exists (select 1 from parent_profiles where user_id = u) then raise exception 'T7 FAIL: failed onboarding left rows'; end if;
  r := private.onboard_family(u, jsonb_build_object('timezone','UTC','consents', ok_consents,
          'child', jsonb_build_object('nickname','Kai','birthYearMonth','2021-05')));
  if not (r->>'created')::boolean or (select count(*) from parental_consents where user_id = u) <> 3 then
    raise exception 'T7 FAIL: onboarding'; end if;

  -- plan limit: Bob is Basic with 1 child
  begin perform private.add_child('00000000-0000-4000-a000-0000000000b1', '{"nickname":"Two","birthYearMonth":"2021-01"}');
        raise exception 'T7 FAIL: Basic family added a second child';
  exception when sqlstate 'KL402' then null; end;

  -- cross-family delete is refused
  select id into leo from child_profiles where nickname = 'Leo';
  begin perform private.delete_child('00000000-0000-4000-a000-0000000000b1', leo);
        raise exception 'T7 FAIL: Bob deleted Alice''s child';
  exception when sqlstate 'KL404' then null; end;

  -- child deletion cascades and keeps the request record
  r := private.delete_child('00000000-0000-4000-a000-0000000000a1', leo);
  if exists (select 1 from child_profiles where id = leo) or exists (select 1 from screen_time_rules where child_id = leo) then
    raise exception 'T7 FAIL: child data left behind'; end if;
  if (select status from deletion_requests where id = (r->>'deletionRequestId')::uuid) <> 'completed' then
    raise exception 'T7 FAIL: child deletion request not kept'; end if;

  -- account deletion: scheduled with grace, not executable early, then complete
  select account_id into bob_acc from parent_profiles where user_id = '00000000-0000-4000-a000-0000000000b1';
  r := private.schedule_account_deletion('00000000-0000-4000-a000-0000000000b1');
  req := (r->>'deletionRequestId')::uuid;
  if (select status from parent_accounts where id = bob_acc) <> 'pending_deletion' then raise exception 'T7 FAIL: status'; end if;
  begin perform private.execute_account_deletion(req);
        raise exception 'T7 FAIL: deletion ran before the grace period';
  exception when sqlstate 'KL409' then null; end;
  update deletion_requests set scheduled_for = now() - interval '1 minute' where id = req;
  r := private.execute_account_deletion(req);
  if r->'authUserIds' <> '["00000000-0000-4000-a000-0000000000b1"]'::jsonb then raise exception 'T7 FAIL: auth ids %', r; end if;
  select count(*) into n from child_profiles where account_id = bob_acc;
  if n > 0 or exists (select 1 from parent_accounts where id = bob_acc) then raise exception 'T7 FAIL: account data left behind'; end if;
  if not exists (select 1 from audit_logs where entity_table = 'parent_accounts' and action = 'delete' and account_id = bob_acc) then
    raise exception 'T7 FAIL: deletion not in the audit log'; end if;
  raise notice 'T7 ok: onboarding (validated, idempotent), plan limit, isolation, child + account deletion';
end $$;

-- ---------------------------------------------------------------------------
-- T8 audit: child data is logged as column names only; the log is append-only
-- ---------------------------------------------------------------------------
do $$
declare j jsonb;
begin
  update child_profiles set nickname = 'Mimi' where nickname = 'Mia';
  select changes into j from audit_logs where entity_table = 'child_profiles' and action = 'update' order by id desc limit 1;
  if j::text like '%Mimi%' or j::text like '%Mia%' then raise exception 'T8 FAIL: child value in audit log: %', j; end if;
  begin
    update audit_logs set action = 'x';
    raise exception 'T8 FAIL: audit log editable';
  exception when insufficient_privilege then null; end;
  raise notice 'T8 ok: audit redacts child values and is append-only';
end $$;

rollback;
