-- =============================================================================
-- Kids Learning Platform: DATABASE DESIGN DRAFT v0.2 (2026-11-17)
--
--   *** NOT A MIGRATION. DO NOT APPLY TO ANY SUPABASE PROJECT. ***
--   This file documents the proposed schema so it can be reviewed and
--   syntax-checked on a throwaway local Postgres. It becomes
--   supabase/migrations/0001_init.sql only after the architecture is approved.
--
-- Supersedes replica/schema.sql (v0.1, different stack and entity names).
-- Target: Supabase Postgres 15+/16+. Relies on Supabase's auth.users,
-- auth.uid() and auth.jwt().
--
-- CONVENTIONS
--   * uuid primary keys (gen_random_uuid()) except pure join / tally tables,
--     which use natural composite keys.
--   * created_at / updated_at on every mutable table, timestamptz, UTC.
--   * "local_date" = the household's calendar day, computed SERVER-SIDE from
--     parent_accounts.timezone. Never from the device clock.
--   * Status fields use CHECK constraints (easier to evolve than enums).
--   * Money: integer minor units (amount_minor bigint) + ISO 4217 currency.
--   * Localised text: jsonb {"en": "...", "es": "..."}.
--   * Every FK has an explicit ON DELETE rule.
--   * Content rows (activities, courses ...) are never hard-deleted once
--     published: they are retired. Child data is hard-deleted on request.
--
-- ACCESS MODEL (see 06-auth-and-authorization.md)
--   * RLS is enabled on every table in public.
--   * Parents / kids apps: READ through RLS only. All their WRITES go through
--     Edge Functions (service role) after explicit checks.
--   * Admin web: reads and writes catalogue tables with the admin's own JWT;
--     RLS checks RBAC permissions AND MFA (aal2). The admin web never holds
--     the service-role key. Publishing needs a separate permission (trigger).
--   * Audit: sensitive tables carry an audit trigger into an append-only log.
-- =============================================================================

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

create schema if not exists private;    -- helpers; NOT exposed through the Data API
create schema if not exists analytics;  -- first-party events; NOT exposed

create or replace function private.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- =============================================================================
-- 1. ADMIN RBAC (needed first: the permission helper reads these tables)
-- =============================================================================

