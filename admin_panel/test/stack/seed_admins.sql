-- LOCAL TEST ONLY: staff accounts for the admin CMS tests (one per role) and the PostgREST login role.
-- trust authentication on the temporary cluster: the login role needs no password
do $$ begin create role authenticator login noinherit; exception when duplicate_object then null; end $$;
grant anon, authenticated, service_role to authenticator;
grant usage on schema admin_api to authenticated;

insert into auth.users (id, email, role, aud) values
  ('00000000-0000-4000-c000-000000000001', 'super@admin.test', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-c000-000000000002', 'manager@admin.test', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-c000-000000000003', 'editor@admin.test', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-c000-000000000004', 'support@admin.test', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-c000-000000000005', 'finance@admin.test', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-c000-000000000006', 'privacy@admin.test', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-c000-000000000007', 'newadmin@admin.test', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-c000-000000000008', 'editor2@admin.test', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-c000-000000000009', 'candidate@admin.test', 'authenticated', 'authenticated')
on conflict (id) do nothing;
insert into admin_users (user_id) values
  ('00000000-0000-4000-c000-000000000001'), ('00000000-0000-4000-c000-000000000002'), ('00000000-0000-4000-c000-000000000003'),
  ('00000000-0000-4000-c000-000000000004'), ('00000000-0000-4000-c000-000000000005'), ('00000000-0000-4000-c000-000000000006'),
  ('00000000-0000-4000-c000-000000000007'), ('00000000-0000-4000-c000-000000000008')
on conflict do nothing;
insert into admin_user_roles (user_id, role_key) values
  ('00000000-0000-4000-c000-000000000001', 'super_admin'), ('00000000-0000-4000-c000-000000000002', 'content_publisher'),
  ('00000000-0000-4000-c000-000000000003', 'content_editor'), ('00000000-0000-4000-c000-000000000004', 'support_agent'),
  ('00000000-0000-4000-c000-000000000005', 'finance'), ('00000000-0000-4000-c000-000000000006', 'privacy_officer'),
  ('00000000-0000-4000-c000-000000000007', 'content_editor'), ('00000000-0000-4000-c000-000000000008', 'content_editor')
on conflict do nothing;
