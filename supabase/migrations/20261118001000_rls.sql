-- Row level security on every public table, grants
-- Kids Learning Platform · migration generated from docs/architecture/database/schema-draft.sql (v0.2,
-- reviewed 2026-11-17, design-aligned 2026-11-18). DDL is kept verbatim from the reviewed draft unless a
-- change is marked "IMPL:" with its reason (see docs/backend/database-schema.md §Changes from the draft).

-- =============================================================================
-- 11. ROW LEVEL SECURITY
--   Read policies for parents and the public catalogue.
--   Write policies ONLY for admins on catalogue tables (permission + MFA).
--   No client write policies on family/child/billing tables: Edge Functions
--   write those with the service role after their own checks.
-- =============================================================================

do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- ---- family -----------------------------------------------------------------
create policy member_read on parent_accounts for select
  using (private.is_account_member(id) or private.has_permission('support.read'));
create policy member_read on parent_profiles for select
  using (private.is_account_member(account_id) or private.has_permission('support.read'));
create policy member_read on parental_consents for select
  using (private.is_account_member(account_id) or private.has_permission('support.read'));
create policy member_read on child_profiles for select
  using (private.is_account_member(account_id) or private.has_permission('support.read'));
create policy member_read on devices for select
  using (private.is_account_member(account_id) or private.has_permission('support.read'));
create policy member_read on content_downloads for select
  using (private.is_account_member(account_id));
create policy member_read on data_export_requests for select
  using (private.is_account_member(account_id));
create policy member_read on deletion_requests for select
  using (private.is_account_member(account_id) or private.has_permission('support.read'));

