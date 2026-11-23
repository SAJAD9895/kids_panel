# 17. Assumptions and open questions

## 17.1 Decisions awaiting your approval

D1–D9 are in [README.md](README.md#decisions-that-need-your-approval). The biggest are **D1** (children's web = Flutter web) and **D3** (RevenueCat).

## 17.2 Open requirements [OPEN]

| id | question | why it matters | default if no answer |
| --- | --- | --- | --- |
| Q1 | Data region: EU or US? | GDPR transfers, latency, cost | EU if launching in the EU/UK/Gulf first; US otherwise |
| Q2 | Launch markets and languages. **Arabic (RTL) in v1?** | layout direction in Flutter and web, content pipeline, voice-over, store listings | English only for v1, Spanish next; RTL-ready layouts from day one (logical paddings) |
| Q3 | Which privacy counsel reviews consent, retention and the DPIA? | the consent method and retention periods in `14-…` are proposals | none — launch is blocked until reviewed |
| Q4 | Pricing per plan and market; trial length | paywall, Stripe prices, store products | monthly + annual, 7-day trial [A U16] |
| Q5 | Launch catalogue size and content budget | the critical path | 3+ months of daily play per stage |
| Q6 | Brand name and domains | domains in `15-…`, store listings, email domain | placeholders until `/replica-brand` |
| Q7 | Co-parent accounts in v1? | invitations, roles, billing ownership | not in v1 (schema supports it) |
| Q8 | Admin login: email + password + TOTP, or company SSO (SAML)? | admin security, Supabase plan | email + password + TOTP |
| Q9 | Crash reporting in kids surfaces: Sentry SaaS, self-hosted, or our own endpoint? | store Kids-category rules | Sentry SaaS with scrubbing, confirmed against store rules at M0 |
| Q10 | Analytics on public marketing pages? | cookies / consent banners | none |
| Q11 | Raw play-history retention (24 months proposed) | storage, privacy | 24 months raw, then aggregates |
| Q12 | Payment records after account deletion (tax) | deletion completeness | delete our mirror; rely on Stripe / store records |
| Q13 | Video volume per month at launch | storage egress cost (D4) | estimate before M3; switch to Mux/R2 if > budget |
| Q14 | Download limits per device and per account | storage, piracy | 2 GB per device default, no account cap |
| Q15 | Schools: when? | the additive `0002_schools` migration | after v1 launch |

## 17.3 Assumptions [A]

| id | assumption | where used | how to verify |
| --- | --- | --- | --- |
| A1 | Flame on Flutter web reaches acceptable performance for our 12 templates on Chromebooks and iPad Safari | D1, `08-…` | M2 benchmark (acceptance criterion) |
| A2 | Apple and Google require IAP for digital subscriptions sold inside the apps; external links are restricted, more so for Kids-category apps | `10-…` | store guidelines review at M8 |
| A3 | Sign in with Apple is required on iOS when Google sign-in is offered | `06-…` | App Store guideline 4.8 at M1 |
| A4 | COPPA's amended rule (2025) requires a written security program, a written retention policy, and separate consent for third-party disclosure; email-plus consent is allowed for internal-only use | `14-…` | counsel (Q3) |
| A5 | A scrubbed crash reporter is acceptable in Kids-category apps | `13-…` | store rules + counsel (Q9) |
| A6 | Supabase Edge Function CPU / time / memory limits rule out transcoding and large exports inside a request | `04-…`, `11-…` | Supabase docs at M0 |
| A7 | Supabase Storage egress is billed per GB beyond the plan quota, so video can dominate cost | `11-…` | current pricing at M0 |
| A8 | Trial is 7 days | `10-…` | recon U16, product decision |
| A9 | Downloads are locked after Plus lapses; stars earned offline sync later | `12-…` | recon U07 (our design either way) |
| A10 | Google Play subscriptions can be revoked server-side on account deletion; Apple's can't | `10-…` §10.8 | provider docs at M8 |
| A11 | 6-month engineering timeline with the team in `16-…` | `16-…` | revisit after M2 |
| A12 | AAC audio plays everywhere we need (iOS, Android, browsers) | `08-…` | M2 device matrix |
| A13 | Flutter web first load for the kids shell ≤ 3 MB | `08-…` | M2 measurement |

## 17.4 Recon unknowns that affect the architecture

From `docs/reconnaissance/unknowns-and-assumptions.md`. The design handles each one either way; the answer changes behaviour, not the schema.

| recon id | unknown | design choice now |
| --- | --- | --- |
| U03 | exact onboarding fields and order | avatar → nickname → birth month → stage, then sign-up (`06-…` §6.2) |
| U04 | screen-time limit reached mid-activity | the activity finishes, then the time's-up screen (heartbeat returns `locked`) |
| U05 | songs: video, audio, or both | `activities.type = 'song'` can carry `video_main` or `audio_main` media |
| U06 | how off-screen PlayTogether activities complete | the adult taps "we did it!"; counts as completed (`offline_activity` type) |
| U07 | offline stars and post-lapse downloads | `12-…` §12.5 |
| U08 | more than 5 stars a day | each 5 stars = one more gift, capped at 20 (`gift_claims.gift_index ≤ 20`) |
| U10 | UI language vs content language | `parent_accounts.ui_locale` and `content_locale`, per-child override |
| U11 | Basic locked state | lock badge + upsell behind the gate |
| U13 | resume abandoned onboarding | child setup stays on the device until sign-up completes |
| U15 | knowledge-check format | E6 quiz with `questions` / `answers`; score kept for pre/post |
| U19 | can a child be deleted | yes, owner + re-auth, immediate |
| U20 | "Most Played" / "What's New" | Most Played per child from sessions; What's New global by `published_at` |
| U21 | does the drawer's progress shortcut pass the gate | yes in our design (reports are parent data) |
| U22 | News and Invite a friend | not in v1 schema (could-haves, M4+ later) |
| U23 | row-level download | downloads the whole row (`library/downloads/manifest` with `collectionId`) |
| U24 | Learn Together lessons | `courses.kind = 'learn_together'`; stars and progress as for solo |
| U25 | character pick | `games.character_pick`; the choice persists per child per game locally [P] |
| U26 | reward widget on other tabs | shown on Play only in v1, returned by `catalog/home` for all tabs so it can be turned on |

## 17.5 Changed by the design review (2026-11-18, `docs/review/design-review.md`)

| area | before | now | reason |
| --- | --- | --- | --- |
| kids navigation | bottom tabs Play / Theater / Lessons / PlayTogether | left rail Home / Learn / Watch / Listen / Me; Together is a Home row + Learn Together courses [P] | design v1.0 (K07); a 6th rail item doesn't fit a phone in landscape |
| section switches | `theater/lessons/playtogether_enabled` | `learn/watch/listen/together_enabled`; a switched-off section's items disappear from every screen; games can't be switched off | follows the new navigation; the old rule only hid tabs |
| screen-time usage | per surface (play, theater…) | per section (games, learn, watch, listen, together) | same |
| parental gate | birth-year keypad | three numbers written as words (K20) | harder for a child who knows a parent's age; works for pre-readers' parents in any language |
| lesson steps | no song step, no lesson reward | `song` step type; optional `lessons.prize_reward_id` ("island prize", K10) | design K10 |
| search | games and videos | every activity type | must-have F-043 |
| API | 61 routes | 64: `account/devices/:id/revoke`, `learning/journey`, `admin/analytics/content` | design P14, K18, A20 |
| tablets and web | Kids Area landscape only | landscape and portrait | iPad Split View and browser windows can't be forced to landscape |

### New open questions from the design review

| id | question | default if no answer |
| --- | --- | --- |
| Q16 | Is "Together" acceptable as a Home row + Learn Together courses, rather than its own section like the original's PlayTogether tab? | yes [P] |
| Q17 | Kid-facing "garden" (K18) and badges (K16): ship in v1 or later? They aren't in the original. | v1, behind a feature flag |
| Q18 | Calm time (K14/K15 Listen tab): a category of songs and stories, or a separate wind-down mode with dimmed colours and a sleep timer? | a category in v1 |
| Q19 | Minimum supported phone height in landscape (the rail and cards are sized for ≥ 360 dp) | 360 dp; smaller phones get the compact rail without labels |

## 17.6 Changed from the previous plan (`replica/architecture.md`)

| area | before | now | reason |
| --- | --- | --- | --- |
| mobile | Expo (React Native) | Flutter + Riverpod | your brief |
| games | PixiJS in a WebView | Flame (+ Rive, Lottie) in Flutter | your brief |
| children's web | Next.js | Flutter web (D1) | Flame games run only in Flutter |
| API | Next.js route handlers | Supabase Edge Functions + Data API | your brief |
| files | Cloudflare R2 | Supabase Storage | your brief (cost risk noted, `11-…`) |
| video | Mux | HLS in Supabase Storage (D4) | your brief; Mux kept as the fallback |
| jobs | Inngest | pg_cron + Supabase Queues | stay inside Supabase |
| schema | 43 tables, entity names from the recon | 64 tables with your entity list (courses, lessons, questions, answers, media assets, sessions, results, payments, notifications, downloads), plus RBAC, consent and audit | your brief |
