# 14. Security and child privacy architecture

**This is a technical design, not legal advice.** The legal requirements below are my reading of the rules and are marked [A]. They need review by privacy counsel in your launch markets before launch [OPEN].

## 14.1 Security principles

1. **Parents control children's accounts.** A child profile exists only under a parent account; only that account's parents can see or change it, and only the owner can delete it or export its data.
2. **Deny by default.** RLS on every table, private buckets by default, no client write policies on family data.
3. **The server decides.** Access, awards, unlocks and entitlements are computed server-side; the apps are untrusted.
4. **Least privilege** for staff (RBAC + MFA), for services (separate keys per environment), and for data (collect the minimum).
5. **Everything sensitive is audited**, and the audit log can't be edited.
6. **Defence in depth**: gateway JWT check → RLS → explicit function checks → constraints.

## 14.2 Requirement → design map (brief section 5)

| requirement | design | where |
| --- | --- | --- |
| parent-controlled child accounts | no child logins; `child_profiles.account_id`; `can_access_child` on every child route and in RLS; owner-only delete / export | `06-…` |
| strict Supabase RLS | enabled on 64 / 64 tables; read policies only for families; admin writes need permission + aal2; tested (29 checks) | `05-…` §5.6–5.7 |
| role-based admin permissions | 6 roles, 10 permissions, enforced in RLS via `private.has_permission`; no self-grant; publish needs a separate permission | `06-…` §6.4 |
| secure authentication | magic link + OTP with PKCE, refresh rotation, Apple/Google, MFA for admins, re-auth for destructive actions | `06-…` |
| protected media | private buckets, signed URLs (15 min), launch gate checks entitlement before issuing them | `11-…` |
| secure payment verification | server-side receipt validation via RevenueCat, webhook signature + re-fetch, idempotent upserts, daily reconcile | `10-…` §10.4 |
| audit logs | `audit_logs` append-only (trigger + revoked grants); triggers on 25 sensitive tables; child rows logged as column names only | `05-…`, schema §10 |
| data deletion and export | `deletion_requests` (7-day grace for accounts) + job; `data_export_requests` + job → zip in `exports`; both need re-auth | §14.6 |
| parental consent | `parental_consents` with type, policy version, method, evidence; consent before any child data reaches the server | §14.4 |

## 14.3 Data inventory (what we hold about children)

| data | why | stored | retention [P, OPEN legal] |
| --- | --- | --- | --- |
| nickname (1–20 chars) | show on the profile | `child_profiles` | until child / account deletion |
| birth year + month (no day) | age-appropriate content, stage | `child_profiles` | same |
| avatar choice | profile picture from our library | `child_profiles` | same |
| play history (sessions, results, answers) | progress, rewards, reports | play tables | raw for 24 months, then aggregated into `daily_progress` and deleted [OPEN] |
| skill mastery, course progress, rewards | learning features | progress tables | until deletion |
| pseudonymous product events | product improvement | `analytics.events` | 13 months |
| device record (install id, platform, app version) | downloads, push for parents | `devices` | 90 days after last seen |
| **not collected** | — | — | photos, voice, video of the child, full birth date, school, location, contacts, advertising ids, free-text chat |

About parents: email, optional display name, timezone, country, consents, subscription and payment records (amount, currency, provider ids; **no card numbers** — Stripe and the stores hold those).

## 14.4 Parental consent [A, OPEN legal]

