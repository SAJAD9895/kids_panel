# Design review: Kids Learning Platform

Date: 2026-11-18. Reviewer: Claude (design + architecture cross-check). **Documentation only; no application code was written.**

## Verdict

**Conditionally ready.** After the corrections below, the recon, architecture and design agree with each other, and engineering can start **M0 Foundations, M1 Identity and M2 Game runtime + vertical slice** once you approve the architecture decisions (D1–D9) and the new design decisions (Q16–Q19). The **kids screens K21–K37 (P1 items) and the parent screens P01–P17 still need mockups** before M4, M5, M7 and M8 build their screens. Details per module in §6.

## 1. What was reviewed and how

| input | files |
| --- | --- |
| Reconnaissance | `docs/reconnaissance/*` (46 screens S01–S46, 25 flows F01–F25, 141 features, 39 games, 19 screenshots), `replica/recon.md` |
| Architecture | `docs/architecture/01–17`, `database/schema-draft.sql` |
| Design | `docs/design/tokens/*` (v1.0), `docs/design/mockups/kids.html` + `screens/K*.png` (K01–K20), `replica/design/*` (first pass, incl. `components.md`) |

Checks run:
- Every must-have feature (70) mapped to a designed screen (script over `feature-tracking.csv` and the K→S map). Before the review, **33 of 70** must-haves had no designed screen (plus 1 partly designed, F-164). 6 of the 33 are back-end or data rules (F-022, F-041, F-139, F-144, X-001, X-002); the other 27 fall on the 16 screens and surfaces listed in §3 M1.
- Every token name used in `components.md` checked against v1.0 `tokens.json`: **17 of 34 no longer existed**.
- `contrast.py docs/design/tokens/tokens.json`: **60 pairs, 0 AA failures** (before and after).
- Draft schema reloaded on a throwaway Postgres 16 with the Supabase auth stub after the schema edits: loads cleanly; 64 tables, 64 with RLS, 138 policies, 118 foreign keys; `schema-draft-checks.sql` exits 0 with every check at its expected value; an insert using an old section name (`theater`) is rejected by the new check constraint.

## 2. Completed items (already good before the review)

- **Recon** is thorough: every screen has an ID, flows have tap counts to beat, unknowns are tagged.
- **Architecture** covers all 16 brief topics, and the schema is verified (RLS on every table, idempotent sync, star rule, audit log).
- **Tokens v1.0** are a single source for Flutter and Next.js, with a generator and 0 contrast failures. They use their own palette and characters (Pip, Bolt, Nova), not the original's.
- **Mockups K01–K17** cover onboarding, home (tablet, phone, web), category, course, lesson path, game (+ pause, complete), video, songs, stories, rewards and the child profile in one consistent visual language.
- **Component specs** (first pass) were strong on states and accessibility: every component listed states, a11y and the screens using it.
- Child-safety rules are consistent across design and architecture: no prices or links in kids screens, gate before grown-up areas, no third-party SDKs.
- Onboarding matches the recon's must-haves: child first (K05/K06), then the grown-up (K03), birth month + year only, a magic link plus a 6-digit code (K04).

## 3. Missing items

Status: **added** = written in this review; **open** = still to do.

| # | category | missing | status |
| --- | --- | --- | --- |
| M1 | screens | 16 must-have UI screens had no design: plan picker S04, password + reset S06/S43, Parents home S31, screen time S34, time's up S30, progress report S32, subscription S35, web checkout S07, check-in S19, certificate S20, gift claim S23, per-activity download, voice-first kid UI (F-036), web player W-001, parent web W-002, CMS X-003 | **added** as written specs K21–K37, P01–P17, A01–A22 (`docs/design/screen-specs.md`); **open**: mockups for P1 items |
| M2 | screens | kids: search, saved, sticker book + scenes, character pick, Learn Together, world page, book reader, audio player, permission ask, who's playing, update needed, free used up | **added** (K21–K37 specs); **open**: mockups |
| M3 | flows | no navigation map; flows F02, F05, F07, F11–F14, F16–F24 had no screen path in the design | **added**: navigation map + flow coverage with tap counts (`docs/design/README.md` §3, §6); all 25 flows mapped |
| M4 | parent dashboard | web: plan picker / checkout page, device management, help, per-child activity list, add-child page | **added** to `03-nextjs-architecture.md` and P-specs; new route `POST /account/devices/:id/revoke` |
| M5 | admin CMS | admin home, content analytics, avatars/characters, localization report, schedule preview "as a 4-year-old sees it", lesson prize editing | **added** (A02, A08, A10, A20–A22; route `GET /admin/analytics/content`) |
| M6 | responsive | only K07 had phone and web variants; no tablet portrait, no iPad Split View, no narrow web window, no parent/admin breakpoints; two different breakpoint sets | **added**: `docs/design/README.md` §4 (window classes, per-surface tables, orientation rules); **open**: portrait / bottom-bar mockup, phone variants of K08–K17 |
| M7 | learning requirements | no shared rules for spoken instructions, replay, idle hints, wrong answers, interruptions/resume, difficulty step-down, audio mix, captions, autoplay, read-along, tracing tolerance | **added**: `docs/design/interactions.md` (I1–I15 + lessons, video, audio, reading, tracing, mic) |
| M8 | states | states existed only as component lists; per-screen loading / empty / error / offline / locked missing; only K04 (error text) and K11 (pause, complete) drew any state | **added**: `docs/design/states.md` for every K, P and A screen; **open**: draw the P1 state variants |
| M9 | accessibility | architecture had no accessibility requirements (no screen reader, text scaling, reduced motion, switch access, captions policy, test plan) | **added**: `docs/design/accessibility.md` with rules C1–C12, vision, hearing, motion, motor and CI checks; linked from `02-…` and roadmap M4 acceptance |
| M10 | design system | production primitives (Flutter widget gallery, React `/design` route) | **open, intentionally**: application code, waits for approval |
| M11 | assets | K18–K20 have no PNG renders; final art, characters and voice are placeholders | **open** (content track C1, `/replica-brand`) |

