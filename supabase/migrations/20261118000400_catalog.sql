-- Content catalogue: taxonomy, game templates, activities, games, questions, courses, paths, collections, rewards
-- Kids Learning Platform · migration generated from docs/architecture/database/schema-draft.sql (v0.2,
-- reviewed 2026-11-17, design-aligned 2026-11-18). DDL is kept verbatim from the reviewed draft unless a
-- change is marked "IMPL:" with its reason (see docs/backend/database-schema.md §Changes from the draft).

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
-- IMPL: operator class schema-qualified (pg_trgm lives in `extensions` on Supabase).
create index on activities using gin ((title->>'en') extensions.gin_trgm_ops);

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

