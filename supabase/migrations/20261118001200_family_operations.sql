-- Family operations: the multi-table writes behind onboarding, children and deletion.
-- Kids Learning Platform · new in the implementation (docs/architecture/04-backend-architecture.md §4.3:
-- "multi-row changes go through one SQL function in private").
--
-- WHO CALLS THESE: only Edge Functions, over the database connection they get from the platform
-- (SUPABASE_DB_URL, Supavisor transaction mode). EXECUTE is revoked from public/anon/authenticated,
-- and `private` is not an exposed Data API schema, so no client can call them.
-- TRUST: p_user_id is ALWAYS the `sub` of the caller's verified JWT, read by the Edge Function.
-- It is never taken from a request body. Every function re-checks membership/ownership itself.
-- ERRORS: SQLSTATE 'KL4xx' + a stable message key the Edge Function maps to its HTTP problem code:
--   KL400 VALIDATION · KL402 CHILD_LIMIT · KL403 FORBIDDEN · KL404 NOT_FOUND · KL409 CONFLICT

-- ---------------------------------------------------------------------------
-- small validators
-- ---------------------------------------------------------------------------
create or replace function private.fail(code text, msg text, detail text default null)
returns void language plpgsql as $$
begin
  raise exception using errcode = code, message = msg, detail = coalesce(detail, '');
end $$;

-- 'YYYY-MM' → first day of that month; the child must be 1–12 years old (month precision).
create or replace function private.parse_birth_year_month(v text) returns date
language plpgsql stable set search_path = '' as $$
declare d date;
begin
  if v is null or v !~ '^\d{4}-(0[1-9]|1[0-2])$' then
    perform private.fail('KL400', 'VALIDATION', 'birthYearMonth must be YYYY-MM');
  end if;
  d := (v || '-01')::date;
  if d > date_trunc('month', now())::date - interval '12 months'
     or d < date_trunc('month', now())::date - interval '13 years' then
    perform private.fail('KL400', 'VALIDATION', 'child must be between 1 and 12 years old');
  end if;
  return d;
end $$;

create or replace function private.child_limit(acc uuid) returns int
language sql stable set search_path = '' as $$
  -- Plus: the plan's max_children; Basic (no active entitlement): 1  [07-api POST /children]
  select coalesce((
    select p.max_children
    from public.entitlements e
    join public.subscriptions s on s.id = e.source_subscription_id
    join public.subscription_plans p on p.id = s.plan_id
    where e.account_id = acc and e.entitlement = 'plus' and e.active_until > now()
    order by p.max_children desc limit 1), 1);
$$;

-- Inserts one child from a JSON object {nickname, birthYearMonth, avatarId?, stage?, contentLocale?}.
create or replace function private.insert_child(acc uuid, c jsonb) returns uuid
language plpgsql set search_path = '' as $$
declare new_id uuid; av uuid;
begin
  if jsonb_typeof(c) is distinct from 'object' then
    perform private.fail('KL400', 'VALIDATION', 'child is required');
  end if;
  if nullif(c->>'avatarId', '') is not null then
    select id into av from public.avatars where id = (c->>'avatarId')::uuid and active;
    if av is null then perform private.fail('KL400', 'VALIDATION', 'unknown avatar'); end if;
  end if;
  insert into public.child_profiles (account_id, nickname, avatar_id, birth_year_month, learning_stage, content_locale, sort)
  values (acc,
          btrim(c->>'nickname'),
          av,
          private.parse_birth_year_month(c->>'birthYearMonth'),
          coalesce(nullif(c->>'stage', ''), 'auto'),
          nullif(c->>'contentLocale', ''),
          (select coalesce(max(sort) + 1, 0) from public.child_profiles where account_id = acc))
  returning id into new_id;
  insert into public.screen_time_rules (child_id) values (new_id);   -- defaults: no limit, all sections on
  return new_id;
exception
  when check_violation or not_null_violation then
    perform private.fail('KL400', 'VALIDATION', 'invalid child: ' || sqlerrm);
    return null;
  when invalid_text_representation then
    perform private.fail('KL400', 'VALIDATION', 'invalid id');
    return null;
end $$;

