-- Admin RBAC tables + reference roles and permissions
-- Kids Learning Platform · migration generated from docs/architecture/database/schema-draft.sql (v0.2,
-- reviewed 2026-11-17, design-aligned 2026-11-18). DDL is kept verbatim from the reviewed draft unless a
-- change is marked "IMPL:" with its reason (see docs/backend/database-schema.md §Changes from the draft).

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

