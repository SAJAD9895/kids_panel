-- =============================================================================
-- Kids Learning Platform · seed data for LOCAL DEVELOPMENT AND TESTS ONLY
--
-- Runs after the migrations on `supabase db reset` (local) and on preview branches.
-- NEVER run it against production: it creates sign-in users with known ids.
-- Everything here is fake: no real people, emails use the reserved .test domain,
-- media rows point at placeholder paths (no files are uploaded), and no store or
-- Stripe product ids are set (you add your own test ids, docs/backend/setup-guide.md).
--
-- Test users (sign in locally with the magic-link / OTP flow; Inbucket shows the email):
--   alice@example.test   parent A, Plus, children Mia (4) and Leo (6)
--   bob@example.test     parent B, Basic, child Sam (5)
--   editor@example.test  admin: content_editor
--   publisher@example.test admin: content_publisher
--   support@example.test admin: support_agent
--   root@example.test    admin: super_admin
-- Admin permissions only count in an MFA (aal2) session: enrol TOTP on first admin login.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Auth users (fixed ids so tests can refer to them)
-- ---------------------------------------------------------------------------
insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select id::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', email, now(),
       '{"provider":"email","providers":["email"]}', '{}', now(), now()
from (values
  ('00000000-0000-4000-a000-0000000000a1', 'alice@example.test'),
  ('00000000-0000-4000-a000-0000000000b1', 'bob@example.test'),
  ('00000000-0000-4000-a000-0000000000e1', 'editor@example.test'),
  ('00000000-0000-4000-a000-0000000000e2', 'publisher@example.test'),
  ('00000000-0000-4000-a000-0000000000e3', 'support@example.test'),
  ('00000000-0000-4000-a000-0000000000e4', 'root@example.test')
) as u(id, email)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 2. Admins (roles and permissions are reference data in the migrations)
-- ---------------------------------------------------------------------------
insert into admin_users (user_id) values
  ('00000000-0000-4000-a000-0000000000e1'), ('00000000-0000-4000-a000-0000000000e2'),
  ('00000000-0000-4000-a000-0000000000e3'), ('00000000-0000-4000-a000-0000000000e4');
insert into admin_user_roles (user_id, role_key) values
  ('00000000-0000-4000-a000-0000000000e1', 'content_editor'),
  ('00000000-0000-4000-a000-0000000000e2', 'content_publisher'),
  ('00000000-0000-4000-a000-0000000000e3', 'support_agent'),
  ('00000000-0000-4000-a000-0000000000e4', 'super_admin');

-- ---------------------------------------------------------------------------
-- 3. Media placeholders (registered paths; files are not uploaded by the seed)
-- ---------------------------------------------------------------------------
insert into media_assets (bucket, object_path, kind, mime_type, bytes, sha256, width, height, duration_ms, access, status)
select bucket, path, kind, mime, bytes, encode(extensions.digest(path, 'sha256'), 'hex'), w::int, h::int, dur::int,
       case when bucket = 'public-assets' then 'public' else 'gated' end, 'ready'
from (values
  ('public-assets', 'avatars/buddy-01.webp',            'image',     'image/webp', 12000, 512, 512, null),
  ('public-assets', 'avatars/buddy-02.webp',            'image',     'image/webp', 12000, 512, 512, null),
  ('public-assets', 'avatars/buddy-03.webp',            'image',     'image/webp', 12000, 512, 512, null),
  ('public-assets', 'avatars/buddy-04.webp',            'image',     'image/webp', 12000, 512, 512, null),
  ('public-assets', 'avatars/buddy-05.webp',            'image',     'image/webp', 12000, 512, 512, null),
  ('public-assets', 'avatars/buddy-06.webp',            'image',     'image/webp', 12000, 512, 512, null),
  ('public-assets', 'stickers/garden-01.webp',          'image',     'image/webp',  8000, 256, 256, null),
  ('public-assets', 'stickers/garden-02.webp',          'image',     'image/webp',  8000, 256, 256, null),
  ('public-assets', 'stickers/garden-03.webp',          'image',     'image/webp',  8000, 256, 256, null),
  ('public-assets', 'stickers/garden-04.webp',          'image',     'image/webp',  8000, 256, 256, null),
  ('public-assets', 'scenes/garden.webp',               'image',     'image/webp', 90000, 2048, 1536, null),
  ('public-assets', 'thumbs/placeholder/1/512.webp',    'image',     'image/webp', 30000, 512, 384, null),
  ('content',       'packs/shape-homes/1/pack.zip',     'game_pack', 'application/zip', 4200000, null, null, null)
  -- video, song and story files: §16 (generated from the real development media)
) as m(bucket, path, kind, mime, bytes, w, h, dur);

insert into avatars (key, asset_id, sort)
select 'buddy-0' || n, (select id from media_assets where object_path = 'avatars/buddy-0' || n || '.webp'), n
from generate_series(1, 6) n;

-- ---------------------------------------------------------------------------
-- 4. Taxonomy
-- ---------------------------------------------------------------------------
insert into subjects (key, name, sort) values
  ('letters',  '{"en":"Letters","es":"Letras"}', 1),
  ('numbers',  '{"en":"Numbers","es":"Números"}', 2),
  ('shapes',   '{"en":"Shapes and colours","es":"Formas y colores"}', 3),
  ('science',  '{"en":"Science","es":"Ciencia"}', 4),
  ('nature',   '{"en":"Nature","es":"Naturaleza"}', 5),
  ('music',    '{"en":"Music","es":"Música"}', 6),
  ('art',      '{"en":"Art","es":"Arte"}', 7),
  ('feelings', '{"en":"Feelings","es":"Emociones"}', 8),
  ('health',   '{"en":"Healthy habits","es":"Hábitos sanos"}', 9),
  ('english',  '{"en":"English words","es":"Palabras en inglés"}', 10),
  ('thinking', '{"en":"Thinking","es":"Pensamiento"}', 11),
  ('moving',   '{"en":"Moving","es":"Movimiento"}', 12);

insert into skills (subject_id, key, skill_group, name)
select (select id from subjects where key = s), k, g, n::jsonb from (values
  ('letters',  'letter_recognition', 'literacy_numeracy', '{"en":"Recognising letters"}'),
  ('letters',  'letter_sounds',      'literacy_numeracy', '{"en":"Letter sounds"}'),
  ('letters',  'writing_letters',    'literacy_numeracy', '{"en":"Writing letters"}'),
  ('numbers',  'counting',           'literacy_numeracy', '{"en":"Counting to 20"}'),
  ('numbers',  'comparing',          'literacy_numeracy', '{"en":"More and less"}'),
  ('shapes',   'shape_names',        'thinking',          '{"en":"Naming shapes"}'),
  ('thinking', 'memory',             'thinking',          '{"en":"Memory"}'),
  ('thinking', 'sorting',            'thinking',          '{"en":"Sorting and matching"}'),
  ('english',  'vocabulary',         'language',          '{"en":"New words"}'),
  ('english',  'listening',          'language',          '{"en":"Listening"}'),
  ('feelings', 'naming_feelings',    'social_life',       '{"en":"Naming feelings"}'),
  ('feelings', 'taking_turns',       'social_life',       '{"en":"Taking turns"}'),
  ('moving',   'fine_motor',         'movement',          '{"en":"Small movements"}'),
  ('moving',   'rhythm',             'movement',          '{"en":"Rhythm"}')
) as x(s, k, g, n);

insert into categories (key, name, sort, status) values
  ('animals',  '{"en":"Animals"}', 1, 'published'),
  ('garden',   '{"en":"Garden"}', 2, 'published'),
  ('space',    '{"en":"Space"}', 3, 'published'),
  ('bedtime',  '{"en":"Bedtime"}', 4, 'published');

-- ---------------------------------------------------------------------------
-- 5. Game templates E1–E12 (docs/architecture/08-game-engine.md §8.3)
-- ---------------------------------------------------------------------------
insert into game_templates (key, version, runtime, orientation, supported_platforms, status)
select k, '1.0.0', 'flame', o, array['ios','android','web'], 'active' from (values
  ('drag_to_target','landscape'), ('memory_match','landscape'), ('trace_write','landscape'),
  ('colour_draw','landscape'), ('find_hidden','landscape'), ('quiz','any'),
  ('runner_catcher','landscape'), ('shape_fit','landscape'), ('maze_path','landscape'),
  ('book_reader','landscape'), ('rhythm_pattern','landscape'), ('stacking','portrait')
) as t(k, o);

-- ---------------------------------------------------------------------------
-- 6. Activities (published unless noted)
-- ---------------------------------------------------------------------------
insert into activities (slug, type, title, keywords, subject_id, primary_category_id, thumbnail_asset_id,
                        age_min_months, age_max_months, difficulty, players, estimated_seconds,
                        plus_only, free_eligible, status, published_at)
