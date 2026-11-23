# Authentication, parental consent and deletion

Design: `docs/architecture/06-auth-and-authorization.md`, `14-security-and-child-privacy.md`. Configuration: `supabase/config.toml` (local) mirrored in the dashboard (`setup-guide.md` §4). Email templates: `supabase/templates/`.

## 1. Who signs in

| identity | method | stored as |
| --- | --- | --- |
| **Parent** | email **magic link + 6-digit code in the same email** (the code works when the link opens on another device); optional password; Sign in with Apple; Google | `auth.users` → `parent_profiles` → `parent_accounts` |
| **Child** | **never signs in**. A profile under the parent's session in kid mode, behind the parental gate | `child_profiles` |
| **Admin** | email + password, **TOTP MFA required** (the database ignores admin permissions below `aal2`) | `auth.users` → `admin_users` + roles |
| Edge Functions | service role (platform-provided, server-only) | — |

Apple rule: offering Google sign-in on iOS requires offering Sign in with Apple too.

## 2. Settings (in `config.toml`; set the same in the dashboard)

| setting | value | why |
| --- | --- | --- |
| OTP length / expiry | 6 digits / 10 min | the code typed on another device |
| email resend interval | 60 s | abuse |
| access token (JWT) lifetime | 1 h | short-lived tokens |
| refresh token rotation + reuse interval | on, 10 s | detects a stolen refresh token |
| confirm email, secure email change, secure password change | on | email is the identity |
| password minimum | 10 characters, mixed case + digits (+ leaked-password protection on Pro) | optional passwords must be strong |
| anonymous sign-ins, phone | off | not used; less to attack |
| MFA (TOTP) | enrol + verify on | admins |
| flow | PKCE in every client | no tokens in URLs |
| rate limits | sign-in/sign-up 30 / 5 min / IP, verifications 30, emails per hour (raise after custom SMTP) | brute force, email bombing |

Token storage: mobile `flutter_secure_storage`; parent and admin web httpOnly Secure SameSite=Lax cookies via `@supabase/ssr`; children's web (Flutter web) the browser default, offset by a strict CSP and no third-party scripts.

## 3. Sign-up and onboarding (F01)

```mermaid
sequenceDiagram
  participant App as App (parent)
  participant Auth as Supabase Auth
  participant EF as Edge Function onboarding
  participant DB as private.onboard_family
  App->>App: child nickname, birth month, buddy — kept ON THE DEVICE
  App->>Auth: signInWithOtp(email), PKCE
  Auth-->>App: email: link + 6-digit code
  App->>Auth: verifyOtp(code) or open the link
  Auth-->>App: session (JWT sub = user id)
  App->>EF: POST /onboarding/complete {timezone, locales, child, consents[]}
  EF->>EF: verify JWT → user id; validate body (zod); add evidence (hashed IP, UA class)
  EF->>DB: onboard_family(user id FROM THE JWT, payload)
  DB-->>EF: {accountId, childId, created}
```

`private.onboard_family` (implemented, tested in T7):
- writes account, owner profile, consents and the first child in **one transaction**, so no child data exists without consent;
- requires the `terms`, `privacy_policy` and `child_data_collection` consents, each with a `policyVersion`. `child_data_collection` must use the `email_plus` method. **It rejects `third_party_disclosure`**, because v1 discloses nothing to third parties;
- validates the timezone (IANA), country (ISO alpha-2), locales, nickname (1–20 characters) and a birth `YYYY-MM` for a child aged 1–12;
- is **idempotent per user** (a retry returns the same account with `created: false`) and serialised with an advisory lock.

`p_user_id` is always the JWT's `sub`. A request body can't name another parent, and no function accepts an account id or role from the client.

## 4. Parental consent requirements

What the system records (`parental_consents`): one row per consent type, with `policy_version`, `method`, `granted_at`, `revoked_at`, and `evidence` (hashed IP, user-agent class, confirmation email id; set by the Edge Function, never by the client).

| requirement | status |
| --- | --- |
| consent before any child data reaches the server | **enforced** by `onboard_family` (single transaction) |
| separate consents for terms, privacy, child data; optional marketing and push are off by default | **enforced** (required set; `marketing_opt_in` defaults to false) |
| no third-party disclosure of children's data in v1 | **enforced** (the consent type is rejected) |
| method `email_plus` for child data (verified email + confirmation email) | **enforced** in the DB; the Edge Function must send the confirmation email (M1) |
| a new material `policy_version` requires fresh consent at next sign-in | Edge Function `account/me` compares versions (M1) |
| withdrawing `child_data_collection` stops processing and starts child deletion | `POST /account/consents` (M1) → `private.delete_child` |
| the consent method is acceptable per market (COPPA 2025 amendments, GDPR Art. 8, UK Children's Code) | **[OPEN] needs counsel** (Q3); this is a design, not legal advice |
| DPIA, written retention policy, information security program | M12 deliverables |

## 5. Account and child deletion requirements

| scope | who | grace | implemented by |
| --- | --- | --- | --- |
| one child | owner, after re-authentication (fresh code) | none | `private.delete_child`: deletes the child and **every** child-owned row by cascade; keeps a `deletion_requests` record (completed, no child link); analytics events become anonymous because the link (`analytics_id`) is gone |
| whole account | owner, after re-authentication | **7 days**, cancellable | `private.schedule_account_deletion` → status `pending_deletion`; `private.cancel_account_deletion`; the daily job calls `private.execute_account_deletion` when due |

After `execute_account_deletion` the job (M12) must also, in this order:
1. cancel the Stripe subscription and delete the Stripe customer; delete the RevenueCat subscriber; tell the parent that **store subscriptions must be cancelled in the App Store / Google Play** (they can't be cancelled server-side);
2. delete export files under `exports/{accountId}/`;
3. delete the auth users it returns (`authUserIds`) with `auth.admin.deleteUser`. (`parent_accounts.owner_user_id` is `ON DELETE RESTRICT`, so deleting a user in the dashboard first fails on purpose: deletion must go through this flow.)

What remains: the audit log (no child values) and Supabase backups until they roll off (days to weeks by plan). **The privacy policy must say both.** Apple requires in-app account deletion for apps with sign-up; this is it.

## 6. Re-authentication

Required (a fresh 6-digit code) for: changing email, changing the password, deleting a child or the account, requesting a data export. **This is the Edge Function's job** (M1): it checks that the JWT's `amr` sign-in timestamp is under 10 minutes old before calling the SQL operation. The SQL functions check ownership, not freshness.

## 7. Kid mode and the parental gate

The gate (design K20: three numbers written as words) is a **child-proofing UX**, not a security boundary. Real protection is server-side: purchases need store confirmation, deletions need re-authentication, and reports are read-only. A passed gate gives a 5-minute in-memory gate token on the device.

## 8. Admins

- Invited by `admin.manage` (`POST /admin/users/invite`, company domain only); the first super admin is bootstrapped by SQL (`setup-guide.md` §6).
- TOTP enrolment on first login; every admin permission needs `aal2`. Idle timeout 30 min in the admin web.
- Never holds the service key; writes catalogue tables through RLS.