## 4. Issues found

Severity: **H** blocks a correct build; **M** causes rework; **L** polish or consistency.

| # | sev | issue | evidence | fix applied |
| --- | --- | --- | --- | --- |
| R1 | H | **Two navigation models.** Design v1.0 uses a left rail (Home, Learn, Watch, Listen, Me); the component specs, Flutter router, API (`catalog/home?surface=play\|theater\|lessons\|playtogether`), schema (`collections.surface`, `screen_time_*`) and roadmap M4 still used the original's 4 bottom tabs | `kids.html` RAIL; `02-…` §2.4; `07-…` catalog; schema `screen_time_rules` | all aligned to the rail; sections redefined as content kinds (`docs/design/README.md` §2.3); schema, API, Flutter, roadmap updated |
| R2 | H | **Two token sets.** `docs/design/tokens` (v1.0) says it supersedes `replica/design/tokens.json`, but `components.md` was written against the old one: 17 of its 34 token names no longer exist (`accent`, `kids-text`, `kids-pill-*`, `kids-gate-bg`, `kids-lessons-*` …); tap size 56 vs 64, sidebar 264 vs 256, breakpoints sm/md/lg/xl vs window classes | token diff; script | `components.md` moved to `docs/design/` and rewritten to v1.0 names; old files marked superseded |
| R3 | H | **PlayTogether (must-have F-030) had no place** in the new rail | `features.csv` F-030; RAIL has 5 items | Together row on Home + Learn Together courses + two-player badge; a parent switch "Together" [P, **Q16**] |
| R4 | M | **Parental gate conflict**: architecture and components specify the original's birth-year keypad; K20 draws "tap the numbers written as words" | `06-…` §6.3; K20 | K20 adopted (harder to pass for a child who knows a parent's age); instruction never spoken; `06-…`, `02-…`, components updated |
| R5 | M | **Star overload**: the star icon means "saved" (favorite), "played today" and reward stars | `design.css .fav` uses `lucide star` + `kids-star` | saved = heart (components); **open**: update the K07/K12 mockups |
| R6 | M | **Lesson model gaps**: K10 has a "Sing" step and an "Island prize"; the schema had no `song` step type and no lesson reward | K10; `lesson_steps.step_type` | `song` added; `lessons.prize_reward_id` + `child_rewards.source = 'lesson_prize'`; terms table in README §7 |
| R7 | M | **Search scope**: API searched games and videos only; must-have F-043 is all types; K14/K15 add songs and stories | `07-…` catalog/search | search covers every activity type |
| R8 | M | **Landscape-only Kids Area** can't be enforced on iPad Split View or a browser window | `02-…` §2.4 | landscape + portrait on tablets and web, rail → bottom bar; "turn your device" for games; minimum sizes [**Q19**] |
| R9 | M | **K17/K18 (garden, badges, "big moments") had no data source** and aren't in the original | K17, K18 | `GET /learning/journey`; garden levels from mastery bands, never shrink (`09-…` §9.3) [**Q17**] |
| R10 | M | **Parent/admin gaps** (M4, M5) | `03-…` folders | pages + 3 routes added (61 → 64) |
| R11 | L | K20 device settings lack the autoplay and strict video lock switches that the interaction rules need | K20 | `DeviceSettingsList` spec; **open**: add 2 rows to the mockup |
| R12 | L | "Calm time" (K14/K15) is a new concept with no definition | K14 | defined as a category in v1 [**Q18**] |
| R13 | L | Terms differ (island / unit / lesson; buddy / avatar; saved / favorites) | K09, K10, schema | terms table, `docs/design/README.md` §7 |
| R14 | L | K18–K20 exist in the HTML but have no PNG | `docs/design/screens/` | **open** |
| R15 | L | Architecture still pointed the Tailwind preset at `/replica-design` | `03-…` §3.4 | points to `docs/design/tokens/` |

