# Unknowns and assumptions

Everything here is **not verified** from a public source. Each item says what we assumed, why, how much it matters, and how to verify it.
How to verify: **SS** = a screenshot you can provide; **Pub** = more public sources (walkthrough videos, store screenshots); **Decide** = we don't need to know, it's our design call.

## Status after the screenshot review (2026-11-17, see `screenshot-analysis.md`)

| ID | status | what the screenshots show |
| --- | --- | --- |
| U01 | **resolved** | Explore is the top-right search icon. The bottom nav has 4 tabs (Play, Theater, Lessons, PlayTogether) [SS-01, 04, 11] |
| U02 | **resolved** | Kids Area landscape; **Parents Area and Progress Report portrait**; orientation is **per activity** (stacking game in portrait) [SS-12, 14, 16] |
| U08 | partly | the reward widget has exactly 5 star slots plus a gift [SS-01]; behaviour above 5 still unseen |
| U15 | partly | the check-in is the "Knowledge Check" node, first in each unit; the question format is still unseen [SS-10] |
| U17 | **resolved** | birth-year gate with a 4-digit keypad [SS-17] |
| U19 | partly | each profile has an edit (pencil) action [SS-15, 16]; delete still unseen |
| U11 | open | no Basic/locked state in the screenshots (the account appears to be on Plus) |
| U21 | **new** | does the Progress Reports shortcut in the drawer pass the parental gate? [SS-15] |
| U22 | **new** | what's in "News" and "Invite a friend" (referral reward?) [SS-16] |
| U23 | **new** | what the row-level download icon downloads: the whole row, or opens a picker? [SS-01, 04, 11] |
| U24 | **new** | the Learn Together lesson's structure, and whether it awards stars or progress [SS-18, 19] |
| U25 | **new** | which games use the character pick, and whether the choice persists [SS-09, 13] |
| U26 | **new** | whether the reward widget appears on the Theater, Lessons and PlayTogether tabs (not visible in SS-04 or SS-11) |

`reference/` also holds one unrelated image (an Edapt pre-session guide page). Remove it, or ignore it.

## A. Open questions about the original

| ID | unknown | current assumption | why it matters | verify by |
| --- | --- | --- | --- | --- |
| U01 | Where **Explore** lives: in the bottom nav, or as a top-right icon? R2 lists 5 sections; R3 shows 4 bottom icons; R26 puts Explore top-right next to the heart. | top-right search icon plus 4 bottom tabs (Play, Theater, Lessons, PlayTogether) | navigation shell | SS of Kids Home |
| U02 | Orientation of the kids' screens | landscape only on tablets; phones landscape too | layout system | SS on phone and tablet; store screenshots R34 |
| U03 | Exact onboarding fields and order (e.g. birthdate vs age, level choices) | avatar → name → birthdate → level, as in add-child (R11) | F01 tap count | SS of onboarding, or a public walkthrough video |
| U04 | What happens when the screen-time limit runs out mid-activity | the activity finishes, then a time's-up screen (S30) | kid experience, enforcement | SS / Decide |
| U05 | Songs: video in Theater, audio-only, or both? | mostly videos; podcasts are audio | player architecture | SS of a song |
| U06 | How off-screen PlayTogether activities count as complete | a "we did it!" confirmation by the adult | stars and progress | SS |
| U07 | Offline: are stars and progress saved offline and synced? What happens to downloads after Plus lapses? | queued locally and synced; downloads locked after lapse | data model | Decide (we must design it anyway) |
| U08 | Daily star rules above 5 stars: several gifts per day? | each 5 stars = one more gift | rewards logic | SS |
| U09 | Monthly achievement card: in the app, by email, or a push? | in-app card in the Parents Area | parent engagement | SS / Pub |
| U10 | Language switching: device-driven or an in-app setting? Can kid content language differ from UI language? | UI follows the device; content language set per account | i18n model | SS of Settings |
| U11 | The Basic locked state: what a child sees after 10 activities | the remaining cards show a lock; tapping opens S29 behind the gate | conversion UX | SS |
| U12 | "Parent community" (R34): what and where? | a link to an external group or content, not an in-app social feature | scope | Pub |
| U13 | Resume when onboarding is abandoned | restarts at S01 | onboarding robustness | Decide |
| U14 | "Wizard Game" (G35) mechanic | unknown | game inventory | Pub / ignore |
| U15 | Check-in format and scoring; what parents see about pre vs post | a quiz engine with a score per skill; a comparison in the Progress Center | lessons + reports | SS of a lesson and the progress screen |
| U16 | Trial length and pricing per region | 7 days ("try Plus free for a week", R search snippet of lingokids.com/app) | billing | Pub (lingokids.com/app) |
| U17 | Whether the Parental Gate varies (math problems on some devices?) | birth year only | gate design | SS |
| U18 | Where the shuffle button sits and how it picks | end of the activity list; random from eligible unplayed items | discovery | SS |
| U19 | Can a child profile be deleted? | yes, from edit profile | data deletion | SS |
| U20 | What "Most Played" and "What's New" are computed from | per child for Most Played; global for What's New | feed logic | Decide |

