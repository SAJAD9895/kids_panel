# Row level security and access rules

Implemented in `supabase/migrations/20261118001000_rls.sql` (tables), `…001100_storage.sql` (Storage) and `…001200_family_operations.sql` (privileged functions). Tested by `supabase/tests/01_rls_and_operations.sql` (T1–T8), `02_schema_audit.sql` (A1–A12), `03_security_escalation.sql` (S1–S4) and, against real Supabase, `tests/integration/backend.integration.test.ts`.

## 1. The model in five rules

1. **RLS is on for every table in `public`** (64/64), each with at least one policy. Test T1 fails the build otherwise.
2. **Clients read through RLS. Families never write directly.** Parents and the kids app have no `INSERT/UPDATE/DELETE` privilege on any family, child or billing table. All their writes go through Edge Functions, which check the caller and then use the service role or a `private` function.
3. **Identity comes only from the verified JWT.** Policies use `auth.uid()` and `auth.jwt()`. No policy or function reads a parent id, child id or role from request data. Edge Functions pass `sub` from the verified token as `p_user_id`.
4. **Admins** write catalogue tables with their own JWT, and only with the right permission **and** an MFA session (`aal2`). Publishing needs a second permission, enforced by a trigger. The admin web never holds the service key.
5. **Privileged functions** (`private.onboard_family` …) are not callable by `anon` or `authenticated` (`EXECUTE` revoked, schema not exposed).

## 2. Helper functions (`private`, not exposed)

| function | true when | notes |
| --- | --- | --- |
| `is_account_member(acc)` | the caller has a `parent_profiles` row in that account | `security definer`, so policies don't recurse into `parent_profiles`' own RLS |
| `can_access_child(child)` | the child belongs to an account the caller is a member of | same |
| `has_permission(perm)` | the caller is an **active** admin, holds a role with that permission, **and** the JWT has `aal = 'aal2'` | MFA is part of the permission, not a UI check |
| `is_service()` | the service role or the migration owner | invoker on purpose (used by the publish guard) |

## 3. Who can read what

| table group | parent (own family) | other parents | anon | admin (aal2) |
| --- | --- | --- | --- | --- |
| `parent_accounts`, `parent_profiles`, `parental_consents`, `child_profiles`, `devices`, `deletion_requests` | ✓ own account | ✗ | ✗ | `support.read` |
| `content_downloads`, `data_export_requests` | ✓ | ✗ | ✗ | ✗ |
| child-owned: sessions, results, responses, stars, gifts, child rewards, scenes, enrolments, step completions, mastery, daily progress, paths, certificates, favourites, free allocations, screen time | ✓ own children | ✗ | ✗ | `support.read` |
| catalogue: activities, games, questions, answers, courses, modules, lessons, steps, paths, collections (in their time window), categories, rewards, reward sets, game templates, public media, avatars, subjects, skills | published / active only | same | same | drafts with `content.read` |
| `subscription_plans` | active | same | same | `billing.read` |
| `subscriptions`, `payments`, `entitlements`, `promo_redemptions` | ✓ own account | ✗ | ✗ | `billing.read` |
| `billing_webhook_events`, `promo_codes` | ✗ | ✗ | ✗ | `billing.read` |
| `notifications`, `notification_preferences` | own user only | ✗ | ✗ | ✗ |
| `admin_users`, `admin_user_roles` | ✗ | ✗ | ✗ | self, or `admin.manage` |
| `admin_roles`, `admin_permissions`, `admin_role_permissions` | ✗ | ✗ | ✗ | `admin.manage` |
| `audit_logs` | ✗ | ✗ | ✗ | `audit.read` |
| `feature_flags` | ✓ | ✓ | ✓ | ✓ |
| `analytics.*` | schema not reachable by any client role | | | |

**Children** are not database users. A child is a profile under the parent's session in "kid mode" (`docs/architecture/06-…` §6.3), so a child can only ever reach what the parent's session can reach: their own family. One child's private data is visible to the parent, not to other families. Within one family, the apps show one child's data at a time (`X-Child-Id`, checked by `can_access_child`).

## 4. Who can write what

| writer | how | tables |
| --- | --- | --- |
| parents, kids app | **Edge Functions only** (service connection after checks) | everything family-, child- and billing-owned |
| admins (own JWT, aal2) | Data API with RLS | catalogue tables (`content.write`) **while they are drafts**; publishing, and any change to live content or its child rows (game config, questions, answers, steps, row items, active rewards, ready media), needs `content.publish` (trigger `guard_live` on 20 tables, migration 0013); `subscription_plans`, `promo_codes` (`billing.manage`); `admin_users`, `admin_user_roles` (`admin.manage`, **never for themselves**); `feature_flags` (`admin.manage`) |
| webhooks, jobs | Edge Functions with signature / shared secret → service connection | billing, notifications, deletion, analytics |
| nobody | — | `audit_logs` (append-only trigger; written only by the audit trigger) |

Two layers protect every write: **privileges** (clients hold no `INSERT/UPDATE/DELETE` on family/child/billing tables) and **policies** (no client write policy exists there). Test T3 checks that a parent can't mint a star, edit their own child directly, create an account for someone else, or grant themselves an admin role.

## 5. Admin roles

| role | permissions |
| --- | --- |
| `content_editor` | content.read, content.write |
| `content_publisher` | content.read, content.write, content.publish |
| `support_agent` | support.read, support.act, billing.read |
| `finance` | billing.read, billing.manage, support.read |
| `privacy_officer` | privacy.act, audit.read, support.read |
| `super_admin` | all 10 (at most two people) |

- Roles are data (`admin_role_permissions`), so they can be changed without code.
- No self-grant (policy `user_id <> auth.uid()`), so a super admin can't escalate themselves or create a second identity unnoticed: every change is audited.
- `support.read` is broad: read-only access to family records **including children's play history and answers** (needed to investigate "my child's progress is missing"). Keep it to a small support team; the `admin` Edge Function will audit every family lookup (M3). Narrowing it (e.g. aggregates only) is a policy change in one place if counsel asks for it.
- **The first super admin** is created once by SQL from the dashboard (`setup-guide.md` §6). There is no API path to become an admin.

## 6. Storage

| bucket | public | client policies | access |
| --- | --- | --- | --- |
| `public-assets` | yes | none (no SELECT policy, so the bucket can't be listed) | public URLs of published art |
| `content`, `video`, `exports` | no | **none** | signed URLs from Edge Functions (15 min; exports 7 days) |
| `admin-staging` | no | INSERT only: `content.write` + aal2, path must start with the uploader's user id | `admin/media/finalize` (service) verifies and moves it |

Test T6 checks this.

## 7. Audit

Audited tables log `insert/update/delete` with actor type (`parent`, `admin`, `service`, `system`) from the JWT. Child tables (`child_profiles`, `screen_time_rules`) log **column names only**, never values (T8). The log is append-only for every role including the owner; only the retention job may purge, by setting `app.audit_purge` in its own transaction.

## 8. Running the tests

```bash
scripts/db-verify.sh        # throwaway Postgres 17, ~10 s; exits non-zero on any failure
```

Against real Supabase (local CLI or a preview branch), run the same file after `supabase db reset`:

```bash
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2- | tr -d '"')" -f supabase/tests/01_rls_and_operations.sql
```