## 5. Recommended corrections (remaining work, in order)

1. **Approve** D1–D9 (architecture) and **Q16–Q19** (`17-…` §17.5): Together placement, garden and badges in v1, Calm time, minimum phone height.
2. **Mockups, P1 first** (before the module that builds them):
   - kids: K21 search, K23 gift, K24 sticker book + scenes, K26 Learn Together, K27 check-in, K28 certificate, K29 time's up, K30 ask a grown-up, K32 book reader, K33 audio player, K35 who's playing, K37 free used up;
   - parents: P01–P04, P06–P08, P10, P12, P13, P16, P17 (app portrait + web);
   - admin: wireframes for A01–A06, A08, A11, A12, A14, A16–A18;
   - responsive: K07 tablet portrait (bottom bar), and phone variants of K09, K10, K11, K13;
   - states: kids error and loading (K07, K11), K19 empty, P04 empty (fewer than 5 activities).
3. **Fix existing mockups**: heart instead of star on cards (R5); K20 add Autoplay and Strict video lock (R11); render K18–K20 PNGs.
4. **Build the primitives** once approved (replica-design step 4): Flutter widget gallery + React `/design` route from `docs/design/components.md`, screenshot them, then re-run `contrast.py`.
5. **Brand pass** (`/replica-brand`): app name, final palette values (role names stay), logo; then re-run the contrast check.
6. **Legal review** of the K03 consent wording and the P12 privacy screen together with Q3.
7. **Child usability test** on the M2 vertical slice (5 children per age band, with parental consent).

## 6. Implementation readiness

| module | ready? | what it needs from design |
| --- | --- | --- |
| M0 Foundations | **yes** (after approval) | tokens + generator exist |
| M1 Identity, family, consent | **yes** | K01–K06, K20 drawn; P16/P17 build from spec + components |
| M2 Game runtime + vertical slice | **yes** | K07, K11 (+ pause, complete), `interactions.md` |
| M3 Content platform (admin) | **yes, with wireframes recommended** | A01–A13 specs; admin uses shared components |
| M4 Kids experience | **not yet** | P1 kids mockups (K21, K29, K30, K35, K37), portrait variant, heart fix |
| M5 Learning | **not yet** | K26, K27, K28 mockups |
| M6 Rewards | **not yet** | K23, K24 mockups; Q17 |
| M7 Parent dashboards | **not yet** | P01–P05, P10–P15 mockups (gate added to the roadmap) |
| M8 Billing | **not yet** | P06–P09 mockups |
| M9 Offline | **yes** | K19 + P10 spec |
| M10 Notifications | **yes** | P11 spec, weekly digest spec |
| M11 Templates E2–E12 | **yes** | `interactions.md` rules; per-template art from C1 |
| M12–M13 | later | accessibility checks §6, child usability test |

## 7. Files changed in this review

| file | change |
| --- | --- |
| `docs/design/README.md` | **new**: file status, IA (rail, sections, Together), navigation map, responsive spec, screen map, flow coverage, terms |
| `docs/design/screen-specs.md` | **new**: K21–K37, P01–P17, A01–A22 |
| `docs/design/states.md` | **new**: per-screen loading / empty / error / offline / locked |
| `docs/design/interactions.md` | **new**: game, lesson, video, audio, reading, tracing rules |
| `docs/design/accessibility.md` | **new**: child UX + WCAG requirements and checks |
| `docs/design/components.md` | **moved** from `replica/design/`, aligned with v1.0 tokens and the rail; NavRail, gate, card, heart; 8 new components |
| `replica/design/components.md`, `tokens.json`, `tokens.css` | marked superseded |
| `docs/architecture/database/schema-draft.sql` | sections (`collections.surface`, `screen_time_rules`, `screen_time_usage.section`, session source `together`), `song` step, `lessons.prize_reward_id`, `lesson_prize` reward source; re-verified |
| `docs/architecture/07-api-specification.md` | `catalog/home?section=`, search all types, heartbeat `section`, +3 routes (64) |
| `docs/architecture/02-…`, `03-…`, `04-…`, `05-…`, `06-…`, `09-…`, `16-…`, `17-…`, `README.md` | rail navigation, gate, orientation, parent/admin pages, counts, garden levels, design gates in the roadmap, Q16–Q19 and the change log (§17.5) |

The pre-review schema is saved at `/private/tmp/claude-501/-Users-sajadk-kids-learning-platform/469a66d9-291e-4f01-9ac9-403840a265c6/scratchpad/schema-draft.before-review.sql` (the scratchpad; it can be cleared on reboot).
