-- First-party analytics (not exposed through the Data API)
-- Kids Learning Platform · migration generated from docs/architecture/database/schema-draft.sql (v0.2,
-- reviewed 2026-11-17, design-aligned 2026-11-18). DDL is kept verbatim from the reviewed draft unless a
-- change is marked "IMPL:" with its reason (see docs/backend/database-schema.md §Changes from the draft).

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

-- IMPL: partitions are created by a function instead of the draft's two hard-coded months, so a
-- late first deploy still has the right ones; a DEFAULT partition catches anything outside them
-- (an insert is never lost). jobs/maintenance (pg_cron, daily) calls ensure_event_partitions(3)
-- and drops partitions older than 13 months (docs/architecture/13-analytics.md).
create or replace function private.ensure_event_partitions(months_ahead int default 3)
returns void language plpgsql set search_path = '' as $$
declare m date := date_trunc('month', now())::date; i int; s date; e date; n text;
begin
  for i in 0..months_ahead loop
    s := (m + make_interval(months => i))::date;
    e := (s + interval '1 month')::date;
    n := format('events_%s', to_char(s, 'YYYY_MM'));
    if to_regclass('analytics.' || n) is null then
      execute format('create table analytics.%I partition of analytics.events for values from (%L) to (%L)', n, s, e);
    end if;
  end loop;
end $$;
revoke all on function private.ensure_event_partitions(int) from public;

create table analytics.events_default partition of analytics.events default;
select private.ensure_event_partitions(3);
