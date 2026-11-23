-- =============================================================================
-- X1 Admin CMS (migration 20261123000100): publishing workflow (graph, permissions, validation,
-- four-eyes), live-content lock, MFA requirement, settings, account suspension, audited star
-- grants, admin roles (no self-grant, last super admin), lesson prerequisites, schema exposure.
-- Seed admins: editor e1 (content_editor), publisher e2 (content_publisher), support e3, root e4.
-- Runs in one transaction and ROLLS BACK.
-- =============================================================================
\set ON_ERROR_STOP on
begin;

-- Act as [p_user] (authenticated, with that MFA level) until pg_temp.owner().
create function pg_temp.act(p_user uuid, p_aal text default 'aal2') returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
create function pg_temp.owner() returns void language plpgsql as $$
begin
  perform set_config('role', 'none', true);
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
end $$;
-- The KL error code a statement raises ('' if none).
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare d text;
begin
  execute p_sql;
  return '';
exception when others then
  get stacked diagnostics d = pg_exception_detail;
  return sqlstate || ' ' || sqlerrm || ' ' || coalesce(d, '');
end $$;
grant execute on all functions in schema pg_temp to authenticated;

do $$
declare
  editor uuid := '00000000-0000-4000-a000-0000000000e1';
  pub    uuid := '00000000-0000-4000-a000-0000000000e2';
  sup    uuid := '00000000-0000-4000-a000-0000000000e3';
  root   uuid := '00000000-0000-4000-a000-0000000000e4';
  alice  uuid := '00000000-0000-4000-a000-0000000000a1';
  game uuid; tmpl uuid; subj uuid; r jsonb; e text; acc uuid; leo uuid; mia uuid; act uuid;
  c uuid; m uuid; l1 uuid; l2 uuid; other_lesson uuid; req uuid := gen_random_uuid(); bal int;
