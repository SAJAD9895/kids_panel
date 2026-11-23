-- =============================================================================
-- Schema audit: tables, keys, foreign keys, indexes, types, functions, policies, buckets.
-- Structural rules from docs/backend/database-schema.md §3 and §6, checked automatically.
-- =============================================================================
\set ON_ERROR_STOP on
begin;
do $$
declare r record; bad text[];
begin
  -- A1 every public table has a primary key
  select array_agg(c.relname) into bad from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r','p')
    and not exists (select 1 from pg_constraint k where k.conrelid = c.oid and k.contype = 'p');
  if bad is not null then raise exception 'A1 FAIL: no primary key: %', bad; end if;

  -- A2 every foreign key has an index whose leading columns are the FK columns (any order of the FK set)
  select array_agg(format('%s(%s)', k.conrelid::regclass, k.conname)) into bad
  from pg_constraint k join pg_namespace n on n.oid = k.connamespace
  where k.contype = 'f' and n.nspname in ('public')
    and not exists (
      select 1 from pg_index i where i.indrelid = k.conrelid
        and ((select array_agg(x order by x) from unnest((i.indkey::int2[])[0:cardinality(k.conkey)-1]) x)
             = (select array_agg(x order by x) from unnest(k.conkey) x)
          -- subtype FKs (id, type): an index led by the id is enough when the referenced id is unique by itself
          or ((i.indkey::int2[])[0] = k.conkey[1]
              and exists (select 1 from pg_index u where u.indrelid = k.confrelid and u.indisunique
                          and u.indnatts = 1 and (u.indkey::int2[])[0] = k.confkey[1]))));
  if bad is not null then raise exception 'A2 FAIL: unindexed foreign keys: %', bad; end if;

  -- A3 every foreign key states its ON DELETE rule (no implicit NO ACTION)
  select array_agg(format('%s.%s', k.conrelid::regclass, k.conname)) into bad
  from pg_constraint k join pg_namespace n on n.oid = k.connamespace
  where k.contype = 'f' and n.nspname = 'public' and k.confdeltype = 'a';
  if bad is not null then raise exception 'A3 FAIL: FK without an explicit ON DELETE: %', bad; end if;

  -- A4 times are timestamptz; no json (only jsonb); no float money
  select array_agg(table_name || '.' || column_name) into bad from information_schema.columns
  where table_schema in ('public','analytics')
    and (data_type in ('timestamp without time zone','json','money')
         or (data_type in ('real','double precision','numeric') and column_name ~ '(amount|price|cents|minor)'));
  if bad is not null then raise exception 'A4 FAIL: disallowed column types: %', bad; end if;

  -- A5 every table with updated_at has the set_updated_at trigger
  select array_agg(c.table_name) into bad from information_schema.columns c
  join pg_tables t on t.schemaname = c.table_schema and t.tablename = c.table_name
  where c.table_schema = 'public' and c.column_name = 'updated_at'
    and not exists (select 1 from pg_trigger g where g.tgrelid = ('public.' || c.table_name)::regclass and g.tgname = 'set_updated_at');
  if bad is not null then raise exception 'A5 FAIL: updated_at without trigger: %', bad; end if;

  -- A6 every SECURITY DEFINER function pins its search_path
  select array_agg(p.oid::regprocedure::text) into bad from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public','private') and p.prosecdef
    and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%');
  if bad is not null then raise exception 'A6 FAIL: security definer without search_path: %', bad; end if;

  -- A7 no functions in the exposed schema (nothing callable through /rest/v1/rpc)
  select array_agg(p.oid::regprocedure::text) into bad from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public';
  if bad is not null then raise exception 'A7 FAIL: functions in public (exposed via RPC): %', bad; end if;

  -- A8 client roles may execute only the helpers RLS policies need
  select array_agg(p.proname) into bad from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private'
    and (has_function_privilege('authenticated', p.oid, 'EXECUTE') or has_function_privilege('anon', p.oid, 'EXECUTE'))
    and p.proname not in ('is_service','is_account_member','can_access_child','has_permission',
                          'set_updated_at','guard_publish','guard_live_content','is_live','audit_row','audit_append_only');
  if bad is not null then raise exception 'A8 FAIL: client-executable private functions: %', bad; end if;

  -- A9 policies that let EVERYONE read must be on public reference data only
  select array_agg(tablename) into bad from pg_policies
  where schemaname = 'public' and cmd in ('SELECT','ALL') and qual = 'true'
    and tablename not in ('subjects','skills','feature_flags');
  if bad is not null then raise exception 'A9 FAIL: unconditional read policy on: %', bad; end if;

  -- A10 no client write policy on family / child / billing tables
  select array_agg(distinct tablename) into bad from pg_policies
  where schemaname = 'public' and cmd in ('INSERT','UPDATE','DELETE','ALL')
    and tablename in ('parent_accounts','parent_profiles','parental_consents','child_profiles','devices',
      'activity_sessions','activity_results','question_responses','star_awards','gift_claims','child_rewards',
      'scene_placements','course_enrollments','lesson_step_completions','skill_mastery','daily_progress',
      'child_learning_paths','certificates','favorites','daily_free_allocations','screen_time_rules',
      'screen_time_usage','content_downloads','subscriptions','payments','entitlements','promo_redemptions',
      'billing_webhook_events','notifications','notification_preferences','data_export_requests',
      'deletion_requests','audit_logs');
  if bad is not null then raise exception 'A10 FAIL: client write policy on: %', bad; end if;

  -- A11 buckets: exactly one public bucket; every bucket has a size limit except admin-staging
  if (select array_agg(id order by id) from storage.buckets where public) <> array['public-assets'] then
    raise exception 'A11 FAIL: public buckets: %', (select array_agg(id) from storage.buckets where public); end if;
  if exists (select 1 from storage.buckets where file_size_limit is null) then raise exception 'A11 FAIL: bucket without size limit'; end if;
  if exists (select 1 from storage.buckets where id = 'public-assets' and 'image/svg+xml' = any (allowed_mime_types)) then
    raise exception 'A11 FAIL: SVG allowed in the public bucket'; end if;
  if exists (select 1 from pg_policies where schemaname = 'storage' and cmd in ('SELECT','ALL')) then
    raise exception 'A11 FAIL: a client read policy exists on storage.objects'; end if;

  -- A12 consent / child-data minimisation rules are enforced by constraints
  if not exists (select 1 from pg_constraint where conrelid = 'public.child_profiles'::regclass
                 and pg_get_constraintdef(oid) like '%EXTRACT(day FROM birth_year_month)%') then
    raise exception 'A12 FAIL: birth date not month-precision'; end if;

  raise notice 'A1–A12 ok: keys, % FKs indexed with explicit ON DELETE, types, triggers, functions, policies, buckets',
    (select count(*) from pg_constraint k join pg_namespace n on n.oid = k.connamespace where k.contype = 'f' and n.nspname = 'public');
end $$;
rollback;
