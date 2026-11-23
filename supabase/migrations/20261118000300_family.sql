-- Family: parent accounts, parent profiles, consent, media assets, avatars, child profiles, devices
-- Kids Learning Platform · migration generated from docs/architecture/database/schema-draft.sql (v0.2,
-- reviewed 2026-11-17, design-aligned 2026-11-18). DDL is kept verbatim from the reviewed draft unless a
-- change is marked "IMPL:" with its reason (see docs/backend/database-schema.md §Changes from the draft).

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

