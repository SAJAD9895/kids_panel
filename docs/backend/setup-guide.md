# Backend setup guide

What exists: `supabase/migrations/` (13 files), `supabase/seed.sql`, `supabase/tests/`, `supabase/config.toml`, `supabase/templates/`, `scripts/db-verify.sh`, `.env.example`, `.gitignore`. **Nothing has been applied to a hosted Supabase project yet.**

## 1. Which Supabase project

**Use a new, dedicated Supabase project for this platform (one per environment: staging, production).** Do not put it in the project used by the "school" app (`/Users/sajadk/Desktop/try/school`, Skillverse), for four reasons:

1. **Name collisions.** Skillverse's migrations already create `public.skills`, `subjects`, `lessons`, `parent_profiles`, `notifications`, `subscriptions`, `subscription_plans`, `certificates`, `audit_logs` and others with different columns. Our migrations would fail on the first collision. Forcing them in would mean renaming or dropping the other app's tables, which is destructive.
2. **One shared user pool.** Supabase Auth is per project. A children's product (COPPA, GDPR-K, Apple Kids Category) would share sign-in, email templates, rate limits and redirect URLs with a teenage social platform. Consent, deletion and "who are our users" would become entangled.
3. **Blast radius.** A bad migration, a leaked key or a restore in one app would hit the other.
4. **Region and plan.** The data region (open question Q1, EU or US) and the plan (backups, upload size) should be chosen for this product.