create table admin_users (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  status       text not null default 'active' check (status in ('active','suspended')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table admin_roles (
  key          text primary key check (key ~ '^[a-z_]+$'),
  description  text not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table admin_permissions (
  key          text primary key check (key ~ '^[a-z_]+\.[a-z_]+$'),   -- 'content.publish'
  description  text not null,
  created_at   timestamptz not null default now()
);

create table admin_role_permissions (
  role_key        text not null references admin_roles(key) on delete cascade,
  permission_key  text not null references admin_permissions(key) on delete cascade,
  created_at      timestamptz not null default now(),
  primary key (role_key, permission_key)
);
create index on admin_role_permissions (permission_key);

create table admin_user_roles (
  user_id     uuid not null references admin_users(user_id) on delete cascade,
  role_key    text not null references admin_roles(key) on delete restrict,
  granted_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  primary key (user_id, role_key)
);
create index on admin_user_roles (role_key);
create index on admin_user_roles (granted_by);

-- =============================================================================
-- 2. FAMILY: parent accounts, parent profiles, consent, child profiles, devices
-- =============================================================================

-- The household. Owns children, subscription, settings. (A school later.)
create table parent_accounts (
  id              uuid primary key default gen_random_uuid(),
  owner_user_id   uuid not null references auth.users(id) on delete restrict,
  status          text not null default 'active'
                    check (status in ('active','pending_deletion','suspended')),
  timezone        text not null default 'UTC',      -- IANA name
  country         char(2),                           -- ISO 3166-1 alpha-2
  ui_locale       text not null default 'en',
  content_locale  text not null default 'en',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index on parent_accounts (owner_user_id);

-- One row per signed-in adult. v1: one account per user; co-parents later.
create table parent_profiles (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  account_id        uuid not null references parent_accounts(id) on delete cascade,
  role              text not null default 'owner' check (role in ('owner','co_parent')),
  display_name      text check (char_length(display_name) <= 60),
  marketing_opt_in  boolean not null default false,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index on parent_profiles (account_id);

-- Evidence of parental consent and policy acceptance. Append-mostly; revocation
-- sets revoked_at. Required by COPPA (verifiable parental consent) and GDPR Art. 8.
create table parental_consents (
  id              uuid primary key default gen_random_uuid(),
  account_id      uuid not null references parent_accounts(id) on delete cascade,
  user_id         uuid references auth.users(id) on delete set null,
  consent_type    text not null check (consent_type in
                    ('terms','privacy_policy','child_data_collection',
                     'third_party_disclosure','marketing_email','push_notifications')),
  policy_version  text not null,
  method          text not null check (method in
                    ('email_plus','payment_card','store_purchase','signed_form','checkbox')),
  granted_at      timestamptz not null default now(),
  revoked_at      timestamptz,
  evidence        jsonb not null default '{}',   -- hashed IP, user-agent class, email message id
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint revoke_after_grant check (revoked_at is null or revoked_at >= granted_at)
);
create index on parental_consents (account_id, consent_type);
create index on parental_consents (user_id);

-- Every stored file. Bytes live in Supabase Storage; this is the registry.
create table media_assets (
  id           uuid primary key default gen_random_uuid(),
  bucket       text not null check (bucket in ('public-assets','content','video')),
  object_path  text not null,
  kind         text not null check (kind in
                 ('image','audio','video_hls','video_mp4','subtitle','rive','lottie','game_pack','pdf')),
  mime_type    text not null,
  bytes        bigint not null check (bytes >= 0),
  sha256       text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  width        integer check (width > 0),
  height       integer check (height > 0),
  duration_ms  integer check (duration_ms >= 0),
  locale       text,                                -- null = language-neutral
  access       text not null default 'gated' check (access in ('public','gated')),
  status       text not null default 'uploaded'
                 check (status in ('uploaded','processing','ready','failed','retired')),
  created_by   uuid references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (bucket, object_path),
  constraint public_bucket_is_public check ((bucket = 'public-assets') = (access = 'public'))
);
create index on media_assets (kind, status);
create index on media_assets (created_by);

create table avatars (
  id          uuid primary key default gen_random_uuid(),
  key         text not null unique,
  asset_id    uuid not null references media_assets(id) on delete restrict,
  sort        smallint not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index on avatars (asset_id);

-- Child profile. No auth user, no email. Data minimisation: a nickname and
-- birth YEAR+MONTH only (day forced to 1). analytics_id is the only key used
-- in analytics; deleting the child breaks the link and anonymises the events.
create table child_profiles (
  id                 uuid primary key default gen_random_uuid(),
  account_id         uuid not null references parent_accounts(id) on delete cascade,
  nickname           text not null check (char_length(nickname) between 1 and 20),
  avatar_id          uuid references avatars(id) on delete set null,
  birth_year_month   date not null check (extract(day from birth_year_month) = 1),
  learning_stage     text not null default 'auto' check (learning_stage in
                       ('auto','toddler','preschool','kindergarten','grade1','grade2')),
  content_locale     text,                          -- null = account default
  analytics_id       uuid not null default gen_random_uuid() unique,
  status             text not null default 'active' check (status in ('active','archived')),
  sort               smallint not null default 0,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index on child_profiles (account_id);
create index on child_profiles (avatar_id);

-- An installed app (or a browser). Push token and download ownership hang off it.
create table devices (
  id                     uuid primary key default gen_random_uuid(),
  account_id             uuid not null references parent_accounts(id) on delete cascade,
  user_id                uuid references auth.users(id) on delete set null,
  install_id             text not null unique,      -- random per install, generated on device
  platform               text not null check (platform in ('ios','android','web')),
  app_version            text not null,
  os_version             text,
  push_token             text unique,
  push_token_updated_at  timestamptz,
  last_seen_at           timestamptz not null default now(),
  revoked_at             timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create index on devices (account_id);
create index on devices (user_id);

-- =============================================================================
-- 3. CONTENT CATALOGUE (authored in the admin web)
-- =============================================================================

-- Browsing themes ("Animals", "Space", "Vehicles"); a tree.
create table categories (
  id             uuid primary key default gen_random_uuid(),
  parent_id      uuid references categories(id) on delete restrict,
  key            text not null unique,
  name           jsonb not null,
  icon_asset_id  uuid references media_assets(id) on delete set null,
  sort           integer not null default 0,
  status         text not null default 'draft' check (status in ('draft','published','retired')),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint not_own_parent check (parent_id is null or parent_id <> id)
);
create index on categories (parent_id);
create index on categories (icon_asset_id);

-- Curriculum areas: English, Literacy, Maths, Science, Social-emotional ...
create table subjects (
  id             uuid primary key default gen_random_uuid(),
  key            text not null unique,
  name           jsonb not null,
  icon_asset_id  uuid references media_assets(id) on delete set null,
  sort           integer not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index on subjects (icon_asset_id);

create table skills (
  id           uuid primary key default gen_random_uuid(),
  subject_id   uuid references subjects(id) on delete restrict,   -- null = cross-subject
  key          text not null unique,
  skill_group  text not null check (skill_group in
                 ('movement','language','literacy_numeracy','thinking','social_life')),
  name         jsonb not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index on skills (subject_id);

-- A reusable game mechanic (E1..E12), versioned. Activities = template + config + assets.
create table game_templates (
  id                   uuid primary key default gen_random_uuid(),
  key                  text not null,                  -- 'drag_to_target'
  version              text not null check (version ~ '^\d+\.\d+\.\d+$'),
  runtime              text not null default 'flame' check (runtime in ('flame','rive','unity')),
  orientation          text not null default 'landscape'
                         check (orientation in ('landscape','portrait','any')),
  supported_platforms  text[] not null default '{ios,android,web}'
                         check (supported_platforms <@ array['ios','android','web']
                                and cardinality(supported_platforms) > 0),
  config_schema        jsonb not null default '{}',     -- JSON Schema for games.config
  min_app_build        integer not null default 1,
  status               text not null default 'draft' check (status in ('draft','active','deprecated')),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (key, version),
  constraint unity_not_on_web check (runtime <> 'unity' or not ('web' = any(supported_platforms)))
);

-- Every playable or watchable item. Subtype rows: games (1:1), questions (1:n).
create table activities (
  id                   uuid primary key default gen_random_uuid(),
  slug                 text not null unique,
  type                 text not null check (type in
                         ('game','video','song','story','audiobook','quiz','printable','offline_activity')),
  title                jsonb not null,
  description          jsonb not null default '{}',
  keywords             text not null default '',
  subject_id           uuid references subjects(id) on delete restrict,
  primary_category_id  uuid references categories(id) on delete set null,
  thumbnail_asset_id   uuid references media_assets(id) on delete restrict,
  age_min_months       smallint not null default 24 check (age_min_months between 0 and 144),
  age_max_months       smallint not null default 96 check (age_max_months between 0 and 144),
  difficulty           smallint not null default 1 check (difficulty between 1 and 5),
  players              smallint not null default 1 check (players in (1,2)),
  estimated_seconds    integer check (estimated_seconds > 0),
  plus_only            boolean not null default true,
  free_eligible        boolean not null default true,   -- may enter the Basic daily allocation
  locales              text[] not null default '{en}',
  status               text not null default 'draft'
                         check (status in ('draft','in_review','published','retired')),
  content_version      integer not null default 1 check (content_version > 0),
  published_at         timestamptz,
  published_by         uuid references auth.users(id) on delete set null,
  search_tsv           tsvector generated always as
                         (to_tsvector('simple', coalesce(title->>'en','') || ' ' || keywords)) stored,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (id, type),                                       -- target of subtype FKs
  constraint age_range check (age_min_months <= age_max_months),
  constraint published_has_date check (status <> 'published' or published_at is not null)
);
create index on activities (status, type, age_min_months, age_max_months);
create index on activities (subject_id);
create index on activities (primary_category_id);
create index on activities (thumbnail_asset_id);
create index on activities (published_by);
create index on activities using gin (search_tsv);
create index on activities using gin ((title->>'en') gin_trgm_ops);

create table activity_categories (
  activity_id  uuid not null references activities(id) on delete cascade,
  category_id  uuid not null references categories(id) on delete restrict,
  created_at   timestamptz not null default now(),
  primary key (activity_id, category_id)
);
create index on activity_categories (category_id);

create table activity_skills (
  activity_id  uuid not null references activities(id) on delete cascade,
  skill_id     uuid not null references skills(id) on delete restrict,
  weight       numeric(3,2) not null default 1.00 check (weight > 0 and weight <= 1),
  is_primary   boolean not null default false,              -- the pill on the card
  created_at   timestamptz not null default now(),
  primary key (activity_id, skill_id)
);
create index on activity_skills (skill_id);
create unique index one_primary_skill on activity_skills (activity_id) where is_primary;

create table activity_media (
  activity_id  uuid not null references activities(id) on delete cascade,
  role         text not null check (role in
                 ('video_main','audio_main','subtitle','cover','page_image','page_audio','printable_pdf')),
  locale       text not null default 'und',                -- 'und' = language-neutral
  position     smallint not null default 0,                -- page order for stories
  asset_id     uuid not null references media_assets(id) on delete restrict,
  created_at   timestamptz not null default now(),
  primary key (activity_id, role, locale, position)
);
create index on activity_media (asset_id);

-- Game subtype. The composite FK guarantees the parent activity IS a game.
create table games (
  activity_id        uuid primary key,
  activity_type      text not null default 'game' check (activity_type = 'game'),
  template_id        uuid not null references game_templates(id) on delete restrict,
  config             jsonb not null default '{}',     -- validated against template.config_schema
  pack_asset_id      uuid references media_assets(id) on delete restrict,  -- art + audio bundle
  character_pick     boolean not null default false,
  needs_permissions  text[] not null default '{}'
                       check (needs_permissions <@ array['microphone','camera']),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  foreign key (activity_id, activity_type) references activities(id, type) on delete cascade
);
create index on games (template_id);
create index on games (pack_asset_id);

-- Questions: quizzes, knowledge checks, question-driven game templates.
create table questions (
  id                     uuid primary key default gen_random_uuid(),
  activity_id            uuid not null references activities(id) on delete cascade,
  position               smallint not null check (position >= 0),
  type                   text not null check (type in
                           ('single_choice','multi_choice','true_false','match','order',
                            'tap_target','listen_choose')),
  prompt                 jsonb not null,                -- localised text
  prompt_audio_asset_id  uuid references media_assets(id) on delete restrict,
  prompt_image_asset_id  uuid references media_assets(id) on delete restrict,
  skill_id               uuid references skills(id) on delete restrict,
  difficulty             smallint not null default 1 check (difficulty between 1 and 5),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  unique (activity_id, position)
);
create index on questions (skill_id);
create index on questions (prompt_audio_asset_id);
create index on questions (prompt_image_asset_id);

-- Authored answer options (what the child can pick), not the child's responses.
create table answers (
  id              uuid primary key default gen_random_uuid(),
  question_id     uuid not null references questions(id) on delete cascade,
  position        smallint not null check (position >= 0),
  content         jsonb not null default '{}',
  image_asset_id  uuid references media_assets(id) on delete restrict,
  audio_asset_id  uuid references media_assets(id) on delete restrict,
  is_correct      boolean not null default false,
  match_key       text,                    -- pairs for 'match'
  correct_order   smallint,                -- for 'order'
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (question_id, position)
);
create index on answers (image_asset_id);
create index on answers (audio_asset_id);

-- Courses = the original's "Lessons" programmes.
--   course -> course_module (the original's "workbook") -> lesson ("unit")
--   -> lesson_step ("node": knowledge check, collect, trace ...).
create table courses (
  id               uuid primary key default gen_random_uuid(),
  slug             text not null unique,
  kind             text not null default 'solo' check (kind in ('solo','learn_together')),
  title            jsonb not null,
  description      jsonb not null default '{}',
  subject_id       uuid references subjects(id) on delete restrict,
  primary_skill_id uuid references skills(id) on delete set null,
  stage            text not null check (stage in ('toddler','preschool','kindergarten','grade1','grade2')),
  cover_asset_id   uuid references media_assets(id) on delete restrict,
  plus_only        boolean not null default true,
  sort             integer not null default 0,
  status           text not null default 'draft'
                     check (status in ('draft','in_review','published','retired')),
  published_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint published_has_date check (status <> 'published' or published_at is not null)
);
create index on courses (status, stage, sort);
create index on courses (subject_id);
create index on courses (primary_skill_id);
create index on courses (cover_asset_id);

create table course_modules (
  id          uuid primary key default gen_random_uuid(),
  course_id   uuid not null references courses(id) on delete cascade,
  position    smallint not null check (position >= 0),
  title       jsonb not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (course_id, position)
);

create table lessons (
  id              uuid primary key default gen_random_uuid(),
  module_id       uuid not null references course_modules(id) on delete cascade,
  position        smallint not null check (position >= 0),
  title           jsonb not null,
  cover_asset_id  uuid references media_assets(id) on delete restrict,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (module_id, position)
);
create index on lessons (cover_asset_id);

create table lesson_steps (
  id           uuid primary key default gen_random_uuid(),
  lesson_id    uuid not null references lessons(id) on delete cascade,
  position     smallint not null check (position >= 0),
  step_type    text not null check (step_type in
                 ('knowledge_check','intro','practice','collect','trace','video','story','song','review')),
  activity_id  uuid not null references activities(id) on delete restrict,
  required     boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (lesson_id, position)
);
create index on lesson_steps (activity_id);

-- An ordered sequence of courses for a stage ("Preschool path").
create table learning_paths (
  id              uuid primary key default gen_random_uuid(),
  slug            text not null unique,
  title           jsonb not null,
  description     jsonb not null default '{}',
  stage           text not null check (stage in ('toddler','preschool','kindergarten','grade1','grade2')),
  age_min_months  smallint not null check (age_min_months between 0 and 144),
  age_max_months  smallint not null check (age_max_months between 0 and 144),
  status          text not null default 'draft' check (status in ('draft','published','retired')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint age_range check (age_min_months <= age_max_months)
);
create index on learning_paths (status, stage);

create table learning_path_courses (
  path_id     uuid not null references learning_paths(id) on delete cascade,
  course_id   uuid not null references courses(id) on delete restrict,
  position    smallint not null check (position >= 0),
  created_at  timestamptz not null default now(),
  primary key (path_id, course_id),
  unique (path_id, position)
);
create index on learning_path_courses (course_id);

-- Feed rows, worlds, weekly drops: scheduled content, not hard-coded screens.
create table collections (
  id              uuid primary key default gen_random_uuid(),
  slug            text not null unique,
  surface         text not null check (surface in ('home','learn','watch','listen','explore')),  -- kids rail sections (docs/design/README.md §2)
  kind            text not null check (kind in
                    ('daily_picks','world','topic','row','drop','most_played','whats_new')),
  title           jsonb not null,
  art_asset_id    uuid references media_assets(id) on delete set null,
  category_id     uuid references categories(id) on delete set null,
  age_min_months  smallint not null default 0 check (age_min_months between 0 and 144),
  age_max_months  smallint not null default 144 check (age_max_months between 0 and 144),
  plus_only       boolean not null default false,
  sort            integer not null default 0,
  starts_at       timestamptz,
  ends_at         timestamptz,
  status          text not null default 'draft' check (status in ('draft','published','retired')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint window_ok check (ends_at is null or starts_at is null or ends_at > starts_at)
);
create index on collections (surface, status, sort);
create index on collections (starts_at, ends_at);
create index on collections (art_asset_id);
create index on collections (category_id);

create table collection_items (
  collection_id  uuid not null references collections(id) on delete cascade,
  activity_id    uuid not null references activities(id) on delete cascade,
  position       integer not null check (position >= 0),
  created_at     timestamptz not null default now(),
  primary key (collection_id, activity_id),
  unique (collection_id, position)
);
create index on collection_items (activity_id);

-- Rewards catalogue: stickers (grouped in sets), scenes, badges, avatar items.
create table reward_sets (
  id          uuid primary key default gen_random_uuid(),
  key         text not null unique,
  title       jsonb not null,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table rewards (
  id          uuid primary key default gen_random_uuid(),
  set_id      uuid references reward_sets(id) on delete restrict,
  type        text not null check (type in ('sticker','scene','badge','avatar_item')),
  key         text not null unique,
  title       jsonb not null,
  asset_id    uuid not null references media_assets(id) on delete restrict,
  rarity      text not null default 'common' check (rarity in ('common','rare','special')),
  unlock_rule text,                 -- badges only: a named rule evaluated by the progress engine
  status      text not null default 'active' check (status in ('draft','active','retired')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (id, type),
  constraint sticker_in_set check (type <> 'sticker' or set_id is not null),
  constraint badge_has_rule check (type <> 'badge' or unlock_rule is not null)
);
create index on rewards (set_id);
create index on rewards (asset_id);

-- "Island prize" [design K10]: an optional sticker given once when a lesson is completed.
alter table lessons add column prize_reward_id uuid references rewards(id) on delete set null;
create index on lessons (prize_reward_id);

-- =============================================================================
-- 4. PLAY, RESULTS AND LEARNING PROGRESS (child-owned; written only by Edge Functions)
-- =============================================================================

-- One attempt at one activity. The id is generated ON THE DEVICE, so a replayed
-- offline upload hits the primary key and is absorbed (idempotency).
create table activity_sessions (
  id               uuid primary key,
  child_id         uuid not null references child_profiles(id) on delete cascade,
  activity_id      uuid not null references activities(id) on delete restrict,
  device_id        uuid references devices(id) on delete set null,
  lesson_step_id   uuid references lesson_steps(id) on delete set null,
  source           text not null check (source in
                     ('feed','search','collection','course','favorite','shuffle',
                      'together','learning_path','offline')),
  platform         text not null check (platform in ('ios','android','web')),
  app_version      text not null,
  content_version  integer not null check (content_version > 0),
  status           text not null check (status in ('started','completed','abandoned')),
  started_at       timestamptz not null,
  ended_at         timestamptz,
  local_date       date not null,
  played_offline   boolean not null default false,
  received_at      timestamptz not null default now(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint ended_when_done check (status = 'started' or ended_at is not null),
  constraint time_order check (ended_at is null or ended_at >= started_at),
  constraint plausible_length check (ended_at is null or ended_at - started_at <= interval '4 hours')
);
create index on activity_sessions (child_id, local_date desc);
create index on activity_sessions (activity_id);
create index on activity_sessions (device_id);
create index on activity_sessions (lesson_step_id);

-- The outcome of a finished session (1:1).
create table activity_results (
  session_id     uuid primary key references activity_sessions(id) on delete cascade,
  completed      boolean not null,                 -- reached the main learning moment
  score          numeric(5,2) check (score between 0 and 100),
  correct_count  smallint check (correct_count >= 0),
  total_count    smallint check (total_count >= 0),
  duration_ms    integer not null check (duration_ms >= 0),
  metrics        jsonb not null default '{}' check (pg_column_size(metrics) <= 8192),
  created_at     timestamptz not null default now(),
  constraint counts_ok check (correct_count is null or total_count is null or correct_count <= total_count)
);

-- The child's answer to each question in a session.
create table question_responses (
  session_id   uuid not null references activity_sessions(id) on delete cascade,
  question_id  uuid not null references questions(id) on delete restrict,
  attempt      smallint not null default 1 check (attempt between 1 and 20),
  answer_id    uuid references answers(id) on delete set null,
  is_correct   boolean not null,
  response_ms  integer check (response_ms >= 0),
  created_at   timestamptz not null default now(),
  primary key (session_id, question_id, attempt)
);
create index on question_responses (question_id);
create index on question_responses (answer_id);

-- One star per DISTINCT activity per child per household day. The PK is the rule.
create table star_awards (
  child_id     uuid not null references child_profiles(id) on delete cascade,
  local_date   date not null,
  activity_id  uuid not null references activities(id) on delete restrict,
  session_id   uuid not null references activity_sessions(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (child_id, local_date, activity_id)
);
create index on star_awards (activity_id);
create index on star_awards (session_id);

-- Every 5 stars in a day unlocks gift n (needs >= 5n stars; checked by the engine).
create table gift_claims (
  child_id       uuid not null references child_profiles(id) on delete cascade,
  local_date     date not null,
  gift_index     smallint not null check (gift_index between 1 and 20),
  reward_set_id  uuid not null references reward_sets(id) on delete restrict,
  claimed_at     timestamptz not null default now(),
  primary key (child_id, local_date, gift_index)
);
create index on gift_claims (reward_set_id);

create table child_rewards (
  child_id         uuid not null references child_profiles(id) on delete cascade,
  reward_id        uuid not null references rewards(id) on delete restrict,
  quantity         integer not null default 1 check (quantity > 0),
  source           text not null check (source in ('gift','badge_rule','certificate','lesson_prize','admin_grant')),
  first_earned_at  timestamptz not null default now(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  primary key (child_id, reward_id)
);
create index on child_rewards (reward_id);

-- Stickers placed on a scene (Scene Book). Normalised 0..1 coordinates.
create table scene_placements (
  id               uuid primary key default gen_random_uuid(),
  child_id         uuid not null references child_profiles(id) on delete cascade,
  scene_id         uuid not null,
  scene_type       text not null default 'scene' check (scene_type = 'scene'),
  sticker_id       uuid not null,
  sticker_type     text not null default 'sticker' check (sticker_type = 'sticker'),
  x                real not null check (x between 0 and 1),
  y                real not null check (y between 0 and 1),
  scale            real not null default 1 check (scale between 0.2 and 4),
  rotation         real not null default 0,
  z                smallint not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  foreign key (scene_id, scene_type) references rewards(id, type) on delete cascade,
  foreign key (sticker_id, sticker_type) references rewards(id, type) on delete restrict
);
create index on scene_placements (child_id, scene_id);
create index on scene_placements (scene_id);
create index on scene_placements (sticker_id);

create table course_enrollments (
  child_id         uuid not null references child_profiles(id) on delete cascade,
  course_id        uuid not null references courses(id) on delete restrict,
  status           text not null default 'in_progress' check (status in ('in_progress','completed','paused')),
  current_step_id  uuid references lesson_steps(id) on delete set null,
  started_at       timestamptz not null default now(),
  completed_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  primary key (child_id, course_id),
  constraint completed_has_date check (status <> 'completed' or completed_at is not null)
);
create index on course_enrollments (course_id);
create index on course_enrollments (current_step_id);

-- First successful completion of a step. Drives sequential unlock.
create table lesson_step_completions (
  child_id      uuid not null references child_profiles(id) on delete cascade,
  step_id       uuid not null references lesson_steps(id) on delete cascade,
  session_id    uuid not null references activity_sessions(id) on delete cascade,
  score         numeric(5,2) check (score between 0 and 100),
  completed_at  timestamptz not null,
  created_at    timestamptz not null default now(),
  primary key (child_id, step_id)
);
create index on lesson_step_completions (step_id);
create index on lesson_step_completions (session_id);

-- Learning progress per skill (see 09-learning-progress-engine.md for the update rule).
create table skill_mastery (
  child_id           uuid not null references child_profiles(id) on delete cascade,
  skill_id           uuid not null references skills(id) on delete restrict,
  mastery            numeric(4,3) not null default 0 check (mastery between 0 and 1),
  evidence_count     integer not null default 0 check (evidence_count >= 0),
  last_practiced_at  timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  primary key (child_id, skill_id)
);
create index on skill_mastery (skill_id);

-- Daily roll-up for reports (rebuilt from sessions if ever wrong).
create table daily_progress (
  child_id            uuid not null references child_profiles(id) on delete cascade,
  local_date          date not null,
  sessions_started    integer not null default 0 check (sessions_started >= 0),
  sessions_completed  integer not null default 0 check (sessions_completed >= 0),
  seconds_played      integer not null default 0 check (seconds_played >= 0),
  stars               smallint not null default 0 check (stars >= 0),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  primary key (child_id, local_date)
);

create table child_learning_paths (
  child_id           uuid not null references child_profiles(id) on delete cascade,
  path_id            uuid not null references learning_paths(id) on delete restrict,
  current_course_id  uuid references courses(id) on delete set null,
  started_at         timestamptz not null default now(),
  completed_at       timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  primary key (child_id, path_id)
);
create index on child_learning_paths (path_id);
create index on child_learning_paths (current_course_id);

create table certificates (
  id          uuid primary key default gen_random_uuid(),
  child_id    uuid not null references child_profiles(id) on delete cascade,
  course_id   uuid not null references courses(id) on delete restrict,
  issued_at   timestamptz not null default now(),
  created_at  timestamptz not null default now(),
  unique (child_id, course_id)
);
create index on certificates (course_id);

create table favorites (
  child_id     uuid not null references child_profiles(id) on delete cascade,
  activity_id  uuid not null references activities(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (child_id, activity_id)
);
create index on favorites (activity_id);
create index on favorites (child_id, created_at desc);

-- Basic (free) tier: a fixed set of up to 10 activities per child per day.
create table daily_free_allocations (
  child_id      uuid not null references child_profiles(id) on delete cascade,
  local_date    date not null,
  activity_ids  uuid[] not null check (cardinality(activity_ids) between 0 and 10),
  created_at    timestamptz not null default now(),
  primary key (child_id, local_date)
);

create table screen_time_rules (
  child_id              uuid primary key references child_profiles(id) on delete cascade,
  daily_limit_minutes   smallint check (daily_limit_minutes between 5 and 600),  -- null = none
  -- Sections are content kinds, applied on every screen (a switched-off section's items
  -- disappear from Home and search too). Games can't be switched off or limited [V R14].
  -- learn = courses/lessons, watch = videos, listen = songs/stories/audiobooks,
  -- together = two-player activities (docs/design/README.md §2.3).
  limited_sections      text[] not null default '{learn,watch,listen,together}'
                          check (limited_sections <@ array['learn','watch','listen','together']),
  learn_enabled         boolean not null default true,
  watch_enabled         boolean not null default true,
  listen_enabled        boolean not null default true,
  together_enabled      boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create table screen_time_usage (
  child_id    uuid not null references child_profiles(id) on delete cascade,
  local_date  date not null,
  section     text not null check (section in ('games','learn','watch','listen','together')),
  seconds     integer not null default 0 check (seconds between 0 and 86400),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (child_id, local_date, section)
);

-- What a device has downloaded for offline use (the bytes stay on the device).
create table content_downloads (
  id                uuid primary key default gen_random_uuid(),
  device_id         uuid not null references devices(id) on delete cascade,
  account_id        uuid not null references parent_accounts(id) on delete cascade,
  activity_id       uuid not null references activities(id) on delete restrict,
  content_version   integer not null check (content_version > 0),
  bytes             bigint not null check (bytes >= 0),
  status            text not null default 'active'
                      check (status in ('active','removed','expired','revoked')),
  downloaded_at     timestamptz not null default now(),
  last_verified_at  timestamptz not null default now(),
  removed_at        timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (device_id, activity_id)
);
create index on content_downloads (account_id, status);
create index on content_downloads (activity_id);

-- =============================================================================
-- 5. SUBSCRIPTIONS AND PAYMENTS
-- =============================================================================

create table subscription_plans (
  id                 uuid primary key default gen_random_uuid(),
  key                text not null unique,             -- 'plus_monthly', 'plus_annual'
  entitlement        text not null default 'plus' check (entitlement in ('plus')),
  billing_interval   text not null check (billing_interval in ('month','year','lifetime')),
  trial_days         smallint not null default 7 check (trial_days between 0 and 31),
  apple_product_id   text unique,
  google_product_id  text unique,
  stripe_price_id    text unique,
  max_children       smallint not null default 4 check (max_children between 1 and 10),
  active             boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table subscriptions (
  id                        uuid primary key default gen_random_uuid(),
  account_id                uuid not null references parent_accounts(id) on delete cascade,
  plan_id                   uuid not null references subscription_plans(id) on delete restrict,
  provider                  text not null check (provider in ('apple','google','stripe','promo')),
  provider_subscription_id  text not null,  -- Apple originalTransactionId / Google purchase token id / Stripe sub id / promo redemption id
  environment               text not null default 'production' check (environment in ('production','sandbox')),
  status                    text not null check (status in
                              ('trialing','active','grace_period','billing_retry','paused',
                               'cancelled','expired','refunded','revoked')),
  current_period_start      timestamptz,
  current_period_end        timestamptz,
  auto_renew                boolean not null default false,
  started_at                timestamptz not null,
  ended_at                  timestamptz,
  last_verified_at          timestamptz not null default now(),
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  unique (provider, provider_subscription_id),
  constraint period_order check (current_period_end is null or current_period_start is null
                                 or current_period_end > current_period_start)
);
create index on subscriptions (account_id, status);
create index on subscriptions (plan_id);
create index on subscriptions (current_period_end);

-- Money movements reported by the provider. Amounts in minor units.
create table payments (
  id                   uuid primary key default gen_random_uuid(),
  account_id           uuid not null references parent_accounts(id) on delete cascade,
  subscription_id      uuid references subscriptions(id) on delete set null,
  provider             text not null check (provider in ('apple','google','stripe')),
  provider_payment_id  text not null,      -- Apple transactionId / Google orderId / Stripe invoice or charge id
  kind                 text not null check (kind in ('initial','renewal','refund','chargeback','adjustment')),
  amount_minor         bigint not null,    -- negative for refunds and chargebacks
  currency             char(3) not null check (currency ~ '^[A-Z]{3}$'),
  status               text not null check (status in ('pending','succeeded','failed','refunded')),
  occurred_at          timestamptz not null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (provider, provider_payment_id)
);
create index on payments (account_id, occurred_at desc);
create index on payments (subscription_id);

-- Derived access, rewritten only by the billing service from subscriptions.
create table entitlements (
  account_id              uuid not null references parent_accounts(id) on delete cascade,
  entitlement             text not null default 'plus' check (entitlement in ('plus')),
  active_until            timestamptz,                 -- null = not entitled
  source_subscription_id  uuid references subscriptions(id) on delete set null,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  primary key (account_id, entitlement)
);
create index on entitlements (source_subscription_id);

-- Every inbound billing webhook, stored BEFORE processing. Unique = replay-safe.
create table billing_webhook_events (
  id                 uuid primary key default gen_random_uuid(),
  provider           text not null check (provider in ('apple','google','stripe','revenuecat')),
  provider_event_id  text not null,
  event_type         text not null,
  account_id         uuid references parent_accounts(id) on delete set null,
  payload            jsonb not null,
  received_at        timestamptz not null default now(),
  processed_at       timestamptz,
  attempts           smallint not null default 0,
  last_error         text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (provider, provider_event_id)
);
create index on billing_webhook_events (account_id);
create index on billing_webhook_events (received_at) where processed_at is null;

create table promo_codes (
  id                uuid primary key default gen_random_uuid(),
  code              text not null unique check (code = upper(code) and char_length(code) between 6 and 32),
  plan_id           uuid not null references subscription_plans(id) on delete restrict,
  grants_days       smallint not null check (grants_days between 1 and 1095),
  max_redemptions   integer not null check (max_redemptions > 0),
  redeemed_count    integer not null default 0 check (redeemed_count >= 0),
  active            boolean not null default true,
  expires_at        timestamptz,
  created_by        uuid references auth.users(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint not_over_redeemed check (redeemed_count <= max_redemptions)
);
create index on promo_codes (plan_id);
create index on promo_codes (created_by);

create table promo_redemptions (
  id               uuid primary key default gen_random_uuid(),
  code_id          uuid not null references promo_codes(id) on delete restrict,
  account_id       uuid not null references parent_accounts(id) on delete cascade,
  subscription_id  uuid references subscriptions(id) on delete set null,
  redeemed_at      timestamptz not null default now(),
  created_at       timestamptz not null default now(),
  unique (code_id, account_id)
);
create index on promo_redemptions (account_id);
create index on promo_redemptions (subscription_id);

-- =============================================================================
-- 6. NOTIFICATIONS (parents only; children never receive notifications)
-- =============================================================================

create table notifications (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  account_id           uuid not null references parent_accounts(id) on delete cascade,
  type                 text not null check (type in
                         ('weekly_progress','certificate_earned','trial_ending','billing_issue',
                          'new_content','account_security','export_ready','deletion_scheduled')),
  channel              text not null check (channel in ('push','email','in_app')),
  template_key         text not null,
  params               jsonb not null default '{}',   -- never contains the child's nickname for push
  status               text not null default 'queued'
                         check (status in ('queued','sent','failed','read','cancelled')),
  scheduled_for        timestamptz not null default now(),
  sent_at              timestamptz,
  read_at              timestamptz,
  provider_message_id  text,
  error                text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index on notifications (user_id, created_at desc);
create index on notifications (account_id);
create index on notifications (status, scheduled_for) where status = 'queued';

create table notification_preferences (
  user_id     uuid not null references auth.users(id) on delete cascade,
  type        text not null,
  channel     text not null check (channel in ('push','email','in_app')),
  enabled     boolean not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (user_id, type, channel)
);

-- =============================================================================
-- 7. PRIVACY OPERATIONS, AUDIT, CONFIG
-- =============================================================================

create table data_export_requests (
  id            uuid primary key default gen_random_uuid(),
  account_id    uuid not null references parent_accounts(id) on delete cascade,
  requested_by  uuid references auth.users(id) on delete set null,
  status        text not null default 'requested'
                  check (status in ('requested','processing','ready','expired','failed')),
  object_path   text,                                  -- exports bucket, private
  expires_at    timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index on data_export_requests (account_id);
create index on data_export_requests (requested_by);

create table deletion_requests (
  id             uuid primary key default gen_random_uuid(),
  account_id     uuid not null references parent_accounts(id) on delete cascade,
  child_id       uuid references child_profiles(id) on delete cascade,  -- null = whole account
  requested_by   uuid references auth.users(id) on delete set null,
  scope          text not null check (scope in ('account','child')),
  status         text not null default 'scheduled'
                   check (status in ('scheduled','cancelled','processing','completed','failed')),
  scheduled_for  timestamptz not null default now() + interval '7 days',
  completed_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint scope_matches check ((scope = 'child') = (child_id is not null))
);
create index on deletion_requests (account_id);
create index on deletion_requests (child_id);
create index on deletion_requests (requested_by);
create index on deletion_requests (scheduled_for) where status = 'scheduled';

-- Append-only. No FKs on purpose: entries must survive the deletion of what
-- they describe. Child-related rows store column NAMES only, never values.
create table audit_logs (
  id             bigint generated always as identity primary key,
  occurred_at    timestamptz not null default now(),
  actor_type     text not null check (actor_type in ('parent','admin','system','service')),
  actor_user_id  uuid,
  action         text not null,                   -- 'insert','update','delete' or a verb ('content.publish')
  entity_table   text not null,
  entity_id      text,
  account_id     uuid,
  changes        jsonb not null default '{}',
  request_id     text,
  ip_hash        text
);
create index on audit_logs (entity_table, entity_id);
create index on audit_logs (actor_user_id, occurred_at desc);
create index on audit_logs (account_id, occurred_at desc);
create index on audit_logs (occurred_at);

create table feature_flags (
  key          text primary key check (key ~ '^[a-z0-9_.]+$'),
  enabled      boolean not null default false,
  rules        jsonb not null default '{}',   -- {"platforms":["web"],"min_app_build":42,"percent":10}
  description  text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- =============================================================================
-- 8. ANALYTICS (first-party, pseudonymous, partitioned by month; not exposed)
-- =============================================================================

create table analytics.events (
  id            uuid not null default gen_random_uuid(),
  occurred_at   timestamptz not null,
  received_at   timestamptz not null default now(),
  event_name    text not null check (event_name ~ '^[a-z_]+\.[a-z_]+$'),   -- 'session.completed'
  surface       text not null check (surface in ('kids_app','parent_app','parent_web','admin_web')),
  subject_id    uuid,          -- child_profiles.analytics_id (kids) or null; never a user id for kids
  account_hash  text,          -- salted hash for parent surfaces; null for kids
  platform      text check (platform in ('ios','android','web')),
  app_version   text,
  props         jsonb not null default '{}' check (pg_column_size(props) <= 2048),
  primary key (id, occurred_at)
) partition by range (occurred_at);
create index on analytics.events (event_name, occurred_at);
create index on analytics.events (subject_id, occurred_at);
-- Monthly partitions are created ahead by a scheduled job; dropped after 13 months.
create table analytics.events_2026_11 partition of analytics.events
  for values from ('2026-11-01') to ('2026-12-01');
create table analytics.events_2026_12 partition of analytics.events
  for values from ('2026-12-01') to ('2027-01-01');

-- =============================================================================
-- 9. HELPER FUNCTIONS (private schema, security definer, fixed search_path)
-- =============================================================================

-- True for the service role (Edge Functions) and for migrations / cron run as postgres.
-- INVOKER function on purpose: inside a SECURITY DEFINER function current_user is
-- the owner, so callers that need this must not be definers themselves.
create or replace function private.is_service() returns boolean
language sql stable as $$
  select current_user in ('postgres','supabase_admin','service_role')
      or coalesce(auth.jwt()->>'role', '') = 'service_role';
$$;

create or replace function private.is_account_member(acc uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from parent_profiles p
                 where p.account_id = acc and p.user_id = auth.uid());
$$;

create or replace function private.can_access_child(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from child_profiles ch
                 join parent_profiles p on p.account_id = ch.account_id
                 where ch.id = c and p.user_id = auth.uid());
$$;

-- RBAC + MFA: an admin permission only counts in an aal2 (MFA-verified) session.
create or replace function private.has_permission(perm text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
     and exists (select 1
                 from admin_users u
                 join admin_user_roles ur on ur.user_id = u.user_id
                 join admin_role_permissions rp on rp.role_key = ur.role_key
                 where u.user_id = auth.uid() and u.status = 'active'
                   and rp.permission_key = perm);
$$;

-- The household calendar day for a timestamp. Used by the progress engine.
create or replace function private.local_date(acc uuid, ts timestamptz) returns date
language sql stable security definer set search_path = public as $$
  select (ts at time zone a.timezone)::date from parent_accounts a where a.id = acc;
$$;

-- =============================================================================
-- 10. TRIGGERS: updated_at, publish guard, audit, append-only audit log
-- =============================================================================

do $$
declare t record;
begin
  for t in
    select c.table_schema, c.table_name
    from information_schema.columns c
    join information_schema.tables tb
      on tb.table_schema = c.table_schema and tb.table_name = c.table_name
    where c.table_schema = 'public' and c.column_name = 'updated_at'
      and tb.table_type = 'BASE TABLE'
  loop
    execute format(
      'create trigger set_updated_at before update on %I.%I
         for each row execute function private.set_updated_at()',
      t.table_schema, t.table_name);
  end loop;
end $$;

-- Editing content needs content.write (RLS); moving it to 'published' also needs content.publish.
create or replace function private.guard_publish() returns trigger
language plpgsql set search_path = public as $$          -- invoker: see is_service()
begin
  if new.status = 'published'
     and (tg_op = 'INSERT' or old.status is distinct from 'published')
     and not private.is_service()
     and not private.has_permission('content.publish') then
    raise exception 'content.publish permission required to publish %', tg_table_name
      using errcode = '42501';
  end if;
  return new;
end $$;

create trigger guard_publish before insert or update of status on activities
  for each row execute function private.guard_publish();
create trigger guard_publish before insert or update of status on courses
  for each row execute function private.guard_publish();
create trigger guard_publish before insert or update of status on collections
  for each row execute function private.guard_publish();
create trigger guard_publish before insert or update of status on learning_paths
  for each row execute function private.guard_publish();

-- Generic audit trigger. TG_ARGV[0] = 'redact' stores changed column names only.
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
    coalesce(row_j->>'id', row_j->>'user_id', row_j->>'account_id', row_j->>'key'),
    nullif(coalesce(row_j->>'account_id', ''), '')::uuid,
    payload);
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  -- full before/after values
  foreach t in array array[
    'parent_accounts','parental_consents','subscriptions','entitlements','payments',
    'promo_codes','promo_redemptions','subscription_plans','feature_flags',
    'admin_users','admin_user_roles','admin_role_permissions',
    'activities','games','courses','lesson_steps','collections','learning_paths','rewards',
    'game_templates','media_assets','data_export_requests','deletion_requests']
  loop
    execute format('create trigger audit after insert or update or delete on %I
                    for each row execute function private.audit_row()', t);
  end loop;
  -- child data: column names only
  foreach t in array array['child_profiles','screen_time_rules']
  loop
    execute format('create trigger audit after insert or update or delete on %I
                    for each row execute function private.audit_row(''redact'')', t);
  end loop;
end $$;

-- The audit log is append-only. Retention purge sets app.audit_purge = 'on' in its own transaction.
create or replace function private.audit_append_only() returns trigger
language plpgsql as $$
begin
  if tg_op = 'DELETE' and current_setting('app.audit_purge', true) = 'on' then
    return old;
  end if;
  raise exception 'audit_logs is append-only' using errcode = '42501';
end $$;
create trigger append_only before update or delete on audit_logs
  for each row execute function private.audit_append_only();

-- =============================================================================
-- 11. ROW LEVEL SECURITY
--   Read policies for parents and the public catalogue.
--   Write policies ONLY for admins on catalogue tables (permission + MFA).
--   No client write policies on family/child/billing tables: Edge Functions
--   write those with the service role after their own checks.
-- =============================================================================

do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- ---- family -----------------------------------------------------------------
create policy member_read on parent_accounts for select
  using (private.is_account_member(id) or private.has_permission('support.read'));
create policy member_read on parent_profiles for select
  using (private.is_account_member(account_id) or private.has_permission('support.read'));
create policy member_read on parental_consents for select
  using (private.is_account_member(account_id) or private.has_permission('support.read'));
create policy member_read on child_profiles for select
  using (private.is_account_member(account_id) or private.has_permission('support.read'));
create policy member_read on devices for select
  using (private.is_account_member(account_id) or private.has_permission('support.read'));
create policy member_read on content_downloads for select
  using (private.is_account_member(account_id));
create policy member_read on data_export_requests for select
  using (private.is_account_member(account_id));
create policy member_read on deletion_requests for select
  using (private.is_account_member(account_id) or private.has_permission('support.read'));

-- ---- child-owned (parents of that child; support staff read-only) --------------
do $$
declare t text;
begin
  foreach t in array array[
    'activity_sessions','star_awards','gift_claims','child_rewards','scene_placements',
    'course_enrollments','lesson_step_completions','skill_mastery','daily_progress',
    'child_learning_paths','certificates','favorites','daily_free_allocations',
    'screen_time_rules','screen_time_usage']
  loop
    execute format('create policy child_read on %I for select
                    using (private.can_access_child(child_id) or private.has_permission(''support.read''))', t);
  end loop;
end $$;
create policy child_read on activity_results for select using (
  exists (select 1 from activity_sessions s where s.id = session_id
          and (private.can_access_child(s.child_id) or private.has_permission('support.read'))));
create policy child_read on question_responses for select using (
  exists (select 1 from activity_sessions s where s.id = session_id
          and (private.can_access_child(s.child_id) or private.has_permission('support.read'))));

-- ---- catalogue: published rows readable by anyone (onboarding precedes sign-up);
--      drafts readable with content.read; writes need content.write --------------
create policy public_read on avatars for select using (active or private.has_permission('content.read'));
create policy public_read on subjects for select using (true);
create policy public_read on skills for select using (true);
create policy published_read on categories for select
  using (status = 'published' or private.has_permission('content.read'));
create policy active_read on game_templates for select
  using (status <> 'draft' or private.has_permission('content.read'));
create policy public_read on media_assets for select
  using ((access = 'public' and status = 'ready') or private.has_permission('content.read'));
create policy published_read on activities for select
  using (status = 'published' or private.has_permission('content.read'));
create policy published_read on activity_categories for select using (
  exists (select 1 from activities a where a.id = activity_id
          and (a.status = 'published' or private.has_permission('content.read'))));
create policy published_read on activity_skills for select using (
  exists (select 1 from activities a where a.id = activity_id
          and (a.status = 'published' or private.has_permission('content.read'))));
create policy published_read on activity_media for select using (
  exists (select 1 from activities a where a.id = activity_id
          and (a.status = 'published' or private.has_permission('content.read'))));
create policy published_read on games for select using (
  exists (select 1 from activities a where a.id = activity_id
          and (a.status = 'published' or private.has_permission('content.read'))));
create policy published_read on questions for select using (
  exists (select 1 from activities a where a.id = activity_id
          and (a.status = 'published' or private.has_permission('content.read'))));
create policy published_read on answers for select using (
  exists (select 1 from questions q join activities a on a.id = q.activity_id
          where q.id = question_id
          and (a.status = 'published' or private.has_permission('content.read'))));
create policy published_read on courses for select
  using (status = 'published' or private.has_permission('content.read'));
create policy published_read on course_modules for select using (
  exists (select 1 from courses c where c.id = course_id
          and (c.status = 'published' or private.has_permission('content.read'))));
create policy published_read on lessons for select using (
  exists (select 1 from course_modules m join courses c on c.id = m.course_id
          where m.id = module_id
          and (c.status = 'published' or private.has_permission('content.read'))));
create policy published_read on lesson_steps for select using (
  exists (select 1 from lessons l join course_modules m on m.id = l.module_id
          join courses c on c.id = m.course_id
          where l.id = lesson_id
          and (c.status = 'published' or private.has_permission('content.read'))));
create policy published_read on learning_paths for select
  using (status = 'published' or private.has_permission('content.read'));
create policy published_read on learning_path_courses for select using (
  exists (select 1 from learning_paths p where p.id = path_id
          and (p.status = 'published' or private.has_permission('content.read'))));
create policy published_read on collections for select using (
  (status = 'published' and (starts_at is null or starts_at <= now())
   and (ends_at is null or ends_at > now()))
  or private.has_permission('content.read'));
create policy published_read on collection_items for select using (
  exists (select 1 from collections c where c.id = collection_id
          and (c.status = 'published' or private.has_permission('content.read'))));
create policy active_read on reward_sets for select
  using (active or private.has_permission('content.read'));
create policy active_read on rewards for select
  using (status = 'active' or private.has_permission('content.read'));

do $$
declare t text;
begin
  foreach t in array array[
    'avatars','categories','subjects','skills','game_templates','media_assets','activities',
    'activity_categories','activity_skills','activity_media','games','questions','answers',
    'courses','course_modules','lessons','lesson_steps','learning_paths','learning_path_courses',
    'collections','collection_items','reward_sets','rewards']
  loop
    execute format('create policy admin_insert on %I for insert
                    with check (private.has_permission(''content.write''))', t);
    execute format('create policy admin_update on %I for update
                    using (private.has_permission(''content.write''))
                    with check (private.has_permission(''content.write''))', t);
    execute format('create policy admin_delete on %I for delete
                    using (private.has_permission(''content.write''))', t);
  end loop;
end $$;

-- ---- billing -------------------------------------------------------------------
create policy public_read on subscription_plans for select
  using (active or private.has_permission('billing.read'));
create policy admin_write on subscription_plans for all
  using (private.has_permission('billing.manage')) with check (private.has_permission('billing.manage'));
create policy member_read on subscriptions for select
  using (private.is_account_member(account_id) or private.has_permission('billing.read'));
create policy member_read on payments for select
  using (private.is_account_member(account_id) or private.has_permission('billing.read'));
create policy member_read on entitlements for select
  using (private.is_account_member(account_id) or private.has_permission('billing.read'));
create policy member_read on promo_redemptions for select
  using (private.is_account_member(account_id) or private.has_permission('billing.read'));
create policy admin_read on billing_webhook_events for select
  using (private.has_permission('billing.read'));
create policy admin_read on promo_codes for select
  using (private.has_permission('billing.read'));
create policy admin_write on promo_codes for all
  using (private.has_permission('billing.manage')) with check (private.has_permission('billing.manage'));

-- ---- notifications ---------------------------------------------------------------
create policy self_read on notifications for select using (user_id = auth.uid());
create policy self_read on notification_preferences for select using (user_id = auth.uid());

-- ---- admin, audit, config -------------------------------------------------------------
create policy self_or_admin_read on admin_users for select
  using (user_id = auth.uid() or private.has_permission('admin.manage'));
create policy self_or_admin_read on admin_user_roles for select
  using (user_id = auth.uid() or private.has_permission('admin.manage'));
create policy admin_read on admin_roles for select using (private.has_permission('admin.manage'));
create policy admin_read on admin_permissions for select using (private.has_permission('admin.manage'));
create policy admin_read on admin_role_permissions for select using (private.has_permission('admin.manage'));
create policy admin_write on admin_users for all
  using (private.has_permission('admin.manage')) with check (private.has_permission('admin.manage'));
create policy admin_write on admin_user_roles for all
  using (private.has_permission('admin.manage') and user_id <> auth.uid())        -- no self-grant
  with check (private.has_permission('admin.manage') and user_id <> auth.uid());
create policy admin_read on audit_logs for select using (private.has_permission('audit.read'));
create policy public_read on feature_flags for select using (true);
create policy admin_write on feature_flags for all
  using (private.has_permission('admin.manage')) with check (private.has_permission('admin.manage'));

-- The audit log cannot be written or changed by any client role
-- (Supabase grants table privileges to anon/authenticated by default; take them back).
revoke insert, update, delete, truncate on audit_logs from public, anon, authenticated;

-- 'private' is NOT in the Data API's exposed schemas, but RLS policies call its
-- functions as the requesting role, so those roles need USAGE (not table access).
revoke all on schema private from public;
grant usage on schema private to anon, authenticated, service_role;
-- analytics is written only by the ingest Edge Function (service role).
revoke all on schema analytics from public, anon, authenticated;

-- =============================================================================
-- 12. SEED: roles and permissions (reference data, part of the migration)
-- =============================================================================

insert into admin_permissions (key, description) values
  ('content.read',    'See drafts and unpublished content'),
  ('content.write',   'Create and edit content'),
  ('content.publish', 'Publish and retire content'),
  ('support.read',    'Look up a family for support (read-only)'),
  ('support.act',     'Resend login, cancel deletion, grant promo time'),
  ('billing.read',    'See subscriptions, payments, webhook events'),
  ('billing.manage',  'Plans, promo codes, manual entitlement fixes'),
  ('privacy.act',     'Run export / deletion on request'),
  ('audit.read',      'Read the audit log'),
  ('admin.manage',    'Manage admin users, roles, feature flags');

insert into admin_roles (key, description) values
  ('content_editor',    'Builds activities, courses, collections'),
  ('content_publisher', 'Reviews and publishes content'),
  ('support_agent',     'Helps families'),
  ('finance',           'Billing and promo codes'),
  ('privacy_officer',   'Data requests and audits'),
  ('super_admin',       'Everything; at most two people');

insert into admin_role_permissions (role_key, permission_key) values
  ('content_editor','content.read'), ('content_editor','content.write'),
  ('content_publisher','content.read'), ('content_publisher','content.write'),
  ('content_publisher','content.publish'),
  ('support_agent','support.read'), ('support_agent','support.act'), ('support_agent','billing.read'),
  ('finance','billing.read'), ('finance','billing.manage'), ('finance','support.read'),
  ('privacy_officer','privacy.act'), ('privacy_officer','audit.read'), ('privacy_officer','support.read');
insert into admin_role_permissions (role_key, permission_key)
  select 'super_admin', key from admin_permissions;

-- =============================================================================
-- Future (NOT v1): 0002_schools adds organizations, classrooms, classroom_members,
-- student_logins (picture password), assignments, school_licences. Additive only:
-- parent_accounts gains no columns; schools get their own owner table.
-- =============================================================================
