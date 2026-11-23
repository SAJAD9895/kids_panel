# Kids Learning Platform: technical architecture

**Status: draft for review. No application code, no production tables.** Nothing in this folder is applied anywhere until you approve it.
Date: 2026-11-17. Source of truth for requirements: `docs/reconnaissance/` (screens S01–S46, flows F01–F25, games G01–G39, features in `feature-tracking.csv`, screenshots SS-01…SS-19).

This replaces `replica/architecture.md` and `replica/schema.sql`. Those were written for an Expo + PixiJS + Next.js API stack before you fixed the stack in this brief. They stay in the repo only as history.

## Legend

| tag | meaning |
| --- | --- |
| **[V]** | verified: from the recon docs (with the recon tag, e.g. [V R21], [SS-10]) or tested here |
| **[D]** | decided by your brief |
| **[P]** | proposal: my design choice, open to change at review |
| **[A]** | assumption: believed true, not verified; listed in `17-assumptions-and-open-questions.md` |
| **[OPEN]** | unresolved requirement; needs your answer or legal advice |

## Documents

| # | file | brief section |
| --- | --- | --- |
| 1 | [01-system-architecture.md](01-system-architecture.md) | 3.1 overall diagram, 3.2 module architecture, platforms, stack |
| 2 | [02-flutter-architecture.md](02-flutter-architecture.md) | 3.3 Flutter folders, Riverpod, Clean Architecture |
| 3 | [03-nextjs-architecture.md](03-nextjs-architecture.md) | 3.4 Next.js folders (parent + admin web) |
| 4 | [04-backend-architecture.md](04-backend-architecture.md) | 3.5 backend (Supabase modular monolith) |
| 5 | [05-database.md](05-database.md) + [database/schema-draft.sql](database/schema-draft.sql) | 3.6 ERD, section 4 tables, keys, indexes, constraints, policies |
| 6 | [06-auth-and-authorization.md](06-auth-and-authorization.md) | 3.7 |
| 7 | [07-api-specification.md](07-api-specification.md) | 3.8 |
| 8 | [08-game-engine.md](08-game-engine.md) | 3.9 |
| 9 | [09-learning-progress-engine.md](09-learning-progress-engine.md) | 3.10 |
| 10 | [10-subscriptions-and-payments.md](10-subscriptions-and-payments.md) | 3.11 |
| 11 | [11-media-storage.md](11-media-storage.md) | 3.12 |
| 12 | [12-offline-sync.md](12-offline-sync.md) | 3.13 |
| 13 | [13-analytics.md](13-analytics.md) | 3.14 |
| 14 | [14-security-and-child-privacy.md](14-security-and-child-privacy.md) | 3.15 and section 5 |
| 15 | [15-deployment.md](15-deployment.md) | 3.16 |
| 16 | [16-roadmap.md](16-roadmap.md) | sections 6–7: modules, dependencies, acceptance criteria |
| 17 | [17-assumptions-and-open-questions.md](17-assumptions-and-open-questions.md) | assumptions, unresolved requirements |
| — | [`docs/design/`](../design/README.md) | design v1.0: navigation, responsive spec, screens, states, interactions, accessibility (aligned with this architecture in `docs/review/design-review.md`, 2026-11-18) |

## Numbers at a glance

| | count | how verified |
| --- | --- | --- |
| Postgres tables (public) | **64** + 1 partitioned analytics table | loaded on a throwaway Postgres 16 with a Supabase auth stub |
| RLS | on **64 / 64** tables, **138** policies, 0 tables without a policy | same run |
| Foreign keys | **118**, every one indexed (leading column) | same run, re-run 2026-11-18 after the design review |
| Behaviour checks | **29 passed, 0 failed** (cross-family isolation, admin MFA, publish permission, idempotent replay, star rule, audit redaction, append-only audit, cascade delete …) | `database/schema-draft-checks.sql` |
| Edge Functions | **15** functions, **64** routes (incl. 2 webhooks, 7 internal job routes) | `07-api-specification.md` |
| Game templates for v1 | **12** (E1–E12), Flame-based | `08-game-engine.md`, from recon G01–G39 |
| Roadmap modules | **14** (M0–M13), each with dependencies and acceptance criteria | `16-roadmap.md` |

