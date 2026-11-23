# Authentication, session and child profiles (as built)

Backend side: `docs/backend/authentication.md`, `api-design.md`. Screen designs: `docs/design/` (K01–K07, K20, K35, P01, P02, P16, P17).

## 1. Screens

| id | route | screen | states |
| --- | --- | --- | --- |
| K01 | `/` | splash while the session is restored and the family looked up | loading; error with retry and sign-out (offline at start) |
| K02 | `/welcome` | two doors: set up / I have an account | — |
| K05 | `/setup/child`, `/parents/children/new` | nickname + birth month and year | validation per field; age hint ("age 5 → Big explorer") |
| K06 | `/setup/buddy`, `/parents/children/new/buddy`, `/parents/children/:id/buddy` | pick a buddy | skeleton tiles; kid error + retry; empty ("pick one later"); busy while adding |
| K03 | `/setup/grown-up` | email + consents (or consents only, when already signed in) | email / consent validation; send error |
| — | `/sign-in` | email code, or password | not found (offers sign-up), wrong password, rate limit |
| K04 | `/sign-in/code` | 6-digit code | wrong / expired code; resend after 60 s; lost state ("start again") |
| — | `/setup/finish` | creates the family | loading; error with "Try again" and "Edit details" |
| K35 | `/who` | who's playing | skeleton; kid error; empty ("ask a grown-up"); one child → picked automatically |
| K07 | `/kids` | greeting, buddy, Grown-ups, switch player (shell only) | — |
| K20 | `/gate` | three numbers as words + keypad (also keyboard digits, Backspace, Esc) | wrong → new numbers |
| P01 | `/parents` | children, account, sign out | demo banner; loading; error |
| P02 | `/parents/children` | list, add | skeleton; error; empty; pull to refresh |
| P02 | `/parents/children/:id` | edit nickname, birth month, buddy; delete | not found; save / delete errors; plan limit dialog |
| P17 | dialog | fresh email code before deleting | sending; wrong code; resend |

Screenshots of the web build: `screens/`.

## 2. Flows

**Sign-up (F01).** K02 → K05 → K06 → K03 → K04 → family created → K07. The child's details and the consents stay **on the device** (in memory) until the parent has a session. Then one call, `POST /onboarding/complete`, creates the account, the consents and the child in one transaction. If the parent signs in through "I have an account" but has no family yet, the router sends them through K05 → K06 → K03 (consents only) → finish.

**Sign-in (F03).** Email → code (or link), or email + password. Afterwards: one child → kids home; two or more → K35.

**Session.** Supabase restores the session at start-up (Keychain / Keystore on mobile, browser storage on the web) and refreshes the 1-hour token automatically. When the session ends anywhere (sign-out, refresh token revoked or reused, another device's global sign-out), `sessionProvider` clears the chosen child, the gate, the drafts and the cached family data, and the router returns to Welcome.

**Sign-out.** P01 › Sign out › confirm. Local scope: other devices stay signed in.

**Parental gate.** Every `/parents…` route needs an open gate (5 minutes, memory only). Closing the Parents Area locks it again. It is child-proofing, not security; the server never trusts it.

**Child profiles.**
- Add: P02 › Add a child › K05 › K06 › "Add Kai" → `POST /children`. Over the plan limit the server answers `402 CHILD_LIMIT` and the parent sees "No room for another profile" (no prices: this is behind the gate, but P07 isn't built yet).
- Edit: `PATCH /children/:id` with nickname, birth month and buddy.
- Delete: confirm → `DELETE /children/:id`. If the last sign-in is older than 10 minutes the function answers `401 REAUTH_REQUIRED`; the app sends a fresh code (P17), verifies it, and retries. Deleting the child who is playing clears the selection.

## 3. What the app sends (and never sends)

| call | body |
| --- | --- |
| `POST /onboarding/complete` | `timezone` (IANA, from the device), `marketingOptIn`, `child {nickname, birthYearMonth, avatarId?}`, `consents [{type, policyVersion, method}]` (terms + privacy `checkbox`, child data `email_plus`) |
| `POST /children`, `PATCH /children/:id` | `{nickname, birthYearMonth, avatarId}` |
| reads (Data API, RLS) | `parent_profiles.account_id` (has a family?), `child_profiles` (active, own family only), `avatars` (active) |

Never sent: a user id, account id, role or consent evidence (the server takes identity from the JWT and adds evidence itself; a unit test checks the onboarding body). Child data kept to the schema's minimum: a nickname (no "@", no long numbers) and a month and year.

## 4. Error messages

Repositories turn every Supabase error into a `Failure` (`core/error`). Grown-ups see its plain message ("That code didn't match or has expired…", "We couldn't connect…"). Children never see error text: kid screens show Bolt and "Try again".

## 5. Not done yet

- Magic-link deep link: wired on Android and iOS, untested until a project exists. Universal Links / App Links need a domain.
- Apple / Google: code path exists, hidden by default.
- Password reset page (P16 web), changing email or password (P13), account deletion (P12), screen time (P03).
- `GET /account/me` (new policy versions → ask consent again; minimum app version) and `POST /account/devices`.
- The consent confirmation email (`email_plus` method) is a TODO in the onboarding Edge Function (Resend, M1).
