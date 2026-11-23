# Backend test report (Phase 6)

Date: 2026-11-18. Scope: `supabase/` (13 migrations, seed, config, templates), `docs/backend/`.
**Overall: the database layer passes every local test after two fixes. It has NOT been applied to a development Supabase project, because none exists yet. So the auth, session and HTTP-level tests are written and type-checked but not run.**

## 1. How it was tested

| tool | what it does | run here |
| --- | --- | --- |
| `scripts/db-verify.sh` | throwaway Postgres 17 + a stand-in for Supabase `auth`/`storage` and its default grants → 13 migrations → seed → 3 SQL suites (88 assertions); everything in one transaction per suite, rolled back | ✓ passed |
| `supabase/tests/01_rls_and_operations.sql` | T1–T8: RLS coverage, family isolation, blocked writes, anon, admin RBAC + MFA, storage, operations, audit | ✓ |
| `supabase/tests/02_schema_audit.sql` (new) | A1–A12: keys, FK indexes, `ON DELETE` rules, column types, triggers, function hardening, RPC surface, policy shapes, buckets, minimisation | ✓ |
| `supabase/tests/03_security_escalation.sql` (new) | S1–S4: id probes across families, privilege escalation, suspended admins, review bypass | ✓ |
| `scripts/check-secrets.sh` (new) | secret patterns, DB URLs with passwords, env files, server keys in client code, git history | ✓ (git history skipped: not a repo yet) |
| `scripts/check-auth-config.py` (new) | 17 auth settings in `config.toml` + the magic-link template | ✓ 17/17 |
| `supabase/tests/integration/backend.integration.test.ts` (new) | real Supabase: sign-in, JWT claims, Data API isolation, blocked writes, RPC exposure, Storage over HTTP, refresh-token rotation, global sign-out | **not run: no target.** Type-checked (`deno check`) ✓; refuses to run without `KL_INTEGRATION_TARGET=local\|dev` ✓ |

Final run:

```
T1 ok: 64 tables, RLS + policies everywhere, writes and privileged functions locked
T2 ok: Bob sees only his own rows in 29 family/child tables
T3 ok: parents read their own data; every direct write is refused
T4 ok: anon sees the published catalogue and nothing else
T5 ok: MFA required, editor ≠ publisher, support read-only, no self-grant
T6 ok: storage writes limited to admin-staging, own folder, content.write
T7 ok: onboarding (validated, idempotent), plan limit, isolation, child + account deletion
T8 ok: audit redacts child values and is append-only
A1–A12 ok: keys, 118 FKs indexed with explicit ON DELETE, types, triggers, functions, policies, buckets
S1 ok: id probes across families return nothing (both directions, incl. aal2)
S2 ok: no path from parent → admin, editor → publisher, or runtime permission edits
S3 ok: suspended or non-MFA admins see nothing
S4 ok: published content changes only with content.publish; drafts editable by editors
✓ all migrations, seed and tests passed
```

## 2. Results by task

