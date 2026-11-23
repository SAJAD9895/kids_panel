-- =============================================================================
-- Security: cross-family probes by id, privilege escalation, suspended admins, review bypass.
-- =============================================================================
\set ON_ERROR_STOP on
begin;
\set alice '00000000-0000-4000-a000-0000000000a1'
\set bob   '00000000-0000-4000-a000-0000000000b1'
\set editor '00000000-0000-4000-a000-0000000000e1'
\set publisher '00000000-0000-4000-a000-0000000000e2'
\set support '00000000-0000-4000-a000-0000000000e3'
\set root  '00000000-0000-4000-a000-0000000000e4'

-- ids known only to the superuser, handed to the probes (an attacker who guessed them)
create temp table probe as
select (select id from child_profiles where nickname = 'Mia') mia,
       (select id from child_profiles where nickname = 'Sam') sam,
       (select account_id from child_profiles where nickname = 'Mia') alice_acc,
       (select id from activity_sessions limit 1) mia_session;
grant select on probe to authenticated, anon;

-- S1 Bob probes Alice's data by id; Alice probes Bob's
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'bob', 'role', 'authenticated', 'aal', 'aal2')::text, true),
       set_config('request.jwt.claim.sub', :'bob', true) \g /dev/null
do $$
declare p probe;
begin
  select * into p from probe;
  if exists (select 1 from child_profiles where id = p.mia) then raise exception 'S1 FAIL: Bob reads Mia by id'; end if;
  if exists (select 1 from activity_sessions where child_id = p.mia) then raise exception 'S1 FAIL: sessions'; end if;
  if exists (select 1 from activity_results where session_id = p.mia_session) then raise exception 'S1 FAIL: results'; end if;
  if exists (select 1 from skill_mastery where child_id = p.mia) or exists (select 1 from star_awards where child_id = p.mia)
     or exists (select 1 from course_enrollments where child_id = p.mia) or exists (select 1 from favorites where child_id = p.mia) then
    raise exception 'S1 FAIL: progress'; end if;
  if exists (select 1 from parent_accounts where id = p.alice_acc) or exists (select 1 from subscriptions where account_id = p.alice_acc)
     or exists (select 1 from entitlements where account_id = p.alice_acc) or exists (select 1 from parental_consents where account_id = p.alice_acc) then
    raise exception 'S1 FAIL: account / billing / consent'; end if;
  -- aal2 doesn't make a parent an admin
  if exists (select 1 from audit_logs) then raise exception 'S1 FAIL: parent with aal2 reads audit'; end if;
end $$;
select set_config('request.jwt.claims', json_build_object('sub', :'alice', 'role', 'authenticated', 'aal', 'aal1')::text, true),
       set_config('request.jwt.claim.sub', :'alice', true) \g /dev/null
do $$
declare p probe;
begin
  select * into p from probe;
  if exists (select 1 from child_profiles where id = p.sam) or exists (select 1 from screen_time_rules where child_id = p.sam) then
    raise exception 'S1 FAIL: Alice reads Sam'; end if;
  raise notice 'S1 ok: id probes across families return nothing (both directions, incl. aal2)';
end $$;

-- S2 escalation attempts
do $$
begin
  begin insert into admin_users (user_id) values ('00000000-0000-4000-a000-0000000000a1');
        raise exception 'S2 FAIL: parent made themselves an admin user';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'root', 'role', 'authenticated', 'aal', 'aal2')::text, true),
       set_config('request.jwt.claim.sub', :'root', true) \g /dev/null
do $$
begin
  begin insert into admin_role_permissions (role_key, permission_key) values ('content_editor', 'admin.manage');
        raise exception 'S2 FAIL: role permissions editable at runtime';
  exception when insufficient_privilege then null; end;
  begin insert into admin_permissions (key, description) values ('x.y', 'x');
        raise exception 'S2 FAIL: permissions editable at runtime';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims', json_build_object('sub', :'editor', 'role', 'authenticated', 'aal', 'aal2')::text, true),
       set_config('request.jwt.claim.sub', :'editor', true) \g /dev/null
