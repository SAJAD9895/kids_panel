-- LOCAL TEST ONLY: the PostgREST login role (trust authentication on the temporary cluster, no
-- password). The families come from supabase/seed.sql (alice@example.test, bob@example.test).
do $$ begin create role authenticator login noinherit; exception when duplicate_object then null; end $$;
grant anon, authenticated, service_role to authenticator;
