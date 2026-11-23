-- Notifications, privacy requests, audit log, feature flags
-- Kids Learning Platform · migration generated from docs/architecture/database/schema-draft.sql (v0.2,
-- reviewed 2026-11-17, design-aligned 2026-11-18). DDL is kept verbatim from the reviewed draft unless a
-- change is marked "IMPL:" with its reason (see docs/backend/database-schema.md §Changes from the draft).

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
  -- IMPL: was ON DELETE CASCADE, which deleted the record of a child deletion together with the child;
  -- 14-security §14.6 requires the request row to be kept. Now SET NULL (see scope_matches below).
  child_id       uuid references child_profiles(id) on delete set null,  -- null = whole account, or a completed child deletion
  requested_by   uuid references auth.users(id) on delete set null,
  scope          text not null check (scope in ('account','child')),
  status         text not null default 'scheduled'
                   check (status in ('scheduled','cancelled','processing','completed','failed')),
  scheduled_for  timestamptz not null default now() + interval '7 days',
  completed_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint scope_matches check (
    (scope = 'account' and child_id is null)
    or (scope = 'child' and (child_id is not null or status = 'completed')))
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

