# 3. Next.js architecture (parent web + admin web)

Two Next.js apps (App Router, TypeScript strict, Tailwind) in a pnpm workspace [D]. They are **separate deployments on separate domains** [P]: the admin app has stricter headers, MFA, an optional IP allowlist and its own cookie scope, and a bug in the parent app can't expose admin pages.

| app | domain [P] | users | does not do |
| --- | --- | --- | --- |
| `apps/parent-web` | `parents.<domain>` (plus marketing pages at `www.`) | parents | no child-facing UI (that's Flutter web at `play.<domain>`) |
| `apps/admin-web` | `admin.<domain>` | staff with an admin role | never holds the Supabase service-role key |

## 3.1 Data access pattern (both apps)

- **Reads**: React Server Components create a Supabase server client with `@supabase/ssr` from the user's httpOnly cookie. Queries run under RLS **as that user**.
- **Mutations**:
  - parent web: a Server Action calls the right Edge Function with the user's JWT;
  - admin web: content CRUD writes go straight to tables under RLS (role permission + MFA, D2); privileged operations (uploads, publish validation, support lookups, privacy runs) call the `admin` Edge Function.
- **Types**: `supabase gen types typescript` → `packages/ts/supabase/database.types.ts`, regenerated in CI on every migration. Edge Function request/response schemas are zod, shared from `packages/ts/supabase/api/`.
- **No Next.js API routes for business logic.** Webhooks go to Edge Functions. Next.js route handlers are used only for the auth callback and health checks.

## 3.2 `apps/parent-web` folders

```
apps/parent-web/
├── app/
│   ├── (marketing)/                    landing, pricing, privacy policy, terms (static)
│   ├── (auth)/
│   │   ├── login/                      magic link + OTP, password, Apple, Google
│   │   ├── auth/callback/route.ts      exchanges the code for a session (PKCE)
│   │   └── signup/                     web onboarding (S01–S03 web variant), consent capture
│   ├── (dashboard)/
│   │   ├── layout.tsx                  sidebar, account switcher (future co-parents), session check
│   │   ├── page.tsx                    overview: children, this week, subscription status
│   │   ├── children/new/page.tsx       add a child (P02; plan limit → upsell)
│   │   ├── children/[childId]/
│   │   │   ├── page.tsx                profile, avatar, stage, archive / delete (P02)
│   │   │   ├── activity/page.tsx       recent activity list, newest first (P04b)
│   │   │   ├── progress/page.tsx       S32 report: 14-day default, 7–90 selectable [V SS-14]
│   │   │   ├── courses/page.tsx        course progress, certificates (PDF)
│   │   │   └── screen-time/page.tsx    S33/S34: limit, limited sections, toggles
│   │   ├── subscription/page.tsx       S35: plan, Stripe portal; store subs → instructions
│   │   ├── redeem/page.tsx             S08 promo codes
│   │   ├── plans/page.tsx              plan picker + Stripe Checkout (P07/P08, S04/S07)
│   │   ├── downloads/page.tsx          per-device download usage, read-only on the web (P10)
│   │   ├── devices/page.tsx            signed-in devices, sign a device out (P14)
│   │   ├── notifications/page.tsx      preferences
│   │   ├── help/page.tsx               help articles, contact support, app version (P15)
│   │   ├── privacy/page.tsx            consents, data export, delete child / account
│   │   └── settings/page.tsx           email, password, language, timezone, sign out
│   └── layout.tsx                      CSP nonce, fonts, theme
├── components/                         page-specific components
├── lib/
│   ├── supabase/server.ts | client.ts  @supabase/ssr factories
│   ├── edge.ts                         typed Edge Function caller (forwards the user JWT)
│   └── format.ts                       dates in the household timezone
├── middleware.ts                       session refresh; redirects for (dashboard)
└── next.config.ts                      security headers
```

## 3.3 `apps/admin-web` folders

```
apps/admin-web/
├── app/
│   ├── (auth)/login/                   email + password or SSO [OPEN], then TOTP MFA (aal2 required)
│   ├── (admin)/
│   │   ├── layout.tsx                  nav filtered by the user's permissions
│   │   ├── page.tsx                    home: my drafts, review queue, failed media, today's publishes, alerts (A02)
│   │   ├── content/
│   │   │   ├── activities/             list, filters, edit, questions + answers editor
│   │   │   ├── games/[activityId]/     template picker + JSON-Schema form (from game_templates.config_schema) + live preview
│   │   │   ├── courses/                course → modules → lessons → steps tree editor
│   │   │   ├── paths/                  learning paths
│   │   │   ├── collections/            feed rows, worlds, drops with schedule windows
│   │   │   ├── taxonomy/               categories, subjects, skills
│   │   │   ├── rewards/                sets, stickers, scenes, badges, lesson prizes
│   │   │   ├── avatars/                avatar and buddy art, characters (A21)
│   │   │   ├── localization/           missing-translation and missing-voice-over report per locale (A22)
│   │   │   └── review/                 publish queue (content.publish only)
│   │   ├── media/                      library, resumable upload, processing status
│   │   ├── templates/                  game template versions (read-mostly; engineers ship them)
│   │   ├── analytics/                  content performance (A20, `GET /admin/analytics/content`)
│   │   ├── families/                   support lookup by email (support.read), actions (support.act)
│   │   ├── billing/                    subscriptions, payments, webhook events, promo codes
│   │   ├── privacy/                    export / deletion requests, retention runs
│   │   ├── audit/                      audit log viewer (audit.read)
│   │   ├── admins/                     admin users and roles (admin.manage)
│   │   └── flags/                      feature flags
├── components/
│   ├── data-table/                     TanStack Table wrapper (server pagination)
│   ├── forms/                          react-hook-form + zod; localized-text field ({en, es, …})
│   ├── json-schema-form/               @rjsf for game config
│   └── preview/                        iframe of the template playground (Flutter web)
├── lib/
│   ├── permissions.ts                  can(user, 'content.publish'), mirrors private.has_permission
│   └── supabase/                       server/client factories
├── middleware.ts                       requires session AND aal2; short idle timeout (30 min)
└── next.config.ts                      strict CSP, frame-ancestors 'none', noindex
```

**Activity preview**: the admin embeds `tools/template_playground` (a small Flutter web build) in an iframe and posts the draft config to it. Editors see the real game before publishing, on the same engine children use.

## 3.4 Shared TypeScript packages

| package | contents |
| --- | --- |
| `packages/ts/ui` | buttons, inputs, dialogs, tables, empty and error states; Tailwind preset generated from `docs/design/tokens/tokens.json` (`tailwind.preset.cjs`); components per `docs/design/components.md` |
| `packages/ts/supabase` | generated DB types; `createServerClient` helpers; zod schemas for every Edge Function route; typed `callEdge()` |
| `packages/ts/config` | tsconfig, eslint (incl. `no-restricted-imports` so the admin can't import the service key helper), tailwind base |

## 3.5 Web security headers [P]

| header | parent web | admin web |
| --- | --- | --- |
| Content-Security-Policy | nonce-based scripts; connect-src Supabase + Stripe; frame-src Stripe | nonce-based; connect-src Supabase only; frame-src the playground origin |
| Strict-Transport-Security | max-age=63072000; includeSubDomains; preload | same |
| X-Frame-Options / frame-ancestors | DENY | DENY |
| Referrer-Policy | strict-origin-when-cross-origin | no-referrer |
| Permissions-Policy | camera=(), microphone=(), geolocation=() | same |
| robots | marketing indexed, dashboard noindex | noindex everywhere |

## 3.6 Accessibility and i18n

- WCAG 2.2 AA for both apps (the original declares no accessibility features [V R35]; we can do better).
- `next-intl` [P] with the same locale set as the app; RTL support via logical CSS properties if Arabic is in scope [OPEN].
