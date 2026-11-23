\set QUIET on
\pset tuples_only on
-- fixtures (as postgres = migration/service context)
insert into auth.users(id,email) values
 ('00000000-0000-0000-0000-00000000000a','a@x'),('00000000-0000-0000-0000-00000000000b','b@x'),
 ('00000000-0000-0000-0000-0000000000e1','editor@x'),('00000000-0000-0000-0000-0000000000e2','pub@x'),
 ('00000000-0000-0000-0000-0000000000e3','super@x');
insert into parent_accounts(id,owner_user_id,timezone) values
 ('10000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000a','Asia/Dubai'),
 ('10000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-00000000000b','America/Los_Angeles');
insert into parent_profiles(user_id,account_id) values
 ('00000000-0000-0000-0000-00000000000a','10000000-0000-0000-0000-00000000000a'),
 ('00000000-0000-0000-0000-00000000000b','10000000-0000-0000-0000-00000000000b');
insert into child_profiles(id,account_id,nickname,birth_year_month) values
 ('20000000-0000-0000-0000-00000000000a','10000000-0000-0000-0000-00000000000a','Kid A','2021-03-01'),
 ('20000000-0000-0000-0000-00000000000b','10000000-0000-0000-0000-00000000000b','Kid B','2020-07-01');
insert into admin_users(user_id) values ('00000000-0000-0000-0000-0000000000e1'),('00000000-0000-0000-0000-0000000000e2'),('00000000-0000-0000-0000-0000000000e3');
insert into admin_user_roles(user_id,role_key) values ('00000000-0000-0000-0000-0000000000e1','content_editor'),('00000000-0000-0000-0000-0000000000e2','content_publisher'),('00000000-0000-0000-0000-0000000000e3','super_admin');
insert into media_assets(id,bucket,object_path,kind,mime_type,bytes,sha256,access,status) values
 ('30000000-0000-0000-0000-000000000001','public-assets','thumbs/a.webp','image','image/webp',100,repeat('a',64),'public','ready'),
 ('30000000-0000-0000-0000-000000000002','content','packs/a.zip','game_pack','application/zip',100,repeat('b',64),'gated','ready');
insert into game_templates(id,key,version) values ('40000000-0000-0000-0000-000000000001','drag_to_target','1.0.0');
insert into activities(id,slug,type,title,status,published_at) values
 ('50000000-0000-0000-0000-000000000001','g1','game','{"en":"Game 1"}','published',now()),
 ('50000000-0000-0000-0000-000000000002','v1','video','{"en":"Video 1"}','published',now()),
 ('50000000-0000-0000-0000-000000000003','d1','game','{"en":"Draft"}','draft',null);
insert into games(activity_id,template_id,pack_asset_id) values ('50000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000002');
insert into reward_sets(id,key,title) values ('60000000-0000-0000-0000-000000000001','animals','{"en":"Animals"}');
insert into rewards(id,set_id,type,key,title,asset_id,unlock_rule) values
 ('61000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001','sticker','s1','{}','30000000-0000-0000-0000-000000000001',null),
 ('61000000-0000-0000-0000-000000000002',null,'scene','sc1','{}','30000000-0000-0000-0000-000000000001',null),
 ('61000000-0000-0000-0000-000000000003',null,'badge','b1','{}','30000000-0000-0000-0000-000000000001','first_course');
insert into subscription_plans(id,key,billing_interval) values ('70000000-0000-0000-0000-000000000001','plus_monthly','month');
insert into promo_codes(id,code,plan_id,grants_days,max_redemptions) values ('71000000-0000-0000-0000-000000000001','WELCOME01','70000000-0000-0000-0000-000000000001',30,1);