The project referenced by that app's `.env.local` also **didn't respond** when checked on 2026-11-18 (its API host doesn't resolve, so it is paused or deleted). It is also not visible to the Supabase connector used here, which sees a different organisation.

Free-plan note: free projects pause after inactivity and allow 2 active projects per organisation. Production for a paid kids app should be on Pro (daily backups, PITR add-on, larger uploads, no pausing).

## 2. Verify locally (no Docker needed)

```bash
brew install postgresql@17          # once
scripts/db-verify.sh                # throwaway DB: migrations → seed → T1–T8, A1–A12, S1–S4
scripts/check-secrets.sh            # secret scan (run before every commit / in CI)
scripts/check-auth-config.py        # auth settings lint
```

## 3. Local Supabase (full stack)

Needs Docker Desktop and the Supabase CLI (`brew install supabase/tap/supabase`).

```bash
supabase start                      # local Postgres, Auth, Storage, Studio, Inbucket (emails)
supabase db reset                   # applies migrations + seed.sql
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/tests/01_rls_and_operations.sql
```

Run this once before the first remote push: it repeats the T1–T8 tests on the **real** Supabase schemas rather than the local stand-in.

## 4. Hosted project: dashboard configuration (manual)

Create the project first (Dashboard → New project; choose the region from Q1; Postgres 17; a strong database password kept in your password manager). Then:

| # | where (Dashboard) | set |
| --- | --- | --- |
| 1 | Authentication → URL Configuration | Site URL = parent web URL; Redirect URLs = the four callback URLs from `config.toml` with your real domains (parent web, admin web, children's web, mobile deep link) |
| 2 | Authentication → Sign In / Providers → Email | enable; **Confirm email** on; **Secure email change** on; OTP length 6; OTP expiry 600 s |
| 3 | Authentication → Sign In / Providers | **Phone** off; **Anonymous** off; **Apple** and **Google** on only with *your own* Apple Services ID / key and Google OAuth client (start Google's OAuth consent-screen verification early; it can take weeks) |
| 4 | Authentication → Email Templates | paste `supabase/templates/*.html` (magic link must contain both `{{ .ConfirmationURL }}` and `{{ .Token }}`), or run `supabase config push` |
| 5 | Authentication → Emails → SMTP Settings | custom SMTP via Resend on your own domain (SPF, DKIM, DMARC). The built-in sender is rate-limited and not for production |
| 6 | Authentication → Rate Limits | raise "emails sent" once custom SMTP works; keep sign-in and verification limits |
| 7 | Authentication → Multi-Factor | TOTP enabled (admins) |
| 8 | Authentication → Sessions / Attack Protection | refresh-token rotation on (reuse interval 10 s); JWT expiry 3600; password minimum 10 with mixed case + digits; **leaked password protection** on (Pro); CAPTCHA (Turnstile) on sign-up if abuse appears |
| 9 | Project Settings → Data API | **Exposed schemas: `public` only** (remove `graphql_public`); extra search path `public, extensions`; max rows 1000. Do **not** expose `private` or `analytics` |
| 10 | Database → Extensions | optional: disable `pg_graphql` (unused). Later (M8/M12): enable `pg_cron`, `pg_net` and Queues (`pgmq`) for jobs |
| 11 | Storage → Settings | global upload limit ≥ 2 GB (Pro; the Free plan caps uploads at 50 MB, which blocks video and pack uploads). Buckets are created by the migration |
| 12 | Database → Settings | **SSL enforcement** on; Network restrictions if you have fixed CI IPs |
| 13 | Database → Backups | daily backups (Pro) on; **PITR** add-on recommended before launch; do one test restore into a scratch project |
| 14 | Project Settings → API Keys | use the publishable key in clients and the secret key only in server environments; rotate if one ever leaks |
| 15 | Advisors → Security and Performance | run after the first push; fix any finding before launch |
| 16 | Edge Functions → Secrets (from M1) | `RESEND_API_KEY`, then Stripe test keys, RevenueCat, signing keys (`.env.example` lists names) |

## 5. Apply the migrations (after §3 passes)

```bash
supabase login
supabase link --project-ref <your-new-project-ref>
supabase db push --dry-run          # INSPECT the list of migrations it will apply
supabase db push                    # applies supabase/migrations/* in order
```

- `db push` does **not** run `seed.sql`. Never seed production: the seed creates sign-in users with known ids. For staging test data, use a Supabase preview branch (it seeds) or run the seed manually against staging only.
- After pushing, regenerate types: `supabase gen types typescript --linked > packages/ts/supabase/database.types.ts` (when the app repos exist).

## 6. Bootstrap the first admin (once, per environment)

There is no API path to become an admin. In Dashboard → SQL Editor (runs as `postgres`), after that person has signed up with their work email:

```sql
insert into admin_users (user_id)
select id from auth.users where email = 'first.admin@your-company.example';
insert into admin_user_roles (user_id, role_key)
select id, 'super_admin' from auth.users where email = 'first.admin@your-company.example';
```

They then enrol TOTP on first admin-web login; their permissions only apply in an MFA (aal2) session. Add a second super admin the same way and invite everyone else through the admin web.

## 7. Secrets

- Values live only in untracked `.env.local` files, the hosting provider's env settings and Supabase Edge Function secrets. `.gitignore` excludes `.env*` (except `.env.example`).
- The **secret / service-role key and `SUPABASE_DB_URL` never go into the Flutter app, the Next.js client bundle or any file in the repo.** Edge Functions receive them from the platform.
- This repo is not a git repository yet. Run `git init` before the first commit, then check with `git status` that no `.env.local` is staged.

## 8. Security checklist

| | item | status |
| --- | --- | --- |
| ✓ | RLS on every public table; a second family gets nothing back (T2, 29 tables) | done, tested |
| ✓ | no client write privileges on family/child/billing tables (T1, T3) | done, tested |
| ✓ | admin permissions need MFA; editor can't publish; no self-grant (T5) | done, tested |
| ✓ | privileged functions not callable by clients; identity only from the JWT | done, tested (T1) |
| ✓ | consent before child data; child data minimised in the schema | done, tested (T7) |
| ✓ | child and account deletion that actually deletes (cascade), with a 7-day grace for accounts | DB side done, tested (T7); Stripe / RevenueCat / auth-user steps are in the M12 job |
| ✓ | audit log append-only; child values never logged (T8) | done, tested |
| ✓ | storage: private buckets, size and type limits, no client reads, no SVG in the public bucket (T6) | done, tested |
| ✓ | secrets only in env; `.env*` ignored; `.env.example` has names only | done |
| ☐ | input validation (zod) on every Edge Function route | M1 (SQL functions validate too) |
| ☐ | rate limits on sign-in (Auth settings) and on routes that send email | Auth: §4 #6; routes: M1 |
| ☐ | webhooks verify signatures, store event ids first | M8 |
| ☐ | re-run the SQL tests and `tests/integration/backend.integration.test.ts` on real Supabase (local CLI or the dev project) | §3, before Flutter integration |
| ☐ | `npm audit` / `deno` dependency audit | when Edge Function code exists |
| ☐ | privacy policy lists every processor (Supabase, Resend, Stripe, RevenueCat, Sentry, stores) and the backup retention | legal, before launch |
| ☐ | legal review of the consent method per market (Q3) | open |