| # | task | result | evidence |
| --- | --- | --- | --- |
| 1 | migrations valid **and applied to the dev project** | **valid: PASS. Applied: FAILED (blocked)**. No development project exists for this platform; the only candidate (the school app's) doesn't respond and its schema collides (`setup-guide.md` §1) | db-verify; Supabase connector project list (2026-11-18) |
| 2 | every table, relationship, FK, index | PASS: 64 tables with primary keys; 118 FKs, each indexed and each with an explicit `ON DELETE`; timestamps `timestamptz`; `updated_at` triggers everywhere; no functions in the exposed schema | A1–A7 |
| 3 | audit all RLS policies | PASS after fix F1: RLS + ≥1 policy on all 64 tables; unconditional reads only on `subjects`, `skills`, `feature_flags`; no client write policy on 33 family/child/billing tables; only RLS helpers are client-executable | T1, A8–A10 |
| 4 | Parent A can't access Parent B's children or learning data | PASS: exact own-row counts in 29 family/child tables; id probes for children, sessions, results, mastery, stars, enrolments, favourites, account, billing, consents return nothing, in both directions, even with an aal2 token | T2, S1 |
| 5 | parent authentication and session handling | **PARTIAL**. DB side PASS: identity only from the JWT, onboarding validation, consent gate, idempotency (T7). Config PASS (17/17). Live Auth (sign-in, JWT, refresh rotation, sign-out revocation) **NOT RUN**: needs a Supabase instance | T7, check-auth-config, integration test (pending) |
| 6 | admin permissions; no role escalation | PASS after fix F2: MFA required; suspended admins lose everything; no parent → admin, no editor → publisher, no self-grant, role/permission tables immutable at runtime; editors can no longer change live content | T5, S2–S4 |
| 7 | storage buckets and media access | PASS (SQL): one public bucket, size + type limits on all, no SVG, no client read policy, admin-staging upload only own folder + content.write + MFA, no client writes to content/video/exports. HTTP-level checks (signed URLs, download refusal) are in the integration test, **not run** | T6, A11 |
| 8 | no service keys or secrets in frontend code or Git | PASS for the working tree (no client code exists yet; `.env.example` names only; `.gitignore` covers `.env*`). Git history: **not checkable**, the folder isn't a git repository | check-secrets |
| 9 | missing Edge Functions / backend operations | Identified: **0 of 15 Edge Functions exist**; 6 of 64 routes have their SQL operation; `apply_session`, gift claim, enrol, billing events, redeem and others are still to build | `integration-readiness.md` §3 |
| 10 | fix confirmed issues; document manual steps | 2 issues fixed (§3); manual steps in `integration-readiness.md` §4 | migration 0013 |

## 3. Issues found and fixed

| id | severity | issue | how it was found | fix |
| --- | --- | --- | --- | --- |
| **F2** | **High** | **Review bypass.** An editor (content.write, no content.publish) could change a *published* activity's title, a live game's config, a live quiz's correct answers, remove steps from a live course, or add items to a live feed row. Children saw it immediately, with no publisher review. The draft's `guard_publish` only checked the moment a row *became* published | S4 (failed before the fix) | migration `0013`: `private.is_live()` + trigger `guard_live` on 20 catalogue tables. Any insert, update or delete touching live content, or a child row of live content, needs `content.publish` or the service role. Drafts stay editable. Publishers can still edit live content (S4) |
| **F1** | Low | `private.local_date(account, ts)` returned any household's day (revealing its timezone) and was executable by every role. Not reachable today (`private` isn't exposed), but no policy needs it | A8 (failed before the fix) | migration `0013`: `EXECUTE` revoked from clients, granted to `service_role` |
| — | Low | `.env.example` used inline comments after `KEY=`, which some dotenv parsers read as the value | check-secrets | comments moved onto their own lines |

Earlier phase (already fixed, re-verified): empty-consent bypass and the child-deletion constraint error in the operation functions.

## 4. Accepted behaviour (by design, noted for the record)

| item | why it's accepted |
| --- | --- |
| Kids can read `answers.is_correct` of published quizzes | the app needs it to give feedback offline; answers aren't secret, and stars are decided server-side by `apply_session` |
| `support.read` sees children's play history and answers | needed for support cases; small team, audited lookups (M3); one policy change narrows it if counsel asks (`rls-policies.md` §5) |
| New rewards, avatars and media are created as drafts (`status 'draft'`, `active = false`, `uploaded`) by editors, then made live by a publisher or the finalize step | consequence of F2; the admin web must default these fields (A10, A12 specs) |
| Composite subtype FKs `(id, type)` are covered by an index on `id` | `id` is unique on its own, so the index serves the FK checks (A2 rule documents this) |

## 5. Not tested yet (needs a Supabase instance)

- Supabase Auth itself: OTP and magic-link emails, PKCE, password policy, Apple and Google, MFA enrolment, rate limits.
- Session behaviour: JWT claims, refresh-token rotation and reuse detection, global sign-out.
- PostgREST: the real `/rest/v1` and `/rpc` surface, exposed schemas, max rows.
- Storage over HTTP: signed URLs, MIME and size enforcement, public bucket listing.
- The stand-in's fidelity: real `auth.uid()`, grants and `storage` schema can differ in detail.

All of these are automated in `supabase/tests/integration/backend.integration.test.ts`. Run it, plus `db-verify` style SQL suites, on the dev project (`integration-readiness.md` §4).
