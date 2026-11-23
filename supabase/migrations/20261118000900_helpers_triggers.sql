-- Authorisation helpers, updated_at / publish-guard / audit triggers
-- Kids Learning Platform · migration generated from docs/architecture/database/schema-draft.sql (v0.2,
-- reviewed 2026-11-17, design-aligned 2026-11-18). DDL is kept verbatim from the reviewed draft unless a
-- change is marked "IMPL:" with its reason (see docs/backend/database-schema.md §Changes from the draft).

-- =============================================================================
-- 9. HELPER FUNCTIONS (private schema, security definer, fixed search_path)
-- =============================================================================

-- True for the service role (Edge Functions) and for migrations / cron run as postgres.
-- INVOKER function on purpose: inside a SECURITY DEFINER function current_user is
-- the owner, so callers that need this must not be definers themselves.
create or replace function private.is_service() returns boolean
language sql stable as $$
  select current_user in ('postgres','supabase_admin','service_role')
      or coalesce(auth.jwt()->>'role', '') = 'service_role';
$$;

create or replace function private.is_account_member(acc uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from parent_profiles p
                 where p.account_id = acc and p.user_id = auth.uid());
$$;

create or replace function private.can_access_child(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from child_profiles ch
                 join parent_profiles p on p.account_id = ch.account_id
                 where ch.id = c and p.user_id = auth.uid());
$$;

-- RBAC + MFA: an admin permission only counts in an aal2 (MFA-verified) session.
create or replace function private.has_permission(perm text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
     and exists (select 1
                 from admin_users u
                 join admin_user_roles ur on ur.user_id = u.user_id
                 join admin_role_permissions rp on rp.role_key = ur.role_key
                 where u.user_id = auth.uid() and u.status = 'active'
                   and rp.permission_key = perm);
$$;

-- The household calendar day for a timestamp. Used by the progress engine.
create or replace function private.local_date(acc uuid, ts timestamptz) returns date
language sql stable security definer set search_path = public as $$
  select (ts at time zone a.timezone)::date from parent_accounts a where a.id = acc;
$$;

-- =============================================================================
-- 10. TRIGGERS: updated_at, publish guard, audit, append-only audit log
-- =============================================================================

do $$
declare t record;
begin
  for t in
    select c.table_schema, c.table_name
    from information_schema.columns c
    join information_schema.tables tb
      on tb.table_schema = c.table_schema and tb.table_name = c.table_name
    where c.table_schema = 'public' and c.column_name = 'updated_at'
      and tb.table_type = 'BASE TABLE'
  loop
    execute format(
      'create trigger set_updated_at before update on %I.%I
         for each row execute function private.set_updated_at()',
      t.table_schema, t.table_name);
  end loop;
end $$;

-- Editing content needs content.write (RLS); moving it to 'published' also needs content.publish.
create or replace function private.guard_publish() returns trigger
language plpgsql set search_path = public as $$          -- invoker: see is_service()
begin
  if new.status = 'published'
     and (tg_op = 'INSERT' or old.status is distinct from 'published')
     and not private.is_service()
     and not private.has_permission('content.publish') then
    raise exception 'content.publish permission required to publish %', tg_table_name
      using errcode = '42501';
  end if;
  return new;
end $$;

create trigger guard_publish before insert or update of status on activities
  for each row execute function private.guard_publish();
create trigger guard_publish before insert or update of status on courses
  for each row execute function private.guard_publish();
create trigger guard_publish before insert or update of status on collections
  for each row execute function private.guard_publish();
create trigger guard_publish before insert or update of status on learning_paths
  for each row execute function private.guard_publish();

-- Generic audit trigger. TG_ARGV[0] = 'redact' stores changed column names only.
create or replace function private.audit_row() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  old_j jsonb := case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end;
  new_j jsonb := case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end;
  row_j jsonb := coalesce(new_j, old_j);
  changed text[];
  payload jsonb;
begin
  if tg_op = 'UPDATE' then
    select coalesce(array_agg(k), '{}') into changed
    from jsonb_object_keys(new_j) k
    where k <> 'updated_at' and (new_j->k) is distinct from (old_j->k);
    if cardinality(changed) = 0 then return new; end if;
  end if;

  if tg_nargs > 0 and tg_argv[0] = 'redact' then
    payload := jsonb_build_object('columns', to_jsonb(coalesce(changed, '{}'::text[])));
  elsif tg_op = 'UPDATE' then
    payload := jsonb_build_object(
      'before', (select jsonb_object_agg(k, old_j->k) from unnest(changed) k),
      'after',  (select jsonb_object_agg(k, new_j->k) from unnest(changed) k));
  else
    payload := jsonb_build_object('row', row_j);
  end if;

  insert into audit_logs (actor_type, actor_user_id, action, entity_table, entity_id, account_id, changes)
  values (
    -- classified from the JWT, not current_user (this function is a definer)
    case when coalesce(auth.jwt()->>'role', '') = 'service_role' then 'service'
         when auth.uid() is null then 'system'                -- migrations, cron
         when exists (select 1 from admin_users where user_id = auth.uid()) then 'admin'
         else 'parent' end,
    auth.uid(),
    lower(tg_op),
    tg_table_name,
    coalesce(row_j->>'id', row_j->>'user_id', row_j->>'account_id', row_j->>'key'),
    -- IMPL: parent_accounts rows carry their account id in `id`; record it so a family's whole
    -- history (incl. its own deletion) is found by account_id.
    nullif(coalesce(row_j->>'account_id', case when tg_table_name = 'parent_accounts' then row_j->>'id' end, ''), '')::uuid,
    payload);
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  -- full before/after values
  foreach t in array array[
    'parent_accounts','parental_consents','subscriptions','entitlements','payments',
    'promo_codes','promo_redemptions','subscription_plans','feature_flags',
    'admin_users','admin_user_roles','admin_role_permissions',
    'activities','games','courses','lesson_steps','collections','learning_paths','rewards',
    'game_templates','media_assets','data_export_requests','deletion_requests']
  loop
    execute format('create trigger audit after insert or update or delete on %I
                    for each row execute function private.audit_row()', t);
  end loop;
  -- child data: column names only
  foreach t in array array['child_profiles','screen_time_rules']
  loop
    execute format('create trigger audit after insert or update or delete on %I
                    for each row execute function private.audit_row(''redact'')', t);
  end loop;
end $$;

-- The audit log is append-only. Retention purge sets app.audit_purge = 'on' in its own transaction.
create or replace function private.audit_append_only() returns trigger
language plpgsql as $$
begin
  if tg_op = 'DELETE' and current_setting('app.audit_purge', true) = 'on' then
    return old;
  end if;
  raise exception 'audit_logs is append-only' using errcode = '42501';
end $$;
create trigger append_only before update or delete on audit_logs
  for each row execute function private.audit_append_only();

