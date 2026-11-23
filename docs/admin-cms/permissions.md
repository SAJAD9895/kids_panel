# Admin permissions

Phase 14, 2026-11-21. Roles and permissions are the Phase 5 RBAC tables (`admin_roles`, `admin_permissions`, `admin_role_permissions`, `admin_user_roles`, `admin_users`). They are reference data in migrations, so changing what a role can do is a reviewed migration, not a click.

## 1. Roles

| role (key) | shown as | permissions |
| --- | --- | --- |
| `super_admin` | **Super admin** | all 10 |
| `content_publisher` | **Content manager** | content.read, content.write, content.publish |
| `content_editor` | Content editor | content.read, content.write |
| `support_agent` | Support | support.read, support.act, billing.read |
| `finance` | Finance | billing.read, billing.manage, support.read |
| `privacy_officer` | Privacy officer | privacy.act, audit.read, support.read |

The brief's two roles are **super admin** and **content manager**. The other four are the existing staff roles from Phase 5, kept because support, finance and privacy work shouldn't need content rights, and the reverse.

## 2. Permission → what it allows

| permission | pages | database |
| --- | --- | --- |
| content.read | content pages, review queue, media, rewards, settings (read) | drafts visible (RLS); `admin_api.validate`, content activity feed |
| content.write | create and edit drafts, upload media, send for review | insert, update and delete on content tables (RLS); staging uploads |
| content.publish | approve, publish, archive, send back; enable categories; activate badges | `transition` moves; edit **approved or published** content (live guard) |
| support.read | families, data requests (read) | `admin_api.families` / `family` / `privacy_requests` |
| support.act | suspend or reactivate a family, add stars, cancel a deletion | `set_account_status`, `grant_stars`, `cancel_deletion` |
| billing.read | subscriptions page | `subscription_plans` (all), `subscriptions`, `payments` (RLS) |
| billing.manage | edit plan metadata | update `subscription_plans` |
| privacy.act | build an export | `admin` function `exports/:id/run` |
| audit.read | audit log | `admin_api.activity` (everything, including full rows) |
| admin.manage | admin users, system settings | `set_roles`, `set_admin_status`, write `app_config`, `admin_user_roles` |

## 3. Rules that hold even against a modified browser

1. **MFA is part of every permission.** `private.has_permission` returns false unless the JWT is `aal2`. A stolen password alone gives nothing.
   - Sign-in is password, then authenticator code. An admin without a factor sets one up at first sign-in.
   - A parent's account is turned away before the factor step.
2. **Nobody grants themselves anything.**
   - `admin_api.set_roles` and `set_admin_status` refuse your own account.
   - The `admin_user_roles` table policy refuses `user_id = auth.uid()` even with `admin.manage`.
   - At least one active super admin always remains.
   - Tested in SQL (X1) and integration.
3. **Roles come from the database, never the client.**
   - The JWT carries no role claims the app trusts.
   - Every page re-reads `admin_api.me()`.
   - Every query is checked by RLS or the function itself.
4. **Suspended admins** have no permissions from their next request: `has_permission` checks `admin_users.status`.
5. **No service key in the app.** Privileged file and export work runs in the `admin` Edge Function, which repeats the permission check.
6. **Audit.**
   - Role, status, settings, content, plan, account and star changes are all logged with the acting admin.
   - The log is append-only: a trigger refuses update and delete, and no client has write access.

## 4. Families and children: least data

Support sees, per family:
- the parents' emails and roles;
- account status, country and time zone;
- subscriptions;
- data requests.

Per child, support sees only:
- **nickname, age in whole years, status;**
- sessions and finished activities in the last 30 days;
- last active;
- star balance.

**Not shown:** birth month, avatar, session details, answers, analytics ids. The reports are for parents (Phase 13), not staff.

**Learning activity "where authorized"** means these counts, for `support.read` only.

## 5. Sensitive operations

| operation | who | safeguards |
| --- | --- | --- |
| suspend or reactivate a family | support.act | written reason (≥ 5 characters), audited. Suspended: the app can't record play or open media (`ACCOUNT_SUSPENDED`), and the parent's data is untouched |
| add stars to a child | support.act | 1–20 stars, a reason (≥ 10 characters), a request id (a repeat does nothing), `admin_adjustment` in the ledger, audited. **No removal, no editing of balances**: clients can't write the ledger at all |
| cancel a scheduled account deletion | support.act | the parent asked; a reason; audited (parents can also cancel themselves) |
| build a requested export | privacy.act | only an existing request from the parent; the file goes to the parent's private export folder; audited with the admin |
| change roles or status | admin.manage | not yourself; at least one super admin remains; audited |
| change settings | admin.manage | values validated by a database trigger (ranges, types) |

## 6. Testing

Each of these rules has a test:
- SQL suite X1;
- `admin_panel/test/integration/cms.test.ts`, as each role, with and without MFA;
- Playwright: signed out, a parent, support on a content page.

See `testing-report.md`.
