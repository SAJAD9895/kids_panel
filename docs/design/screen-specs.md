# Screen specs (screens without a mockup)

Written specs for every screen the mockups don't draw yet. Each lists purpose, layout, content, actions, states (detail in `states.md`), data (`docs/architecture/07-api-specification.md`) and recon source. Components are named as in `components.md`; values come from `tokens/tokens.json`.

Mockup priority: **P1** before its roadmap module starts, **P2** can be built from this spec with the component library.

## 1. Children's app (K21–K37)

All use the rail shell (README §2) unless marked full-screen. Every instruction is spoken; no screen relies on reading.

| id | screen | layout and content | actions | data | recon | priority |
| --- | --- | --- | --- | --- | --- | --- |
| K21 | Search | top: big search field with mic-free keyboard and a "listen" button that reads results; below: 12 subject tiles (our icons, spoken names); results: card grid by type (Games, Videos, Songs, Stories) | type, tap subject → K08, tap card | `catalog/search` | S10 | P1 |
| K22 | Saved games | Me › Saved: grid of favorited cards, newest first; heart on each card | open, un-save | Data API `favorites` | S22 | P2 |
| K23 | Gift opening (full-screen) | dimmed scrim, gift box centre (Lottie), tap to open, 3 stickers fly to the sticker book button | tap gift, "Put in my book" | `rewards/gifts/claim` | S23 | P1 |
| K24 | Sticker book + scenes | left: sticker pages by set (owned, new glow, silhouettes); right: scene canvas; drag a sticker onto a scene, pinch to size | drag, remove (drag back to tray), next scene | `rewards/scenes/:id` | S24, S25 | P1 |
| K25 | Character pick (full-screen) | 3 round character buttons (Rive idle → cheer on select), "Go!" | pick, go | `games.character_pick`; the choice persists per child per game on the device (U25) | S45 | P2 |
| K26 | Learn Together step | split card: left "for the grown-up" (short text + read-aloud for the adult), right the child's activity; "We did it!" button for off-screen tasks | play, we did it | `play/launch`, `play/sync` | S46 | P1 |
| K27 | Check-in (pre / post) | same frame as a quiz (E6); 3–5 picture questions; no right/wrong feedback during a check-in, only "Thanks!" at the end | answer | `play/launch` (step `knowledge_check`) | S19 | P1 |
| K28 | Certificate | big certificate with the child's nickname, course name, date and buddy; confetti; "show a grown-up" | close, open in Me | `progress/certificates` | S20 | P1 |
| K29 | Time's up (full-screen) | calm illustration, buddy yawning, spoken "That's all for today!"; Grown-ups button | Grown-ups → gate → P03 | `play/heartbeat` `locked` | S30 | P1 |
| K30 | Ask a grown-up (locked item) | sheet over the card: buddy points to the Grown-ups button; spoken explanation; no prices, no "buy" words for the child | Grown-ups → gate → P07; close | `play/launch` `402` | S29 | P1 |
| K31 | World / collection | hero banner with the world's art; rows of that world's items | open card | `catalog/collections/:id` | S11 | P2 |
| K32 | Book reader (full-screen) | one page (or a spread on tablets); words highlight as they are read; tap a word to hear it; page turn by swipe or big arrows; "read to me" / "read myself" | play/pause, replay page, page turn, close | pack (E10) | S44 | P1 |
| K33 | Audio player (full-screen) | cover art, play/pause, previous/next, simple progress dots; lyrics line for sing-alongs | play, pause, next, close | pack / HLS audio | S16 | P1 |
| K34 | Mic / camera explainer | buddy with a mic icon: "This game listens to you. Ask a grown-up." → gate → OS prompt; if denied, the game plays without the mic | Grown-ups, play without | `play/launch` `permissions[]` | S42 | P2 |
| K35 | Who's playing? | full-screen: big buddy tiles with names (spoken), up to 5 children; no add button (adding is in the Parents Area) | pick child | `account/me` | S26 | P1 |
| K36 | Update needed | buddy with a toolbox: "A new version is ready"; grown-up button opens the store via the gate | update (gate) | `426 APP_TOO_OLD`, `minSupportedBuild` | — | P2 |
| K37 | Free activities used up (Basic) | cards stay visible with a lock; a banner card first in Home: "Come back tomorrow for more!" plus a moon/sun timer to tomorrow | Grown-ups → gate → P07 | `402 DAILY_FREE_LIMIT` | S09, F16 | P1 |

