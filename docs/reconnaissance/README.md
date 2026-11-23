# Reconnaissance: Kids Learning Platform

Clean-room recon of Lingokids (Monkimun Inc.), used as the reference product for a Lingokids-style app.
Status: **recon only. No application code. Waiting for approval of recon, then architecture.**
Date: 2026-11-17

## Files

| file | what it holds |
| --- | --- |
| `screen-inventory.md` | every screen (S01–S44): purpose, components, interactions, navigation, data, loading/error, mobile vs web |
| `feature-inventory.md` | features grouped by the 16 modules, with Basic/Plus gating |
| `user-flows.md` | goal-based flows (F01–F22) with tap counts and edge cases |
| `game-inventory.md` | 36 game mechanics (G01–G37, G36 unused) found in public activity names, grouped into engines |
| `platform-comparison.md` | what the original runs on vs our Android / iOS / Web targets |
| `screenshot-analysis.md` | the owner's 19 reference screenshots (`reference/`): per-image analysis, components, navigation map, links to S-IDs |
| `unknowns-and-assumptions.md` | everything not verified, how to verify it, and the screenshots needed |
| `feature-tracking.csv` | one row per feature, with evidence level, source, priority, platforms, build status |

## Evidence legend (used in every file)

- **[V] Verified.** Stated in a public source listed below. The source ID is given, e.g. `[V R13]`.
- **[A] Assumption.** Inferred from indirect evidence (naming patterns, store screenshots, reviews, usual app conventions). Needs confirmation.
- **[SS-nn] Screenshot.** Seen in the owner's screenshot nn (`screenshot-analysis.md`). Counts as verified.
- **[P] Proposal.** Our design decision for the clone, not a claim about Lingokids.

## Rules followed

- Public sources only: help center, store listings, marketing pages, terms. **No account was used.**
- No app binaries, JavaScript bundles, private APIs or network traffic were inspected. Activity IDs quoted below come from **links Lingokids publishes on its own public pages** (R1, R37), not from the app.
- No proprietary assets were downloaded or copied. Character, brand and activity names are recorded only to describe the original. **None of them may be reused in the clone.**
- Lingokids' terms (R36) license the service "for personal, non-commercial purposes." Do not use a Lingokids account to research or benchmark this build.
- **Screenshots:** 19 images were provided in `reference/` (18 Lingokids, 1 unrelated) and analysed in `screenshot-analysis.md`. Earlier note: `unknowns-and-assumptions.md` lists which screenshots would settle the open questions. When you send them, store them in `replica/screens/` as reference only, never in the app.

## Sources

| ID | source | URL |
| --- | --- | --- |
| R1 | Marketing home | https://lingokids.com/ |
| R2 | Help: What sections can I find? | https://help.lingokids.com/hc/en-us/articles/9563170182801 |
| R3 | Help: What Are the Sections? | https://help.lingokids.com/hc/en-us/articles/23532720590610 |
| R4 | Help: What is the kids area? | https://help.lingokids.com/hc/en-us/articles/115004901125 |
| R5 | Help: Lessons | https://help.lingokids.com/hc/en-us/articles/18982608761106 |
| R6 | Help: What is Theater | https://help.lingokids.com/hc/en-us/articles/18547807835922 |
| R7 | Help: Reward system | https://help.lingokids.com/hc/en-us/articles/18393545177874 |
| R8 | Help: Activity types | https://help.lingokids.com/hc/en-us/articles/9566835203601 |
| R9 | Help: Parents Area | https://help.lingokids.com/hc/en-us/articles/115005129325 |
| R10 | Help: Progress reports | https://help.lingokids.com/hc/en-us/articles/9569447484177 |
| R11 | Help: Manage kid profile | https://help.lingokids.com/hc/en-us/articles/9568131412881 |
| R12 | Help: Switch profiles | https://help.lingokids.com/hc/en-us/articles/9566343883025 |
| R13 | Help: Screen time limits | https://help.lingokids.com/hc/en-us/articles/360017671017 |
| R14 | Help: Block activities | https://help.lingokids.com/hc/en-us/articles/35187628544402 |
| R15 | Help: Kid's level | https://help.lingokids.com/hc/en-us/articles/360019924937 |
| R16 | Help: Magic link | https://help.lingokids.com/hc/en-us/articles/17234011451922 |
| R17 | Help: Log in and out | https://help.lingokids.com/hc/en-us/articles/115005650909 |
| R18 | Help: Multiple devices | https://help.lingokids.com/hc/en-us/articles/115005532825 |
| R19 | Help: Supported devices | https://help.lingokids.com/hc/en-us/articles/360008947257 |
| R20 | Help: App permissions | https://help.lingokids.com/hc/en-us/articles/11465888382865 |
| R21 | Help: Basic (free) | https://help.lingokids.com/hc/en-us/articles/115005840745 |
| R22 | Help: Basic vs Plus | https://help.lingokids.com/hc/en-us/articles/9522274605585 |
| R23 | Help: Billing options | https://help.lingokids.com/hc/en-us/articles/17620142157714 |
| R24 | Help: Cancel subscription | https://help.lingokids.com/hc/en-us/articles/115005569049 |
| R25 | Help: Payment failed | https://help.lingokids.com/hc/en-us/articles/360000745618 |
| R26 | Help: Favorites | https://help.lingokids.com/hc/en-us/articles/36301428704402 |
| R27 | Help: Offline | https://help.lingokids.com/hc/en-us/articles/212078109 |
| R28 | Help: Printables | https://help.lingokids.com/hc/en-us/articles/37036972477330 |
| R29 | Help: Change email | https://help.lingokids.com/hc/en-us/articles/15448261464977 |
| R30 | Help: Delete account | https://help.lingokids.com/hc/en-us/articles/9521081946641 |
| R31 | Help: Lingokids for Educators | https://help.lingokids.com/hc/en-us/articles/9541001909137 |
| R32 | Help: Partner with Lingokids | https://help.lingokids.com/hc/en-us/articles/9540952610833 |
| R33 | Web: Redeem a code | https://lingokids.com/redeem-your-code |
| R34 | Google Play listing | https://play.google.com/store/apps/details?id=es.monkimun.lingokids |
| R35 | App Store listing | https://apps.apple.com/us/app/lingokids-games-shows/id1002043426 |
| R36 | Terms of Service | https://lingokids.com/terms-of-service |
| R37 | Web: English Learning (public activity list with IDs) | https://lingokids.com/englishlearning |
| R38 | Web: LingoCamp (activity descriptions) | https://lingokids.com/lingocamp |
| R39 | Web: Our content | https://lingokids.com/our-content |
| R40 | Web: Teacher resources | https://lingokids.com/teachers |
| R41 | Help: Technical Support index (article titles) | https://help.lingokids.com/hc/en-us/categories/115000819685 |
| R42 | Help: Subscriptions and Payments index | https://help.lingokids.com/hc/en-us/categories/115000866189 |
| R43 | Help: Using Lingokids index | https://help.lingokids.com/hc/en-us/categories/115000781965 |