-- ---- child-owned (parents of that child; support staff read-only) --------------
do $$
declare t text;
begin
  foreach t in array array[
    'activity_sessions','star_awards','gift_claims','child_rewards','scene_placements',
    'course_enrollments','lesson_step_completions','skill_mastery','daily_progress',
    'child_learning_paths','certificates','favorites','daily_free_allocations',
    'screen_time_rules','screen_time_usage']
  loop
    execute format('create policy child_read on %I for select
                    using (private.can_access_child(child_id) or private.has_permission(''support.read''))', t);
  end loop;
end $$;
create policy child_read on activity_results for select using (
  exists (select 1 from activity_sessions s where s.id = session_id
          and (private.can_access_child(s.child_id) or private.has_permission('support.read'))));
create policy child_read on question_responses for select using (
  exists (select 1 from activity_sessions s where s.id = session_id
          and (private.can_access_child(s.child_id) or private.has_permission('support.read'))));

-- ---- catalogue: published rows readable by anyone (onboarding precedes sign-up);
--      drafts readable with content.read; writes need content.write --------------
create policy public_read on avatars for select using (active or private.has_permission('content.read'));
create policy public_read on subjects for select using (true);
create policy public_read on skills for select using (true);
create policy published_read on categories for select
  using (status = 'published' or private.has_permission('content.read'));
create policy active_read on game_templates for select
  using (status <> 'draft' or private.has_permission('content.read'));
create policy public_read on media_assets for select
  using ((access = 'public' and status = 'ready') or private.has_permission('content.read'));
create policy published_read on activities for select
  using (status = 'published' or private.has_permission('content.read'));
create policy published_read on activity_categories for select using (
  exists (select 1 from activities a where a.id = activity_id
          and (a.status = 'published' or private.has_permission('content.read'))));
create policy published_read on activity_skills for select using (
  exists (select 1 from activities a where a.id = activity_id
          and (a.status = 'published' or private.has_permission('content.read'))));
create policy published_read on activity_media for select using (
  exists (select 1 from activities a where a.id = activity_id
          and (a.status = 'published' or private.has_permission('content.read'))));
create policy published_read on games for select using (
  exists (select 1 from activities a where a.id = activity_id
          and (a.status = 'published' or private.has_permission('content.read'))));
create policy published_read on questions for select using (
  exists (select 1 from activities a where a.id = activity_id
          and (a.status = 'published' or private.has_permission('content.read'))));
create policy published_read on answers for select using (
  exists (select 1 from questions q join activities a on a.id = q.activity_id
          where q.id = question_id
          and (a.status = 'published' or private.has_permission('content.read'))));
create policy published_read on courses for select
  using (status = 'published' or private.has_permission('content.read'));
create policy published_read on course_modules for select using (
  exists (select 1 from courses c where c.id = course_id
          and (c.status = 'published' or private.has_permission('content.read'))));
create policy published_read on lessons for select using (
  exists (select 1 from course_modules m join courses c on c.id = m.course_id
          where m.id = module_id
          and (c.status = 'published' or private.has_permission('content.read'))));
create policy published_read on lesson_steps for select using (
  exists (select 1 from lessons l join course_modules m on m.id = l.module_id
          join courses c on c.id = m.course_id
          where l.id = lesson_id
          and (c.status = 'published' or private.has_permission('content.read'))));
create policy published_read on learning_paths for select
  using (status = 'published' or private.has_permission('content.read'));
create policy published_read on learning_path_courses for select using (
  exists (select 1 from learning_paths p where p.id = path_id
          and (p.status = 'published' or private.has_permission('content.read'))));
create policy published_read on collections for select using (
  (status = 'published' and (starts_at is null or starts_at <= now())
   and (ends_at is null or ends_at > now()))
  or private.has_permission('content.read'));
create policy published_read on collection_items for select using (
  exists (select 1 from collections c where c.id = collection_id
          and (c.status = 'published' or private.has_permission('content.read'))));
create policy active_read on reward_sets for select
  using (active or private.has_permission('content.read'));
create policy active_read on rewards for select
  using (status = 'active' or private.has_permission('content.read'));

do $$
declare t text;
begin
  foreach t in array array[
    'avatars','categories','subjects','skills','game_templates','media_assets','activities',
    'activity_categories','activity_skills','activity_media','games','questions','answers',
    'courses','course_modules','lessons','lesson_steps','learning_paths','learning_path_courses',
    'collections','collection_items','reward_sets','rewards']
  loop
    execute format('create policy admin_insert on %I for insert
                    with check (private.has_permission(''content.write''))', t);
    execute format('create policy admin_update on %I for update
                    using (private.has_permission(''content.write''))
                    with check (private.has_permission(''content.write''))', t);
    execute format('create policy admin_delete on %I for delete
                    using (private.has_permission(''content.write''))', t);
  end loop;
end $$;

-- ---- billing -------------------------------------------------------------------
create policy public_read on subscription_plans for select
  using (active or private.has_permission('billing.read'));
create policy admin_write on subscription_plans for all
  using (private.has_permission('billing.manage')) with check (private.has_permission('billing.manage'));
create policy member_read on subscriptions for select
  using (private.is_account_member(account_id) or private.has_permission('billing.read'));
create policy member_read on payments for select
  using (private.is_account_member(account_id) or private.has_permission('billing.read'));
create policy member_read on entitlements for select
  using (private.is_account_member(account_id) or private.has_permission('billing.read'));
create policy member_read on promo_redemptions for select
  using (private.is_account_member(account_id) or private.has_permission('billing.read'));
create policy admin_read on billing_webhook_events for select
  using (private.has_permission('billing.read'));
create policy admin_read on promo_codes for select
  using (private.has_permission('billing.read'));
create policy admin_write on promo_codes for all
  using (private.has_permission('billing.manage')) with check (private.has_permission('billing.manage'));

-- ---- notifications ---------------------------------------------------------------
-- IMPL: (select auth.uid()) is evaluated once per query instead of once per row (Supabase advisor 0003).
create policy self_read on notifications for select using (user_id = (select auth.uid()));
create policy self_read on notification_preferences for select using (user_id = (select auth.uid()));

-- ---- admin, audit, config -------------------------------------------------------------
create policy self_or_admin_read on admin_users for select
  using (user_id = (select auth.uid()) or private.has_permission('admin.manage'));
create policy self_or_admin_read on admin_user_roles for select
  using (user_id = (select auth.uid()) or private.has_permission('admin.manage'));
create policy admin_read on admin_roles for select using (private.has_permission('admin.manage'));
create policy admin_read on admin_permissions for select using (private.has_permission('admin.manage'));
create policy admin_read on admin_role_permissions for select using (private.has_permission('admin.manage'));
create policy admin_write on admin_users for all
  using (private.has_permission('admin.manage')) with check (private.has_permission('admin.manage'));
create policy admin_write on admin_user_roles for all
  using (private.has_permission('admin.manage') and user_id <> auth.uid())        -- no self-grant
  with check (private.has_permission('admin.manage') and user_id <> auth.uid());
create policy admin_read on audit_logs for select using (private.has_permission('audit.read'));
create policy public_read on feature_flags for select using (true);
create policy admin_write on feature_flags for all
  using (private.has_permission('admin.manage')) with check (private.has_permission('admin.manage'));

-- The audit log cannot be written or changed by any client role
-- (Supabase grants table privileges to anon/authenticated by default; take them back).
revoke insert, update, delete, truncate on audit_logs from public, anon, authenticated;

-- 'private' is NOT in the Data API's exposed schemas, but RLS policies call its
-- functions as the requesting role, so those roles need USAGE (not table access).
revoke all on schema private from public;
grant usage on schema private to anon, authenticated, service_role;
-- analytics is written only by the ingest Edge Function (service role).
revoke all on schema analytics from public, anon, authenticated;

-- IMPL: privilege hardening (defence in depth behind RLS). Supabase grants ALL on every new public
-- table to anon and authenticated. Reads stay granted (RLS filters them); WRITES are revoked
-- everywhere except the tables an admin edits with their own JWT. A forgotten or wrong policy on a
-- family, child or billing table therefore still can't let a client write.
do $$
declare t text;
  admin_writable text[] := array[
    'avatars','categories','subjects','skills','game_templates','media_assets','activities',
    'activity_categories','activity_skills','activity_media','games','questions','answers',
    'courses','course_modules','lessons','lesson_steps','learning_paths','learning_path_courses',
    'collections','collection_items','reward_sets','rewards',
    'subscription_plans','promo_codes','admin_users','admin_user_roles','feature_flags'];
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('revoke insert, update, delete, truncate, references, trigger on public.%I from anon', t);
    execute format('revoke truncate, references, trigger on public.%I from authenticated', t);
    if not t = any (admin_writable) then
      execute format('revoke insert, update, delete on public.%I from authenticated', t);
    end if;
  end loop;
end $$;
-- Future tables created by this role start with read-only client grants; a migration that adds an
-- admin-writable table must grant insert/update/delete to authenticated explicitly.
alter default privileges in schema public revoke insert, update, delete, truncate, references, trigger on tables from anon, authenticated;