## B. Assumptions we're relying on (noted so they can be challenged)

1. **Games are templates plus content.** It rests on the public ID pattern `game_<mechanic>_<theme>` (R1, R37). It's strong evidence but not confirmation. It drives the engine plan in `game-inventory.md`.
2. **ID prefixes encode content type** (`SG_` song, `YO_` yoga…). This is inferred and used only to suggest a content taxonomy.
3. **`ptg` = PlayTogether** in IDs like `game_ptg_stack_farm`. Inferred.
4. **Kids' screens are landscape, tablet-first.** Inferred from "Designed for iPad" and the store screenshot ratios.
5. **The Basic free tier gets the upsell when locked content is tapped.** It's verified only for Favorites after a lapse (R26).
6. **The Parental Gate also guards purchases and external links.** Standard Kids-category practice; the help center confirms the gate only for the Parents Area, timer and permissions.
7. **Feeds are server-curated sets** (`feedSetId`) mixed with per-child signals (age band, favorites, most played).
8. **No online multiplayer.** "Multiplayer" in R39 is taken to mean same-device co-play.

## C. Things we've deliberately not investigated

- How the app is built: its engine, backend or API. We inspected no bundles or traffic, by rule.
- Paid-only screens in depth. Plus-only behaviour comes from help articles only, since no account was used.
- Exact copy, art, music and character design. Not needed; we can't use them.

## D. Screenshots that would settle the most

**Already received:** Kids Home (3 tabs), video player, lesson path, PlayTogether, Learn Together lesson, games, profile drawer, gate, Parents Area home, empty Progress Report.
**Still needed, in priority order:** onboarding S01–S04 · Basic locked state · a Knowledge Check question · a filled Progress Report · Screen Time settings and time's-up · Explore/search results · Favorites · sticker gift, album and scene book · Manage Subscription · Profile/settings · My Downloads · the Lessons tab catalogue.

Original list (kept for reference):

If you send screenshots (from your own device and your own account), these are the highest-value ones, in order. Store them in `replica/screens/` as reference only.

1. Kids Home on a tablet, and the same on a phone (U01, U02, U18)
2. Onboarding steps S01–S04 (U03, U16)
3. A lesson path and a check-in question (U15)
4. The Progress Center filled in (U15)
5. Screen Time settings and the time's-up screen (U04)
6. The Basic locked state after 10 activities (U11)
7. Parents Area → Settings (U10, U19)
8. The daily gift and the Sticker Album (U08)

Note: the Lingokids terms license use "for personal, non-commercial purposes" (R36). Screenshots of your own personal use are for reference. Don't use a Lingokids account to systematically research the app for this commercial build. Prefer public walkthrough videos where they exist.

## E. Scope question carried over

The earlier scoping answer said the clone is for **schools (B2B)**. This brief describes a family/parent product across Android, iOS and Web. **Which is it: family only, schools only, or both?** The school layer (teacher accounts, classes, student login without email, assignments, a teacher dashboard) is in `feature-tracking.csv` as module 17, marked `pending`, and it changes the architecture (organisations, rostering, privacy model).