-- ---------------------------------------------------------------------------
-- POST /onboarding/complete
--   p = {timezone, country?, uiLocale?, contentLocale?, marketingOptIn?,
--        child:{nickname, birthYearMonth, avatarId?, stage?},
--        consents:[{type, policyVersion, method}], evidence:{...set by the Edge Function}}
--   Idempotent per user: a second call returns the existing account (created = false).
-- ---------------------------------------------------------------------------
create or replace function private.onboard_family(p_user_id uuid, p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  acc uuid; child uuid; c jsonb; tz text := coalesce(nullif(p->>'timezone', ''), 'UTC');
  required text[] := array['terms','privacy_policy','child_data_collection'];
  given text[];
begin
  if p_user_id is null or not exists (select 1 from auth.users where id = p_user_id) then
    perform private.fail('KL403', 'FORBIDDEN', 'unknown user');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('onboard:' || p_user_id::text, 0));

  select account_id into acc from public.parent_profiles where user_id = p_user_id;
  if acc is not null then
    select id into child from public.child_profiles where account_id = acc order by sort, created_at limit 1;
    return jsonb_build_object('accountId', acc, 'childId', child, 'created', false);
  end if;

  -- validate before writing anything
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = tz) then
    perform private.fail('KL400', 'VALIDATION', 'unknown timezone');
  end if;
  if nullif(p->>'country', '') is not null and p->>'country' !~ '^[A-Z]{2}$' then
    perform private.fail('KL400', 'VALIDATION', 'country must be ISO 3166-1 alpha-2');
  end if;
  if coalesce(p->>'uiLocale', 'en') !~ '^[a-z]{2}(-[A-Z]{2})?$'
     or coalesce(p->>'contentLocale', 'en') !~ '^[a-z]{2}(-[A-Z]{2})?$' then
    perform private.fail('KL400', 'VALIDATION', 'bad locale');
  end if;
  if jsonb_typeof(p->'consents') is distinct from 'array' then
    perform private.fail('KL400', 'VALIDATION', 'consents are required');
  end if;
  -- coalesce: an empty list must fail the check, not make it NULL (found by test T7)
  select coalesce(array_agg(x->>'type'), '{}') into given from jsonb_array_elements(p->'consents') x;
  if not (given @> required) then
    perform private.fail('KL400', 'VALIDATION', 'terms, privacy_policy and child_data_collection consents are required');
  end if;
  -- 14-security §14.4: no third-party disclosure in v1, so it is never requested or recorded.
  if 'third_party_disclosure' = any (given) then
    perform private.fail('KL400', 'VALIDATION', 'third_party_disclosure is not collected in v1');
  end if;

  insert into public.parent_accounts (owner_user_id, timezone, country, ui_locale, content_locale)
  values (p_user_id, tz, nullif(p->>'country', ''),
          coalesce(nullif(p->>'uiLocale', ''), 'en'), coalesce(nullif(p->>'contentLocale', ''), 'en'))
  returning id into acc;

  insert into public.parent_profiles (user_id, account_id, role, marketing_opt_in)
  values (p_user_id, acc, 'owner', coalesce((p->>'marketingOptIn')::boolean, false));

  for c in select * from jsonb_array_elements(p->'consents') loop
    if (c->>'type') = 'child_data_collection' and (c->>'method') is distinct from 'email_plus' then
      perform private.fail('KL400', 'VALIDATION', 'child_data_collection consent must use the email_plus method');
    end if;
    if coalesce(c->>'policyVersion', '') !~ '^[A-Za-z0-9._-]{1,32}$' then
      perform private.fail('KL400', 'VALIDATION', 'policyVersion required');
    end if;
    insert into public.parental_consents (account_id, user_id, consent_type, policy_version, method, evidence)
    values (acc, p_user_id, c->>'type', c->>'policyVersion', coalesce(c->>'method', 'checkbox'),
            coalesce(case when jsonb_typeof(p->'evidence') = 'object' then p->'evidence' end, '{}'));
  end loop;

  -- 14-security §14.4 (1): the child is written only now, in the same transaction as the consents.
  child := private.insert_child(acc, p->'child');

  return jsonb_build_object('accountId', acc, 'childId', child, 'created', true);
exception
  when check_violation then
    perform private.fail('KL400', 'VALIDATION', sqlerrm);
    return null;
end $$;

