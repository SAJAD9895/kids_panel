# Feature inventory

Grouped by the 16 modules in the brief. Each feature lists its gating (Basic = free, Plus = paid), evidence and screens.
Legend: **[V Rn]** verified, **[A]** assumption, **[P]** proposal. The tracking IDs (F-xxx) match `feature-tracking.csv`.

## The gating model (verified, R21 + R22)

| feature | Basic (free) | Plus |
| --- | --- | --- |
| Ad-free | ✓ | ✓ |
| 10 new activities a day (refresh every 24h) | ✓ | ✓ |
| Explore by categories and subjects | ✓ | ✓ |
| Extra games in Worlds to Explore (some worlds Plus-only) | ✓ (partial) | ✓ |
| Full library (4,000+) and unlimited access | ✗ | ✓ |
| Replay activities | ✗ | ✓ |
| Child chooses what's next | ✗ | ✓ |
| Favorites | ✗ | ✓ |
| Progress Center (full) | ✗ | ✓ |
| Child profiles | 1 | up to 4 |
| Screen-time limits | ✗ | ✓ |
| Offline mode | ✗ | ✓ |
| Full access to Lessons | ✗ | ✓ |

Prices [V R35, US App Store IAP list]: monthly $14.99–$15.99, yearly $71.99–$89.99 (several SKUs, so price testing is likely [A]). Prices vary by country and promotion [V R23]. Payment channels: Apple, Google, Amazon, website (Stripe, PayPal) [V R24, R25], plus redeem codes [V R33].

---

## 1. Onboarding and registration
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-001 | Child profile created before the parent account (profile first, then email) | all | [V R21] | S02, S03 |
| F-002 | Email sign-up with no password at creation | all | [V R21, R16] | S03 |
| F-003 | Sign in with Apple (iOS) | all | [V R21] | S03 |
| F-004 | Plan choice at the end of onboarding (free or Plus trial) | all | [V R21, R34] | S04 |
| F-005 | Free trial of Plus | Plus | [V R34, R35 "unused portion of a free trial"] trial length [A] | S04 |
| F-006 | Age-based content from the start (no level test) | all | [V R15] | S02 |

## 2. Parent authentication
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-010 | Magic-link login | all | [V R16, R17] | S05 |
| F-011 | Password login + web password reset | all | [V R17, R18] | S06, S43 |
| F-012 | Sign in with Apple login | all | [V R41] | S05 |
| F-013 | One account on many devices at no extra cost | Plus | [V R18] | — |
| F-014 | Parental Gate (birth-year question) before grown-up areas | all | [V R9, R13, R14] | S28 |
| F-015 | Gate before device permissions (mic, camera, photos), then a confirmation screen | all | [V R20] | S28, S42 |
| F-016 | Log out (bottom of the Parents Area) | all | [V R17] | S31 |

## 3. Child profiles
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-020 | Profile = avatar, name, birthdate, learning level | all | [V R11] | S02, S33 |
| F-021 | Up to 4 profiles (1 on Basic) | Plus | [V R11, R21] | S33 |
| F-022 | Separate progress and recommendations per profile | all | [V R12] | — |
| F-023 | Switch profile from the top-left chip | all | [V R12] | S26 |
| F-024 | Editing birthdate or level changes the content | all | [V R11, R15] | S33 |
| F-025 | Delete a single child profile | ? | not documented [A] | S33 |

## 4. Home screen and navigation
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-030 | Section navigation: Explore, Play, Theater, Lessons, PlayTogether | all | [V R2, R3] | S09 |
| F-031 | Feed rows: Daily Picks, Worlds to Explore, Topics, Most Played, What's New | all | [V R2] | S09 |
| F-032 | Content adapts to age band and level | all | [V R4, R15] | S09 |
| F-033 | Basic daily allocation of 10 activities | Basic | [V R21] | S09 |
| F-034 | Favorites (heart on cards; games and videos lists; download favorites) | Plus | [V R26] | S12, S22 |
| F-035 | Shuffle button | all [A] | [V R13] | S09 |
| F-036 | Low-reading UI (kids find things without reading) | all | [V R4] | all kid screens |
| F-037 | Deep links to an activity or collection | all | [V R1, R37] | S11, S13 |
| F-038 | Kids menu with timer | Plus | [V R13] | S27 |

