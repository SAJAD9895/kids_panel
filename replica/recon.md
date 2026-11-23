> **Superseded in detail by `docs/reconnaissance/` (2026-11-17, second pass).** That folder holds the full screen inventory, flows, game inventory, platform comparison and unknowns. `replica/features.csv` is now generated from `docs/reconnaissance/feature-tracking.csv`. The school/B2B focus below is **pending your confirmation** (see unknowns-and-assumptions.md §E).

# Recon map: Lingokids (iOS, Android, Amazon, Mac; web for checkout and educator resources)

Scope: the whole product: Kids Area (Play, Explore, Theater, Lessons, PlayTogether, rewards), Parents Area, plans and billing, offline, and the public educator resources. On top of that, the school/B2B layer the original lacks (marked **B-screens** and `original=no` in the matrix).
For: schools, nurseries and tutoring centres (B2B). Kids aged 2 to 8, used on classroom tablets and Chromebooks, run by teachers.
Date: 2026-11-17
Method: public sources only (help center, store listings, marketing site, terms). No account was used, no app code or network traffic was inspected.

> **Terms check.** Lingokids' Terms of Service grant use "for personal, non-commercial purposes" and say "not to copy, share, or sell our content without our permission." Researching a commercial competitor from a paid account falls outside that licence, so this recon uses public pages only. Keep it that way: don't drive a Lingokids Plus account for the build, and copy no content, characters, art or audio.

## Sources

