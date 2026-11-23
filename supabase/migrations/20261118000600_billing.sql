-- Subscriptions, payments, entitlements, webhooks, promo codes
-- Kids Learning Platform · migration generated from docs/architecture/database/schema-draft.sql (v0.2,
-- reviewed 2026-11-17, design-aligned 2026-11-18). DDL is kept verbatim from the reviewed draft unless a
-- change is marked "IMPL:" with its reason (see docs/backend/database-schema.md §Changes from the draft).

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

