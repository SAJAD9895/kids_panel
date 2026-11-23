-- Foundation: extensions, schemas, shared trigger function
-- Kids Learning Platform · migration generated from docs/architecture/database/schema-draft.sql (v0.2,
-- reviewed 2026-11-17, design-aligned 2026-11-18). DDL is kept verbatim from the reviewed draft unless a
-- change is marked "IMPL:" with its reason (see docs/backend/database-schema.md §Changes from the draft).


-- IMPL: Supabase installs extensions into the `extensions` schema (not public).
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm  with schema extensions;
create schema if not exists private;    -- helpers; NOT exposed through the Data API
create schema if not exists analytics;  -- first-party events; NOT exposed

create or replace function private.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;