select slug, type, title::jsonb, kw, (select id from subjects where key = subj),
       (select id from categories where key = cat),
       (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'),
       amin, amax, diff, players, secs, plus, free, status,
       case when status = 'published' then now() - interval '7 days' end
from (values
  ('shape-homes',      'game',      '{"en":"Shape homes"}',          'shapes triangle square', 'shapes',  'garden',  36, 72, 1, 1, 180, false, true,  'published'),
  ('count-the-boats',  'game',      '{"en":"Count the boats"}',      'count numbers boats',    'numbers', null,      36, 84, 2, 1, 180, true,  true,  'published'),
  ('trace-a-to-h',     'game',      '{"en":"Trace a to h"}',         'letters trace abc',      'letters', null,      42, 84, 2, 1, 240, true,  true,  'published'),
  ('find-the-b',       'game',      '{"en":"Find the b"}',           'letters find abc',       'letters', 'garden',  42, 84, 1, 1, 150, true,  true,  'published'),
  ('letters-check',    'quiz',      '{"en":"Letters check-in"}',     'letters check abc',      'letters', null,      42, 84, 1, 1, 120, false, false, 'published'),
  ('race-together',    'game',      '{"en":"Race together"}',        'race together two',      'moving',  null,      48, 96, 1, 2, 240, true,  true,  'published'),
  ('pip-meets-a-snail','video',     '{"en":"Pip meets a snail"}',    'pip snail garden',       'nature',  'garden',  24, 84, 1, 1, 312, false, true,  'published'),
  ('counting-train',   'song',      '{"en":"The counting train"}',   'song counting train',    'music',   null,      24, 84, 1, 1, 151, false, true,  'published'),
  ('the-sleepy-cloud', 'story',     '{"en":"The sleepy cloud"}',     'story bedtime cloud',    'feelings','bedtime', 24, 84, 1, 1, 300, true,  true,  'published'),
  ('draft-new-game',   'game',      '{"en":"New game (draft)"}',     'draft',                  'thinking',null,      36, 84, 1, 1, 180, true,  true,  'draft')
) as a(slug, type, title, kw, subj, cat, amin, amax, diff, players, secs, plus, free, status);

insert into games (activity_id, template_id, config, pack_asset_id, character_pick)
select a.id, (select id from game_templates where key = t and version = '1.0.0'), '{}'::jsonb,
       case when a.slug = 'shape-homes' then (select id from media_assets where object_path = 'packs/shape-homes/1/pack.zip') end,
       a.slug = 'race-together'
from activities a join (values
  ('shape-homes','drag_to_target'), ('count-the-boats','memory_match'), ('trace-a-to-h','trace_write'),
  ('find-the-b','find_hidden'), ('race-together','runner_catcher'), ('draft-new-game','maze_path')
) as g(slug, t) on g.slug = a.slug;

insert into activity_skills (activity_id, skill_id, weight, is_primary)
select (select id from activities where slug = a), (select id from skills where key = s), w, p from (values
  ('shape-homes','shape_names',1.0,true), ('shape-homes','sorting',0.5,false),
  ('count-the-boats','counting',1.0,true), ('trace-a-to-h','writing_letters',1.0,true),
  ('trace-a-to-h','fine_motor',0.5,false), ('find-the-b','letter_recognition',1.0,true),
  ('letters-check','letter_recognition',1.0,true), ('race-together','taking_turns',1.0,true),
  ('pip-meets-a-snail','listening',1.0,true), ('counting-train','counting',0.6,true),
  ('counting-train','rhythm',0.4,false), ('the-sleepy-cloud','naming_feelings',1.0,true)
) as x(a, s, w, p);

-- activity_media for videos, songs and stories: §16 (generated)

-- knowledge check: 3 picture questions, one correct answer each
insert into questions (activity_id, position, type, prompt, skill_id)
select (select id from activities where slug = 'letters-check'), n, 'single_choice',
       jsonb_build_object('en', 'Which one is ' || l || '?'), (select id from skills where key = 'letter_recognition')
from (values (0,'a'), (1,'b'), (2,'c')) as q(n, l);
insert into answers (question_id, position, content, is_correct)
select q.id, x.pos, jsonb_build_object('en', x.letter), x.letter = substr(q.prompt->>'en', 14, 1)
from questions q
cross join lateral (values (0, 'a'), (1, 'b'), (2, 'c')) as x(pos, letter)
where q.activity_id = (select id from activities where slug = 'letters-check');

-- ---------------------------------------------------------------------------
-- 7. Rewards: a sticker set, a scene, badges, an island prize
-- ---------------------------------------------------------------------------
insert into reward_sets (key, title) values ('garden-friends', '{"en":"Garden friends"}');
insert into rewards (set_id, type, key, title, asset_id, rarity, unlock_rule, status)
select case when t = 'sticker' then (select id from reward_sets where key = 'garden-friends') end,
       t, k, title::jsonb, (select id from media_assets where object_path = p), r, rule, 'active'
from (values
  ('sticker','garden-snail',  '{"en":"Snail"}',  'stickers/garden-01.webp','common', null),
  ('sticker','garden-bee',    '{"en":"Bee"}',    'stickers/garden-02.webp','common', null),
  ('sticker','garden-flower', '{"en":"Flower"}', 'stickers/garden-03.webp','common', null),
  ('sticker','garden-rainbow','{"en":"Rainbow"}','stickers/garden-04.webp','rare',   null),
  ('scene',  'scene-garden',  '{"en":"The garden"}','scenes/garden.webp',  'common', null)
  -- badges: §17 (Phase 12)
) as x(t, k, title, p, r, rule);

-- ---------------------------------------------------------------------------
-- 8. A course: "Letters a to h" → 1 module → 3 islands (lessons) → steps
-- ---------------------------------------------------------------------------
insert into courses (slug, kind, title, description, subject_id, primary_skill_id, stage, plus_only, status, published_at)
values ('letters-a-to-h', 'solo', '{"en":"Letters a to h"}', '{"en":"Learn your first 8 letters with Bolt"}',
        (select id from subjects where key = 'letters'), (select id from skills where key = 'letter_recognition'),
        'preschool', false, 'published', now() - interval '7 days');
insert into course_modules (course_id, position, title)
values ((select id from courses where slug = 'letters-a-to-h'), 0, '{"en":"Workbook 1"}');
insert into lessons (module_id, position, title, prize_reward_id)
select (select m.id from course_modules m join courses c on c.id = m.course_id where c.slug = 'letters-a-to-h'),
       n, jsonb_build_object('en', 'Island ' || (n + 1) || ': ' || t),
       case when n = 1 then (select id from rewards where key = 'garden-rainbow') end
from (values (0, 'a b c'), (1, 'd e f'), (2, 'g h')) as l(n, t);
insert into lesson_steps (lesson_id, position, step_type, activity_id)
select (select l.id from lessons l where l.title->>'en' like 'Island ' || (i + 1) || ':%'),
       pos, st, (select id from activities where slug = a)
from (values
  (0,0,'knowledge_check','letters-check'), (0,1,'practice','find-the-b'), (0,2,'trace','trace-a-to-h'),
  (1,0,'intro','pip-meets-a-snail'), (1,1,'song','counting-train'), (1,2,'story','the-sleepy-cloud'),
  (2,0,'practice','find-the-b'), (2,1,'knowledge_check','letters-check')
) as s(i, pos, st, a);

insert into learning_paths (slug, title, stage, age_min_months, age_max_months, status)
values ('preschool-start', '{"en":"Starting school"}', 'preschool', 36, 72, 'published');
insert into learning_path_courses (path_id, course_id, position)
values ((select id from learning_paths where slug = 'preschool-start'), (select id from courses where slug = 'letters-a-to-h'), 0);

-- ---------------------------------------------------------------------------
-- 9. Collections (rows per rail section, docs/design/README.md §2)
-- ---------------------------------------------------------------------------
insert into collections (slug, surface, kind, title, sort, status, category_id)
values ('games-for-today', 'home',   'daily_picks', '{"en":"Games for today"}', 1, 'published', null),
       ('play-together',   'home',   'row',         '{"en":"Play together"}',   2, 'published', null),
       ('garden-world',    'home',   'world',       '{"en":"Pip''s garden"}',    3, 'published', (select id from categories where key = 'garden')),
       ('shows',           'watch',  'row',         '{"en":"Shows"}',           1, 'published', null),
       ('songs',           'listen', 'row',         '{"en":"Songs"}',           1, 'published', null),
       ('bedtime-stories', 'listen', 'row',         '{"en":"Bedtime stories"}', 2, 'published', (select id from categories where key = 'bedtime'));
insert into collection_items (collection_id, activity_id, position)
select (select id from collections where slug = c), (select id from activities where slug = a), p from (values
  ('games-for-today','shape-homes',0), ('games-for-today','count-the-boats',1), ('games-for-today','find-the-b',2),
  ('play-together','race-together',0), ('garden-world','shape-homes',0), ('garden-world','pip-meets-a-snail',1),
  ('shows','pip-meets-a-snail',0), ('songs','counting-train',0), ('bedtime-stories','the-sleepy-cloud',0)
) as x(c, a, p);

-- ---------------------------------------------------------------------------
-- 10. Plans, promo code, feature flags (no real store / Stripe ids)
-- ---------------------------------------------------------------------------
insert into subscription_plans (key, billing_interval, trial_days, max_children) values
  ('plus_monthly', 'month', 7, 4),
  ('plus_annual',  'year',  7, 4);
insert into promo_codes (code, plan_id, grants_days, max_redemptions)
values ('TESTPLUS30', (select id from subscription_plans where key = 'plus_annual'), 30, 5);
insert into feature_flags (key, enabled, description) values
  ('kids.garden',       true,  'Kid-facing garden and badges (design K16–K18, open question Q17)'),
  ('kids.together_row', true,  'Together row on Home (Q16)'),
  ('kids.calm_time',    false, 'Calm time category in Listen (Q18)');

-- ---------------------------------------------------------------------------
-- 11. Families, created through the real onboarding function
-- ---------------------------------------------------------------------------
select private.onboard_family('00000000-0000-4000-a000-0000000000a1', jsonb_build_object(
  'timezone', 'Asia/Dubai', 'country', 'AE', 'uiLocale', 'en', 'contentLocale', 'en',
  'child', jsonb_build_object('nickname', 'Mia', 'birthYearMonth', to_char(now() - interval '4 years 2 months', 'YYYY-MM'),
                              'avatarId', (select id from avatars where key = 'buddy-04')),
  'consents', jsonb_build_array(
     jsonb_build_object('type','terms','policyVersion','2026-11','method','checkbox'),
     jsonb_build_object('type','privacy_policy','policyVersion','2026-11','method','checkbox'),
     jsonb_build_object('type','child_data_collection','policyVersion','2026-11','method','email_plus')),
  'evidence', jsonb_build_object('seed', true)));

select private.onboard_family('00000000-0000-4000-a000-0000000000b1', jsonb_build_object(
  'timezone', 'Europe/London', 'country', 'GB',
  'child', jsonb_build_object('nickname', 'Sam', 'birthYearMonth', to_char(now() - interval '5 years', 'YYYY-MM')),
  'consents', jsonb_build_array(
     jsonb_build_object('type','terms','policyVersion','2026-11','method','checkbox'),
     jsonb_build_object('type','privacy_policy','policyVersion','2026-11','method','checkbox'),
     jsonb_build_object('type','child_data_collection','policyVersion','2026-11','method','email_plus'))));

-- Alice has Plus (a promo subscription, as an admin grant would create), so she can add a second child
insert into subscriptions (account_id, plan_id, provider, provider_subscription_id, environment, status,
                           current_period_start, current_period_end, started_at)
select a.id, (select id from subscription_plans where key = 'plus_annual'), 'promo', 'seed-promo-alice', 'sandbox',
       'active', now() - interval '10 days', now() + interval '355 days', now() - interval '10 days'
from parent_accounts a where a.owner_user_id = '00000000-0000-4000-a000-0000000000a1';
insert into entitlements (account_id, active_until, source_subscription_id)
select s.account_id, s.current_period_end, s.id from subscriptions s where s.provider_subscription_id = 'seed-promo-alice';

select private.add_child('00000000-0000-4000-a000-0000000000a1', jsonb_build_object(
  'nickname', 'Leo', 'birthYearMonth', to_char(now() - interval '6 years 5 months', 'YYYY-MM'),
  'avatarId', (select id from avatars where key = 'buddy-02')));

insert into notification_preferences (user_id, type, channel, enabled) values
  ('00000000-0000-4000-a000-0000000000a1', 'weekly_progress', 'email', true),
  ('00000000-0000-4000-a000-0000000000b1', 'weekly_progress', 'email', true);

-- ---------------------------------------------------------------------------
-- 12. A little play history for Mia (what the progress engine would have written)
-- ---------------------------------------------------------------------------
with mia as (
  select ch.id, ch.account_id from child_profiles ch where ch.nickname = 'Mia'
), s as (
  insert into activity_sessions (id, child_id, activity_id, source, platform, app_version, content_version,
                                 status, started_at, ended_at, local_date)
  select gen_random_uuid(), mia.id, a.id, 'feed', 'ios', '1.0.0', 1, 'completed',
         now() - (x.mins || ' minutes')::interval, now() - (x.mins - 3 || ' minutes')::interval,
         private.local_date(mia.account_id, now() - (x.mins || ' minutes')::interval)
  from mia
  join (values ('shape-homes', 60), ('count-the-boats', 45), ('pip-meets-a-snail', 30)) as x(slug, mins) on true
  join activities a on a.slug = x.slug
  returning id, child_id, activity_id, local_date
), r as (
  insert into activity_results (session_id, completed, score, duration_ms)
  select id, true, 100, 180000 from s returning session_id
)
insert into star_awards (child_id, local_date, activity_id, session_id)
select child_id, local_date, activity_id, id from s;

insert into daily_progress (child_id, local_date, sessions_started, sessions_completed, seconds_played, stars)
select child_id, local_date, count(*), count(*), count(*) * 180, count(*)
from star_awards group by child_id, local_date;

insert into skill_mastery (child_id, skill_id, mastery, evidence_count, last_practiced_at)
select ch.id, sk.id, m, n, now() from child_profiles ch
join (values ('shape_names', 0.55, 3), ('counting', 0.30, 2), ('listening', 0.80, 4)) as x(k, m, n) on true
join skills sk on sk.key = x.k
where ch.nickname = 'Mia';

insert into course_enrollments (child_id, course_id, status, current_step_id)
select ch.id, c.id, 'in_progress',
       (select st.id from lesson_steps st join lessons l on l.id = st.lesson_id
         where l.title->>'en' like 'Island 2:%' and st.position = 0)
from child_profiles ch, courses c where ch.nickname = 'Mia' and c.slug = 'letters-a-to-h';

insert into favorites (child_id, activity_id)
select ch.id, a.id from child_profiles ch, activities a where ch.nickname = 'Mia' and a.slug = 'shape-homes';

-- ---------------------------------------------------------------------------
-- 13. More learning content for development (Phase 8: home + learning navigation).
-- Enough to show every state: several subjects, free and Plus courses, two learning paths,
-- a finished island for Mia, stickers and a badge. Placeholder art; titles are working copy.
-- ---------------------------------------------------------------------------
insert into activities (slug, type, title, description, keywords, subject_id, primary_category_id, thumbnail_asset_id,
                        age_min_months, age_max_months, difficulty, players, estimated_seconds,
                        plus_only, free_eligible, status, published_at)
select slug, type, title::jsonb, descr::jsonb, kw, (select id from subjects where key = subj), null,
       (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'),
       amin, amax, diff, 1, secs, plus, true, 'published', now() - interval '3 days'
from (values
  ('more-or-less',        'game',  '{"en":"More or less?"}',         '{"en":"Which basket has more apples?"}',     'compare more less',   'numbers',  36, 84, 2, 180, true),
  ('number-trace-1-5',    'game',  '{"en":"Number trace 1 to 5"}',   '{"en":"Trace the numbers with your finger"}', 'numbers trace',       'numbers',  42, 84, 1, 200, false),
  ('numbers-on-the-farm', 'video', '{"en":"Numbers on the farm"}',   '{"en":"Count the animals with Pip"}',        'count farm video',    'numbers',  24, 72, 1, 250, false),
  ('ten-little-seeds',    'song',  '{"en":"Ten little seeds"}',      '{"en":"Sing and count to ten"}',             'song counting seeds', 'numbers',  24, 72, 1, 140, false),
  ('shape-sort',          'game',  '{"en":"Shape sort"}',            '{"en":"Put each shape in its box"}',         'shapes sort',         'shapes',   24, 60, 1, 150, false),
  ('colour-the-garden',   'game',  '{"en":"Colour the garden"}',     '{"en":"Paint the flowers any colour you like"}','colour draw garden', 'shapes',   24, 72, 1, 240, true),
  ('why-does-it-rain',    'video', '{"en":"Why does it rain?"}',     '{"en":"Nova follows a raindrop"}',           'rain weather science','science',  36, 96, 2, 280, true),
  ('feelings-song',       'song',  '{"en":"How do you feel?"}',      '{"en":"Happy, sad, cross and calm"}',        'feelings song',       'feelings', 24, 84, 1, 130, false),
  ('calm-breathing',      'story', '{"en":"Bolt takes a breath"}',   '{"en":"A calm story about big feelings"}',   'calm story feelings', 'feelings', 36, 96, 1, 260, true)
) as a(slug, type, title, descr, kw, subj, amin, amax, diff, secs, plus);

insert into games (activity_id, template_id, config, character_pick)
select a.id, (select id from game_templates where key = t and version = '1.0.0'), '{}'::jsonb, false
from activities a join (values
  ('more-or-less','drag_to_target'), ('number-trace-1-5','trace_write'), ('shape-sort','shape_fit'),
  ('colour-the-garden','colour_draw')
) as g(slug, t) on g.slug = a.slug;

insert into activity_skills (activity_id, skill_id, weight, is_primary)
select (select id from activities where slug = a), (select id from skills where key = s), 1, true from (values
  ('more-or-less','comparing'), ('number-trace-1-5','counting'), ('numbers-on-the-farm','counting'),
  ('ten-little-seeds','counting'), ('shape-sort','shape_names'), ('colour-the-garden','fine_motor'),
  ('feelings-song','naming_feelings'), ('calm-breathing','naming_feelings')
) as x(a, s);

-- Courses: a free one for little ones, two Plus ones.
insert into courses (slug, kind, title, description, subject_id, primary_skill_id, stage, plus_only, sort, status, published_at)
select slug, 'solo', title::jsonb, descr::jsonb, (select id from subjects where key = subj),
       (select id from skills where key = skill), stage, plus, sort, 'published', now() - interval '3 days'
from (values
  ('counting-to-10',  '{"en":"Counting to 10"}',  '{"en":"Count boats, seeds and farm animals"}', 'numbers',  'counting',        'preschool', true,  2),
  ('shapes-around-us','{"en":"Shapes around us"}','{"en":"Find circles, squares and triangles"}', 'shapes',   'shape_names',     'toddler',   false, 3),
  ('big-feelings',    '{"en":"Big feelings"}',    '{"en":"Name your feelings and calm down"}',    'feelings', 'naming_feelings', 'kindergarten', true, 4)
) as c(slug, title, descr, subj, skill, stage, plus, sort);

insert into course_modules (course_id, position, title)
select id, 0, '{"en":"Workbook 1"}' from courses where slug in ('counting-to-10', 'shapes-around-us', 'big-feelings');

insert into lessons (module_id, position, title)
select m.id, l.n, jsonb_build_object('en', l.t)
from course_modules m join courses c on c.id = m.course_id
join (values ('counting-to-10', 0, 'Island 1: 1 2 3'), ('counting-to-10', 1, 'Island 2: up to 10'),
             ('shapes-around-us', 0, 'Island 1: circles'), ('shapes-around-us', 1, 'Island 2: squares and triangles'),
             ('big-feelings', 0, 'Island 1: happy and sad')) as l(course, n, t) on l.course = c.slug;

insert into lesson_steps (lesson_id, position, step_type, activity_id)
select l.id, s.pos, s.st, (select id from activities where slug = s.a)
from (values
  ('counting-to-10', 0, 0, 'intro', 'numbers-on-the-farm'), ('counting-to-10', 0, 1, 'practice', 'count-the-boats'),
  ('counting-to-10', 0, 2, 'trace', 'number-trace-1-5'),
  ('counting-to-10', 1, 0, 'song', 'ten-little-seeds'), ('counting-to-10', 1, 1, 'practice', 'more-or-less'),
  ('shapes-around-us', 0, 0, 'practice', 'shape-sort'), ('shapes-around-us', 0, 1, 'practice', 'shape-homes'),
  ('shapes-around-us', 1, 0, 'practice', 'colour-the-garden'),
  ('big-feelings', 0, 0, 'song', 'feelings-song'), ('big-feelings', 0, 1, 'story', 'calm-breathing')
) as s(course, lesson, pos, st, a)
join courses c on c.slug = s.course
join course_modules m on m.course_id = c.id
join lessons l on l.module_id = m.id and l.position = s.lesson;

insert into learning_path_courses (path_id, course_id, position)
select (select id from learning_paths where slug = 'preschool-start'), (select id from courses where slug = 'counting-to-10'), 1;
insert into learning_paths (slug, title, description, stage, age_min_months, age_max_months, status)
values ('little-steps', '{"en":"Little steps"}', '{"en":"Shapes, colours and feelings for the youngest"}',
        'toddler', 24, 48, 'published');
insert into learning_path_courses (path_id, course_id, position)
select (select id from learning_paths where slug = 'little-steps'), (select id from courses where slug = c), p
from (values ('shapes-around-us', 0), ('big-feelings', 1)) as x(c, p);

update learning_paths set description = '{"en":"Letters and numbers before school"}' where slug = 'preschool-start';

insert into collection_items (collection_id, activity_id, position)
select (select id from collections where slug = c), (select id from activities where slug = a), p from (values
  ('games-for-today', 'shape-sort', 3), ('games-for-today', 'more-or-less', 4),
  ('shows', 'numbers-on-the-farm', 1), ('shows', 'why-does-it-rain', 2),
  ('songs', 'ten-little-seeds', 1), ('songs', 'feelings-song', 2), ('bedtime-stories', 'calm-breathing', 1)
) as x(c, a, p);

-- Mia finished Island 1 of "Letters a to h" (the enrollment above already points at Island 2).
with mia as (select id, account_id from child_profiles where nickname = 'Mia'),
steps as (
  select st.id step_id, st.activity_id, st.position
  from lesson_steps st join lessons l on l.id = st.lesson_id
  join course_modules m on m.id = l.module_id join courses c on c.id = m.course_id
  where c.slug = 'letters-a-to-h' and l.position = 0
),
s as (
  insert into activity_sessions (id, child_id, activity_id, lesson_step_id, source, platform, app_version,
                                 content_version, status, started_at, ended_at, local_date)
  select gen_random_uuid(), mia.id, steps.activity_id, steps.step_id, 'course', 'ios', '1.0.0', 1, 'completed',
         now() - interval '2 days' + steps.position * interval '5 minutes',
         now() - interval '2 days' + steps.position * interval '5 minutes' + interval '3 minutes',
         private.local_date(mia.account_id, now() - interval '2 days')
  from mia, steps
  returning id, child_id, lesson_step_id, ended_at
)
insert into lesson_step_completions (child_id, step_id, session_id, score, completed_at)
select child_id, lesson_step_id, id, 100, ended_at from s;

insert into child_rewards (child_id, reward_id, source)
select ch.id, r.id, case when r.type = 'badge' then 'badge_rule' else 'gift' end
from child_profiles ch join rewards r on r.key in ('garden-snail', 'garden-bee')
where ch.nickname = 'Mia';

-- ---------------------------------------------------------------------------
-- 14. Learning-engine content for development (Phase 9). games.config.items in the engine's
-- format (docs/flutter/activity-types.md). GENERATED from kids_app/lib/demo/demo_activity_content.dart
-- by `dart run tool/seed_content_sql.dart`; test/unit/seed_content_test.dart checks they match.
-- "Try everything" has one item of every activity type.
-- ---------------------------------------------------------------------------
insert into activities (slug, type, title, description, keywords, subject_id, thumbnail_asset_id,
                        age_min_months, age_max_months, difficulty, players, estimated_seconds,
                        plus_only, free_eligible, status, published_at)
values ('engine-sampler', 'game', '{"en":"Try everything!"}', '{"en":"One of every kind of game"}', 'sampler all games',
        (select id from subjects where key = 'thinking'),
        (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'),
        36, 96, 1, 1, 420, false, true, 'published', now() - interval '1 day');
insert into games (activity_id, template_id, config)
values ((select id from activities where slug = 'engine-sampler'),
        (select id from game_templates where key = 'quiz' and version = '1.0.0'), '{}');
insert into collection_items (collection_id, activity_id, position)
values ((select id from collections where slug = 'games-for-today'), (select id from activities where slug = 'engine-sampler'), 5);

-- >>> generated by kids_app/tool/seed_content_sql.dart --write (do not edit by hand)
update games set config = '{"intro":{"text":"Find the letter","speak":"Listen, then tap the letter you hear."},"items":[{"kind":"letter_recognition","target":"b"},{"kind":"letter_recognition","target":"d"},{"kind":"letter_recognition","target":"p"}]}'::jsonb -- engine:find-the-b
where activity_id = (select id from activities where slug = 'find-the-b');
update games set config = '{"intro":{"text":"Count with me","speak":"Count the boats, then tap the number."},"items":[{"kind":"number_recognition","count":3,"picture":"icon:sailboat"},{"kind":"number_recognition","count":5,"picture":"icon:sailboat"},{"kind":"number_recognition","count":4,"picture":"icon:sailboat"}]}'::jsonb -- engine:count-the-boats
where activity_id = (select id from activities where slug = 'count-the-boats');
update games set config = '{"intro":{"text":"Trace the letters","speak":"Use your finger to trace each letter."},"items":[{"kind":"trace","glyph":"a"},{"kind":"trace","glyph":"b"},{"kind":"trace","glyph":"c"}]}'::jsonb -- engine:trace-a-to-h
where activity_id = (select id from activities where slug = 'trace-a-to-h');
update games set config = '{"intro":{"text":"Trace the numbers","speak":"Trace each number with your finger."},"items":[{"kind":"trace","glyph":"1"},{"kind":"trace","glyph":"2"},{"kind":"trace","glyph":"3"}]}'::jsonb -- engine:number-trace-1-5
where activity_id = (select id from activities where slug = 'number-trace-1-5');
update games set config = '{"intro":{"text":"Shape homes","speak":"Help each shape find its home."},"items":[{"kind":"drag_to_target","prompt":{"text":"Take each shape home","speak":"Drag each shape to the home with the same shape."},"tokens":[{"id":"circle","picture":"shape:circle"},{"id":"square","picture":"shape:square"},{"id":"triangle","picture":"shape:triangle"}],"targets":[{"id":"home-circle","picture":"shape:circle","label":"circle"},{"id":"home-square","picture":"shape:square","label":"square"},{"id":"home-triangle","picture":"shape:triangle","label":"triangle"}],"solution":{"circle":"home-circle","square":"home-square","triangle":"home-triangle"}}]}'::jsonb -- engine:shape-homes
where activity_id = (select id from activities where slug = 'shape-homes');
update games set config = '{"intro":{"text":"Shape sort","speak":"Is it round, or does it have corners?"},"items":[{"kind":"sort","prompt":{"text":"Round or corners?","speak":"Put the round things on one side and the things with corners on the other."},"bins":[{"id":"round","label":"Round","picture":"shape:circle"},{"id":"corners","label":"Corners","picture":"shape:square"}],"items":[{"id":"ball","picture":"icon:ball","label":"ball","bin":"round"},{"id":"sun","picture":"icon:sun","label":"sun","bin":"round"},{"id":"house","picture":"icon:house","label":"house","bin":"corners"},{"id":"star","picture":"shape:star","label":"star","bin":"corners"}]}]}'::jsonb -- engine:shape-sort
where activity_id = (select id from activities where slug = 'shape-sort');
update games set config = '{"intro":{"text":"More or less?","speak":"Look at the baskets. Which has more?"},"items":[{"kind":"image_choice","prompt":{"text":"Which has more?","speak":"Which basket has more apples?"},"options":[{"id":"three","picture":"count:3:apple","label":"three apples"},{"id":"five","picture":"count:5:apple","label":"five apples"}],"correct":["five"]},{"kind":"image_choice","prompt":{"text":"Which has less?","speak":"Which basket has fewer carrots?"},"options":[{"id":"two","picture":"count:2:carrot","label":"two carrots"},{"id":"six","picture":"count:6:carrot","label":"six carrots"}],"correct":["two"]}]}'::jsonb -- engine:more-or-less
where activity_id = (select id from activities where slug = 'more-or-less');
update games set config = '{"intro":{"text":"Try everything!","speak":"Here is one of every kind of game. Ready?"},"items":[{"kind":"multiple_choice","prompt":{"text":"Which one is a fruit?"},"options":[{"id":"banana","label":"banana"},{"id":"car","label":"car"},{"id":"shoe","label":"shoe"}],"correct":["banana"],"hint":"You can eat it!"},{"kind":"image_choice","prompt":{"text":"Which one can fly?","picture":"icon:tree"},"options":[{"id":"bird","picture":"icon:bird","label":"bird"},{"id":"fish","picture":"icon:fish","label":"fish"},{"id":"cow","picture":"icon:cow","label":"cow"}],"correct":["bird"]},{"kind":"audio_choice","prompt":{"speak":"Find the cat."},"options":[{"id":"cat","picture":"icon:cat","label":"cat"},{"id":"dog","picture":"icon:dog","label":"dog"},{"id":"duck","picture":"icon:duck","label":"duck"}],"correct":["cat"]},{"kind":"letter_recognition","target":"m"},{"kind":"number_recognition","target":7,"distractors":[1,4,9]},{"kind":"drag_to_target","prompt":{"text":"Who lives where?"},"tokens":[{"id":"fish","picture":"icon:fish","label":"fish"},{"id":"bird","picture":"icon:bird","label":"bird"}],"targets":[{"id":"water","label":"water","picture":"icon:water"},{"id":"tree","label":"tree","picture":"icon:tree"}],"solution":{"fish":"water","bird":"tree"}},{"kind":"sort","prompt":{"text":"Animals or food?"},"bins":[{"id":"animals","label":"Animals","picture":"icon:pets"},{"id":"food","label":"Food","picture":"icon:cake"}],"items":[{"id":"cow","picture":"icon:cow","label":"cow","bin":"animals"},{"id":"apple","picture":"icon:apple","label":"apple","bin":"food"},{"id":"duck","picture":"icon:duck","label":"duck","bin":"animals"}]},{"kind":"match_pairs","prompt":{"text":"Match the word to the picture"},"pairs":[{"left":{"label":"cat"},"right":{"picture":"icon:cat","label":"cat"}},{"left":{"label":"sun"},"right":{"picture":"icon:sun","label":"sun"}},{"left":{"label":"car"},"right":{"picture":"icon:car","label":"car"}}]},{"kind":"fill_blank","sentence":"The cow says ___","picture":"icon:cow","options":[{"id":"moo","label":"moo"},{"id":"quack","label":"quack"},{"id":"woof","label":"woof"}],"correct":"moo"},{"kind":"word_build","word":"cat","picture":"icon:cat"},{"kind":"memory","cards":[{"id":"sun","picture":"icon:sun","label":"sun"},{"id":"moon","picture":"icon:moon","label":"moon"},{"id":"star","picture":"shape:star","label":"star"}]},{"kind":"puzzle","picture":"char:pip","grid":2},{"kind":"trace","glyph":"o"},{"kind":"arithmetic","a":2,"op":"+","b":1,"picture":"icon:apple"},{"kind":"shape_complete","shape":"circle","missing":"right","distractors":["square","triangle"]},{"kind":"jigsaw","picture":"char:pip","grid":2}]}'::jsonb -- engine:engine-sampler
where activity_id = (select id from activities where slug = 'engine-sampler');

-- ---------------------------------------------------------------------------
-- 15. The game collection (Phase 10, docs/games/game-catalog.md): eight games on the
-- learning engine, each with Easy / Medium / Hard levels, in the "Game room" home row.
-- ---------------------------------------------------------------------------
insert into game_templates (key, version, runtime, orientation, supported_platforms, config_schema, status)
values ('learning_engine', '1.0.0', 'flutter', 'landscape', array['ios','android','web'],
        '{"$schema":"https://json-schema.org/draft/2020-12/schema","$id":"learning_engine/1.0.0","title":"games.config for the learning engine","description":"One list of items, or 2+ difficulty levels (easiest first). Kinds and fields: docs/games/content-requirements.md. The app re-checks every item when it parses it.","type":"object","properties":{"intro":{"oneOf":[{"type":"string"},{"type":"object","properties":{"text":{"$ref":"#/$defs/text"},"speak":{"$ref":"#/$defs/text"}}}]},"items":{"type":"array","items":{"$ref":"#/$defs/item"},"maxItems":30},"levels":{"type":"array","items":{"$ref":"#/$defs/level"},"minItems":1,"maxItems":5}},"anyOf":[{"required":["items"]},{"required":["levels"]}],"$defs":{"text":{"oneOf":[{"type":"string","maxLength":200},{"type":"object","additionalProperties":{"type":"string","maxLength":200}}]},"picture":{"type":"string","pattern":"^(shape|icon|char|glyph|count|half|gap|asset):[^\\s]+$"},"choice":{"oneOf":[{"type":"string"},{"type":"object","properties":{"id":{"type":"string"},"label":{"$ref":"#/$defs/text"},"picture":{"$ref":"#/$defs/picture"},"speak":{"$ref":"#/$defs/text"}}}]},"item":{"type":"object","required":["kind"],"properties":{"kind":{"enum":["arithmetic","audio_choice","drag_to_target","fill_blank","image_choice","jigsaw","letter_recognition","match_pairs","memory","multiple_choice","number_recognition","puzzle","shape_complete","sort","trace","word_build"]},"prompt":{"oneOf":[{"type":"string"},{"type":"object","properties":{"text":{"$ref":"#/$defs/text"},"speak":{"$ref":"#/$defs/text"},"picture":{"$ref":"#/$defs/picture"}}}]},"hint":{"$ref":"#/$defs/text"},"options":{"type":"array","items":{"$ref":"#/$defs/choice"},"minItems":2,"maxItems":8},"cards":{"type":"array","items":{"$ref":"#/$defs/choice"},"minItems":2,"maxItems":8},"timer":{"type":"boolean"},"target":{"type":["string","integer"]},"mode":{"enum":["name","sound","case"]},"count":{"type":"integer","minimum":1,"maximum":10},"a":{"type":"integer","minimum":0,"maximum":10},"b":{"type":"integer","minimum":0,"maximum":10},"op":{"enum":["+","-"]},"grid":{"type":"integer","minimum":2,"maximum":4},"word":{"type":"string","minLength":1,"maxLength":8},"glyph":{"type":"string","maxLength":1},"shape":{"enum":["circle","square","triangle","star","heart"]},"missing":{"enum":["left","right","top","bottom"]},"picture":{"$ref":"#/$defs/picture"}},"allOf":[{"if":{"properties":{"kind":{"const":"arithmetic"}}},"then":{"required":["kind","a","b"]}},{"if":{"properties":{"kind":{"const":"audio_choice"}}},"then":{"required":["kind","options","correct","prompt"]}},{"if":{"properties":{"kind":{"const":"drag_to_target"}}},"then":{"required":["kind","tokens","targets","solution"]}},{"if":{"properties":{"kind":{"const":"fill_blank"}}},"then":{"required":["kind","sentence","options","correct"]}},{"if":{"properties":{"kind":{"const":"image_choice"}}},"then":{"required":["kind","options","correct"]}},{"if":{"properties":{"kind":{"const":"jigsaw"}}},"then":{"required":["kind","picture"]}},{"if":{"properties":{"kind":{"const":"letter_recognition"}}},"then":{"required":["kind","target"]}},{"if":{"properties":{"kind":{"const":"match_pairs"}}},"then":{"required":["kind","pairs"]}},{"if":{"properties":{"kind":{"const":"memory"}}},"then":{"required":["kind","cards"]}},{"if":{"properties":{"kind":{"const":"multiple_choice"}}},"then":{"required":["kind","options","correct"]}},{"if":{"properties":{"kind":{"const":"shape_complete"}}},"then":{"required":["kind","shape"]}},{"if":{"properties":{"kind":{"const":"sort"}}},"then":{"required":["kind","bins","items"]}},{"if":{"properties":{"kind":{"const":"word_build"}}},"then":{"required":["kind","word"]}}]},"level":{"type":"object","required":["id","items"],"properties":{"id":{"type":"string","pattern":"^[a-z0-9-]{1,32}$"},"label":{"$ref":"#/$defs/text"},"minAgeMonths":{"type":"integer","minimum":0,"maximum":144},"options":{"type":"integer","minimum":2,"maximum":8},"attempts":{"type":"integer","minimum":1,"maximum":5},"items":{"type":"array","items":{"$ref":"#/$defs/item"},"minItems":1,"maxItems":30}}}}}'::jsonb, 'active');
insert into activities (slug, type, title, description, keywords, subject_id, thumbnail_asset_id,
                        age_min_months, age_max_months, difficulty, players, estimated_seconds,
                        plus_only, free_eligible, status, published_at)
values
  ('memory-match', 'game', '{"en":"Memory match"}', '{"en":"Flip the cards and find the pairs"}', 'memory pairs cards',
   (select id from subjects where key = 'thinking'), (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'),
   30, 108, 2, 1, 240, false, true, 'published', now() - interval '1 day'),
  ('picture-match', 'game', '{"en":"Picture match"}', '{"en":"Match each picture to its word"}', 'match pictures words',
   (select id from subjects where key = 'english'), (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'),
   30, 96, 2, 1, 200, false, true, 'published', now() - interval '1 day'),
  ('word-builder', 'game', '{"en":"Word builder"}', '{"en":"Put the letters in order to make a word"}', 'spelling words letters',
   (select id from subjects where key = 'letters'), (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'),
   42, 108, 2, 1, 240, false, true, 'published', now() - interval '1 day'),
  ('number-fun', 'game', '{"en":"Number fun"}', '{"en":"Count, match numbers, add and take away"}', 'numbers counting adding',
   (select id from subjects where key = 'numbers'), (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'),
   30, 108, 2, 1, 300, false, true, 'published', now() - interval '1 day'),
  ('alphabet-adventure', 'game', '{"en":"Alphabet adventure"}', '{"en":"Letters big and small, their sounds, and tracing"}', 'alphabet letters phonics tracing',
   (select id from subjects where key = 'letters'), (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'),
   30, 96, 2, 1, 300, false, true, 'published', now() - interval '1 day'),
  ('sort-it-out', 'game', '{"en":"Sort it out"}', '{"en":"Sort by shape, colour, size and kind"}', 'sorting colours shapes sizes',
   (select id from subjects where key = 'shapes'), (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'),
   30, 96, 2, 1, 240, false, true, 'published', now() - interval '1 day'),
  ('puzzle-time', 'game', '{"en":"Puzzle time"}', '{"en":"Jigsaws and shapes to finish"}', 'puzzle jigsaw shapes',
   (select id from subjects where key = 'thinking'), (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'),
   30, 108, 2, 1, 300, false, true, 'published', now() - interval '1 day'),
  ('quiz-time', 'game', '{"en":"Quiz time"}', '{"en":"Questions to read, look at and listen to"}', 'quiz questions',
   (select id from subjects where key = 'thinking'), (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'),
   36, 108, 2, 1, 240, false, true, 'published', now() - interval '1 day');
insert into games (activity_id, template_id, config)
select a.id, (select id from game_templates where key = 'learning_engine' and version = '1.0.0'), '{}'
from activities a where a.slug in ('memory-match', 'picture-match', 'word-builder', 'number-fun', 'alphabet-adventure', 'sort-it-out', 'puzzle-time', 'quiz-time');
insert into collections (slug, surface, kind, title, sort, status, category_id)
values ('game-room', 'home', 'row', '{"en":"Game room"}', 2, 'published', null);
insert into collection_items (collection_id, activity_id, position)
select (select id from collections where slug = 'game-room'), a.id, x.p
from (values ('memory-match', 0), ('picture-match', 1), ('word-builder', 2), ('number-fun', 3), ('alphabet-adventure', 4), ('sort-it-out', 5), ('puzzle-time', 6), ('quiz-time', 7)) as x(slug, p)
join activities a on a.slug = x.slug;
update games set config = '{"intro":{"text":"Find the pairs","speak":"Turn over two cards at a time. Can you find all the pairs in a few moves?"},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"options":3,"items":[{"kind":"memory","timer":true,"cards":[{"id":"cat","picture":"icon:cat","label":"cat"},{"id":"dog","picture":"icon:dog","label":"dog"},{"id":"duck","picture":"icon:duck","label":"duck"}]},{"kind":"memory","timer":true,"cards":[{"id":"sun","picture":"icon:sun","label":"sun"},{"id":"moon","picture":"icon:moon","label":"moon"},{"id":"star","picture":"shape:star","label":"star"}]}]},{"id":"medium","label":"Medium","minAgeMonths":54,"options":6,"items":[{"kind":"memory","timer":true,"cards":[{"id":"apple","picture":"icon:apple","label":"apple"},{"id":"banana","picture":"icon:banana","label":"banana"},{"id":"carrot","picture":"icon:carrot","label":"carrot"},{"id":"cake","picture":"icon:cake","label":"cake"},{"id":"flower","picture":"icon:flower","label":"flower"},{"id":"tree","picture":"icon:tree","label":"tree"}]}]},{"id":"hard","label":"Hard","minAgeMonths":78,"options":8,"items":[{"kind":"memory","timer":true,"cards":[{"id":"cat","picture":"icon:cat","label":"cat"},{"id":"dog","picture":"icon:dog","label":"dog"},{"id":"cow","picture":"icon:cow","label":"cow"},{"id":"duck","picture":"icon:duck","label":"duck"},{"id":"fish","picture":"icon:fish","label":"fish"},{"id":"bird","picture":"icon:bird","label":"bird"},{"id":"sun","picture":"icon:sun","label":"sun"},{"id":"moon","picture":"icon:moon","label":"moon"}]}]}]}'::jsonb -- engine:memory-match
where activity_id = (select id from activities where slug = 'memory-match');
update games set config = '{"intro":{"text":"Match the pictures","speak":"Tap or drag each word to its picture. Tap a picture to hear its name."},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"match_pairs","prompt":{"text":"Match the word to the picture"},"pairs":[{"left":{"label":"cat"},"right":{"picture":"icon:cat","label":"cat"}},{"left":{"label":"sun"},"right":{"picture":"icon:sun","label":"sun"}}]},{"kind":"drag_to_target","prompt":{"text":"Who lives where?","speak":"Take each animal to its home."},"tokens":[{"id":"fish","picture":"icon:fish","label":"fish"},{"id":"bird","picture":"icon:bird","label":"bird"}],"targets":[{"id":"water","label":"water","picture":"icon:water"},{"id":"tree","label":"tree","picture":"icon:tree"}],"solution":{"fish":"water","bird":"tree"}}]},{"id":"medium","label":"Medium","minAgeMonths":54,"items":[{"kind":"match_pairs","prompt":{"text":"Match the word to the picture"},"pairs":[{"left":{"label":"dog"},"right":{"picture":"icon:dog","label":"dog"}},{"left":{"label":"car"},"right":{"picture":"icon:car","label":"car"}},{"left":{"label":"cake"},"right":{"picture":"icon:cake","label":"cake"}}]},{"kind":"match_pairs","prompt":{"text":"Match the word to the picture"},"pairs":[{"left":{"label":"apple"},"right":{"picture":"icon:apple","label":"apple"}},{"left":{"label":"ball"},"right":{"picture":"icon:ball","label":"ball"}},{"left":{"label":"house"},"right":{"picture":"icon:house","label":"house"}}]}]},{"id":"hard","label":"Hard","minAgeMonths":78,"items":[{"kind":"match_pairs","prompt":{"text":"Match the word to the picture"},"pairs":[{"left":{"label":"flower"},"right":{"picture":"icon:flower","label":"flower"}},{"left":{"label":"carrot"},"right":{"picture":"icon:carrot","label":"carrot"}},{"left":{"label":"moon"},"right":{"picture":"icon:moon","label":"moon"}},{"left":{"label":"sailboat"},"right":{"picture":"icon:sailboat","label":"sailboat"}}]},{"kind":"match_pairs","prompt":{"text":"Which go together?","speak":"Match the things that go together."},"pairs":[{"left":{"id":"fish","picture":"icon:fish","label":"fish"},"right":{"id":"water","picture":"icon:water","label":"water"}},{"left":{"id":"bird","picture":"icon:bird","label":"bird"},"right":{"id":"tree","picture":"icon:tree","label":"tree"}},{"left":{"id":"dog","picture":"icon:dog","label":"dog"},"right":{"id":"house","picture":"icon:house","label":"house"}}]}]}]}'::jsonb -- engine:picture-match
where activity_id = (select id from activities where slug = 'picture-match');
update games set config = '{"intro":{"text":"Build the word","speak":"Look at the picture. Tap the letters in order to spell the word."},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"word_build","word":"cat","picture":"icon:cat"},{"kind":"word_build","word":"sun","picture":"icon:sun"},{"kind":"word_build","word":"dog","picture":"icon:dog"}]},{"id":"medium","label":"Medium","minAgeMonths":60,"items":[{"kind":"word_build","word":"fish","picture":"icon:fish","extra":"a"},{"kind":"word_build","word":"moon","picture":"icon:moon","extra":"e"},{"kind":"word_build","word":"cake","picture":"icon:cake","extra":"o"}]},{"id":"hard","label":"Hard","minAgeMonths":78,"items":[{"kind":"word_build","word":"apple","picture":"icon:apple","extra":"u"},{"kind":"word_build","word":"house","picture":"icon:house","extra":"a"},{"kind":"word_build","word":"flower","picture":"icon:flower","extra":"i"}]}]}'::jsonb -- engine:word-builder
where activity_id = (select id from activities where slug = 'word-builder');
update games set config = '{"intro":{"text":"Number fun","speak":"Let us count, find numbers, and add and take away."},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"number_recognition","count":3,"picture":"icon:apple"},{"kind":"number_recognition","target":2,"distractors":[5,4]},{"kind":"match_pairs","prompt":{"text":"Match the number","speak":"Count, then match each group to its number."},"pairs":[{"left":{"picture":"count:1:star","speak":"1 stars"},"right":{"label":"1"}},{"left":{"picture":"count:2:star","speak":"2 stars"},"right":{"label":"2"}},{"left":{"picture":"count:3:star","speak":"3 stars"},"right":{"label":"3"}}]},{"kind":"arithmetic","a":2,"op":"+","b":1,"picture":"icon:apple"}]},{"id":"medium","label":"Medium","minAgeMonths":54,"items":[{"kind":"number_recognition","count":6,"picture":"icon:sailboat"},{"kind":"number_recognition","target":8,"distractors":[3,6,9]},{"kind":"match_pairs","prompt":{"text":"Match the number","speak":"Count, then match each group to its number."},"pairs":[{"left":{"picture":"count:4:ball","speak":"4 balls"},"right":{"label":"4"}},{"left":{"picture":"count:5:ball","speak":"5 balls"},"right":{"label":"5"}},{"left":{"picture":"count:6:ball","speak":"6 balls"},"right":{"label":"6"}}]},{"kind":"arithmetic","a":3,"op":"+","b":2,"picture":"icon:banana"},{"kind":"arithmetic","a":5,"op":"-","b":2,"picture":"icon:apple"}]},{"id":"hard","label":"Hard","minAgeMonths":78,"options":4,"items":[{"kind":"number_recognition","target":15,"distractors":[12,18,51]},{"kind":"arithmetic","a":6,"op":"+","b":3},{"kind":"arithmetic","a":9,"op":"-","b":4},{"kind":"arithmetic","a":7,"op":"+","b":5},{"kind":"arithmetic","a":10,"op":"-","b":7}]}]}'::jsonb -- engine:number-fun
where activity_id = (select id from activities where slug = 'number-fun');
update games set config = '{"intro":{"text":"Alphabet adventure","speak":"Find letters, match big and small letters, listen to their sounds and trace them."},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"letter_recognition","target":"a"},{"kind":"letter_recognition","target":"B","mode":"case"},{"kind":"match_pairs","prompt":{"text":"Big and small","speak":"Match each big letter to its small letter."},"pairs":[{"left":{"picture":"glyph:A","speak":"big A"},"right":{"picture":"glyph:a","speak":"small a"}},{"left":{"picture":"glyph:B","speak":"big B"},"right":{"picture":"glyph:b","speak":"small b"}}]},{"kind":"letter_recognition","target":"s","mode":"sound"},{"kind":"trace","glyph":"L"}]},{"id":"medium","label":"Medium","minAgeMonths":54,"items":[{"kind":"letter_recognition","target":"d"},{"kind":"letter_recognition","target":"g","mode":"case"},{"kind":"match_pairs","prompt":{"text":"Big and small","speak":"Match each big letter to its small letter."},"pairs":[{"left":{"picture":"glyph:E","speak":"big E"},"right":{"picture":"glyph:e","speak":"small e"}},{"left":{"picture":"glyph:H","speak":"big H"},"right":{"picture":"glyph:h","speak":"small h"}},{"left":{"picture":"glyph:M","speak":"big M"},"right":{"picture":"glyph:m","speak":"small m"}}]},{"kind":"letter_recognition","target":"m","mode":"sound"},{"kind":"trace","glyph":"T"},{"kind":"trace","glyph":"E"}]},{"id":"hard","label":"Hard","minAgeMonths":78,"options":4,"items":[{"kind":"letter_recognition","target":"q"},{"kind":"letter_recognition","target":"N","mode":"case"},{"kind":"match_pairs","prompt":{"text":"Big and small","speak":"Match each big letter to its small letter."},"pairs":[{"left":{"picture":"glyph:D","speak":"big D"},"right":{"picture":"glyph:d","speak":"small d"}},{"left":{"picture":"glyph:Q","speak":"big Q"},"right":{"picture":"glyph:q","speak":"small q"}},{"left":{"picture":"glyph:N","speak":"big N"},"right":{"picture":"glyph:n","speak":"small n"}},{"left":{"picture":"glyph:R","speak":"big R"},"right":{"picture":"glyph:r","speak":"small r"}}]},{"kind":"letter_recognition","target":"f","mode":"sound"},{"kind":"letter_recognition","target":"p","mode":"sound"},{"kind":"trace","glyph":"M"},{"kind":"trace","glyph":"Z"}]}]}'::jsonb -- engine:alphabet-adventure
where activity_id = (select id from activities where slug = 'alphabet-adventure');
update games set config = '{"intro":{"text":"Sort it out","speak":"Drag each one to the group where it belongs."},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"sort","prompt":{"text":"Sort by colour","speak":"Put the red ones and the blue ones together."},"bins":[{"id":"red","label":"Red","picture":"shape:square?color=red"},{"id":"blue","label":"Blue","picture":"shape:square?color=blue"}],"items":[{"id":"red-ball","picture":"icon:ball?color=red","bin":"red"},{"id":"blue-ball","picture":"icon:ball?color=blue","bin":"blue"},{"id":"red-star","picture":"shape:star?color=red","bin":"red"},{"id":"blue-heart","picture":"shape:heart?color=blue","bin":"blue"}]},{"kind":"sort","prompt":{"text":"Big or small?","speak":"Put the big ones and the small ones together."},"bins":[{"id":"big","label":"Big","picture":"shape:circle?size=big&color=green"},{"id":"small","label":"Small","picture":"shape:circle?size=small&color=green"}],"items":[{"id":"big-apple","picture":"icon:apple?size=big","bin":"big"},{"id":"small-apple","picture":"icon:apple?size=small","bin":"small"},{"id":"big-star","picture":"shape:star?size=big","bin":"big"},{"id":"small-star","picture":"shape:star?size=small","bin":"small"}]}]},{"id":"medium","label":"Medium","minAgeMonths":54,"items":[{"kind":"sort","prompt":{"text":"Sort by shape","speak":"Circles, triangles and squares. Put each shape in its group."},"bins":[{"id":"circle","label":"Circles","picture":"shape:circle"},{"id":"triangle","label":"Triangles","picture":"shape:triangle"},{"id":"square","label":"Squares","picture":"shape:square"}],"items":[{"id":"c1","picture":"shape:circle?color=red","bin":"circle"},{"id":"t1","picture":"shape:triangle?color=blue","bin":"triangle"},{"id":"s1","picture":"shape:square?color=yellow","bin":"square"},{"id":"c2","picture":"shape:circle?color=purple&size=small","bin":"circle"},{"id":"t2","picture":"shape:triangle?color=green&size=small","bin":"triangle"},{"id":"s2","picture":"shape:square?color=orange&size=medium","bin":"square"}]},{"kind":"sort","prompt":{"text":"Animals or food?"},"bins":[{"id":"animals","label":"Animals","picture":"icon:pets"},{"id":"food","label":"Food","picture":"icon:cake"}],"items":[{"id":"cow","picture":"icon:cow","bin":"animals","label":"cow"},{"id":"apple","picture":"icon:apple","bin":"food","label":"apple"},{"id":"fish","picture":"icon:fish","bin":"animals","label":"fish"},{"id":"carrot","picture":"icon:carrot","bin":"food","label":"carrot"},{"id":"duck","picture":"icon:duck","bin":"animals","label":"duck"},{"id":"banana","picture":"icon:banana","bin":"food","label":"banana"}]}]},{"id":"hard","label":"Hard","minAgeMonths":78,"items":[{"kind":"sort","prompt":{"text":"Sort by colour","speak":"Red, yellow or green? Sort them all."},"bins":[{"id":"red","label":"Red","picture":"shape:square?color=red"},{"id":"yellow","label":"Yellow","picture":"shape:square?color=yellow"},{"id":"green","label":"Green","picture":"shape:square?color=green"}],"items":[{"id":"r1","picture":"icon:apple?color=red","bin":"red"},{"id":"y1","picture":"icon:banana?color=yellow","bin":"yellow"},{"id":"g1","picture":"icon:tree?color=green","bin":"green"},{"id":"r2","picture":"shape:heart?color=red","bin":"red"},{"id":"y2","picture":"shape:star?color=yellow","bin":"yellow"},{"id":"g2","picture":"icon:flower?color=green","bin":"green"}]},{"kind":"sort","prompt":{"text":"Where do they live?","speak":"On a farm, in the water, or in the sky?"},"bins":[{"id":"farm","label":"Farm","picture":"icon:house"},{"id":"water","label":"Water","picture":"icon:water"},{"id":"sky","label":"Sky","picture":"icon:sun"}],"items":[{"id":"cow","picture":"icon:cow","bin":"farm","label":"cow"},{"id":"fish","picture":"icon:fish","bin":"water","label":"fish"},{"id":"bird","picture":"icon:bird","bin":"sky","label":"bird"},{"id":"dog","picture":"icon:dog","bin":"farm","label":"dog"},{"id":"boat","picture":"icon:sailboat","bin":"water","label":"boat"}]}]}]}'::jsonb -- engine:sort-it-out
where activity_id = (select id from activities where slug = 'sort-it-out');
update games set config = '{"intro":{"text":"Puzzle time","speak":"Build the pictures and finish the shapes."},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"jigsaw","picture":"char:pip","grid":2},{"kind":"shape_complete","shape":"circle","missing":"right","distractors":["square","triangle"]},{"kind":"shape_complete","shape":"heart","missing":"left","distractors":["star","square"]}]},{"id":"medium","label":"Medium","minAgeMonths":54,"items":[{"kind":"jigsaw","picture":"char:bolt","grid":3},{"kind":"shape_complete","shape":"star","missing":"right","distractors":["heart","circle","triangle"]},{"kind":"shape_complete","shape":"triangle","missing":"top","distractors":["circle","square","heart"]}]},{"id":"hard","label":"Hard","minAgeMonths":78,"options":4,"items":[{"kind":"jigsaw","picture":"char:nova","grid":4},{"kind":"puzzle","picture":"char:pip","grid":3},{"kind":"shape_complete","shape":"heart","missing":"bottom","color":"purple"}]}]}'::jsonb -- engine:puzzle-time
where activity_id = (select id from activities where slug = 'puzzle-time');
update games set config = '{"intro":{"text":"Quiz time","speak":"Answer the questions. Some you read, some you look at, and some you listen to."},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"image_choice","prompt":{"text":"Which one can swim?"},"options":[{"id":"fish","picture":"icon:fish","label":"fish"},{"id":"cat","picture":"icon:cat","label":"cat"},{"id":"car","picture":"icon:car","label":"car"}],"correct":["fish"],"hint":"It lives in water."},{"kind":"audio_choice","prompt":{"speak":"Which animal says moo?"},"options":[{"id":"cow","picture":"icon:cow","label":"cow"},{"id":"duck","picture":"icon:duck","label":"duck"},{"id":"dog","picture":"icon:dog","label":"dog"}],"correct":["cow"]},{"kind":"multiple_choice","prompt":{"text":"What do we see at night?","picture":"icon:moon"},"options":[{"id":"moon","label":"the moon"},{"id":"sun","label":"the sun"}],"correct":["moon"]}]},{"id":"medium","label":"Medium","minAgeMonths":54,"items":[{"kind":"image_choice","prompt":{"text":"Which one grows in the ground?"},"options":[{"id":"carrot","picture":"icon:carrot","label":"carrot"},{"id":"cake","picture":"icon:cake","label":"cake"},{"id":"ball","picture":"icon:ball","label":"ball"},{"id":"bird","picture":"icon:bird","label":"bird"}],"correct":["carrot"]},{"kind":"audio_choice","prompt":{"speak":"Find the one that can fly."},"options":[{"id":"bird","picture":"icon:bird","label":"bird"},{"id":"fish","picture":"icon:fish","label":"fish"},{"id":"cow","picture":"icon:cow","label":"cow"},{"id":"dog","picture":"icon:dog","label":"dog"}],"correct":["bird"]},{"kind":"multiple_choice","prompt":{"text":"Which ones are fruit?","speak":"Tap all the fruit, then tap Done."},"options":[{"id":"apple","label":"apple","picture":"icon:apple"},{"id":"banana","label":"banana","picture":"icon:banana"},{"id":"car","label":"car","picture":"icon:car"}],"correct":["apple","banana"]},{"kind":"fill_blank","sentence":"A duck says ___","picture":"icon:duck","options":["quack","moo","woof"],"correct":"quack"}]},{"id":"hard","label":"Hard","minAgeMonths":78,"options":4,"items":[{"kind":"multiple_choice","prompt":{"text":"How many legs does a bird have?"},"options":[{"id":"2","label":"two"},{"id":"4","label":"four"},{"id":"6","label":"six"}],"correct":["2"]},{"kind":"audio_choice","prompt":{"speak":"Which one shines in the night sky?"},"options":[{"id":"moon","picture":"icon:moon","label":"moon"},{"id":"sun","picture":"icon:sun","label":"sun"},{"id":"tree","picture":"icon:tree","label":"tree"}],"correct":["moon"]},{"kind":"image_choice","prompt":{"text":"Which is the biggest?"},"options":[{"id":"big","picture":"icon:ball?size=big","label":"big ball"},{"id":"medium","picture":"icon:ball?size=medium","label":"middle ball"},{"id":"small","picture":"icon:ball?size=small","label":"small ball"}],"correct":["big"]},{"kind":"fill_blank","sentence":"Fish live in ___","picture":"icon:fish","options":["water","trees","cakes"],"correct":"water"}]}]}'::jsonb -- engine:quiz-time
where activity_id = (select id from activities where slug = 'quiz-time');

-- ---------------------------------------------------------------------------
-- 16. Media library (Phase 11, docs/multimedia/): original videos, songs and stories made by
-- content/dev-media/make_dev_media.py. Upload the files with scripts/upload-dev-media.sh.
-- ---------------------------------------------------------------------------
insert into categories (key, name, sort, status) values
  ('weather', '{"en":"Weather"}', 5, 'published'),
  ('colours-and-shapes', '{"en":"Colour fun"}', 6, 'published'),
  ('music-time', '{"en":"Music time"}', 7, 'published'),
  ('feelings', '{"en":"Calm and kind"}', 8, 'published')
on conflict (key) do nothing;
insert into media_assets (bucket, object_path, kind, mime_type, bytes, sha256, width, height, duration_ms, locale, access, status) values
  ('content', 'calm-breathing/1/pages/1.webp', 'image', 'image/webp', 5288, '8627a5329a581d8c446479584de4a3fd6fd5faf4810d288504f121b26b9ff4b0', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'calm-breathing/1/pages/2.webp', 'image', 'image/webp', 5806, '8a8742e2d12ace24c160aa23e0fb5b4dbfda4d57aa0222c59f41ad0181e9fd5a', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'calm-breathing/1/pages/3.webp', 'image', 'image/webp', 7118, 'ce9aaed76edf56e4d04369822961e27b4be2673eef182e97a5d57133d002b6cb', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'calm-breathing/1/pages/4.webp', 'image', 'image/webp', 6860, '6f4be03bb06a63d6782821627980a271f0fe2ebe8535a3f493e32f10cfce46d0', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'calm-breathing/1/pages/5.webp', 'image', 'image/webp', 5622, '6bd5ea2e1dab1b663b674f39319541961116dcc118757097179fd2ccd031bb3c', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'calm-breathing/1/pages/6.webp', 'image', 'image/webp', 7680, '023b93f344842bbd17ff818bcd03c3d543c36ca5afcf0443c09443619cbb15c8', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'nova-counts-the-stars/1/pages/1.webp', 'image', 'image/webp', 6382, '603547059d30f1e25cc9c4c269edf71f0740cb9be81d587a1a0ef5c89fdbfaad', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'nova-counts-the-stars/1/pages/2.webp', 'image', 'image/webp', 4774, '1c09784cded7b937224c7ef39489c46b67cd5371d25749033112755ae86c4105', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'nova-counts-the-stars/1/pages/3.webp', 'image', 'image/webp', 5804, 'aa74122471183dd4fa4213d90b5320198ea36358f67d8329b86b8b788b90f2d9', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'nova-counts-the-stars/1/pages/4.webp', 'image', 'image/webp', 8570, '99bb34d8f23f1ac3db8213d88332b98c4cadfc0076e6832bf01b88d76cf99704', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'nova-counts-the-stars/1/pages/5.webp', 'image', 'image/webp', 8120, '63b0c312c2ec8dce42bd3e4eb9eacd4c25519be28a18b72bf3005043fc116236', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'nova-counts-the-stars/1/pages/6.webp', 'image', 'image/webp', 6308, '12ea7846b6e4e3d3590ac0afffc8658757fdd0df1aaa294efa4a9be6b7a41182', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'pip-and-the-lost-seed/1/pages/1.webp', 'image', 'image/webp', 5876, '309316ea93569ff72cfbb2a15920eaf85714d5665b1df70f9cadcd296296f2c7', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'pip-and-the-lost-seed/1/pages/2.webp', 'image', 'image/webp', 6792, '7d1108ed1560876e91bbd576b7d79eaebda4beba845b70cce2bd9a858863a0f0', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'pip-and-the-lost-seed/1/pages/3.webp', 'image', 'image/webp', 7570, '6d7292efa9062a3a8284e488fbb78c25e566fa01f7fa5a63905390fb393d173f', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'pip-and-the-lost-seed/1/pages/4.webp', 'image', 'image/webp', 6812, 'fcaebdb2f011b135ea1dc0696cafc2a412dc206811d081d6459fbf5071b35f95', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'pip-and-the-lost-seed/1/pages/5.webp', 'image', 'image/webp', 6756, '6dac59b7950c7a6933744b305299c0ef1e967594ff61a69a99986a51fbace528', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'pip-and-the-lost-seed/1/pages/6.webp', 'image', 'image/webp', 8052, '4237a780249e6ddde7bb6490052634e971ea17cdf57673b917e60cb6e52f3251', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'songs/counting-train/en.m4a', 'audio', 'audio/mp4', 374670, 'b99ada9470ca199a7cda6f1f2bf0c0d3356404955d5b499caf7332de9aba7604', null, null, 45136, 'en', 'gated', 'ready'),
  ('content', 'songs/feelings-song/en.m4a', 'audio', 'audio/mp4', 510336, '7b5af213650924d4d2bd6c6455ad397122066c2d9376a0dec3fc4bebf3d54772', null, null, 61500, 'en', 'gated', 'ready'),
  ('content', 'songs/moon-lullaby/en.m4a', 'audio', 'audio/mp4', 507182, '2c1cf5bb986e3a8e4ac5bf6c6e7cec7187e943b7f4f00043e968ec68f599b774', null, null, 61500, 'en', 'gated', 'ready'),
  ('content', 'songs/ten-little-seeds/en.m4a', 'audio', 'audio/mp4', 452098, 'd6c49ff58954b57823c52ea959af48891c73776bfe01fd17c2a9276545779714', null, null, 54833, 'en', 'gated', 'ready'),
  ('content', 'songs/tidy-up-tune/en.m4a', 'audio', 'audio/mp4', 391652, 'c70056a2c89ed13b21f980800a95d42f707c5abf1f5b283684221e72b92fad64', null, null, 47214, 'en', 'gated', 'ready'),
  ('content', 'the-sleepy-cloud/1/pages/1.webp', 'image', 'image/webp', 4544, 'ae30ada3e340ff75437c2298cffb896d560861b077ce287fe612bb15aefdf31b', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'the-sleepy-cloud/1/pages/2.webp', 'image', 'image/webp', 4874, '7a43aefd9e924df9c56b7abc354ed185bc16d729f26530486705bedaadc1ae13', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'the-sleepy-cloud/1/pages/3.webp', 'image', 'image/webp', 4360, '08520a9029eaa16036cb178b11be962db8252eab4b9313edc4927a32d276c172', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'the-sleepy-cloud/1/pages/4.webp', 'image', 'image/webp', 4918, '80b53f8484ff993cf8b67a0f7cf5db1e9aca487f577aebe5063ead1e2bc351e0', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'the-sleepy-cloud/1/pages/5.webp', 'image', 'image/webp', 6766, '5b7d949b36e2292219b1c2611fa25f2b7e6b0a1696cbc2cbab623710b0fcd80b', 960, 600, null, null, 'gated', 'ready'),
  ('content', 'the-sleepy-cloud/1/pages/6.webp', 'image', 'image/webp', 7574, 'c4937e4901925d173635f8670a14883e100181546094dab4ce7dc806e021a80f', 960, 600, null, null, 'gated', 'ready'),
  ('public-assets', 'badges/first-course/1/256.webp', 'image', 'image/webp', 8780, 'becfb4c13251d14a5216ceb36be10a30cc35bc8d823c622b0f1f0ece16174e33', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/first-course/1/512.webp', 'image', 'image/webp', 16230, '157bae549a5b706adcb8004fcea4774afabdeabbf0a70cc36bf7c497d7c093c9', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/first-game/1/256.webp', 'image', 'image/webp', 8660, 'a55dee6ab89c2c6c59b91b677115ff8234747a3683c42856fb94d7ddc2f15759', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/first-game/1/512.webp', 'image', 'image/webp', 16148, '8780ad8c076cb5d3722f996e197b1ffb3eebfd2501287de0058f3ef77855a8a7', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/first-island/1/256.webp', 'image', 'image/webp', 8576, 'f93aa56f25e76a5b32fe36cfdc1cc3e02869cb2b739368c89ef69aa762b8f618', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/first-island/1/512.webp', 'image', 'image/webp', 15704, '448b8b0e7b1ad632fd870d7343fbdeb1df131b976a26deed927de70d3c1b825e', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/goal-1/1/256.webp', 'image', 'image/webp', 9848, 'bff18934ef33281a26d4809cab4cffbc6847ea2e458ab365e32a97a159538f6a', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/goal-1/1/512.webp', 'image', 'image/webp', 18576, '37bbae4e067de1e07f54eafbc5766a84c0a95caf2553cebe26867dd2008a7851', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/goal-10/1/256.webp', 'image', 'image/webp', 9900, 'd4d4926fb968d2c95b58a92d0340f2cccbf1ca86177653d65112625e0e5006e2', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/goal-10/1/512.webp', 'image', 'image/webp', 18728, 'ca243dad42dd33b376bc9549283d8639161b581463b539b5ac7b8cf304c93439', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/letters/1/256.webp', 'image', 'image/webp', 8484, 'c3e042571781306700e63b49b0e28d8b478db3e5c83881c1ad0d51826f30def8', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/letters/1/512.webp', 'image', 'image/webp', 15234, '42b11f67a8174f783c0afab0fcbaef62fa076b9e84c0bf9fc31bc2cf4007e898', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/numbers/1/256.webp', 'image', 'image/webp', 8680, '0e4eb26ad292ccd9a091e1eeffdde99f9a87f6ec09670bd1460715441c263873', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/numbers/1/512.webp', 'image', 'image/webp', 15824, 'd40e6fab7ae61675e59b156687dfd56ed06fa64d1c2727a5e95275d3f9547d02', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/shapes/1/256.webp', 'image', 'image/webp', 8504, '00c390e95a476ff76929d929f83996898437079f63c425a0a0d890f9cb494cf8', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/shapes/1/512.webp', 'image', 'image/webp', 15314, 'a80ba5ffc2aa448ca0402d6edd48c2e41584e581ecfc6b14922457cdee421fe8', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/stars-100/1/256.webp', 'image', 'image/webp', 8924, '9aeab83755661fb18c54ef8593384574e490f68cc9b2d123b0cae9bc42d7e443', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/stars-100/1/512.webp', 'image', 'image/webp', 16724, 'b2ca32d22339498a022cb5a810398edbfce82adbab6318a9e4e2b34d72711a92', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/stars-25/1/256.webp', 'image', 'image/webp', 8922, '4f284f65853b84dcd75482a4e1d4e1675f67abffabf2ba9f3c87db2d51645720', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/stars-25/1/512.webp', 'image', 'image/webp', 16852, '035d4472984e624ae8787c8b827a8b2d2a55253bdd1519a9f20b0051175cdf3e', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/streak-3/1/256.webp', 'image', 'image/webp', 8558, '3a8336c5e0ea10d34349f7058d92b7c8a139a88fb2296dd261f369089501b27b', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/streak-3/1/512.webp', 'image', 'image/webp', 15902, '29921031f131e15dd996d0b4e03aa1109504b10d92f7d3b63d140088afff2652', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/streak-30/1/256.webp', 'image', 'image/webp', 8338, '0b70f4547e325235a7d7b7ee9ebca82e2e544ac5d4c8b51c31fec0d0e1a42d7d', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/streak-30/1/512.webp', 'image', 'image/webp', 14724, '7c3627e22d5fe417958bd6a7f5cbe450581fe766af2e411769010e7258f66c99', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/streak-7/1/256.webp', 'image', 'image/webp', 8814, '4ee3ca3e92572de1a5929aa91b3c9da9615840da28dde066a5bc2b954ab55399', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/streak-7/1/512.webp', 'image', 'image/webp', 16060, '8a0b9d2d5e570d93626b65e3fe0f8a6d705f604cc7bc26e199a984b8a930a9da', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/thinking/1/256.webp', 'image', 'image/webp', 8346, '0cdf7dd9591c960c2072670eae760e4246a1cd66963476f2de531a9ec4c46b1e', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/thinking/1/512.webp', 'image', 'image/webp', 15186, 'ce215bfdfb3bbae1e2a66031eddae4d66a7db7ed56e35e1e0048b84c79253fc4', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/week-1/1/256.webp', 'image', 'image/webp', 8638, '09600007cf84a7bf8f336fbb6aa81e67f2c0e2d85a6e990a2429e7069504411b', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/week-1/1/512.webp', 'image', 'image/webp', 15562, '7aebb530b9980c563a6c294e8e1ee43562ed846822b9f926a2da1e52de9eed75', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'badges/week-4/1/256.webp', 'image', 'image/webp', 8502, 'ddcc030d78f8d18bdaabb897f2873d1d0a210bf0d357630925bfa2226021d316', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'badges/week-4/1/512.webp', 'image', 'image/webp', 15350, '153e08c2e23d91067ffa0cd16c2acdbbef6051aed55e6fd53944eaf7e3ec51a7', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/calm-breathing/1/256.webp', 'image', 'image/webp', 1334, 'af66d292b92923b9c6abdfab78eeac2e5f88ce61211dfcddd0f407833c7b21f6', 256, 160, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/calm-breathing/1/512.webp', 'image', 'image/webp', 2506, 'bf2892feec36bd9a2c7b7474e4779232ac403eb092556b1f9ea6c1a868b5bf1f', 512, 320, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/counting-train/1/256.webp', 'image', 'image/webp', 3138, '0cb2bee63262a85988c92750c0d6d9402ae5eec10b8a4e4539b3c63772076f33', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/counting-train/1/512.webp', 'image', 'image/webp', 5646, '64c8c91de166f1eae1196a790b04134b4299304ec56cad3d586cda38db071481', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/feelings-song/1/256.webp', 'image', 'image/webp', 2884, '64eb850257c3aab948986bd242e598f912013779cca9b2ec449fadce301540a1', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/feelings-song/1/512.webp', 'image', 'image/webp', 6826, 'cb41aa56253a9b176b0eb6c961a0cb124e8dbd487262f2302d49c5f1f458fb77', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/moon-lullaby/1/256.webp', 'image', 'image/webp', 2452, 'e2139ad70c5d800e1f241e22bdea9a8bee6c070c708402e44521fe35eb66e7b2', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/moon-lullaby/1/512.webp', 'image', 'image/webp', 5626, 'e27ce290918cac3c7de75f075372e7d366ba9278debcf677568f8c545b69deb0', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/nova-counts-the-stars/1/256.webp', 'image', 'image/webp', 1356, '02d130d24ff41f52bf1dbb4acda86240c1aa6b57e54bb3dffee166d37190b038', 256, 160, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/nova-counts-the-stars/1/512.webp', 'image', 'image/webp', 2842, '3757151f065f0bcdef92aefedd8f517d22bfdaa014cf4f45f67770fd6bc76e14', 512, 320, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/numbers-on-the-farm/1/256.webp', 'image', 'image/webp', 1484, 'e9bc2e443e9df7c1c000d87a492726b87dbb15ed09792724c5a10ffd2effc243', 256, 144, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/numbers-on-the-farm/1/512.webp', 'image', 'image/webp', 3206, 'e0ba9570a25b4a33e39c8e1b6dbf19f5825cb34eaba85579b23e1fbb919fc345', 512, 288, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/pip-and-the-lost-seed/1/256.webp', 'image', 'image/webp', 1146, '06d514265ae1398af28619ec7da88507019483ad7d16899bd83451e71bf15028', 256, 160, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/pip-and-the-lost-seed/1/512.webp', 'image', 'image/webp', 2422, '2c83a9a0c60a92383bd5bf94cc63bb66600e6e530245c09460edc0108ad87413', 512, 320, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/pip-meets-a-snail/1/256.webp', 'image', 'image/webp', 2278, 'fe7a52e8a974acbb6d0fdcf9349fcaf297c1cd972383b95ebd8958516f3e48bf', 256, 144, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/pip-meets-a-snail/1/512.webp', 'image', 'image/webp', 5222, '83ad39b8f1659515fd9d70dd2c9ca37977dbd22ce5fa9ef9ef4d6f5bb2c1ec1a', 512, 288, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/rainbow-colours/1/256.webp', 'image', 'image/webp', 2352, '704027c7d2829994b339633ad73d893d7cc09ae69af9f3e0b7ad2374692a083c', 256, 144, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/rainbow-colours/1/512.webp', 'image', 'image/webp', 5068, '0551b5a114fb152b503e39dbf17ac505422aa36860fa8f29f7594cc53263e9f7', 512, 288, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/shapes-all-around/1/256.webp', 'image', 'image/webp', 2040, '02b756f4f2823da99b5e9aa46307331b50e78775fa3720791391e9720cd7defa', 256, 144, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/shapes-all-around/1/512.webp', 'image', 'image/webp', 4304, 'f1ca717fb6acc78b9b99bb70ed4e210c0e7835840a65cd0762a8e7a1dae79763', 512, 288, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/ten-little-seeds/1/256.webp', 'image', 'image/webp', 1942, '6f05b370ff224793c59892096d3aa54c2fea5a433a7f74b8170db51dbad7d6c2', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/ten-little-seeds/1/512.webp', 'image', 'image/webp', 4300, '1220f5658ff1ff971942ad39594bc0332226be9f0fb209ae3d7fde65c16dbdb8', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/the-sleepy-cloud/1/256.webp', 'image', 'image/webp', 908, '1cd7073a0f39d12e78c4ad6ca0d8c486ded1394e73164260ce049abb00a3f080', 256, 160, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/the-sleepy-cloud/1/512.webp', 'image', 'image/webp', 1872, '513a85ea8688e48c5743e364109c5ff5a70ba26d84c3e008cae4244ffca0833c', 512, 320, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/tidy-up-tune/1/256.webp', 'image', 'image/webp', 1690, 'cd56dcb6b874d866a893f225c69e372a47f312ce08aa729ab3c193952d66e904', 256, 256, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/tidy-up-tune/1/512.webp', 'image', 'image/webp', 3540, 'afd06648f0769cf6617fdfa9791f85b071c21a483790ba8790020cbae35a091b', 512, 512, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/why-does-it-rain/1/256.webp', 'image', 'image/webp', 1820, '63f202ad1db2ab4468bdd1f9a9054333b21092cb289dc90226eae6ed59e2d1b6', 256, 144, null, null, 'public', 'ready'),
  ('public-assets', 'thumbs/why-does-it-rain/1/512.webp', 'image', 'image/webp', 4008, '8680682d4c61af6c0f313f08be45918d57a7bd5a2f4cba1459621f5b340fec83', 512, 288, null, null, 'public', 'ready'),
  ('video', 'numbers-on-the-farm/mp4/540p.mp4', 'video_mp4', 'video/mp4', 376800, '06ee33ae885714b5311c3b501c8f67ed7fbeafd80cb409b9965040d9ac37767f', 640, 360, 36000, null, 'gated', 'ready'),
  ('video', 'numbers-on-the-farm/subs/en.vtt', 'subtitle', 'text/vtt', 389, '9b4e4d661151fab2a7a70e7c856e09d517e8267bbef8e234ae512b3e70f09d7f', null, null, null, 'en', 'gated', 'ready'),
  ('video', 'pip-meets-a-snail/mp4/540p.mp4', 'video_mp4', 'video/mp4', 529111, '52add4300016d771e93fb382204cd274ab6d2785f669508b28adf303c4d1a7e1', 640, 360, 36000, null, 'gated', 'ready'),
  ('video', 'pip-meets-a-snail/subs/en.vtt', 'subtitle', 'text/vtt', 385, '0253ef4633e21dfa58bd49a1698666c07e8f7da2162111ea3e10d7fd8da1ac7a', null, null, null, 'en', 'gated', 'ready'),
  ('video', 'rainbow-colours/mp4/540p.mp4', 'video_mp4', 'video/mp4', 375320, '599302b8283a4e66c0005164895ed8e9168cc4110da115ac41c3728ea8ecaab0', 640, 360, 32000, null, 'gated', 'ready'),
  ('video', 'rainbow-colours/subs/en.vtt', 'subtitle', 'text/vtt', 288, 'bba84ec8aef9666ff116b8955e7ac7167f6182ac1bb98f1dd916717cde3c945e', null, null, null, 'en', 'gated', 'ready'),
  ('video', 'shapes-all-around/mp4/540p.mp4', 'video_mp4', 'video/mp4', 365006, '42c60d7669fbdc94169a017425aca4f7a408b65d56319d8821900dbee8284ac0', 640, 360, 32000, null, 'gated', 'ready'),
  ('video', 'shapes-all-around/subs/en.vtt', 'subtitle', 'text/vtt', 321, '83e87995509796a7f5723a82c24a05649499377c4f6c85e8f245c7c9ebe7a1cb', null, null, null, 'en', 'gated', 'ready'),
  ('video', 'why-does-it-rain/mp4/540p.mp4', 'video_mp4', 'video/mp4', 539703, '4b8d8f860017494abe48733d65f24f1fe9cfe676ec721d0e73066eed4f5dd7c0', 640, 360, 36000, null, 'gated', 'ready'),
  ('video', 'why-does-it-rain/subs/en.vtt', 'subtitle', 'text/vtt', 282, '5c45eb24d64235b5d65a7596eb6b673d3b430ae86eaa5601175ca05358edcf55', null, null, null, 'en', 'gated', 'ready');
insert into activities (slug, type, title, description, keywords, subject_id, primary_category_id, thumbnail_asset_id,
                        age_min_months, age_max_months, difficulty, players, estimated_seconds,
                        plus_only, free_eligible, status, published_at) values
  ('shapes-all-around', 'video', '{"en":"Shapes all around"}', '{"en":"Circles, squares, triangles, stars and hearts"}', 'shapes circle square triangle', (select id from subjects where key = 'shapes'), (select id from categories where key = 'colours-and-shapes'), (select id from media_assets where object_path = 'thumbs/shapes-all-around/1/512.webp'), 24, 72, 1, 1, 32, false, true, 'published', now() - interval '2 days'),
  ('rainbow-colours', 'video', '{"en":"Rainbow colours"}', '{"en":"Six colours make a rainbow"}', 'colours rainbow', (select id from subjects where key = 'art'), (select id from categories where key = 'colours-and-shapes'), (select id from media_assets where object_path = 'thumbs/rainbow-colours/1/512.webp'), 24, 72, 1, 1, 32, false, true, 'published', now() - interval '2 days'),
  ('tidy-up-tune', 'song', '{"en":"Tidy-up tune"}', '{"en":"A bouncy tune for tidying toys"}', 'tidy song', (select id from subjects where key = 'health'), (select id from categories where key = 'music-time'), (select id from media_assets where object_path = 'thumbs/tidy-up-tune/1/512.webp'), 24, 84, 1, 1, 48, false, true, 'published', now() - interval '2 days'),
  ('moon-lullaby', 'song', '{"en":"Moon lullaby"}', '{"en":"A soft tune for sleepy time"}', 'lullaby bedtime moon', (select id from subjects where key = 'music'), (select id from categories where key = 'bedtime'), (select id from media_assets where object_path = 'thumbs/moon-lullaby/1/512.webp'), 24, 96, 1, 1, 62, false, true, 'published', now() - interval '2 days'),
  ('pip-and-the-lost-seed', 'story', '{"en":"Pip and the lost seed"}', '{"en":"Where did the wind take Pip''s seed?"}', 'story seed garden', (select id from subjects where key = 'nature'), (select id from categories where key = 'garden'), (select id from media_assets where object_path = 'thumbs/pip-and-the-lost-seed/1/512.webp'), 24, 84, 1, 1, 72, false, true, 'published', now() - interval '2 days'),
  ('nova-counts-the-stars', 'story', '{"en":"Nova counts the stars"}', '{"en":"Count to ten under the night sky"}', 'story stars counting night', (select id from subjects where key = 'numbers'), (select id from categories where key = 'space'), (select id from media_assets where object_path = 'thumbs/nova-counts-the-stars/1/512.webp'), 24, 84, 1, 1, 72, false, true, 'published', now() - interval '2 days');
-- the media activities already in §6 / §13: real length, category, thumbnail
update activities set description = '{"en":"A slow, friendly visitor in the garden"}', estimated_seconds = 36, subject_id = (select id from subjects where key = 'nature'), primary_category_id = (select id from categories where key = 'garden'), thumbnail_asset_id = (select id from media_assets where object_path = 'thumbs/pip-meets-a-snail/1/512.webp') where slug = 'pip-meets-a-snail';
update activities set description = '{"en":"Count the sheep with Bolt"}', estimated_seconds = 36, subject_id = (select id from subjects where key = 'numbers'), primary_category_id = (select id from categories where key = 'animals'), thumbnail_asset_id = (select id from media_assets where object_path = 'thumbs/numbers-on-the-farm/1/512.webp') where slug = 'numbers-on-the-farm';
update activities set description = '{"en":"Nova follows a raindrop"}', estimated_seconds = 36, subject_id = (select id from subjects where key = 'science'), primary_category_id = (select id from categories where key = 'weather'), thumbnail_asset_id = (select id from media_assets where object_path = 'thumbs/why-does-it-rain/1/512.webp') where slug = 'why-does-it-rain';
update activities set description = '{"en":"All aboard: one, two, three, four!"}', estimated_seconds = 46, subject_id = (select id from subjects where key = 'music'), primary_category_id = (select id from categories where key = 'music-time'), thumbnail_asset_id = (select id from media_assets where object_path = 'thumbs/counting-train/1/512.webp') where slug = 'counting-train';
update activities set description = '{"en":"Grow and count to ten"}', estimated_seconds = 55, subject_id = (select id from subjects where key = 'numbers'), primary_category_id = (select id from categories where key = 'garden'), thumbnail_asset_id = (select id from media_assets where object_path = 'thumbs/ten-little-seeds/1/512.webp') where slug = 'ten-little-seeds';
update activities set description = '{"en":"Happy, sleepy, cross and calm"}', estimated_seconds = 62, subject_id = (select id from subjects where key = 'feelings'), primary_category_id = (select id from categories where key = 'feelings'), thumbnail_asset_id = (select id from media_assets where object_path = 'thumbs/feelings-song/1/512.webp') where slug = 'feelings-song';
update activities set description = '{"en":"A little cloud looks for a place to rest"}', estimated_seconds = 72, subject_id = (select id from subjects where key = 'feelings'), primary_category_id = (select id from categories where key = 'bedtime'), thumbnail_asset_id = (select id from media_assets where object_path = 'thumbs/the-sleepy-cloud/1/512.webp') where slug = 'the-sleepy-cloud';
update activities set description = '{"en":"A calm story about big feelings"}', estimated_seconds = 72, subject_id = (select id from subjects where key = 'feelings'), primary_category_id = (select id from categories where key = 'feelings'), thumbnail_asset_id = (select id from media_assets where object_path = 'thumbs/calm-breathing/1/512.webp') where slug = 'calm-breathing';
insert into activity_media (activity_id, role, locale, position, asset_id, text) values
  ((select id from activities where slug = 'pip-meets-a-snail'), 'video_main', 'und', 0, (select id from media_assets where object_path = 'pip-meets-a-snail/mp4/540p.mp4'), null),
  ((select id from activities where slug = 'pip-meets-a-snail'), 'subtitle', 'en', 0, (select id from media_assets where object_path = 'pip-meets-a-snail/subs/en.vtt'), null),
  ((select id from activities where slug = 'numbers-on-the-farm'), 'video_main', 'und', 0, (select id from media_assets where object_path = 'numbers-on-the-farm/mp4/540p.mp4'), null),
  ((select id from activities where slug = 'numbers-on-the-farm'), 'subtitle', 'en', 0, (select id from media_assets where object_path = 'numbers-on-the-farm/subs/en.vtt'), null),
  ((select id from activities where slug = 'why-does-it-rain'), 'video_main', 'und', 0, (select id from media_assets where object_path = 'why-does-it-rain/mp4/540p.mp4'), null),
  ((select id from activities where slug = 'why-does-it-rain'), 'subtitle', 'en', 0, (select id from media_assets where object_path = 'why-does-it-rain/subs/en.vtt'), null),
  ((select id from activities where slug = 'shapes-all-around'), 'video_main', 'und', 0, (select id from media_assets where object_path = 'shapes-all-around/mp4/540p.mp4'), null),
  ((select id from activities where slug = 'shapes-all-around'), 'subtitle', 'en', 0, (select id from media_assets where object_path = 'shapes-all-around/subs/en.vtt'), null),
  ((select id from activities where slug = 'rainbow-colours'), 'video_main', 'und', 0, (select id from media_assets where object_path = 'rainbow-colours/mp4/540p.mp4'), null),
  ((select id from activities where slug = 'rainbow-colours'), 'subtitle', 'en', 0, (select id from media_assets where object_path = 'rainbow-colours/subs/en.vtt'), null),
  ((select id from activities where slug = 'counting-train'), 'audio_main', 'en', 0, (select id from media_assets where object_path = 'songs/counting-train/en.m4a'), null),
  ((select id from activities where slug = 'ten-little-seeds'), 'audio_main', 'en', 0, (select id from media_assets where object_path = 'songs/ten-little-seeds/en.m4a'), null),
  ((select id from activities where slug = 'feelings-song'), 'audio_main', 'en', 0, (select id from media_assets where object_path = 'songs/feelings-song/en.m4a'), null),
  ((select id from activities where slug = 'tidy-up-tune'), 'audio_main', 'en', 0, (select id from media_assets where object_path = 'songs/tidy-up-tune/en.m4a'), null),
  ((select id from activities where slug = 'moon-lullaby'), 'audio_main', 'en', 0, (select id from media_assets where object_path = 'songs/moon-lullaby/en.m4a'), null),
  ((select id from activities where slug = 'the-sleepy-cloud'), 'page_image', 'und', 0, (select id from media_assets where object_path = 'the-sleepy-cloud/1/pages/1.webp'), '{"en":"A little cloud floated over the hill. She yawned a big, fluffy yawn."}'),
  ((select id from activities where slug = 'the-sleepy-cloud'), 'page_image', 'und', 1, (select id from media_assets where object_path = 'the-sleepy-cloud/1/pages/2.webp'), '{"en":"The sun was going down, and the sky turned pink and orange."}'),
  ((select id from activities where slug = 'the-sleepy-cloud'), 'page_image', 'und', 2, (select id from media_assets where object_path = 'the-sleepy-cloud/1/pages/3.webp'), '{"en":"Bird flew past. \"Goodnight, little cloud!\" she sang."}'),
  ((select id from activities where slug = 'the-sleepy-cloud'), 'page_image', 'und', 3, (select id from media_assets where object_path = 'the-sleepy-cloud/1/pages/4.webp'), '{"en":"The cloud looked for a soft place to rest. The hill was too pointy."}'),
  ((select id from activities where slug = 'the-sleepy-cloud'), 'page_image', 'und', 4, (select id from media_assets where object_path = 'the-sleepy-cloud/1/pages/5.webp'), '{"en":"The moon came up and made a silver bed in the sky."}'),
  ((select id from activities where slug = 'the-sleepy-cloud'), 'page_image', 'und', 5, (select id from media_assets where object_path = 'the-sleepy-cloud/1/pages/6.webp'), '{"en":"The little cloud curled up, closed her eyes, and drifted off to sleep. Goodnight!"}'),
  ((select id from activities where slug = 'calm-breathing'), 'page_image', 'und', 0, (select id from media_assets where object_path = 'calm-breathing/1/pages/1.webp'), '{"en":"Bolt''s tower of blocks fell down. Crash! Bolt felt cross."}'),
  ((select id from activities where slug = 'calm-breathing'), 'page_image', 'und', 1, (select id from media_assets where object_path = 'calm-breathing/1/pages/2.webp'), '{"en":"His face went hot and his hands went tight."}'),
  ((select id from activities where slug = 'calm-breathing'), 'page_image', 'und', 2, (select id from media_assets where object_path = 'calm-breathing/1/pages/3.webp'), '{"en":"Pip said, \"Let''s smell a flower and blow out a candle.\""}'),
  ((select id from activities where slug = 'calm-breathing'), 'page_image', 'und', 3, (select id from media_assets where object_path = 'calm-breathing/1/pages/4.webp'), '{"en":"Breathe in through your nose... like smelling a flower."}'),
  ((select id from activities where slug = 'calm-breathing'), 'page_image', 'und', 4, (select id from media_assets where object_path = 'calm-breathing/1/pages/5.webp'), '{"en":"Breathe out slowly... like blowing out a candle. Whoosh."}'),
  ((select id from activities where slug = 'calm-breathing'), 'page_image', 'und', 5, (select id from media_assets where object_path = 'calm-breathing/1/pages/6.webp'), '{"en":"Bolt felt calm again. Together, they built an even taller tower!"}'),
  ((select id from activities where slug = 'pip-and-the-lost-seed'), 'page_image', 'und', 0, (select id from media_assets where object_path = 'pip-and-the-lost-seed/1/pages/1.webp'), '{"en":"Pip had one tiny seed. \"Where shall I plant you?\" asked Pip."}'),
  ((select id from activities where slug = 'pip-and-the-lost-seed'), 'page_image', 'und', 1, (select id from media_assets where object_path = 'pip-and-the-lost-seed/1/pages/2.webp'), '{"en":"Whoosh! The wind blew the seed away."}'),
  ((select id from activities where slug = 'pip-and-the-lost-seed'), 'page_image', 'und', 2, (select id from media_assets where object_path = 'pip-and-the-lost-seed/1/pages/3.webp'), '{"en":"Pip looked under a leaf. No seed. Pip looked in a flower. No seed."}'),
  ((select id from activities where slug = 'pip-and-the-lost-seed'), 'page_image', 'und', 3, (select id from media_assets where object_path = 'pip-and-the-lost-seed/1/pages/4.webp'), '{"en":"A snail pointed with its feelers. \"Over there, in the soft soil!\""}'),
  ((select id from activities where slug = 'pip-and-the-lost-seed'), 'page_image', 'und', 4, (select id from media_assets where object_path = 'pip-and-the-lost-seed/1/pages/5.webp'), '{"en":"Rain came, and sun came. A little green shoot popped up."}'),
  ((select id from activities where slug = 'pip-and-the-lost-seed'), 'page_image', 'und', 5, (select id from media_assets where object_path = 'pip-and-the-lost-seed/1/pages/6.webp'), '{"en":"The lost seed had found the perfect home. It grew into a flower!"}'),
  ((select id from activities where slug = 'nova-counts-the-stars'), 'page_image', 'und', 0, (select id from media_assets where object_path = 'nova-counts-the-stars/1/pages/1.webp'), '{"en":"When the sky was dark, Nova liked to count the stars."}'),
  ((select id from activities where slug = 'nova-counts-the-stars'), 'page_image', 'und', 1, (select id from media_assets where object_path = 'nova-counts-the-stars/1/pages/2.webp'), '{"en":"One star, two stars, three stars, twinkling high."}'),
  ((select id from activities where slug = 'nova-counts-the-stars'), 'page_image', 'und', 2, (select id from media_assets where object_path = 'nova-counts-the-stars/1/pages/3.webp'), '{"en":"Four stars, five stars, a little line of light."}'),
  ((select id from activities where slug = 'nova-counts-the-stars'), 'page_image', 'und', 3, (select id from media_assets where object_path = 'nova-counts-the-stars/1/pages/4.webp'), '{"en":"A cloud drifted by and hid some stars. \"Come back!\" said Nova."}'),
  ((select id from activities where slug = 'nova-counts-the-stars'), 'page_image', 'und', 4, (select id from media_assets where object_path = 'nova-counts-the-stars/1/pages/5.webp'), '{"en":"The cloud moved on. Six, seven, eight, nine, ten!"}'),
  ((select id from activities where slug = 'nova-counts-the-stars'), 'page_image', 'und', 5, (select id from media_assets where object_path = 'nova-counts-the-stars/1/pages/6.webp'), '{"en":"\"Goodnight, stars,\" whispered Nova. \"I''ll count you again tomorrow.\""}')
;
insert into collections (slug, surface, kind, title, sort, status, category_id) values
  ('featured-videos', 'watch', 'drop', '{"en":"Featured"}', 1, 'published', null),
  ('shows', 'watch', 'row', '{"en":"Shows"}', 2, 'published', null),
  ('featured-listen', 'listen', 'drop', '{"en":"Featured"}', 3, 'published', null),
  ('songs', 'listen', 'row', '{"en":"Songs"}', 4, 'published', null),
  ('stories', 'listen', 'row', '{"en":"Stories"}', 5, 'published', null),
  ('bedtime-stories', 'listen', 'row', '{"en":"Bedtime stories"}', 6, 'published', null)
on conflict (slug) do update set title = excluded.title, kind = excluded.kind, sort = excluded.sort;
delete from collection_items where collection_id in (select id from collections where slug in ('featured-videos', 'shows', 'featured-listen', 'songs', 'stories', 'bedtime-stories'));
insert into collection_items (collection_id, activity_id, position) values
  ((select id from collections where slug = 'featured-videos'), (select id from activities where slug = 'shapes-all-around'), 0),
  ((select id from collections where slug = 'featured-videos'), (select id from activities where slug = 'pip-meets-a-snail'), 1),
  ((select id from collections where slug = 'shows'), (select id from activities where slug = 'pip-meets-a-snail'), 0),
  ((select id from collections where slug = 'shows'), (select id from activities where slug = 'numbers-on-the-farm'), 1),
  ((select id from collections where slug = 'shows'), (select id from activities where slug = 'why-does-it-rain'), 2),
  ((select id from collections where slug = 'shows'), (select id from activities where slug = 'shapes-all-around'), 3),
  ((select id from collections where slug = 'shows'), (select id from activities where slug = 'rainbow-colours'), 4),
  ((select id from collections where slug = 'featured-listen'), (select id from activities where slug = 'moon-lullaby'), 0),
  ((select id from collections where slug = 'featured-listen'), (select id from activities where slug = 'pip-and-the-lost-seed'), 1),
  ((select id from collections where slug = 'songs'), (select id from activities where slug = 'counting-train'), 0),
  ((select id from collections where slug = 'songs'), (select id from activities where slug = 'ten-little-seeds'), 1),
  ((select id from collections where slug = 'songs'), (select id from activities where slug = 'feelings-song'), 2),
  ((select id from collections where slug = 'songs'), (select id from activities where slug = 'tidy-up-tune'), 3),
  ((select id from collections where slug = 'songs'), (select id from activities where slug = 'moon-lullaby'), 4),
  ((select id from collections where slug = 'stories'), (select id from activities where slug = 'pip-and-the-lost-seed'), 0),
  ((select id from collections where slug = 'stories'), (select id from activities where slug = 'nova-counts-the-stars'), 1),
  ((select id from collections where slug = 'stories'), (select id from activities where slug = 'the-sleepy-cloud'), 2),
  ((select id from collections where slug = 'stories'), (select id from activities where slug = 'calm-breathing'), 3),
  ((select id from collections where slug = 'bedtime-stories'), (select id from activities where slug = 'the-sleepy-cloud'), 0),
  ((select id from collections where slug = 'bedtime-stories'), (select id from activities where slug = 'moon-lullaby'), 1),
  ((select id from collections where slug = 'bedtime-stories'), (select id from activities where slug = 'calm-breathing'), 2)
;

-- ---------------------------------------------------------------------------
-- 17. Badges (Phase 12, docs/gamification/achievement-system.md). Unlock rules are evaluated by
-- private.apply_rewards; artwork from content/dev-media/make_dev_media.py (§16 registers it).
-- ---------------------------------------------------------------------------
insert into rewards (type, key, title, description, how_to_earn, asset_id, rarity, unlock_rule, rule_params,
                     bonus_stars, sort, status) values
  ('badge', 'badge-first-game', '{"en":"First game"}', '{"en":"You finished your very first game."}', '{"en":"Finish any game."}', (select id from media_assets where object_path = 'badges/first-game/1/512.webp'), 'special', 'first_game', '{}', 1, 1, 'active'),
  ('badge', 'badge-first-island', '{"en":"First island"}', '{"en":"You finished every step of an island."}', '{"en":"Finish all the steps of one island on a learning path."}', (select id from media_assets where object_path = 'badges/first-island/1/512.webp'), 'special', 'first_lesson', '{}', 2, 2, 'active'),
  ('badge', 'badge-first-course', '{"en":"Course champion"}', '{"en":"You finished a whole course. Amazing!"}', '{"en":"Finish every island of a course."}', (select id from media_assets where object_path = 'badges/first-course/1/512.webp'), 'special', 'first_course', '{}', 3, 3, 'active'),
  ('badge', 'badge-goal-1', '{"en":"Goal getter"}', '{"en":"You reached your goal for the day."}', '{"en":"Reach your daily goal once."}', (select id from media_assets where object_path = 'badges/goal-1/1/512.webp'), 'common', 'daily_goals', '{"count":1}', 1, 10, 'active'),
  ('badge', 'badge-goal-10', '{"en":"Goal keeper"}', '{"en":"Ten days of reaching your goal."}', '{"en":"Reach your daily goal on 10 different days."}', (select id from media_assets where object_path = 'badges/goal-10/1/512.webp'), 'rare', 'daily_goals', '{"count":10}', 2, 11, 'active'),
  ('badge', 'badge-week-1', '{"en":"Great week"}', '{"en":"You learned on lots of days this week."}', '{"en":"Reach your weekly goal once."}', (select id from media_assets where object_path = 'badges/week-1/1/512.webp'), 'common', 'weekly_goals', '{"count":1}', 2, 12, 'active'),
  ('badge', 'badge-week-4', '{"en":"Steady learner"}', '{"en":"Four great weeks of learning, bit by bit."}', '{"en":"Reach your weekly goal in 4 different weeks."}', (select id from media_assets where object_path = 'badges/week-4/1/512.webp'), 'rare', 'weekly_goals', '{"count":4}', 3, 13, 'active'),
  ('badge', 'badge-streak-3', '{"en":"Three learning days"}', '{"en":"You learned on three days in a row."}', '{"en":"Learn on 3 days in a row. One rest day in between is fine."}', (select id from media_assets where object_path = 'badges/streak-3/1/512.webp'), 'common', 'streak', '{"days":3}', 1, 20, 'active'),
  ('badge', 'badge-streak-7', '{"en":"Seven learning days"}', '{"en":"Seven learning days in a row!"}', '{"en":"Learn on 7 days in a row. One rest day in between is fine."}', (select id from media_assets where object_path = 'badges/streak-7/1/512.webp'), 'common', 'streak', '{"days":7}', 2, 21, 'active'),
  ('badge', 'badge-streak-30', '{"en":"Thirty learning days"}', '{"en":"Thirty learning days: learning is your habit!"}', '{"en":"Learn on 30 days in a row. One rest day in between is fine."}', (select id from media_assets where object_path = 'badges/streak-30/1/512.webp'), 'rare', 'streak', '{"days":30}', 3, 22, 'active'),
  ('badge', 'badge-numbers', '{"en":"Number explorer"}', '{"en":"You explored lots of number activities."}', '{"en":"Finish 5 different number activities."}', (select id from media_assets where object_path = 'badges/numbers/1/512.webp'), 'common', 'subject_explorer', '{"subject":"numbers","count":5}', 2, 30, 'active'),
  ('badge', 'badge-letters', '{"en":"Letter explorer"}', '{"en":"You explored lots of letter activities."}', '{"en":"Finish 4 different letter activities."}', (select id from media_assets where object_path = 'badges/letters/1/512.webp'), 'common', 'subject_explorer', '{"subject":"letters","count":4}', 2, 31, 'active'),
  ('badge', 'badge-shapes', '{"en":"Shape explorer"}', '{"en":"You explored lots of shapes and colours."}', '{"en":"Finish 4 different shape and colour activities."}', (select id from media_assets where object_path = 'badges/shapes/1/512.webp'), 'common', 'subject_explorer', '{"subject":"shapes","count":4}', 2, 32, 'active'),
  ('badge', 'badge-thinking', '{"en":"Puzzle explorer"}', '{"en":"You solved lots of thinking puzzles."}', '{"en":"Finish 3 different thinking activities."}', (select id from media_assets where object_path = 'badges/thinking/1/512.webp'), 'common', 'subject_explorer', '{"subject":"thinking","count":3}', 2, 33, 'active'),
  ('badge', 'badge-stars-25', '{"en":"25 stars"}', '{"en":"Stars from 25 finished activities."}', '{"en":"Collect 25 activity stars."}', (select id from media_assets where object_path = 'badges/stars-25/1/512.webp'), 'rare', 'stars', '{"count":25}', 0, 40, 'active'),
  ('badge', 'badge-stars-100', '{"en":"100 stars"}', '{"en":"Stars from 100 finished activities. Wow!"}', '{"en":"Collect 100 activity stars."}', (select id from media_assets where object_path = 'badges/stars-100/1/512.webp'), 'rare', 'stars_100', '{}', 0, 41, 'active')
on conflict (key) do update set title = excluded.title, description = excluded.description, how_to_earn = excluded.how_to_earn, asset_id = excluded.asset_id, rarity = excluded.rarity, unlock_rule = excluded.unlock_rule, rule_params = excluded.rule_params, bonus_stars = excluded.bonus_stars, sort = excluded.sort, status = excluded.status;
-- <<< generated

-- ---------------------------------------------------------------------------
-- 18. Mia's rewards (Phase 12), worked out by the real rules: her island-1 sessions two days
-- ago get their activity stars (one per activity per day, as apply_session would have), then
-- private.apply_rewards runs over every completed session in order. Result: stars ledger,
-- daily goals, the learning-days streak and badges (first game, first island, goal getter).
-- ---------------------------------------------------------------------------
insert into star_awards (child_id, local_date, activity_id, session_id)
select distinct on (s.child_id, s.local_date, s.activity_id) s.child_id, s.local_date, s.activity_id, s.id
from activity_sessions s join child_profiles ch on ch.id = s.child_id
where ch.nickname = 'Mia' and s.status = 'completed'
order by s.child_id, s.local_date, s.activity_id, s.started_at
on conflict do nothing;
delete from daily_progress where child_id in (select id from child_profiles where nickname = 'Mia');
insert into daily_progress (child_id, local_date, sessions_started, sessions_completed, seconds_played, stars)
select s.child_id, s.local_date, count(*), count(*) filter (where s.status = 'completed'),
       coalesce(sum(extract(epoch from (s.ended_at - s.started_at)))::int, 0),
       (select count(*) from star_awards a where a.child_id = s.child_id and a.local_date = s.local_date)
from activity_sessions s join child_profiles ch on ch.id = s.child_id
where ch.nickname = 'Mia' group by s.child_id, s.local_date;
select private.apply_rewards(s.id)
from activity_sessions s join child_profiles ch on ch.id = s.child_id
where ch.nickname = 'Mia' and s.status = 'completed' order by s.started_at;