\echo '--- integrity (expect: rejected / absorbed) ---'
do $$ begin insert into games(activity_id,template_id) values ('50000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000001'); raise notice 'FAIL game row on a video accepted'; exception when foreign_key_violation then raise notice 'OK  game subtype on a video activity rejected (%)', sqlerrm; end $$;
do $$ begin insert into child_profiles(account_id,nickname,birth_year_month) values ('10000000-0000-0000-0000-00000000000a','X','2021-03-15'); raise notice 'FAIL full birth date accepted'; exception when check_violation then raise notice 'OK  full birth date rejected (month only)'; end $$;
do $$ begin insert into game_templates(key,version,runtime,supported_platforms) values ('x','1.0.0','unity','{ios,web}'); raise notice 'FAIL unity on web accepted'; exception when check_violation then raise notice 'OK  unity template on web rejected'; end $$;
do $$ begin insert into scene_placements(child_id,scene_id,sticker_id,x,y) values ('20000000-0000-0000-0000-00000000000a','61000000-0000-0000-0000-000000000002','61000000-0000-0000-0000-000000000003',0.5,0.5); raise notice 'FAIL badge placed as sticker'; exception when foreign_key_violation then raise notice 'OK  badge cannot be placed as a sticker'; end $$;
insert into activity_sessions(id,child_id,activity_id,source,platform,app_version,content_version,status,started_at,ended_at,local_date)
 values ('80000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-00000000000a','50000000-0000-0000-0000-000000000001','feed','android','1.0.0',1,'completed',now()-interval '3 min',now(),private.local_date('10000000-0000-0000-0000-00000000000a',now()))
 on conflict (id) do nothing;
insert into activity_sessions(id,child_id,activity_id,source,platform,app_version,content_version,status,started_at,ended_at,local_date)
 values ('80000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-00000000000a','50000000-0000-0000-0000-000000000001','offline','android','1.0.0',1,'completed',now()-interval '3 min',now(),current_date)
 on conflict (id) do nothing;
select '    replayed session rows = '||count(*)||' (expect 1)' from activity_sessions;
insert into star_awards values ('20000000-0000-0000-0000-00000000000a',current_date,'50000000-0000-0000-0000-000000000001','80000000-0000-0000-0000-000000000001') on conflict do nothing;
insert into star_awards values ('20000000-0000-0000-0000-00000000000a',current_date,'50000000-0000-0000-0000-000000000001','80000000-0000-0000-0000-000000000001') on conflict do nothing;
select '    stars for same activity same day = '||count(*)||' (expect 1)' from star_awards;
update promo_codes set redeemed_count = redeemed_count+1 where id='71000000-0000-0000-0000-000000000001' and redeemed_count < max_redemptions;
update promo_codes set redeemed_count = redeemed_count+1 where id='71000000-0000-0000-0000-000000000001' and redeemed_count < max_redemptions;
select '    promo redeemed_count = '||redeemed_count||' (cap 1)' from promo_codes;
select '    local_date Dubai for 2026-11-17 21:30Z = '||private.local_date('10000000-0000-0000-0000-00000000000a','2026-11-17 21:30Z')||' (expect 2026-11-18)';

\echo '--- parent A (authenticated) ---'
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
set request.jwt.claims = '{"role":"authenticated","aal":"aal1"}';
select '    children visible = '||count(*)||' (expect 1: own)' from child_profiles;
select '    sessions visible = '||count(*)||' (expect 1)' from activity_sessions;
select '    activities visible = '||count(*)||' (expect 2 published)' from activities;
select '    audit rows visible = '||count(*)||' (expect 0)' from audit_logs;
do $$ begin insert into activity_sessions(id,child_id,activity_id,source,platform,app_version,content_version,status,started_at,local_date) values (gen_random_uuid(),'20000000-0000-0000-0000-00000000000a','50000000-0000-0000-0000-000000000001','feed','web','1',1,'started',now(),current_date); raise notice 'FAIL client wrote a session directly'; exception when insufficient_privilege then raise notice 'OK  direct client write to sessions blocked (Edge Functions only)'; end $$;
do $$ begin update child_profiles set nickname='hack' where id='20000000-0000-0000-0000-00000000000b'; if found then raise notice 'FAIL'; else raise notice 'OK  update of another family''s child touched 0 rows'; end if; end $$;
do $$ begin insert into audit_logs(actor_type,action,entity_table) values ('parent','x','y'); raise notice 'FAIL client wrote audit log'; exception when insufficient_privilege then raise notice 'OK  client cannot write audit_logs'; end $$;
reset role;