| # | source | URL | notes |
| --- | --- | --- | --- |
| 1 | marketing site | https://lingokids.com/ | positioning: "Ultimate kids entertainment", 4,000+ activities, no ads, EN/ES/PT, deep-link IDs visible in public links |
| 2 | help center (root) | https://help.lingokids.com/hc/en-us | 4 categories: About, Using, Subscriptions & Payments, Technical Support |
| 3 | help: What sections can I find? | https://help.lingokids.com/hc/en-us/articles/9563170182801 | Explore, Play, Theater, Lessons, Play Together; feeds: Daily Picks, Worlds to Explore, Topics, Most Played, What's New |
| 4 | help: What Are the Sections? | https://help.lingokids.com/hc/en-us/articles/23532720590610 | bottom nav, 400+ game adventures over 12 subjects, PlayTogether content types |
| 5 | help: Lessons | https://help.lingokids.com/hc/en-us/articles/18982608761106 | check-in, then progressive activities, then a final check-in and a certificate; Preschool, K and Grade 1 readiness stages |
| 6 | help: Theater | https://help.lingokids.com/hc/en-us/articles/18547807835922 | 300+ videos, tap for controls, autoplay next, lock icon |
| 7 | help: Reward system | https://help.lingokids.com/hc/en-us/articles/18393545177874 | 1 star per distinct activity, 5 stars unlock a sticker pack, counter resets daily, Sticker Album and Scene Book |
| 8 | help: Activity types | https://help.lingokids.com/hc/en-us/articles/9566835203601 | 5 formats (audiobook, game, podcast, song, video); 5 skill groups and 24 skills; 12 subjects |
| 9 | help: Parents Area | https://help.lingokids.com/hc/en-us/articles/115005129325 | reached through the Parental Gate (birth year); progress, profiles, screen time, subscription, downloads, account, printables |
| 10 | help: Progress reports | https://help.lingokids.com/hc/en-us/articles/9569447484177 | empty until 5 activities; shows activities completed, top skill, top 3 subjects, top skills with activities |
| 11 | help: Manage kid profile | https://help.lingokids.com/hc/en-us/articles/9568131412881 | avatar, name, birthdate, learning level; up to 4 profiles on Plus |
| 12 | help: Switch profiles | https://help.lingokids.com/hc/en-us/articles/9566343883025 | top-left name, then pick a profile |
| 13 | help: Screen time limits | https://help.lingokids.com/hc/en-us/articles/360017671017 | daily limit per kid, limit by type (Theater/Lessons/PlayTogether), games always on, shuffle button, monthly achievement cards |
| 14 | help: Block activities | https://help.lingokids.com/hc/en-us/articles/35187628544402 | section on/off toggles; Play cannot be turned off; some home-feed videos can't be blocked |
| 15 | help: Kid's level | https://help.lingokids.com/hc/en-us/articles/360019924937 | bands: Beginner ≤3, Intermediate 4–6, Advanced 7+; adaptive difficulty |
| 16 | help: Magic link login | https://help.lingokids.com/hc/en-us/articles/17234011451922 | passwordless email link, "I have an account" |
| 17 | help: Basic (free) | https://help.lingokids.com/hc/en-us/articles/115005840745 | 1 profile, 10 games/day refreshed every 24h, extra games in Worlds; onboarding steps |
| 18 | help: Basic vs Plus | https://help.lingokids.com/hc/en-us/articles/9522274605585 | full comparison table: the gated features |
| 19 | help: Billing options | https://help.lingokids.com/hc/en-us/articles/17620142157714 | monthly / yearly, auto-renew, price varies by country |
| 20 | help: Favorites | https://help.lingokids.com/hc/en-us/articles/36301428704402 | heart on cards, Favorites page with games and videos lists, lessons can't be favorited, download favorites |
| 21 | help: Offline | https://help.lingokids.com/hc/en-us/articles/212078109 | download button (turns green), offline hides non-downloaded items, My Downloads |
| 22 | help: Printables | https://help.lingokids.com/hc/en-us/articles/37036972477330 | 60+ topics; Coloring / Coloring and Songs / Parents Guide; download or email |
| 23 | help: Lingokids for Educators | https://help.lingokids.com/hc/en-us/articles/9541001909137 | **no school product**: schools email schools@lingokids.com |
| 24 | help: Partner with Lingokids | https://help.lingokids.com/hc/en-us/articles/9540952610833 | Jamf for school deployment; NASA, OUP, WLF, Disney, Moonbug and others |
| 25 | help: Learning methodology | https://help.lingokids.com/hc/en-us/articles/208259345 | 8 pillars |
| 26 | educator resources | https://lingokids.com/teachers | free lesson-plan library, filters for subject, topic and level (Multilevel, Pre-A1) |
| 27 | lesson plan example | https://lingokids.com/teachers/science-potatoes-multilevel | objectives, lesson PDF, worksheet PDF, related lessons |
| 28 | redeem code | https://lingokids.com/redeem-your-code | web redeem: code, then email, then log in to the app; codes have max redemptions |
| 29 | Google Play listing | https://play.google.com/store/apps/details?id=es.monkimun.lingokids | 50M+ installs, 4.3★ / 225K reviews, "Teacher Approved", Plus feature list, reviews |
| 30 | App Store listing | https://apps.apple.com/us/app/lingokids-games-shows/id1002043426 | 4.2★ / 687K, Editors' Choice, IAP prices $14.99–15.99/mo and $71.99–89.99/yr, weekly content drops in the changelog |
| 31 | Terms of Service | https://lingokids.com/terms-of-service | personal, non-commercial licence |

## Core loop

A child opens a feed chosen for their age, plays a short activity, earns a star (five stars open a sticker pack), and the adult sees it in a progress report. Parents pay for unlimited, repeatable access. **For the school clone:** a teacher assigns a lesson to a class, children play it on shared tablets, and the teacher sees progress per child and per skill.

## Screens

States key: E empty, L loading, F filled, X error, P permission/paywall-locked, O offline, M mobile/phone layout (the app is tablet-first).