## 5. Learning categories
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-040 | 12 subjects for browsing | all | [V R8] | S10 |
| F-041 | Skills taxonomy: 5 groups, 24 skills, each activity built for a specific skill | — | [V R8] | data |
| F-042 | Filter by age; English learning path | all | [V R2] | S10 |
| F-043 | Keyword search | all | [V R2 "search by subject"; free-text search is [A] but a review mentions searching "ABC", R35] | S10 |
| F-044 | Themed collections, character worlds, weekly content drops | all/Plus | [V R1, R2, R35] | S11 |
| F-045 | Category shortcuts: Audiobooks/eBooks, Handwriting, Music | all | [V R31] | S10 |
| F-046 | 650+ learning objectives mapped | — | [V R34] (marketing claim) | data |

## 6. Lessons and courses
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-050 | Lesson = one skill, progressive activities, 1–2 weeks, self-paced, works without an adult | Plus | [V R5] | S18 |
| F-051 | Stages: Preschool, Kindergarten, 1st Grade Readiness | Plus | [V R5] | S17 |
| F-052 | Subjects: Literacy, Maths, Science, SEL, Nutrition, Careers, English vocabulary | Plus | [V R5] | S17 |
| F-053 | Pre and post check-ins ("playful, not tests") | Plus | [V R5] | S19 |
| F-054 | Certificate kept for good | Plus | [V R5] | S20 |
| F-055 | Recommended lessons at the top, by age | Plus | [V R5] | S17 |
| F-056 | Partner lessons (space, English vocabulary, reading) | Plus | [V R2] (partner content, not cloneable) | S17 |
| F-057 | Encouraging progress updates to parents about lessons | Plus | [V R5] channel [A] | S32? |

## 7. Interactive educational games
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-060 | 400+ game adventures over 12 subjects | mixed | [V R3] | S13 |
| F-061 | Template mechanics reused across themes (36 mechanics found) | — | [V R37 names] / [A] engine reuse | S13; see game-inventory |
| F-062 | Completion = the "main learning bit" plus a celebration animation | all | [V R7] | S13 |
| F-063 | Activities using mic, camera or gallery, with the gate | all | [V R20] | S13, S42 |
| F-064 | Adaptive difficulty that nudges up with ability | all | [V R15] | — |
| F-065 | Recommends unseen words and ideas | all | [V R15] | — |
| F-066 | Traceables and handwriting (letters, numbers 1–20, words) | all | [V R4, R37] | S13 |

## 8. Educational videos
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-070 | Theater library of 300+ ad-free videos, by category | mixed | [V R6] | S14 |
| F-071 | Tap for controls; autoplay next; screen lock | all | [V R6] | S15 |
| F-072 | Activity videos (drawing, dance, yoga) and series | all | [V R6] | S14 |
| F-073 | Download videos for offline | Plus | [V R3, R27] | S15, S36 |
| F-074 | Finishing a video earns a star | all | [V R7] | S15 |

## 9. Music and stories
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-080 | Songs: nursery rhymes, originals (ABCs, numbers, routines), sing-alongs | mixed | [V R3, R8] | S14, S16 |
| F-081 | Audiobooks with tap-to-read words | mixed | [V R8, R38] | S44 |
| F-082 | Podcasts (Storytime, LingoListen), also outside the app | mixed | [V R8] | S16 |
| F-083 | Movement songs (dance, yoga) | mixed | [V R34, R37] | S14 |