**Frameworks that apply** (to confirm per market):
- **COPPA** (US, under 13). The FTC's amended rule (finalised 2025) adds, as I understand it: separate consent before disclosing children's data to third parties, a written information security program, and a written data retention policy that rules out keeping data indefinitely [A].
- **GDPR Art. 8** (EU, under 13–16 depending on the country) and the **UK GDPR + Age Appropriate Design Code** (Children's Code: high privacy by default, no nudge techniques, data minimisation, parental controls transparent to the child) [A].
- **Store rules**: Apple Kids Category (parental gate, no third-party analytics or ads) and the Google Play Families policy [A].
- Later, for schools: FERPA (US), and the school as consenting party.

**Design:**
1. **Order of operations.** Child setup happens on the device first [V F01]. Nothing about the child is sent to the server until the parent has an account and has given consent in the same `onboarding/complete` transaction.
2. **What is consented to**, each as a separate `parental_consents` row with `policy_version`: terms, privacy policy, collection of the child's data for the service (`child_data_collection`), and optional marketing email and push. **There is no `third_party_disclosure` consent request in v1, because we don't disclose children's data to third parties** (only to processors under contract).
3. **Method**: v1 records `email_plus` [P]: consent is confirmed from the parent's verified email, followed by a confirmation email. As I understand COPPA, this method is allowed when data is used only internally. A first paid subscription records `store_purchase` / `payment_card` as additional evidence. **Counsel must confirm the method per market.**
4. **Evidence** stored: time, policy version, method, hashed IP, user-agent class, the confirmation email's message id.
5. **Withdrawal**: revoking `child_data_collection` stops processing and starts child deletion. Revoking marketing only stops marketing.
6. **Policy changes**: a new `policy_version` that materially changes data use requires fresh consent at next sign-in.

## 14.5 Child privacy by design

- Data minimisation in the schema itself: month-only birth dates (DB check), a 20-character nickname, no free-text fields for children.
- Child surfaces have no external links, ads, chat, social features or third-party SDKs except the scrubbed crash reporter [OPEN].
- Profiling: skill mastery is used only to adapt learning and inform the parent. It is never used for marketing, never shared, and covered in the DPIA [OPEN].
- Notifications go to parents only, never to children. Push text never contains the child's nickname (`notifications.params` rule).
- Defaults: marketing opt-in off, push off until the parent enables it, no public profiles.
- Mic and camera features are deferred. If added: processed on the device, never uploaded, permission behind the gate.
- **A Data Protection Impact Assessment is required before launch** [A, GDPR Art. 35 / Children's Code]. The DPIA, the retention policy and the security program document are deliverables of M12.

## 14.6 Data export and deletion

**Export** (`POST /account/export`, owner, re-auth):
1. Creates `data_export_requests` → queue → `jobs/exports` builds the export in chunks.
2. Zip contents: `account.json`, `parents.json`, `children/<id>/profile.json`, `sessions.csv`, `results.csv`, `answers.csv`, `progress.json`, `rewards.json`, `consents.json`, `subscriptions.json`, `payments.json`, `notifications.json`, plus a README explaining each file. Machine-readable (GDPR Art. 20).
3. Stored at `exports/{accountId}/{requestId}.zip` (private); the parent gets an email and an in-app notice; the signed link lasts 7 days, then the file is deleted.

**Deletion**:
| scope | trigger | grace | steps |
| --- | --- | --- | --- |
| child | owner, re-auth | none (immediate) [P] | delete `child_profiles` (cascades sessions, results, progress, rewards, favorites); analytics events become anonymous (link deleted); request row kept |
| account | owner, re-auth | **7 days**, cancellable [P] | `jobs/deletions`: cancel the Stripe subscription and delete the customer; warn about store subscriptions (can't be cancelled server-side for Apple); delete the RevenueCat subscriber; delete export files; delete `parent_accounts` (cascades everything); delete the `auth.users` rows; keep the audit log (no child values) |

- Backups: Supabase point-in-time backups keep deleted data until they roll off (days to weeks, by plan). The privacy policy must say so [A].
- Billing records: whether we must keep payment records after deletion for tax purposes is a legal question [OPEN]. Default: our `payments` mirror is deleted; Stripe and the stores keep their own records under their legal duties.
- Staff can run a request on behalf of a parent (`privacy.act`), and it is audited.

## 14.7 Threat model (summary)

| threat | likelihood / impact | mitigations |
| --- | --- | --- |
| one family reads another's child data | low / severe | RLS on all tables, `can_access_child` in every function, pgTAP isolation tests in CI, no client writes |
| modified app awards itself stars, Plus or unlocks | medium / medium | server-side engine and launch gate; constraints; client is untrusted |
| parent account takeover | medium / high | PKCE magic link + OTP, rate limits, refresh rotation, new-device email, sign out all devices |
| admin account takeover | low / severe | MFA enforced in the database, company email only, least privilege, no service key in the admin web, audit, access reviews |
| service-role key leak | low / severe | key only in Edge Function secrets and the CI pipeline secrets; never in apps or Next.js; rotation runbook; secret scanning in CI |
| payment fraud / fake receipts | medium / medium | server-side validation, signature checks, re-fetch, sandbox separation |
| webhook replay / forgery | medium / medium | signatures, timestamp tolerance, unique event ids |
| malicious upload in the CMS | low / medium | only admins upload; staging bucket; type sniffing; size caps; EXIF strip; no SVG with scripts (rasterised in the pipeline) |
| XSS in web apps | low / high | React escaping, strict CSP with nonces, no raw HTML from the CMS (structured text only) |
| content piracy | high / low | signed URLs, accepted residual risk |
| DoS / abuse | medium / medium | rate limits, Vercel firewall, Supabase limits, batch caps |
| vendor exposure of child data | low / high | no third-party SDKs in kids surfaces, DPAs with each processor, EU/US region choice |
| insider misuse | low / high | least privilege, support read-only, every lookup audited, quarterly review |

## 14.8 Platform hardening

| area | measures |
| --- | --- |
| mobile | release obfuscation; secure storage for tokens; no secrets in the binary except publishable keys and the entitlement public key; App Transport Security / Network Security Config with HTTPS only; screenshots allowed (not sensitive) |
| web | HSTS preload, CSP, frame-ancestors none, cookies httpOnly + Secure + SameSite, dependency audit |
| database | private schema for helpers; `search_path` pinned on definer functions; `analytics` schema not exposed; Supabase network restrictions on direct DB access; SSL enforced |
| secrets | per environment; rotation every 12 months or on staff change; listed in a secrets inventory |
| supply chain | lockfiles, Dependabot/Renovate, `pnpm audit`, `dart pub outdated` checks; pinned GitHub Actions by SHA |
| testing | pgTAP RLS suite; OWASP MASVS L1 checklist for the apps; OWASP ASVS L2 for the web apps; external penetration test before launch (M13) |
| incident response | runbook: detect, contain (rotate keys, revoke sessions), assess, notify (GDPR 72 h to the regulator; parents as required), review |