| ID | screen | route / how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S01 | Welcome | first launch | choose new vs returning | hero art, Next, "I have an account" | F |
| S02 | Child setup (onboarding) | S01 → Next | create the first kid profile so content is pitched right | avatar picker, name, birthdate, learning level | F, X (missing fields) |
| S03 | Email capture / sign up | after S02 | create the parent account | email input, Continue with Apple (iOS), Send | F, X (invalid email) |
| S04 | Plan picker / paywall | after S03, or any upsell | choose Basic (free) or Plus trial (monthly/yearly) | plan cards, trial CTA, "continue free", legal text | F, L (store sheet) |
| S05 | Log in (magic link) | S01 → I have an account | passwordless login | email input, "check your inbox" state, Use password link | F, sent, X (unregistered email), not-arrived help |
| S06 | Password login / reset | S05 → Use password | fallback login | email, password, Reset password | F, X |
| S07 | Web subscribe | app.lingokids.com/users/new | buy Plus on the web, away from store fees | email, plan, card form | F, X (card declined) |
| S08 | Web redeem code | app.lingokids.com/en/code/gift/redeem | unlock Plus with a coupon | code input, email, T&C checkbox, Continue | F, X (invalid, used up, fraud-deactivated) |
| S09 | Kids Home / Play feed | default after login; bottom nav "Play" | main feed of games for this age | horizontal feed rows (Daily Picks, Worlds to Explore, Topics, Most Played, What's New), profile chip top-left, heart and Explore top-right, star counter, sticker album bottom corner, shuffle button at the end of the list, bottom nav | F, L, P (Basic: 10/day used up, locked cards), O (only downloads shown), E (new profile) |
| S10 | Explore / Search | bottom nav "Explore" or top-right | browse the whole catalogue | search bar, subject tiles (12), age filter, English path, results grid | F, E (no results), X ("ABC" returning only videos, per a review) |
| S11 | Collection / World / Topic page | tap a row header, World, or deep link `contentPage?feedSetId=` | themed set of activities | header art, activity grid, Plus badge | F, P (Plus-only worlds) |
| S12 | Activity card (with detail) | any feed | preview and start an activity | thumbnail, title, type icon, heart, download button, lock | F, P (locked), downloading, downloaded (green), favorited |
| S13 | Game player | tap a game card; deep link `activity?activity_id=` | play a mini-game | game canvas, back/exit, celebration animation on finish, star awarded | L, F, completed, X (lag on slow connection, per reviews) |
| S14 | Theater | bottom nav "Theater" | video library | category rows (Series & Songs, Song Compilations, Curiosity Time, Baby Bot Knows, Lucas and Me...) | F, L, O, blocked (section off) |
| S15 | Video player | tap a video | watch | tap-to-show controls, autoplay next, lock icon top-right | playing, paused, locked, completed (counts as a star) |
| S16 | Audio player (audiobook / podcast / song) | tap an audio card | listen or read along | play/pause, art, page turn for audiobooks (guess) | F, completed |
| S17 | Lessons catalogue | bottom nav "Lessons" | structured paths, by age | recommended row, rows by stage (Preschool / K / Grade 1 readiness) and subject, partner badges | F, P (Plus only), blocked |
| S18 | Lesson path | tap a lesson | progress through one skill over 1–2 weeks | ordered nodes (check-in, activities, final check-in), progress, certificate icon top-right | not started, in progress, completed |
| S19 | Check-in (assessment) | first and last node of S18 | playful pre/post check | game-style questions, encouraging feedback | F, completed |
| S20 | Certificate | finish a lesson; tap top-right on S18 | celebrate and keep | diploma card, kid name, lesson name | F |
| S21 | PlayTogether | bottom nav "PlayTogether" | co-play: team challenges, creative and off-screen ideas | feed rows, activity cards | F, blocked |
| S22 | Favorites | heart icon top-right on S09 | replay saved items | two lists (games, videos), download-all button, newest first | F, E, P (lapsed Plus → paywall) |
| S23 | Reward claim | tap the Book after 5 stars | open the daily gift | gift/book animation, sticker pack reveal | locked (<5 stars), claimable, claimed |
| S24 | Sticker Album | sticker icon on S09 | collection of earned stickers | sticker grid, Scene Book entry | E, F |
| S25 | Scene Book | inside S24 | decorate scenes with stickers | background scene, drag-and-drop stickers, scene pager | E, F |
| S26 | Profile switcher | tap kid name top-left | switch child; reach Parents Area | avatar list (≤4), Parents Area button | F |
| S27 | Kids menu | Menu in the Kids Area | quick tools | timer icon, other entries | F |
| S28 | Parental Gate | entering any grown-up area | keep kids out | "enter your birth year" keypad | F, X (wrong answer) |
| S29 | Upsell modal | tapping locked content or Favorites after expiry | convert to Plus | value list, CTA to S04 | F |
| S30 | Time's-up screen | daily limit reached (inferred) | stop play kindly | character art, message, gate to extend | F (guess) |
| S31 | Parents Area home | S26 → Parents Area → S28 | the grown-up hub | nav list: Progress Center, Profiles, Screen Time, Account/Subscription, My Downloads, Parents Profile → Settings | F |
| S32 | Progress Center / Report | S31 | see what the kid did | stat tiles (activities completed, top skill, most-played activity), top-3 subjects, top skills with activities, kid switcher | E (<5 activities), F, X (a review reports "under construction") |
| S33 | Profiles: list / add / edit | S31 → Profile | manage up to 4 kids | profile list, Add a child, avatar, name, birthdate, level, Save | F, max reached (4), P (Basic = 1 profile) |
| S34 | Screen Time settings | S31 → Profile → Screen Time, or S27 timer | daily cap and section toggles | time picker, per-type checkboxes (Theater, Lessons, PlayTogether), section on/off toggles, Remove all limits | F, none set, P (Plus only) |
| S35 | Account and Subscription | S31 → Account | plan, renewal date, upgrade, cancel, email | plan card, renewal date, Upgrade, Manage/cancel (sends to store), Change email | Basic, Plus active, cancelled-until-date, lapsed |
| S36 | My Downloads | S31 | manage offline content | list with sizes, Edit, delete one or all | E, F, editing |
| S37 | Settings | S31 → Parents Profile → Settings | misc | Printable worksheets, notifications, language (EN/ES/PT), contact support, delete account, log out | F |
| S38 | Monthly achievement card | shown monthly (inferred) | celebrate progress together | card art, month summary | F (medium confidence) |
| S39 | Educator resources hub (web) | lingokids.com/teachers | free lesson plans for teachers | featured plans, filters (subject 13, topic ~45, level Multilevel / Pre-A1), search | F, E (no match) |
| S40 | Lesson plan page (web) | S39 → card | teach one topic offline | title, subject/level/topic tags, objectives, Download lesson PDF, worksheet PDFs, related lessons | F |
| S41 | Printables library (web) | lingokids.com/printables; S37 | printable sheets | topic grid (60+), type (Coloring / Coloring and Songs / Parents Guide), download, email icon | F |

### B-screens: the school layer (Lingokids has none; these are the B2B product)

| ID | screen | purpose | key components | states |
| --- | --- | --- | --- | --- |
| B01 | School admin: sign up / org setup | create the school, its billing and seat count | org form, seat plan, invoice/PO option | F, X |
| B02 | Admin dashboard | manage teachers, classes, seats, licence dates | teacher list, invite, seat usage meter, licence expiry | E, F, over-seat |
| B03 | Teacher home | the teacher's classes at a glance | class cards, quick "assign", recent activity | E (no class), F |
| B04 | Class roster | add students without email (COPPA) | add by name/first-name+initial, bulk paste/CSV, avatar, birth year or level, print login cards | E, F |
| B05 | Student login (shared device) | kids log in without typing an email | class code or QR, then the class picture grid, then tap own avatar, then a picture password | F, X (wrong picture), device-locked-to-class |
| B06 | Assign | push a lesson, collection or playlist to a class or group | content picker (reuse S10/S17), date range, group select | F |
| B07 | Teacher progress dashboard | per class, per student, per skill | heat-map student × skill, completion %, check-in pre/post delta, time on task | E, F |
| B08 | Student detail | one child's report (S32 for teachers) | timeline, skills, certificates, notes | F |
| B09 | Classroom Theater / projector mode | whole-class viewing on a board | full-screen Theater, no gamification, teacher controls | F |
| B10 | Lesson-plan builder | combine in-app activities and printables into a plan (S39/S40 made live) | plan editor, attach activities, PDFs | E, F |
| B11 | Parent link (optional) | share a child's progress home | invite code, parent read-only view of S32 | F |
| B12 | Integrations | rostering and sign-in | Google Classroom, Clever / ClassLink, MDM deployment notes (Jamf) | connected, X |

## Flows

```
F01 New family starts free and plays
    S01 -> S02 -> S03 -> S04 (choose Basic) -> S09 -> S12 -> S13 -> star
    happy path clicks: ~9 (Next, avatar, name, birthdate, level, email+Send, Continue free, card, play)
    edge: under-13 data entered by an adult only; email typo; Apple relay email; app killed mid-onboarding

F02 Upgrade to Plus
    S12 (locked) -> S29 -> S04 -> store sheet -> S09 (unlocked)
    happy path clicks: 4 + store confirm
    edge: purchase pending/deferred (Ask to Buy); restore purchases; bought on web, logging in on device; trial already used

F03 Returning parent logs in on a new device
    S01 -> S05 -> (email) magic link -> app opens -> S26/S09
    happy path clicks: 3 + email tap
    edge: link opened on a different device; email in spam; unregistered email; fallback S06 password

F04 Kid earns stars and a sticker reward
    S09 -> S13 (complete) -> +1 star ... x5 -> S23 -> S24 -> S25
    happy path clicks: 5 activities + 3
    edge: replaying the same activity gives no star; video counts only if watched to the end; counter resets at local midnight; unclaimed gifts carry over

F05 Kid completes a Lesson
    S17 -> S18 -> S19 (check-in) -> activities in order over several sessions -> S19 (final) -> S20
    happy path clicks: 2 to start, then 1 per node
    edge: resume mid-lesson; lesson blocked by the parent; lesson Plus-only; age band changed mid-lesson

F06 Kid watches Theater
    S14 -> S15 (lock) -> autoplay next
    happy path clicks: 2
    edge: Theater switched off (some home-feed videos still show); daily Theater limit hit; offline with no downloads

F07 Parent checks progress
    S26 -> Parents Area -> S28 -> S31 -> S32
    happy path clicks: 4 + gate
    edge: fewer than 5 activities (empty); multiple kids (switcher); report broken (seen in a review)

F08 Parent adds a second child
    S26 -> S28 -> S31 -> S33 -> Add -> avatar/name/birthdate/level -> Save
    happy path clicks: ~8
    edge: Basic plan (1 profile) -> S29; 4-profile cap

F09 Parent sets a daily limit / blocks sections
    S27 timer -> S28 -> S34 -> set -> Save        (or S31 -> S33 -> S34)
    happy path clicks: 4
    edge: games can't be limited or blocked; limit reached mid-activity -> S30; time-zone/day boundary

F10 Download for offline and play offline
    S12 download -> green -> (offline) S09 shows only downloads -> S13; manage in S36
    happy path clicks: 1 per item
    edge: storage full; download interrupted; progress/stars earned offline must sync later; Plus lapses while content is downloaded

F11 Favorite and replay
    S12 heart -> S22 -> S13
    happy path clicks: 2
    edge: lessons can't be favorited; unfavorite stays visible until the screen is left; lapsed Plus -> S29

F12 Redeem a code
    S08 (code -> email -> Continue) -> install app -> S05 -> magic link -> S09 (Plus)
    happy path clicks: ~5 + install
    edge: code used up; code deactivated for fraud; email already has a store subscription

F13 Cancel / manage subscription
    S31 -> S35 -> store/web management
    happy path clicks: 3 + store
    edge: bought on Apple vs Google vs Amazon vs web (4 different cancel paths, 4 refund articles)

F14 Teacher finds and downloads a lesson plan (web)
    S39 -> filter -> S40 -> Download PDF
    happy path clicks: 3
    edge: no plans for a filter combo; PDF only, nothing links into the app (gap)

F15 Switch child
    S26 -> tap avatar
    happy path clicks: 2

F16 Basic kid uses up today's 10 games
    S09 -> 10 activities -> remaining cards locked -> S29 or come back tomorrow
    edge: the source of most 1–3★ reviews ("wait a whole day")

--- B2B flows (the clone's core loop for schools) ---

F17 School onboards
    B01 -> B02 -> invite teachers -> B03
    edge: PO/invoice billing; seat overrun; licence expiry mid-term

F18 Teacher builds a class and students log in on shared iPads
    B03 -> B04 (paste names) -> print login cards -> B05 (class code -> avatar -> picture password) -> S09
    target clicks for a 4-year-old: <= 3 taps
    edge: two kids pick the same avatar; device shared by two classes; kid leaves the class

F19 Teacher assigns a lesson and reviews results
    B03 -> B06 (pick lesson, class, dates) -> students see it pinned on S09/S17 -> B07 -> B08
    edge: absent students; partial completion; pre/post check-in comparison
```

## Components

| component | variants | states | used on |
| --- | --- | --- | --- |
| BottomNav | kids (Explore, Play, Theater, Lessons, PlayTogether) | selected, disabled (section blocked), hidden (limit reached) | S09, S10, S14, S17, S21 |
| FeedRow | carousel, grid, hero row | loading skeleton, filled, end-of-row shuffle | S09, S11, S14, S17, S21 |
| ActivityCard | game, video, audiobook, podcast, song, lesson | default, locked (Plus), new, favorited, downloading, downloaded (green), completed-today | everywhere in the Kids Area, S22 |
| HeartToggle | card, header | off, on, pending-remove | S12, S09 header, S22 |
| DownloadButton | single, bulk | idle, downloading (progress), done (green), error | S12, S22, S36 |
| ProfileChip / Avatar | small chip, large picker tile | selected, add-new | S09, S26, S33, S02, B04, B05 |
| AvatarPicker | grid | selected | S02, S33, B04 |
| StarCounter | 0–5 pips | filling, full (gift ready) | S09, S13 completion |
| CelebrationOverlay | activity complete, lesson complete, gift | playing, done | S13, S15, S20, S23 |
| ParentalGate | birth-year keypad | idle, wrong, passed | S28 (before S31, S34, S29, external links) |
| UpsellModal / PlanCard | monthly, yearly, trial, free | default, selected, loading, error | S04, S29, S35, S07 |
| VideoControls | overlay | hidden, shown, locked | S15, B09 |
| AudioPlayer | audiobook, podcast, song | playing, paused | S16 |
| LessonPath | node list / map | locked node, current, done, certificate earned | S18 |
| CheckInQuestion | tap-choice, drag, listen-and-pick | idle, correct (celebrate), try-again | S19 |
| CertificateCard | lesson | locked, earned | S18, S20, B08 |
| StickerTile / StickerPackReveal | common, rare (guess) | new, owned | S23, S24 |
| SceneCanvas | drag-and-drop | empty, decorated | S25 |
| SearchBar + SubjectTile | 12 subjects, age filter | idle, results, no results | S10 |
| StatTile | number, top-item | empty (<5 activities), filled | S32, B07, B08 |
| RankedList / mini-bar | top subjects, top skills | empty, filled | S32, B07 |
| Heatmap (new) | student × skill | empty, filled | B07 |
| Toggle | section on/off | on, off, disabled (Play) | S34 |
| DurationPicker | per day | none, set | S34 |
| SettingsRow | link, toggle, destructive | default, pressed | S31, S35, S36, S37 |
| FormInput | email, text, date, code | default, focus, error, disabled | S02, S03, S05, S06, S07, S08, B01, B04 |
| PrimaryButton | primary, secondary, ghost, danger, store-style big kid button | default, pressed, disabled, loading | all |
| Toast / Banner | offline, saved, error | shown, dismissed | S09 (offline), S33, S34 |
| EmptyState | per screen | — | S22, S24, S32, S36, B03, B04, B07 |
| FilterBar (web) | dropdowns: subject, topic, level | selected | S39, S41 |
| ResourceCard (web) | lesson plan, printable | default | S39, S40, S41 |
| PdfDownload (web) | lesson, worksheet | default | S40, S41 |
| LoginCard (new, printable) | per student, with QR | — | B04 |
| PicturePassword (new) | 3×3 picture grid | idle, wrong, ok | B05 |

## Inferred data model

```
ParentAccount  id, email (unique), auth_method (magic_link | password | apple), locale (en | es | pt),
               marketing_opt_in, created_at
               evidence: S03, S05, S06, help "change account email", "delete account"
               confidence: high

Subscription   id, account_id, plan (basic | plus), period (monthly | yearly), status (trial | active |
               cancelled | expired), store (apple | google | amazon | web | code), renews_at, trial_used
               evidence: S35, billing + 4 refund articles, App Store IAP list
               confidence: high

RedeemCode     code, max_redemptions, redeemed_count, grants (plus, duration), active
               evidence: S08 ("maximum number of redemptions", "de-activate if fraud")
               confidence: high

ChildProfile   id, account_id, name, avatar_id, birthdate, level_band (beginner | intermediate | advanced),
               learning_level (manual), created_at
               evidence: S02, S33, help "kid's level" (bands by age), cap 4 on Plus
               confidence: high

Activity       id (slug like game_<mechanic>_<brand>_<theme>), type (game | video | audiobook | podcast | song),
               title, thumbnail, subjects[], skills[], level_bands[], duration, is_plus_only,
               collection_ids[], partner, offline_bundle_size, locales[]
               evidence: deep links on lingokids.com (activity_id=game_packing_puzzle_disney_toystory_toybox),
               help "activity types" (24 skills, 12 subjects), S12
               confidence: high (fields), medium (slug convention)

GameTemplate   id (mechanic: packing_puzzle, runner, artist_playground, memory, hidden_objects, spatial_puzzle,
               sort, answer_race, catcher...), config_schema
               Activity(type=game) = GameTemplate + theme/skin + content (words, numbers)
               evidence: repeated mechanic names across skins (Artist Playground: Explorers / Frozen;
               Runner: Spider-Man; Hidden Objects: Ingredients; Sort the Blocks: Halloween)
               confidence: medium. This matters a lot for build cost.

Subject        id, name   (Reading & Literacy, Maths, Science, Engineering, Technology, Geography, History,
               Art, Music, Practical Life Skills, Amazing Lingokids, Physical Activity)
Skill          id, group (movement | language | literacy_numeracy | thinking | social_life), name
               evidence: help "activity types". confidence: high

FeedSet / Collection  id (feedSetId), title, kind (daily_picks | world | topic | most_played | whats_new |
               brand_collection | theater_category), activity_ids (ordered), is_plus_only, starts_at, ends_at
               evidence: deep link contentPage?feedSetId=310, S09 rows, weekly "drops" in the changelog
               confidence: medium

DailyFreeAllocation  child_id, date, activity_ids[10]
               evidence: Basic = 10 games/day refreshed every 24h. confidence: high (behaviour), guess (storage)

Lesson         id, title, subject, stage (preschool | kindergarten | grade1), skill_focus, partner,
               items (ordered: checkin_pre, activity…, checkin_post), certificate_template
LessonEnrollment  child_id, lesson_id, current_item, started_at, completed_at, pre_score, post_score
Certificate    child_id, lesson_id, issued_at
               evidence: S17–S20, help "Lessons". confidence: high (shape), medium (scores stored)

ActivityCompletion  id, child_id, activity_id, started_at, completed_at, duration_s, completed (bool), source
               (feed | search | lesson | favorite | assignment), offline (bool)
               evidence: stars need "main learning bit" done, progress report counts, offline mode
               confidence: high

StarDay        child_id, date, distinct_activity_ids[], stars (0–5+), gifts_available, gifts_claimed
               evidence: help "reward system" (one star per different activity, resets daily, no claim deadline)
               confidence: high

Sticker        id, pack_id, art, rarity (guess)
ChildSticker   child_id, sticker_id, acquired_at
Scene          id, background
ScenePlacement child_id, scene_id, sticker_id, x, y, scale, rotation
               evidence: S23–S25. confidence: medium

Favorite       child_id, activity_id, created_at      (lessons excluded)
               evidence: help "favorites". confidence: high

Download       device-local: activity_id, bytes, status   (not server data)
               evidence: S36. confidence: high

ScreenTimeRule child_id, daily_limit_min, applies_to (theater | lessons | playtogether)[],
               sections_enabled {theater, lessons, playtogether}   (play always on)
               evidence: S34 + help articles. confidence: high

ProgressReport derived view over ActivityCompletion: count, top_skill, top_activity, top_3_subjects, top_skills
               evidence: S32. confidence: high

AchievementCard  child_id, month, summary   evidence: screen-time article. confidence: guess

LessonPlan (web)  slug, title, subject[], topics[], level (multilevel | pre_a1), objectives[], lesson_pdf,
               worksheet_pdfs[], related[]
Printable (web)   topic, kind (coloring | coloring_songs | parents_guide), pdf
               evidence: S39–S41. confidence: high

--- new for B2B (the original has none) ---
School         id, name, country, billing (card | invoice), seats, licence_start, licence_end
StaffMember    id, school_id, email, role (admin | teacher)
Classroom      id, school_id, teacher_ids[], name, class_code, level_band_default
Student        id, classroom_id, display_name, avatar_id, picture_password, birth_year?, level_band
               (Student replaces ChildProfile in school mode; no email, no PII beyond first name)
Assignment     id, classroom_id, target (lesson | collection | activity list), group_ids[], starts_at, due_at
StudentGroup   id, classroom_id, name, student_ids[]
DeviceBinding  device_id, classroom_id (shared-iPad mode)
```

Relationships: ParentAccount 1-1 Subscription, 1-n ChildProfile. ChildProfile 1-n ActivityCompletion, 1-n Favorite, 1-n LessonEnrollment, 1-1 ScreenTimeRule, 1-n StarDay, n-n Sticker. Activity n-n Subject, n-n Skill, n-n FeedSet, n-1 GameTemplate. Lesson 1-n LessonItem → Activity. B2B: School 1-n StaffMember, 1-n Classroom; Classroom 1-n Student, 1-n Assignment; Student takes the place of ChildProfile in every child-side table.

## Feature matrix

See `features.csv` (126 rows, generated from docs/reconnaissance/feature-tracking.csv). Must: 65, should: 43, could: 10, skip: 8.
Priorities are set for **schools as the buyer**: the classroom loop and teacher visibility come before consumer upsell machinery.

## Out of scope (cannot or should not be cloned)

- **All content and IP:** the 4,000+ activities, 300+ videos, songs, podcasts, audiobooks, lesson content, art and audio. Characters (Baby Bot, Elliot, Billy, Cowy, Lucas and others), the "Lingokids" and "Playlearning™" names, the logo. Their free lesson-plan PDFs and printables too. You need your own original catalogue, which is the biggest cost in this project.
- **Licensed brands:** Disney / Pixar / Marvel / Star Wars, Blippi / Meekah / CoComelon (Moonbug), Pocoyo, BBC Earth.
- **Partner deals:** NASA, Oxford University Press, World Literacy Foundation, WWF, Stanford, Jamf, American Airlines, Novel Effect.
- **Certifications and awards:** kidSAFE COPPA+ seal, Teacher Approved, Editors' Choice, "30 awards". Earn your own. Don't claim theirs.
- **Their audience and data:** 200M downloads, ratings, YouTube channel (3M subs), Alexa skill, Amazon merch store.
- **Their research claims:** "650+ learning objectives", "backed by research". Write your own curriculum map.

## Size

Screens: 41 in the original, plus 12 B2B. Flows: 16 in the original, plus 3 B2B. Entities: ~24, plus 7 B2B.

Hard parts:
1. **Content.** Parity means thousands of activities. Build a small set of **game templates** (8–12 mechanics) driven by content data, and make the catalogue a pipeline (CMS, skins, word lists, VO). Engineering is not the long pole; content is.
2. **Child privacy for schools.** COPPA (school-consent path), FERPA, GDPR-K / UK Age Appropriate Design Code, and the UAE/regional rules if relevant. No student emails. Data processing agreements for schools. Retention and deletion.
3. **Shared-device student login.** Class code, then avatar, then picture password, on shared iPads and Chromebooks, plus MDM deployment.
4. **Adaptive levelling and recommendations.** Age bands, difficulty nudging, the "haven't seen yet" logic, pre/post check-in scoring.
5. **Offline-first play with progress sync.** Classroom wifi is unreliable; stars and completions must queue and merge.
6. **Billing in three channels.** School invoices and seats (B2B), plus optional consumer IAP (Apple/Google), plus codes.

Size: **XL** for full parity, so rescope.
Recommended rescope (B2B v1): ~10 game templates and ~150 original activities, Lessons with check-ins, Theater with your own videos, stars and stickers, the teacher dashboard (B02–B08), shared-device login, and offline. Skip consumer IAP, PlayTogether and Scene Book for v1. That is **L (a quarter)** of engineering, with content production running in parallel.