-- ---------------------------------------------------------------------------
-- POST /children   (owner or co-parent; plan limit)
-- ---------------------------------------------------------------------------
create or replace function private.add_child(p_user_id uuid, c jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare acc uuid; n int; lim int; child uuid;
begin
  select account_id into acc from public.parent_profiles where user_id = p_user_id;
  if acc is null then perform private.fail('KL403', 'FORBIDDEN', 'no family account'); end if;
  perform pg_advisory_xact_lock(hashtextextended('children:' || acc::text, 0));
  select count(*) into n from public.child_profiles where account_id = acc and status = 'active';
  lim := private.child_limit(acc);
  if n >= lim then
    perform private.fail('KL402', 'CHILD_LIMIT', format('limit %s', lim));
  end if;
  child := private.insert_child(acc, c);
  return jsonb_build_object('childId', child);
end $$;

-- ---------------------------------------------------------------------------
-- DELETE /children/:id   (owner only, re-authenticated by the Edge Function; immediate)
-- Cascades sessions, results, progress, rewards, favourites, screen time; the request row is kept.
-- ---------------------------------------------------------------------------
create or replace function private.delete_child(p_user_id uuid, p_child_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare acc uuid; req uuid;
begin
  select a.id into acc
  from public.child_profiles ch
  join public.parent_accounts a on a.id = ch.account_id
  join public.parent_profiles pp on pp.account_id = a.id and pp.user_id = p_user_id and pp.role = 'owner'
  where ch.id = p_child_id;
  if acc is null then perform private.fail('KL404', 'NOT_FOUND', 'child'); end if;

  delete from public.child_profiles where id = p_child_id;      -- cascades every child-owned row

  -- The record of the deletion is kept with no link to the (now deleted) child.
  insert into public.deletion_requests (account_id, child_id, requested_by, scope, status, scheduled_for, completed_at)
  values (acc, null, p_user_id, 'child', 'completed', now(), now())
  returning id into req;
  return jsonb_build_object('deletionRequestId', req);
end $$;

-- ---------------------------------------------------------------------------
-- POST /account/deletion (scope account) and DELETE /account/deletion/:id
-- 7-day grace, cancellable (14-security §14.6).
-- ---------------------------------------------------------------------------
create or replace function private.schedule_account_deletion(p_user_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare acc uuid; req public.deletion_requests;
begin
  select account_id into acc from public.parent_profiles where user_id = p_user_id and role = 'owner';
  if acc is null then perform private.fail('KL403', 'FORBIDDEN', 'owner only'); end if;
  perform pg_advisory_xact_lock(hashtextextended('delete:' || acc::text, 0));
  select * into req from public.deletion_requests
   where account_id = acc and scope = 'account' and status = 'scheduled';
  if req.id is null then
    insert into public.deletion_requests (account_id, requested_by, scope)
    values (acc, p_user_id, 'account') returning * into req;
    update public.parent_accounts set status = 'pending_deletion' where id = acc;
  end if;
  return jsonb_build_object('deletionRequestId', req.id, 'scheduledFor', req.scheduled_for);
end $$;

create or replace function private.cancel_account_deletion(p_user_id uuid, p_request_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare acc uuid;
begin
  select account_id into acc from public.parent_profiles where user_id = p_user_id and role = 'owner';
  update public.deletion_requests set status = 'cancelled'
   where id = p_request_id and account_id = acc and scope = 'account' and status = 'scheduled';
  if not found then perform private.fail('KL404', 'NOT_FOUND', 'no scheduled deletion'); end if;
  update public.parent_accounts set status = 'active' where id = acc and status = 'pending_deletion';
  return jsonb_build_object('cancelled', true);
end $$;

-- jobs/deletions: deletes a DUE account request. Returns the auth user ids the job must then delete
-- with the Auth Admin API (auth.admin.deleteUser) after cancelling Stripe / RevenueCat and removing
-- export files. Deleting parent_accounts cascades every family and child row; the audit log keeps a
-- record of the deletion (no child values: child tables are audited as column names only).
create or replace function private.execute_account_deletion(p_request_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.deletion_requests; users uuid[];
begin
  select * into r from public.deletion_requests
   where id = p_request_id and scope = 'account' for update;
  if r.id is null then perform private.fail('KL404', 'NOT_FOUND', 'request'); end if;
  if r.status <> 'scheduled' or r.scheduled_for > now() then
    perform private.fail('KL409', 'CONFLICT', format('request is %s, due %s', r.status, r.scheduled_for));
  end if;
  update public.deletion_requests set status = 'processing' where id = r.id;
  select coalesce(array_agg(user_id), '{}') into users from public.parent_profiles where account_id = r.account_id;
  delete from public.parent_accounts where id = r.account_id;     -- cascades (incl. this request row)
  return jsonb_build_object('accountId', r.account_id, 'authUserIds', to_jsonb(users));
end $$;

-- ---------------------------------------------------------------------------
-- lock it down: service role (and the owner, postgres) only
-- ---------------------------------------------------------------------------
do $$
declare f text;
begin
  for f in
    select p.oid::regprocedure::text
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private'
      and p.proname in ('fail','parse_birth_year_month','child_limit','insert_child','onboard_family',
                        'add_child','delete_child','schedule_account_deletion',
                        'cancel_account_deletion','execute_account_deletion')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
