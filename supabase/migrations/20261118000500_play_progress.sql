-- Play, results, learning progress, rewards earned, favourites, screen time, downloads
-- Kids Learning Platform · migration generated from docs/architecture/database/schema-draft.sql (v0.2,
-- reviewed 2026-11-17, design-aligned 2026-11-18). DDL is kept verbatim from the reviewed draft unless a
-- change is marked "IMPL:" with its reason (see docs/backend/database-schema.md §Changes from the draft).

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