Child-safety rules for all K screens: no prices, no links out, no "buy" words, no countdowns that pressure the child (K37's timer shows when new games arrive, not a deal) [`docs/architecture/14-…`].

## 2. Parents Area (mobile app, portrait on phones) and parent web

Same specs for both. Web uses the sidebar (README §4.3); the app uses a list with push navigation. Every screen opens only after the gate (app) or a signed-in session (web).

| id | screen | content | actions | data | recon | priority |
| --- | --- | --- | --- | --- | --- | --- |
| P01 | Parents home | child avatar row (+ add), per child: today's minutes, stars, "this week" summary card; subscription status chip; notices (notice dot) | open child, open report, settings | `account/me`, `progress/report?days=7` | S31 | P1 |
| P02 | Children: list / add / edit | list of children; edit: nickname, buddy, birth month/year, stage (auto or override), content language; archive; delete (re-auth) | add (limit → P07), save, delete | `children`, `children/:id` | S33 | P1 |
| P03 | Screen time + sections | per child: daily limit (none, 15–180 min), which sections count, section switches (Learn, Watch, Listen, Together; games always on, shown disabled-on with an explanation) | save (toast "Saved") | `children/:id/screen-time` | S34 | P1 |
| P04 | Progress report | window picker 7/14/30/90 (default 14 [V SS-14]); stat tiles (activities completed, time, stars); top skill, most repeated activity; top 3 subjects; skills by group with bands; course pre/post check scores; daily chart (+ table for screen readers); empty state until 5 activities [F-124] | change window, open course | `progress/report` | S32 | P1 |
| P04b | Recent activity | list of the last 50 activities with time, type and result | — | Data API `activity_sessions` | — (new) | P2 |
| P05 | Courses + certificates | per child: enrolled courses with step progress; certificates with "download PDF" | download | `learning/courses/:id/tree`, `progress/certificates/:id/pdf` | S20 | P2 |
| P06 | Subscription | plan, renewal or end date, store (App Store / Google Play / web); manage: store deep link or Stripe portal; restore purchases; "Have a code?" | upgrade, manage, restore, redeem | `account/me`, `billing/*` | S35 | P1 |
| P07 | Plan picker / paywall | monthly and annual (best value tag), trial line, what Plus adds (in words, no child photos), store price strings, restore, terms + privacy links, "Continue with Basic" always visible | choose, buy, restore, continue free | `billing/plans`, store SDK | S04, S29 | P1 |
| P08 | Web checkout | the same plan cards; Stripe Checkout redirect; success and cancelled return pages | buy | `billing/checkout` | S07 | P1 |
| P09 | Redeem a code | code field (case-insensitive, dashes optional), result: what it unlocks and until when | redeem | `billing/redeem` | S08 | P2 |
| P10 | Downloads | per device (app) or per account (web, read-only): storage used of the 2 GB budget, list by child and row, delete one / all, "Wi-Fi only" switch | delete, toggle | local + `library/downloads/*` | S36 | P1 |
| P11 | Notifications | per type (weekly digest, product news, billing) per channel (email, push) | toggle | `account/notification-preferences` | S37 | P2 |
| P12 | Privacy | consents given (with dates, withdraw), download my data, delete a child, delete the account (7-day grace, cancel link) | export, delete, withdraw | `account/consents`, `account/export`, `account/deletion` | S37 | P1 |
| P13 | Settings / account | email (change → re-auth), password (set / change), app language, timezone, parent PIN (app), sign out, app version | edit, sign out | `account`, Auth | S37 | P1 |
| P14 | Devices | signed-in devices with platform, last seen; "sign this device out" | revoke (re-auth) | Data API `devices`, `account/devices/:id/revoke` | — (new) | P2 |
| P15 | Help | top help articles, contact support (email form, attaches account id, never child data), app version | contact | external help centre | — | P2 |
| P16 | Password log-in + reset | email + password; "forgot password" sends a reset link; reset page (web) with strength hint | log in, reset | Auth | S06, S43 | P1 |
| P17 | Re-authenticate (dialog) | "For your security, enter the code we just sent" (6 boxes) | confirm, resend | Auth OTP | — | P1 |

Weekly digest email (not a screen): per child, last week's minutes, stars, top skill, one suggested activity to do together off-screen. Plain HTML, works without images, unsubscribe link.

## 3. Admin web (CMS)

Desktop-first (README §4.3). Built from the shared web components; no bespoke visual design. Navigation is filtered by permission.

| id | screen | content | key actions | permission | priority |
| --- | --- | --- | --- | --- | --- |
| A01 | Log in + MFA | email + password (or SSO [OPEN Q8]), TOTP enrol / verify | sign in | — | P1 |
| A02 | Home | my drafts, waiting for review, failed media jobs, scheduled drops this week, recent publishes, alerts (webhook failures, deletion jobs late) | open item | any | P1 |
| A03 | Activities list | DataTable: title, type, subject, ages, status badge, Plus, locales complete, updated; filters and saved views; bulk retire | new, filter, bulk | content.read | P1 |
| A04 | Activity editor | tabs: Basics (localized title, description, keywords), Classification (subject, categories, skills with weights, ages, difficulty, players), Media (thumbnail, video/audio with captions), Questions (question + answers editor with "correct" switch, per-question skill), Access (Plus, free-eligible), History (audit) | save draft, validate, submit for review | content.write | P1 |
| A05 | Game config | template + version picker; JSON-Schema form; pack upload; live preview (PreviewFrame with device presets: phone, tablet, web; landscape/portrait) | preview, validate | content.write | P1 |
| A06 | Course editor | tree: course → modules → lessons (islands) → steps; drag to reorder; per lesson: prize sticker; per step: type, activity, required | add, reorder, validate | content.write | P1 |
| A07 | Learning paths | ordered courses per stage | reorder | content.write | P2 |
| A08 | Collections + schedule | list + calendar of rows, worlds and drops with start/end; section (Home, Learn, Watch, Listen, Explore); preview "Home as a 4-year-old sees it on date X" | schedule, preview | content.write | P1 |
| A09 | Taxonomy | categories (tree), subjects, skills and skill groups | edit | content.write | P2 |
| A10 | Rewards | sticker sets, scenes, badges (rule picker), lesson prizes | edit | content.write | P2 |
| A11 | Review queue | items in review with diff from the published version, validation result, preview; approve → publish, or send back with a note | publish, reject | content.publish | P1 |
| A12 | Media library | grid/list, filters by kind and status, UploadDropzone (resumable), processing status, usage ("used by 4 activities"), replace | upload, replace | content.write | P1 |
| A13 | Templates | template versions, supported platforms, min app build, config schema viewer | read | content.read | P2 |
| A14 | Families (support) | search by email; family detail: plan, devices, children (nickname and age only), recent errors; actions: resend login, grant Plus, start export/deletion. Opening a family is audited | resend, grant | support.read / act | P1 |
| A15 | Billing | subscriptions, payments, webhook events (with retry), promo code batches | retry, generate codes | billing.manage | P2 |
| A16 | Privacy requests | export and deletion requests with due dates and status; run now | run | privacy.act | P1 |
| A17 | Audit log | AuditEntry list, filters by actor, entity, action, date | read | audit.read | P1 |
| A18 | Admin users + roles | users, roles, permission matrix, invite | invite, assign | admin.manage | P1 |
| A19 | Feature flags + app versions | flags with rollout %, `minSupportedBuild` per platform; every change needs a reason | change | admin.manage | P2 |
| A20 | Content analytics | launches, completion rate, average time, drop-off step per activity, course and collection; groups under 10 children hidden | filter, export CSV | content.read | P2 |
| A21 | Avatars + characters | buddy art, character rigs (Rive) with their state-machine inputs listed | upload | content.write | P2 |
| A22 | Localization | per locale: missing titles, missing voice-over, missing captions; blocks publish for a locale the item claims | open item | content.read | P2 |