\echo '--- anon ---'
set role anon; set request.jwt.claim.sub = ''; set request.jwt.claims = '{"role":"anon"}';
select '    anon: activities='||(select count(*) from activities)||' children='||(select count(*) from child_profiles)||' gated media='||(select count(*) from media_assets where access='gated')||' (expect 2,0,0)';
reset role;

\echo '--- admin RBAC + MFA ---'
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000e1';
set request.jwt.claims = '{"role":"authenticated","aal":"aal1"}';
do $$ begin insert into activities(slug,type,title) values ('e1','video','{"en":"E"}'); raise notice 'FAIL editor wrote without MFA'; exception when insufficient_privilege then raise notice 'OK  editor without MFA (aal1) cannot write content'; end $$;
set request.jwt.claims = '{"role":"authenticated","aal":"aal2"}';
insert into activities(slug,type,title) values ('e1','video','{"en":"E"}');
select '    editor with MFA created draft: '||count(*) from activities where slug='e1';
do $$ begin update activities set status='published', published_at=now() where slug='e1'; raise notice 'FAIL editor published'; exception when insufficient_privilege then raise notice 'OK  editor cannot publish (needs content.publish)'; end $$;
select '    editor sees drafts: '||count(*)||' (expect 4)' from activities;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000e2';
update activities set status='published', published_at=now() where slug='e1';
select '    publisher published e1: '||status from activities where slug='e1';
select '    publisher sees children = '||count(*)||' (expect 0: no support.read)' from child_profiles;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000e3';
do $$ begin insert into admin_user_roles(user_id,role_key) values ('00000000-0000-0000-0000-0000000000e3','finance'); raise notice 'FAIL self-grant'; exception when insufficient_privilege then raise notice 'OK  super_admin cannot grant roles to self'; end $$;
select '    super_admin reads audit rows = '||(count(*)>0)::text from audit_logs;
reset role;

\echo '--- audit log ---'
update child_profiles set nickname='Renamed' where id='20000000-0000-0000-0000-00000000000a';
select '    child update audit payload = '||changes::text||' (names only, no values)' from audit_logs where entity_table='child_profiles' and action='update';
select '    publish recorded: '||(changes->'after'->>'status') from audit_logs where entity_table='activities' and action='update' order by id desc limit 1;
do $$ begin update audit_logs set action='x'; raise notice 'FAIL audit log edited'; exception when insufficient_privilege then raise notice 'OK  audit log is append-only even for the owner'; end $$;
\echo '--- deletion cascade ---'
delete from parent_accounts where id='10000000-0000-0000-0000-00000000000a';
select '    after account A delete: children='||(select count(*) from child_profiles where account_id='10000000-0000-0000-0000-00000000000a')||' sessions='||(select count(*) from activity_sessions)||' stars='||(select count(*) from star_awards)||' audit rows kept='||(select count(*) from audit_logs);
\echo '--- service role (Edge Function) ---'
set role service_role; set request.jwt.claim.sub = ''; set request.jwt.claims = '{"role":"service_role"}';
insert into activity_sessions(id,child_id,activity_id,source,platform,app_version,content_version,status,started_at,local_date) values ('80000000-0000-0000-0000-000000000009','20000000-0000-0000-0000-00000000000b','50000000-0000-0000-0000-000000000001','feed','web','1',1,'started',now(),current_date);
select '    service role wrote a session for child B: '||count(*) from activity_sessions where id='80000000-0000-0000-0000-000000000009';
reset role;
select '    actor types in audit log: '||string_agg(distinct actor_type, ',') from audit_logs;