## 10. Family activities
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-090 | PlayTogether section | mixed [A] | [V R3] | S21 |
| F-091 | Team challenges, creative adventures, off-screen ideas (yoga, cooking, dance) | mixed | [V R3] | S21 |
| F-092 | Local multiplayer games | mixed | [V R39 "multiplayer games for big family moments"]; same-device play is [A] | S21, S13 |
| F-093 | Free printables (60+ topics), also usable by teachers | free (web) | [V R28] | S41, S37 |

## 11. Rewards and achievements
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-100 | Star per distinct activity per day; replays don't count | all | [V R7] | S09, S13 |
| F-101 | 5 stars = sticker pack; daily reset; no claim deadline | all | [V R7] | S23 |
| F-102 | Sticker Album | all | [V R7] | S24 |
| F-103 | Scene Book decorated with stickers | all | [V R7] | S25 |
| F-104 | Lesson certificates | Plus | [V R5] | S20 |
| F-105 | Monthly achievement cards | ? | [V R13], details [A] | S38 |

## 12. Parent dashboard
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-110 | Parents Area hub behind the gate | all | [V R9] | S31 |
| F-111 | Daily screen-time limit per child | Plus | [V R13] | S34 |
| F-112 | Limit scope by type (Theater, Lessons, PlayTogether); games exempt | Plus | [V R13] | S34 |
| F-113 | Switch sections off (Play always on) | Plus [A] | [V R14] | S34 |
| F-114 | Remove all limits | Plus | [V R13] | S34 |
| F-115 | Push notifications and email opt-out | all | [V R43] | S37 |
| F-116 | Parent community | Plus | [V R34 "parent community"] | ? [A] unknown screen, U12 |

## 13. Learning progress reports
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-120 | Activities completed count | Plus | [V R10] | S32 |
| F-121 | Skill most practised + most repeated activity | Plus | [V R10] | S32 |
| F-122 | Top 3 subjects | Plus | [V R10] | S32 |
| F-123 | Top skills with their activities | Plus | [V R10] | S32 |
| F-124 | Empty until 5 activities | Plus | [V R10] | S32 |
| F-125 | Per-lesson pre/post comparison shown to parents | Plus | promised [V R5]; screen [A] | S32 |

## 14. Subscription and premium features
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-130 | Monthly / yearly auto-renew | Plus | [V R23] | S04, S35 |
| F-131 | Store IAP: Apple, Google, Amazon (and Huawei distribution) | Plus | [V R24, R18] | S04 |
| F-132 | Web checkout (Stripe, PayPal, reCAPTCHA) | Plus | [V R1, R25, R41] | S07 |
| F-133 | Redeem codes with redemption caps and fraud deactivation | Plus | [V R33] | S08 |
| F-134 | Cancel in-app for web subs; store subs cancel in the store | Plus | [V R24] | S35 |
| F-135 | Access continues until period end, then falls back to Basic | Plus | [V R24] | S35 |
| F-136 | Refund policies per channel | — | [V R42] | — |
| F-137 | Localised price / promotions | Plus | [V R23] | S04 |
| F-138 | Upsell when tapping locked content | Basic | [V R26] for favorites; [A] elsewhere | S29 |

## 15. Offline learning
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-140 | Per-activity download (button turns green) | Plus | [V R27] | S12 |
| F-141 | Offline mode hides anything not downloaded | Plus | [V R27] | S09 |
| F-142 | My Downloads: delete one or all | Plus | [V R27] | S36 |
| F-143 | Download all favorites | Plus | [V R26] | S22 |
| F-144 | Offline progress and stars sync later | Plus | **[A] not documented**, needed | — |

## 16. Account settings
| ID | feature | gating | evidence | screens |
| --- | --- | --- | --- | --- |
| F-150 | Change account email | all | [V R29] | S37 |
| F-151 | Delete account in the app (data anonymized) | all | [V R30] | S37 |
| F-152 | Plan and renewal shown in Account | all | [V R21] | S35 |
| F-153 | Printables link | all | [V R28] | S37 |
| F-154 | Contact support | all | [V R43] | S37 |
| F-155 | UI languages | all | [V R35: 17 UI languages]; content in EN/ES/PT [V R1] | S37? |