begin
  select id into subj from subjects where key = 'numbers';
  select id into tmpl from game_templates where key = 'learning_engine' order by version desc limit 1;

  -- 1. an editor drafts a game (direct writes under RLS)
  perform pg_temp.act(editor);
  insert into activities (slug, type, title, subject_id, age_min_months, age_max_months, difficulty)
    values ('x1-ducks', 'game', '{"en":"Ducks"}', subj, 36, 72, 1) returning id into game;
  insert into games (activity_id, template_id, config) values (game, tmpl, '{"items":[]}');

  -- 2. validation: an empty game can't be approved
  r := admin_api.validate('activities', game);
  if not r ? 'The game has no items yet' then raise exception 'X1 FAIL: validate %', r; end if;
  perform admin_api.transition('activities', game, 'in_review');
  perform pg_temp.owner(); perform pg_temp.act(pub);
  e := pg_temp.err(format('select admin_api.transition(''activities'', %L, ''approved'')', game));
  if e not like 'KL400%no items%' then raise exception 'X1 FAIL: approving an empty game: %', e; end if;
  -- sending back needs a note
  e := pg_temp.err(format('select admin_api.transition(''activities'', %L, ''draft'')', game));
  if e not like 'KL400%what needs changing%' then raise exception 'X1 FAIL: send back without a note: %', e; end if;
  perform admin_api.transition('activities', game, 'draft', 'Add items please');
  perform pg_temp.owner(); perform pg_temp.act(editor);
  update games set config = '{"items":[{"kind":"number_recognition","count":3}]}' where activity_id = game;
  perform admin_api.transition('activities', game, 'in_review');
  -- 3. the editor can't approve; impossible moves are refused
  e := pg_temp.err(format('select admin_api.transition(''activities'', %L, ''approved'')', game));
  if e not like 'KL403%content.publish%' then raise exception 'X1 FAIL: editor approves: %', e; end if;
  e := pg_temp.err(format('select admin_api.transition(''activities'', %L, ''retired'')', game));
  if e not like 'KL409%' then raise exception 'X1 FAIL: in_review → retired: %', e; end if;

  -- 4. the publisher approves and publishes; approved isn't visible to families, published is
  perform pg_temp.owner(); perform pg_temp.act(pub);
  perform admin_api.transition('activities', game, 'approved');
  perform pg_temp.owner(); perform pg_temp.act(alice);
  if exists (select 1 from activities where id = game) then raise exception 'X1 FAIL: a parent sees an approved activity'; end if;
  perform pg_temp.owner(); perform pg_temp.act(editor);
  -- approved is locked for editors (live-content guard)
  e := pg_temp.err(format('update activities set title = ''{"en":"x"}'' where id = %L', game));
  if e not like '42501%' then raise exception 'X1 FAIL: editor edits approved content: %', e; end if;
  perform pg_temp.owner(); perform pg_temp.act(pub);
  perform admin_api.transition('activities', game, 'published');
  perform pg_temp.owner(); perform pg_temp.act(alice);
  if not exists (select 1 from activities where id = game) then raise exception 'X1 FAIL: published activity not visible'; end if;
  perform pg_temp.owner();
  if (select published_by from activities where id = game) <> pub then raise exception 'X1 FAIL: published_by'; end if;
  if not exists (select 1 from audit_logs where entity_id = game::text and action = 'content.draft'
                 and changes->>'note' = 'Add items please' and actor_user_id = pub) then
    raise exception 'X1 FAIL: the send-back note is audited'; end if;

  -- 5. four-eyes: the last editor can't approve; switchable by setting
  perform pg_temp.act(pub);
  insert into activities (slug, type, title, subject_id, age_min_months, age_max_months, difficulty)
    values ('x1-own', 'game', '{"en":"Own"}', subj, 36, 72, 1) returning id into act;
  insert into games (activity_id, template_id, config) values (act, tmpl, '{"items":[{"kind":"trace","glyph":"a"}]}');
  perform admin_api.transition('activities', act, 'in_review');
  e := pg_temp.err(format('select admin_api.transition(''activities'', %L, ''approved'')', act));
  if e not like 'KL403%someone else%' then raise exception 'X1 FAIL: four-eyes: %', e; end if;
  perform pg_temp.owner(); perform pg_temp.act(root);
  update app_config set value = 'false' where key = 'content.review_required';
  perform pg_temp.owner(); perform pg_temp.act(pub);
  perform admin_api.transition('activities', act, 'approved');

  -- a game-config edit counts as an edit: the publisher who last changed the items can't approve
  perform pg_temp.owner(); perform pg_temp.act(root);
  update app_config set value = 'true' where key = 'content.review_required';
  perform pg_temp.owner(); perform pg_temp.act(editor);
  insert into activities (slug, type, title, subject_id, age_min_months, age_max_months, difficulty)
    values ('x1-cfg', 'game', '{"en":"Cfg"}', subj, 36, 72, 1) returning id into c;
  insert into games (activity_id, template_id, config) values (c, tmpl, '{"items":[{"kind":"trace","glyph":"a"}]}');
  perform admin_api.transition('activities', c, 'in_review');
  perform pg_temp.owner(); perform pg_temp.act(pub);
  update games set config = '{"items":[{"kind":"trace","glyph":"b"}]}' where activity_id = c;
  e := pg_temp.err(format('select admin_api.transition(''activities'', %L, ''approved'')', c));
  if e not like 'KL403%someone else%' then raise exception 'X1 FAIL: four-eyes after a config edit: %', e; end if;
  perform pg_temp.owner();
  if not exists (select 1 from audit_logs where entity_table = 'games' and entity_id = c::text) then
    raise exception 'X1 FAIL: game edits are logged under the activity id'; end if;
  c := null;

  -- 6. without MFA (aal1) an admin is nobody
  perform pg_temp.owner(); perform pg_temp.act(pub, 'aal1');
  e := pg_temp.err(format('select admin_api.transition(''activities'', %L, ''published'')', act));
  if e not like 'KL403%' then raise exception 'X1 FAIL: aal1 publishes: %', e; end if;
  e := pg_temp.err('select admin_api.dashboard()');
  if e not like 'KL403%' then raise exception 'X1 FAIL: aal1 dashboard: %', e; end if;

  -- 7. settings: validated, admin.manage only, used by the rewards engine
  perform pg_temp.owner(); perform pg_temp.act(pub);
  update app_config set value = '7' where key = 'goals.daily_default';
  if (select value from app_config where key = 'goals.daily_default')::int = 7 then raise exception 'X1 FAIL: publisher changed a setting'; end if;
  perform pg_temp.owner(); perform pg_temp.act(root);
  e := pg_temp.err('update app_config set value = ''11'' where key = ''goals.daily_default''');
  if e not like '23514%' then raise exception 'X1 FAIL: out-of-range setting: %', e; end if;
  update app_config set value = '6' where key = 'goals.daily_default';
  perform pg_temp.owner();
  if private.goal_default('daily') <> 6 then raise exception 'X1 FAIL: goal_default'; end if;

  -- 8. suspension: support restricts a family (reason needed); play and media stop
  select account_id into acc from parent_profiles where user_id = alice;
  select id into leo from child_profiles where nickname = 'Leo';
  select id into mia from child_profiles where nickname = 'Mia';
  perform pg_temp.act(sup);
  e := pg_temp.err(format('select admin_api.set_account_status(%L, ''suspended'', '''')', acc));
  if e not like 'KL400%' then raise exception 'X1 FAIL: suspend without reason: %', e; end if;
  perform admin_api.set_account_status(acc, 'suspended', 'Chargeback under review');
  perform pg_temp.owner();
  e := pg_temp.err(format('select private.launch(%L, %L)', alice,
        jsonb_build_object('childId', mia, 'activityId', (select id from activities where slug = 'shape-homes'))));
  if e not like '%ACCOUNT_SUSPENDED%' then raise exception 'X1 FAIL: launch while suspended: %', e; end if;
  e := pg_temp.err(format('select private.apply_session(%L, %L)', alice, jsonb_build_object('session', jsonb_build_object(
        'id', gen_random_uuid(), 'childId', mia, 'activityId', game, 'source', 'feed', 'platform', 'ios',
        'appVersion', '1', 'contentVersion', 1, 'status', 'started', 'startedAt', now()))));
  if e not like '%ACCOUNT_SUSPENDED%' then raise exception 'X1 FAIL: session while suspended: %', e; end if;
  perform pg_temp.act(sup);
  perform admin_api.set_account_status(acc, 'active', 'Resolved');
  perform pg_temp.owner();
  if not exists (select 1 from audit_logs where action = 'account.suspended' and changes->>'reason' = 'Chargeback under review') then
    raise exception 'X1 FAIL: suspension reason audited'; end if;

  -- 9. star grants: bounded, reasoned, idempotent, audited; editors can't
  perform pg_temp.act(sup);
  e := pg_temp.err(format('select admin_api.grant_stars(%L, 21, ''Lost on an old device'', %L)', leo, req));
  if e not like 'KL400%' then raise exception 'X1 FAIL: 21 stars: %', e; end if;
  r := admin_api.grant_stars(leo, 4, 'Lost on an old device', req);
  bal := (r->>'balance')::int;
  r := admin_api.grant_stars(leo, 4, 'Lost on an old device', req);
  if (r->>'granted')::boolean or (r->>'balance')::int <> bal then raise exception 'X1 FAIL: repeated grant %', r; end if;
  perform pg_temp.owner(); perform pg_temp.act(editor);
  e := pg_temp.err(format('select admin_api.grant_stars(%L, 1, ''Lost on an old device'', %L)', leo, gen_random_uuid()));
  if e not like 'KL403%' then raise exception 'X1 FAIL: editor grants stars: %', e; end if;
  e := pg_temp.err(format('insert into star_transactions (child_id, amount, reason, ref_key, local_date) values (%L, 5, ''admin_adjustment'', ''x'', current_date)', leo));
  if e not like '42501%' then raise exception 'X1 FAIL: direct star insert: %', e; end if;
  perform pg_temp.owner();
  if (select count(*) from audit_logs where action = 'stars.grant' and actor_user_id = sup) <> 1
     or (select count(*) from audit_logs where entity_table = 'star_transactions' and action = 'insert'
         and actor_user_id = sup) <> 1 then
    raise exception 'X1 FAIL: star grant audited once'; end if;

  -- 10. admin roles: super admin only, never your own, a super admin always remains
  perform pg_temp.act(pub);
  e := pg_temp.err('select admin_api.set_roles(''support@example.test'', array[''super_admin''])');
  if e not like 'KL403%' then raise exception 'X1 FAIL: publisher grants roles: %', e; end if;
  e := pg_temp.err(format('insert into admin_user_roles (user_id, role_key) values (%L, ''super_admin'')', pub));
  if e = '' then raise exception 'X1 FAIL: self-grant through the table'; end if;
  perform pg_temp.owner(); perform pg_temp.act(root);
  e := pg_temp.err('select admin_api.set_roles(''root@example.test'', array[''content_editor''])');
  if e not like 'KL40%own%' then raise exception 'X1 FAIL: own roles: %', e; end if;
  perform admin_api.set_roles('support@example.test', array['support_agent','finance']);
  perform pg_temp.owner();
  if (select count(*) from admin_user_roles where user_id = sup) <> 2 then raise exception 'X1 FAIL: set_roles'; end if;

  -- 11. lesson prerequisites: same course, not itself
  perform pg_temp.act(editor);
  insert into courses (slug, title, stage, subject_id) values ('x1-course', '{"en":"C"}', 'preschool', subj) returning id into c;
  insert into course_modules (course_id, position, title) values (c, 0, '{"en":"M"}') returning id into m;
  insert into lessons (module_id, position, title) values (m, 0, '{"en":"L1"}') returning id into l1;
  insert into lessons (module_id, position, title) values (m, 1, '{"en":"L2"}') returning id into l2;
  update lessons set prerequisite_lesson_ids = array[l1] where id = l2;
  e := pg_temp.err(format('update lessons set prerequisite_lesson_ids = array[%L::uuid] where id = %L', l1, l1));
  if e = '' then raise exception 'X1 FAIL: a lesson is its own prerequisite'; end if;
  perform pg_temp.owner();
  select l.id into other_lesson from lessons l join course_modules cm on cm.id = l.module_id where cm.course_id <> c limit 1;
  perform pg_temp.act(editor);
  e := pg_temp.err(format('update lessons set prerequisite_lesson_ids = array[%L::uuid] where id = %L', other_lesson, l2));
  if e = '' then raise exception 'X1 FAIL: a prerequisite from another course'; end if;

  -- 12. admin_api is for signed-in users only; parents get nothing from it
  perform pg_temp.owner(); perform pg_temp.act(alice);
  if admin_api.me() is not null then raise exception 'X1 FAIL: a parent is an admin'; end if;
  e := pg_temp.err('select admin_api.families()');
  if e not like 'KL403%' then raise exception 'X1 FAIL: a parent searches families: %', e; end if;
  perform pg_temp.owner();
  if has_schema_privilege('anon', 'admin_api', 'USAGE') then raise exception 'X1 FAIL: anon reaches admin_api'; end if;
  if has_function_privilege('authenticated', 'private.admin_register_media(uuid,jsonb)', 'EXECUTE')
     or has_function_privilege('authenticated', 'private.launch_core(uuid,jsonb)', 'EXECUTE') then
    raise exception 'X1 FAIL: a service-only function is client-callable'; end if;

  raise notice 'X1 ok: workflow, four-eyes, live lock, MFA, settings, suspension, star grants, roles, prerequisites';
end $$;

rollback;