## Decisions that need your approval

The brief fixed the stack. These are the choices I had to make inside it, plus three places where the brief and the platform limits pull against each other. Details are in each document; the full list of open items is in `17-…`.

| id | decision | why | alternative |
| --- | --- | --- | --- |
| **D1** | **The children's web app is the Flutter app compiled for web**, not a Next.js app. Next.js serves the parent dashboard and the admin dashboard. | Flame games only run inside Flutter. A Next.js kids app would need a second kids UI *and* would still have to embed a Flutter web build for every game. One Flutter codebase gives identical games and kids UI on Android, iOS and web. | Next.js kids shell with the Flutter game player embedded per activity (two kids UIs to build and keep in sync). |
| **D2** | **One write path for families**: the apps read through RLS and write only through Edge Functions. **Admins** write catalogue tables directly with their own JWT, checked by RLS + role permission + MFA. | Server-side rules (stars, gifts, unlocks, entitlement) can't be bypassed by a modified app. The admin web never holds the service-role key. | All admin writes through Edge Functions too (more code, same safety). |
| **D3** | **RevenueCat** validates App Store and Google Play receipts and syncs Stripe. Our own `subscriptions`, `payments` and `entitlements` tables are fed by its webhooks plus a server re-fetch. | Receipt validation, renewals, grace periods and refunds across 3 stores are the most error-prone part of the system. The original has a "paid but no access" support article [V R41]. | Direct integration: App Store Server API + Google Play Developer API + Stripe (no fee, roughly 3–4 more weeks of work and ongoing maintenance). |
| **D4** | **Video**: HLS files produced by our content pipeline (ffmpeg), stored in a private Supabase Storage bucket, played through short-lived signed playlists. | Keeps Supabase Storage as the only media store (your brief). | **Mux** for video only. Faster to build and has adaptive encoding, but adds a vendor. **Cost risk** either way: video egress from Supabase Storage is billed per GB beyond the plan quota; see `11-…`. |
| **D5** | **Unity: not in v1.** The schema allows a `unity` runtime for mobile-only templates later; the database rejects a Unity template marked for web. | None of the 36 mechanics in the recon needs 3D or physics beyond what Flame + Forge2D handle. Unity adds 20–40 MB per app and cannot run inside Flutter web. | Add later per template, mobile only. |
| **D6** | **Jobs on Supabase**: pg_cron + Supabase Queues (pgmq) + Edge Functions. Media transcoding runs in a **content pipeline** (a CLI in GitHub Actions), not in Edge Functions. | No extra job vendor. Edge Functions have CPU and time limits, so ffmpeg cannot run there. | Inngest / Trigger.dev. |
| **D7** | **No third-party analytics or ad SDKs in any surface a child uses.** First-party events into our own Postgres. | COPPA, Apple Kids Category, Google Families policy. | — |
| **D8** | **No child logins.** A child is a profile under a parent account; the device holds the parent session in "kid mode" behind a parental gate. | Matches the original [V R11, SS-15] and keeps child data minimal. | Child PIN profiles (later, for schools). |
| **D9** | **Families first, schools later** (your earlier answer). The school layer is an additive migration. | — | — |

## What you need to decide before M0 starts

1. Approve or change **D1–D9**.
2. **Data region**: EU or US Supabase region (affects GDPR transfers and latency). [OPEN]
3. **Launch markets and languages**, especially whether Arabic (RTL) is in v1. It changes the Flutter layout work and the content pipeline. [OPEN]
4. **Legal review** of the consent method and the retention schedule in `14-…` (COPPA as amended in 2025, GDPR Art. 8, UK Children's Code). I have written a design, not legal advice. [OPEN]
