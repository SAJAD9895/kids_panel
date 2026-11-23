-- SUPERSEDED on 2026-11-17 by docs/architecture/database/schema-draft.sql. Kept for history only; do not apply.
-- Kids Learning Platform: schema v1 (families first, schools later)
-- Target: Postgres 15+ on Supabase. Run as the first migration.
-- Conventions:
--   * every table: id uuid pk (or a natural composite key for pure join/tally tables), created_at, updated_at
--   * times are timestamptz (UTC); "local_date" columns are the child's household calendar day,
--     computed server-side from accounts.timezone
--   * status-like fields use CHECK constraints (easier to evolve than enums)
--   * money is never stored here: prices live in the stores, Stripe and RevenueCat
--   * ACCESS: Postgres row level security. Clients only READ through RLS.
--     ALL WRITES go through the API (Next.js route handlers using the service role)
--     after an explicit authorisation check, so no insert/update/delete policies exist for clients.
--   * Schools: accounts.kind and account_members.role already allow 'school' / 'teacher'.
--     The school tables (classrooms, rosters, assignments, student login) arrive in migration 0002.

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ===========================================================================
-- 1. IDENTITY: accounts, members, children
-- ===========================================================================

-- An account owns children and the subscription. A family today, a school later.
create table accounts (
  id uuid primary key default gen_random_uuid(),
  kind text not null default 'family' check (kind in ('family','school')),
  name text,
  timezone text not null default 'UTC',          -- IANA name, from the parent's device
  country char(2),                                -- ISO 3166-1, for pricing and legal
  locale text not null default 'en',              -- UI / content language
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- auth.users is managed by Supabase Auth (magic link / OTP, password, Apple, Google).
create table account_members (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner','parent','teacher','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (account_id, user_id)
);
create index on account_members (user_id);

create table user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  marketing_opt_in boolean not null default false,
  push_opt_in boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table avatars (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  image_url text not null,
  sort smallint not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Child profile. Data minimisation: birth month only (day forced to 1), first name only.
create table children (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 30),
  avatar_id uuid references avatars(id) on delete set null,
  birth_month date not null check (extract(day from birth_month) = 1),
  learning_level text not null default 'auto'
    check (learning_level in ('auto','beginner','intermediate','advanced')),
  sort smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on children (account_id);

-- ===========================================================================
-- 2. CONTENT CATALOGUE (authored in /admin, read by everyone when published)
-- ===========================================================================

create table subjects (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,                       -- 'literacy','maths','science',...
  name jsonb not null,                            -- {"en":"Maths","es":"Matemáticas"}
  icon_url text,
  sort smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table skills (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,                       -- 'fine_motor','vocabulary','empathy',...
  skill_group text not null check (skill_group in
    ('movement','language','literacy_numeracy','thinking','social_life')),
  name jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- One row per game engine (E1..E12). Activities are engine + config + content pack.
create table game_engines (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,                       -- 'drag_to_target','memory_match','trace',...
  runtime_version text not null,                  -- semver of the HTML5 game runtime bundle
  orientation text not null default 'landscape' check (orientation in ('landscape','portrait','any')),
  config_schema jsonb not null default '{}',      -- JSON Schema the admin form validates against
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table activities (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  type text not null check (type in ('game','video','song','audiobook','podcast')),
  title jsonb not null,                           -- per-locale titles
  keywords text not null default '',              -- authoring keywords for search
  engine_id uuid references game_engines(id) on delete restrict,
  config jsonb not null default '{}',             -- engine params, item lists, difficulty
  pack_path text,                                 -- R2 object key of the content pack (zip)
  pack_version integer not null default 1,
  pack_bytes integer check (pack_bytes >= 0),
  mux_playback_id text,                           -- videos / songs
  duration_seconds integer check (duration_seconds >= 0),
  thumbnail_url text,
  label_skill_id uuid references skills(id) on delete set null, -- the pill shown on the card [SS-01]
  age_min smallint not null default 2 check (age_min between 0 and 12),
  age_max smallint not null default 8 check (age_max between 0 and 12),
  players smallint not null default 1 check (players in (1,2)),  -- 2 = PlayTogether badge [SS-11]
  has_character_pick boolean not null default false,             -- [SS-09]
  needs_permissions text[] not null default '{}',                 -- subset of {mic,camera,photos}
  plus_only boolean not null default true,
  free_eligible boolean not null default true,    -- may appear in the Basic daily allocation
  locales text[] not null default '{en}',
  status text not null default 'draft' check (status in ('draft','published','retired')),
  published_at timestamptz,
  search_tsv tsvector generated always as
    (to_tsvector('simple', coalesce(title->>'en','') || ' ' || keywords)) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint age_range check (age_min <= age_max),
  constraint game_has_engine check (type <> 'game' or engine_id is not null),
  constraint video_has_stream check (type not in ('video','song') or mux_playback_id is not null),
  constraint permissions_known check (needs_permissions <@ array['mic','camera','photos'])
);
create index on activities (engine_id);
create index on activities (label_skill_id);
create index on activities (status, type, age_min, age_max);
create index on activities using gin (search_tsv);
create index on activities using gin ((title->>'en') gin_trgm_ops);

create table activity_subjects (
  activity_id uuid not null references activities(id) on delete cascade,
  subject_id uuid not null references subjects(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (activity_id, subject_id)
);
create index on activity_subjects (subject_id);

create table activity_skills (
  activity_id uuid not null references activities(id) on delete cascade,
  skill_id uuid not null references skills(id) on delete restrict,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (activity_id, skill_id)
);
create index on activity_skills (skill_id);

-- Feed rows, worlds, topics, theater rows, weekly drops. Scheduled, not hard-coded.
create table collections (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  tab text not null check (tab in ('play','theater','lessons','playtogether','explore')),
  kind text not null check (kind in
    ('daily_picks','world','topic','row','drop','most_played','whats_new')),
  title jsonb not null,
  art_url text,
  sort integer not null default 0,
  age_min smallint not null default 0,
  age_max smallint not null default 12,
  plus_only boolean not null default false,
  starts_at timestamptz,
  ends_at timestamptz,
  status text not null default 'draft' check (status in ('draft','published','retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint window_ok check (ends_at is null or starts_at is null or ends_at > starts_at)
);
create index on collections (tab, status, sort);
create index on collections (starts_at, ends_at);

create table collection_items (
  collection_id uuid not null references collections(id) on delete cascade,
  activity_id uuid not null references activities(id) on delete cascade,
  position integer not null,
  created_at timestamptz not null default now(),
  primary key (collection_id, activity_id),
  unique (collection_id, position)
);
create index on collection_items (activity_id);

-- Lessons: lesson -> workbook -> unit -> node  [SS-07, SS-10]
create table lessons (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  kind text not null default 'solo' check (kind in ('solo','learn_together')),  -- [SS-19]
  title jsonb not null,
  subject_id uuid references subjects(id) on delete restrict,
  stage text not null check (stage in ('preschool','kindergarten','grade1')),
  primary_skill_id uuid references skills(id) on delete set null,
  partner_credit text,                              -- our own partners only
  cover_url text,
  plus_only boolean not null default true,
  sort integer not null default 0,
  status text not null default 'draft' check (status in ('draft','published','retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on lessons (subject_id);
create index on lessons (primary_skill_id);
create index on lessons (status, stage, sort);

create table lesson_workbooks (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references lessons(id) on delete cascade,
  position smallint not null,
  title jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (lesson_id, position)
);

create table lesson_units (
  id uuid primary key default gen_random_uuid(),
  workbook_id uuid not null references lesson_workbooks(id) on delete cascade,
  position smallint not null,
  title jsonb not null,
  cover_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workbook_id, position)
);

create table lesson_nodes (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references lesson_units(id) on delete cascade,
  position smallint not null,
  node_type text not null check (node_type in
    ('knowledge_check','collect','trace','practice','video','story','intro')),
  title jsonb not null,
  activity_id uuid not null references activities(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (unit_id, position)
);
create index on lesson_nodes (activity_id);

-- Rewards catalogue
create table sticker_packs (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  title jsonb not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table stickers (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid not null references sticker_packs(id) on delete cascade,
  key text not null unique,
  image_url text not null,
  rarity text not null default 'common' check (rarity in ('common','rare')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on stickers (pack_id);

create table scenes (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  background_url text not null,
  sort smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ===========================================================================
-- 3. PLAY, PROGRESS AND REWARDS (child-owned; written only by the API)
-- ===========================================================================

-- Every finished (or abandoned) activity. Sent online or replayed from the offline queue.
create table activity_completions (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references children(id) on delete cascade,
  activity_id uuid not null references activities(id) on delete restrict,
  client_event_id uuid not null,                  -- generated on device: idempotency key
  source text not null check (source in
    ('feed','search','collection','lesson','favorite','shuffle','playtogether','offline')),
  lesson_node_id uuid references lesson_nodes(id) on delete set null,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  completed boolean not null,                     -- reached the "main learning bit"
  score numeric(5,2) check (score between 0 and 100),   -- knowledge checks only
  local_date date not null,                       -- household calendar day (server computed)
  device_platform text not null check (device_platform in ('ios','android','web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (child_id, client_event_id),
  constraint time_order check (ended_at >= started_at)
);
create index on activity_completions (child_id, local_date desc);
create index on activity_completions (activity_id);
create index on activity_completions (lesson_node_id);

-- One star per DISTINCT activity per day (R7). The PK makes it a database rule.
create table star_awards (
  child_id uuid not null references children(id) on delete cascade,
  local_date date not null,
  activity_id uuid not null references activities(id) on delete restrict,
  completion_id uuid not null references activity_completions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (child_id, local_date, activity_id)
);
create index on star_awards (activity_id);
create index on star_awards (completion_id);

-- Every 5 stars in a day = one gift (R7). gift_index n requires >= 5n stars that day.
create table reward_claims (
  child_id uuid not null references children(id) on delete cascade,
  local_date date not null,
  gift_index smallint not null check (gift_index between 1 and 50),
  sticker_pack_id uuid not null references sticker_packs(id) on delete restrict,
  claimed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  primary key (child_id, local_date, gift_index)
);
create index on reward_claims (sticker_pack_id);

create table child_stickers (
  child_id uuid not null references children(id) on delete cascade,
  sticker_id uuid not null references stickers(id) on delete restrict,
  quantity integer not null default 1 check (quantity > 0),
  first_acquired_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (child_id, sticker_id)
);
create index on child_stickers (sticker_id);

create table scene_placements (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references children(id) on delete cascade,
  scene_id uuid not null references scenes(id) on delete cascade,
  sticker_id uuid not null references stickers(id) on delete restrict,
  x real not null check (x between 0 and 1),      -- normalised to scene size
  y real not null check (y between 0 and 1),
  scale real not null default 1 check (scale between 0.2 and 4),
  rotation real not null default 0,
  z smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on scene_placements (child_id, scene_id);
create index on scene_placements (sticker_id);

create table lesson_enrollments (
  child_id uuid not null references children(id) on delete cascade,
  lesson_id uuid not null references lessons(id) on delete restrict,
  current_node_id uuid references lesson_nodes(id) on delete set null,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (child_id, lesson_id)
);
create index on lesson_enrollments (lesson_id);
create index on lesson_enrollments (current_node_id);

-- First completion of each node unlocks the next one (sequential unlock [SS-10]).
create table node_completions (
  child_id uuid not null references children(id) on delete cascade,
  node_id uuid not null references lesson_nodes(id) on delete cascade,
  completion_id uuid not null references activity_completions(id) on delete cascade,
  score numeric(5,2) check (score between 0 and 100),
  completed_at timestamptz not null,
  created_at timestamptz not null default now(),
  primary key (child_id, node_id)
);
create index on node_completions (node_id);
create index on node_completions (completion_id);

create table certificates (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references children(id) on delete cascade,
  lesson_id uuid not null references lessons(id) on delete restrict,
  issued_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (child_id, lesson_id)
);
create index on certificates (lesson_id);

create table favorites (
  child_id uuid not null references children(id) on delete cascade,
  activity_id uuid not null references activities(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (child_id, activity_id)
);
create index on favorites (activity_id);
create index on favorites (child_id, created_at desc);

-- Basic (free) tier: a fixed set of activities per child per day (R21).
create table daily_free_allocations (
  child_id uuid not null references children(id) on delete cascade,
  local_date date not null,
  activity_ids uuid[] not null check (cardinality(activity_ids) between 0 and 10),
  created_at timestamptz not null default now(),
  primary key (child_id, local_date)
);

-- ===========================================================================
-- 4. PARENT CONTROLS
-- ===========================================================================

create table screen_time_rules (
  child_id uuid primary key references children(id) on delete cascade,
  daily_limit_minutes smallint check (daily_limit_minutes between 5 and 600),  -- null = no limit
  limited_categories text[] not null default '{theater,lessons,playtogether}'
    check (limited_categories <@ array['theater','lessons','playtogether']),   -- games never limited (R13)
  theater_enabled boolean not null default true,
  lessons_enabled boolean not null default true,
  playtogether_enabled boolean not null default true,  -- Play can't be switched off (R14)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Server-side tally (heartbeats), so the limit holds on the web and across devices.
create table screen_time_usage (
  child_id uuid not null references children(id) on delete cascade,
  local_date date not null,
  category text not null check (category in ('play','theater','lessons','playtogether')),
  seconds integer not null default 0 check (seconds >= 0),
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  primary key (child_id, local_date, category)
);

-- ===========================================================================
-- 5. BILLING (RevenueCat is the source of truth for Apple, Google and Stripe)
-- ===========================================================================

create table entitlements (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  product text not null default 'plus' check (product in ('plus')),
  status text not null check (status in ('trial','active','grace','cancelled','expired')),
  source text not null check (source in ('apple','google','stripe','code','staff')),
  period_ends_at timestamptz,
  will_renew boolean not null default false,
  external_ref text,                              -- RevenueCat original_transaction_id / code id
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (account_id, product)
);
create index on entitlements (status, period_ends_at);

-- Every webhook we receive, stored before processing. Unique id = webhooks arrive twice.
create table billing_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('revenuecat','stripe')),
  provider_event_id text not null,
  account_id uuid references accounts(id) on delete set null,
  type text not null,
  payload jsonb not null,
  processed_at timestamptz,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_event_id)
);
create index on billing_events (account_id);
create index on billing_events (processed_at) where processed_at is null;

create table redeem_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code = upper(code)),
  grants_days smallint not null check (grants_days between 1 and 1095),
  max_redemptions integer not null check (max_redemptions > 0),
  redeemed_count integer not null default 0,
  active boolean not null default true,
  expires_at timestamptz,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint not_over check (redeemed_count <= max_redemptions)  -- the race guard (R33)
);

create table code_redemptions (
  id uuid primary key default gen_random_uuid(),
  code_id uuid not null references redeem_codes(id) on delete restrict,
  account_id uuid not null references accounts(id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (code_id, account_id)
);
create index on code_redemptions (account_id);

-- ===========================================================================
-- 6. MESSAGING, REFERRALS, ADMIN
-- ===========================================================================

create table push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('ios','android','web')),
  token text not null unique,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on push_tokens (user_id);

create table news_posts (                         -- Parents Area "News" [SS-16]
  id uuid primary key default gen_random_uuid(),
  title jsonb not null,
  body jsonb not null,
  image_url text,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on news_posts (published_at desc);

create table announcements (                      -- feature tooltips and red dots [SS-15]
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  surface text not null check (surface in ('kids_drawer','parents_area','screen_time','home')),
  message jsonb not null,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table announcement_dismissals (
  user_id uuid not null references auth.users(id) on delete cascade,
  announcement_id uuid not null references announcements(id) on delete cascade,
  dismissed_at timestamptz not null default now(),
  primary key (user_id, announcement_id)
);
create index on announcement_dismissals (announcement_id);

create table referrals (                          -- "Invite a friend" [SS-16]
  id uuid primary key default gen_random_uuid(),
  inviter_account_id uuid not null references accounts(id) on delete cascade,
  invite_code text not null unique,
  invitee_account_id uuid references accounts(id) on delete set null,
  status text not null default 'pending' check (status in ('pending','joined','rewarded','void')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on referrals (inviter_account_id);
create index on referrals (invitee_account_id);

create table staff_users (                        -- content editors and admins for /admin
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('editor','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table deletion_requests (                  -- GDPR / COPPA deletion with a grace period
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  requested_by uuid references auth.users(id) on delete set null,
  scheduled_for timestamptz not null default now() + interval '7 days',
  cancelled_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on deletion_requests (account_id);
create index on deletion_requests (scheduled_for) where completed_at is null and cancelled_at is null;

-- ===========================================================================
-- 7. updated_at triggers
-- ===========================================================================
do $$
declare t text;
begin
  for t in
    select table_name from information_schema.columns
    where table_schema = 'public' and column_name = 'updated_at'
  loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      t || '_updated_at', t);
  end loop;
end $$;

-- ===========================================================================
-- 8. ROW LEVEL SECURITY (reads only; writes go through the API with the service role)
-- ===========================================================================

create or replace function public.is_member(acc uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from account_members m
                 where m.account_id = acc and m.user_id = auth.uid());
$$;

create or replace function public.can_access_child(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from children ch
                 join account_members m on m.account_id = ch.account_id
                 where ch.id = c and m.user_id = auth.uid());
$$;

create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from staff_users s where s.user_id = auth.uid());
$$;

do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- identity
create policy member_read on accounts for select using (is_member(id) or is_staff());
create policy member_read on account_members for select using (is_member(account_id) or is_staff());
create policy self_read on user_profiles for select using (user_id = auth.uid() or is_staff());
create policy member_read on children for select using (is_member(account_id) or is_staff());
create policy public_read on avatars for select using (active or is_staff());

-- catalogue: published rows are readable by anyone (onboarding happens before sign-up).
-- Pack files themselves are private in R2; the API issues short-lived signed URLs after the gating check.
create policy public_read on subjects for select using (true);
create policy public_read on skills for select using (true);
create policy public_read on game_engines for select using (true);
create policy published_read on activities for select using (status = 'published' or is_staff());
create policy published_read on activity_subjects for select using (
  exists (select 1 from activities a where a.id = activity_id and (a.status = 'published' or is_staff())));
create policy published_read on activity_skills for select using (
  exists (select 1 from activities a where a.id = activity_id and (a.status = 'published' or is_staff())));
create policy published_read on collections for select using (
  (status = 'published' and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at > now()))
  or is_staff());
create policy published_read on collection_items for select using (
  exists (select 1 from collections c where c.id = collection_id and (c.status = 'published' or is_staff())));
create policy published_read on lessons for select using (status = 'published' or is_staff());
create policy published_read on lesson_workbooks for select using (
  exists (select 1 from lessons l where l.id = lesson_id and (l.status = 'published' or is_staff())));
create policy published_read on lesson_units for select using (
  exists (select 1 from lesson_workbooks w join lessons l on l.id = w.lesson_id
          where w.id = workbook_id and (l.status = 'published' or is_staff())));
create policy published_read on lesson_nodes for select using (
  exists (select 1 from lesson_units u join lesson_workbooks w on w.id = u.workbook_id
          join lessons l on l.id = w.lesson_id
          where u.id = unit_id and (l.status = 'published' or is_staff())));
create policy public_read on sticker_packs for select using (active or is_staff());
create policy public_read on stickers for select using (true);
create policy public_read on scenes for select using (true);

-- child-owned
create policy child_read on activity_completions for select using (can_access_child(child_id));
create policy child_read on star_awards for select using (can_access_child(child_id));
create policy child_read on reward_claims for select using (can_access_child(child_id));
create policy child_read on child_stickers for select using (can_access_child(child_id));
create policy child_read on scene_placements for select using (can_access_child(child_id));
create policy child_read on lesson_enrollments for select using (can_access_child(child_id));
create policy child_read on node_completions for select using (can_access_child(child_id));
create policy child_read on certificates for select using (can_access_child(child_id));
create policy child_read on favorites for select using (can_access_child(child_id));
create policy child_read on daily_free_allocations for select using (can_access_child(child_id));
create policy child_read on screen_time_rules for select using (can_access_child(child_id));
create policy child_read on screen_time_usage for select using (can_access_child(child_id));

-- billing and account
create policy member_read on entitlements for select using (is_member(account_id));
create policy member_read on code_redemptions for select using (is_member(account_id));
create policy member_read on referrals for select using (is_member(inviter_account_id));
create policy member_read on deletion_requests for select using (is_member(account_id));
-- billing_events, redeem_codes, staff_users: no client policy (service role / staff tooling only)
create policy staff_read on billing_events for select using (is_staff());
create policy staff_read on redeem_codes for select using (is_staff());
create policy staff_read on staff_users for select using (is_staff());

-- messaging
create policy self_read on push_tokens for select using (user_id = auth.uid());
create policy published_read on news_posts for select using (
  (published_at is not null and published_at <= now()) or is_staff());
create policy active_read on announcements for select using (
  (starts_at <= now() and (ends_at is null or ends_at > now())) or is_staff());
create policy self_read on announcement_dismissals for select using (user_id = auth.uid());

-- ===========================================================================
-- Planned migration 0002_schools.sql (NOT part of v1). Additive only:
--   classrooms(id, account_id -> accounts kind='school', name, class_code unique, ...)
--   classroom_teachers(classroom_id, user_id)       -- account_members.role = 'teacher'
--   classroom_students(classroom_id, child_id)      -- children.account_id = the school
--   student_logins(child_id, picture_password_hash) -- shared-device login, no email
--   assignments(id, classroom_id, lesson_id | collection_id, starts_at, due_at)
--   school_licences(account_id, seats, starts_at, ends_at)
-- No v1 table needs to change for this.
-- ===========================================================================