---

## Cross-cutting (verified)
- **No ads, ever; no in-app purchases beyond the subscription** [V R1, R34].
- **kidSAFE COPPA+ certified** [V R1]; Play Families Policy; data deletion on request [V R34].
- **Device requirements:** iOS 15.4+ (2GB RAM, 4.7"+), Android 12+ (4GB RAM, 5"+; 10/11 run "less smoothly"), Fire OS 6+ [V R19].
- **Weekly releases** with content drops (version 26.47 on 2026-11-16) [V R35].

## Not in the original, needed because we target the web [P]
- A kids' player that runs in the browser (games, video, audio).
- A web parent dashboard.
- Web offline (PWA), with honest limits.
- Google sign-in.

## From the earlier scoping answer (schools / B2B), pending your confirmation [P]
The earlier scoping said the clone is for **schools**. This brief describes a family app. Lingokids has no school product [V R31]. If schools stay in scope, add: school org and seats, teacher accounts, class roster without student emails, shared-device student login, assignments, a teacher dashboard, rostering (Google Classroom/Clever), MDM deployment. They're listed as module 17 in `feature-tracking.csv` with `pending` in the notes.

---

## Screenshot findings (2026-11-17, see `screenshot-analysis.md`)

**Confirmed by screenshots [SS]:** F-014 gate (SS-17) · F-023 profile switching (SS-15) · F-030 navigation, with 4 tabs and Explore as a top-right icon (SS-01/04/11) · F-031 Daily Picks / Worlds rows (SS-01) · F-034 heart on cards (SS-01/04/11) · F-050–F-054 lesson structure, Knowledge Check and certificate badge (SS-07/10) · F-060 game player (SS-03/05/12/13) · F-070/F-071 Theater and player with lock (SS-04/06/08) · F-090/F-092 PlayTogether, 2-player badges (SS-11) · F-100/F-101 5-star reward widget (SS-01) · F-110 Parents Area (SS-16) · F-120–F-124 progress report blocks (SS-14) · F-140 download icons (SS-01/04/11).

**New features seen only in the screenshots:**
| ID | feature | module | evidence |
| --- | --- | --- | --- |
| F-160 | Per-tab colour theme (Play / Theater / PlayTogether) | 04 Home & nav | [SS-01, 04, 11] |
| F-161 | Row-level download button next to each feed row title | 15 Offline | [SS-01, 04, 11] (behaviour U23) |
| F-162 | Cards labelled by skill or theme instead of title | 05 Categories | [SS-01, 04, 11] |
| F-163 | Video player: skill chips under the title + an "up next" rail | 08 Videos | [SS-06, 08] |
| F-164 | Lesson hierarchy: workbook → units → nodes (Knowledge Check, Collect, Trace…) with sequential unlocking and a progress bar to the goal | 06 Lessons | [SS-07, 10] |
| F-165 | Learn Together lessons (adult and child co-play lessons with narration replay) | 10 Family | [SS-18, 19] |
| F-166 | Character pick before some games | 07 Games | [SS-09] |
| F-167 | Per-activity orientation (some games portrait) | 07 Games | [SS-12] |
| F-168 | Profile drawer with per-child quick actions (screen time, edit) and a Progress Reports shortcut | 03 Profiles | [SS-15] |
| F-169 | In-app feature-announcement tooltips and red notification dots | 04 Home & nav | [SS-15, 16] |
| F-170 | Progress Report covers a rolling last-2-weeks window; empty state keeps skeleton placeholders | 13 Progress | [SS-14] |
| F-171 | Support entry inside the Progress Report ("Go to Support Area") | 16 Account | [SS-14] |
| F-172 | Invite a friend (referral) | 16 Account | [SS-16] (details U22) |
| F-173 | News (in-app announcements) | 16 Account | [SS-16] (details U22) |
| F-174 | Parents Area in portrait, Kids Area in landscape | 12 Parent dashboard | [SS-16] |