do $$
begin
  begin insert into admin_user_roles (user_id, role_key) values ('00000000-0000-4000-a000-0000000000e1', 'content_publisher');
        raise exception 'S2 FAIL: editor escalated to publisher';
  exception when insufficient_privilege then null; end;
  begin update admin_users set status = 'active' where user_id = '00000000-0000-4000-a000-0000000000e3';
        if found then raise exception 'S2 FAIL: editor changed another admin'; end if;
  exception when insufficient_privilege then null; end;
  begin update subscription_plans set max_children = 10;
        if found then raise exception 'S2 FAIL: editor changed plans'; end if;
  exception when insufficient_privilege then null; end;
  raise notice 'S2 ok: no path from parent → admin, editor → publisher, or runtime permission edits';
end $$;

-- S3 a suspended admin loses every permission, even with MFA
reset role;
update admin_users set status = 'suspended' where user_id = :'support';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'support', 'role', 'authenticated', 'aal', 'aal2')::text, true),
       set_config('request.jwt.claim.sub', :'support', true) \g /dev/null
do $$ begin
  if exists (select 1 from child_profiles) then raise exception 'S3 FAIL: suspended support agent reads families'; end if;
end $$;
select set_config('request.jwt.claims', json_build_object('sub', :'support', 'role', 'authenticated', 'aal', 'aal1')::text, true) \g /dev/null
reset role;
update admin_users set status = 'active' where user_id = :'support';
set local role authenticated;
do $$ begin
  if exists (select 1 from child_profiles) then raise exception 'S3 FAIL: support agent without MFA reads families'; end if;
  raise notice 'S3 ok: suspended or non-MFA admins see nothing';
end $$;

-- S4 review bypass: an editor must not change what children see without a publisher
select set_config('request.jwt.claims', json_build_object('sub', :'editor', 'role', 'authenticated', 'aal', 'aal2')::text, true),
       set_config('request.jwt.claim.sub', :'editor', true) \g /dev/null
do $$
declare live uuid := (select id from activities where slug = 'shape-homes');
begin
  begin update activities set title = '{"en":"Rude words"}' where id = live;
        raise exception 'S4 FAIL: editor changed a PUBLISHED activity live';
  exception when insufficient_privilege then null; end;
  begin update activities set status = 'retired' where id = live;
        raise exception 'S4 FAIL: editor retired a published activity';
  exception when insufficient_privilege then null; end;
  begin update games set config = '{"evil":true}' where activity_id = live;
        raise exception 'S4 FAIL: editor changed a published game config';
  exception when insufficient_privilege then null; end;
  begin update answers set is_correct = not is_correct
          where question_id in (select q.id from questions q join activities a on a.id = q.activity_id where a.slug = 'letters-check');
        raise exception 'S4 FAIL: editor changed answers of a published quiz';
  exception when insufficient_privilege then null; end;
  begin delete from lesson_steps where lesson_id in (select id from lessons);
        raise exception 'S4 FAIL: editor removed steps from a published course';
  exception when insufficient_privilege then null; end;
  begin insert into collection_items (collection_id, activity_id, position)
          values ((select id from collections where slug = 'games-for-today'), (select id from activities where slug = 'draft-new-game'), 9);
        raise exception 'S4 FAIL: editor added an item to a live row';
  exception when insufficient_privilege then null; end;
  -- drafts stay freely editable
  update activities set title = '{"en":"Still a draft"}' where slug = 'draft-new-game';
  update games set config = '{"rounds":3}' where activity_id = (select id from activities where slug = 'draft-new-game');
  if not found then raise exception 'S4 FAIL: editor cannot edit a draft'; end if;
end $$;
select set_config('request.jwt.claims', json_build_object('sub', :'publisher', 'role', 'authenticated', 'aal', 'aal2')::text, true),
       set_config('request.jwt.claim.sub', :'publisher', true) \g /dev/null
do $$ begin
  update activities set title = '{"en":"Shape homes!"}' where slug = 'shape-homes';
  update games set config = '{"rounds":4}' where activity_id = (select id from activities where slug = 'shape-homes');
  if not found then raise exception 'S4 FAIL: publisher cannot edit published content'; end if;
  raise notice 'S4 ok: published content changes only with content.publish; drafts editable by editors';
end $$;

reset role;
rollback;
