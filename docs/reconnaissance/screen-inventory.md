# Screen inventory

IDs are stable: every other file refers to them. S01–S41 match `replica/recon.md`. S42–S44 are new in this pass.
Legend: **[V Rn]** verified in source Rn (see README), **[A]** assumption, **[P]** proposal for our build.

**Key platform fact [V R18, R19]:** Lingokids has **no web or computer version**. The kids and parents app exists only on iOS, iPadOS, Android, Fire OS and Huawei (and on Apple-silicon Macs via the iPad app, [V R35]). The web holds only checkout, code redemption, password reset, the billing portal, and educator/printable resources. So every "Web" line below for an in-app screen is a **[P] proposal**: nothing in the original exists to copy.

**Screenshot evidence (added 2026-11-17):** 18 screenshots from the owner's Android phone are analysed in `screenshot-analysis.md` and cited here as **[SS-nn]**. A **Screenshots** line under a screen records what they confirm or correct. Screens with no such line have no screenshot yet.

Common states key used throughout: **loading**, **empty**, **error**, **offline**, **locked** (needs Plus), **blocked** (section switched off by a parent), **limit** (daily screen time used up).

---

## Module 1: Onboarding and registration

### S01 Welcome
- **Purpose:** first launch. Choose to start new or log in. [V R16, R17: "On the welcome screen, tap I have an account"]
- **UI components:** brand art and characters [A], primary button (Next / start), secondary link **I have an account** [V R16, R21].
- **Buttons and interactions:** Next → S02 [V R21]. I have an account → S05 [V R16].
- **Navigation:** shown when no session exists, i.e. on first launch or after log out [A].
- **Data:** none. Device locale picks the UI language (EN/ES/PT marketed [V R1]; the App Store lists 17 UI languages [V R35]).
- **Loading/error:** app boot/asset download splash [A]. "Can't download / unsupported OS" is handled before this screen by the store [V R41].
- **Mobile vs web:** mobile only in the original. [P] Web: a landing page with "Start" and "Log in"; no store install step.

### S02 Child setup (first profile)
- **Purpose:** create the first child profile so content can be pitched at the right level. [V R21 step 3]
- **UI components:** avatar grid, name field, birthdate (or age) picker, learning-level choice [V R11 lists these fields for add-child; A that onboarding uses the same set].
- **Buttons and interactions:** pick avatar, type name, set birthdate, choose level, Continue.
- **Navigation:** S01 → S02 → S03 [V R21 order: profile first, then email].
- **Data:** writes ChildProfile {avatar_id, name, birthdate, level}. The age band is derived (≤3 Beginner, 4–6 Intermediate, 7+ Advanced) [V R15].
- **Loading/error:** missing name or birthdate blocks Continue [A].
- **Mobile vs web:** [P] identical form, with a native date picker on mobile and a dropdown/year picker on web.

### S03 Email capture / sign-up
- **Purpose:** create the parent account. [V R21 step 4]
- **UI components:** email field, **Continue with Apple** (iOS/iPadOS only) [V R21], **Send** button, privacy/terms text [A].
- **Buttons and interactions:** Send → account created and the plan picker shows [V R21]. Apple → system sheet [V R21].
- **Navigation:** S02 → S03 → S04.
- **Data:** ParentAccount {email, auth_method}. Apple may give a relay email [A]; there is a help article "Trouble logging in with Apple" [V R41].
- **Loading/error:** invalid email; email already registered, which should route to login [A]; network error.
- **Mobile vs web:** [P] Web adds Sign in with Google, the most common need on Chromebooks and web, plus Apple on the web. On Android, Google sign-in is not documented in the original [A].

### S04 Plan picker / paywall
- **Purpose:** choose Basic (free) or Plus (trial, then monthly or yearly). [V R21 step 5 "Choose the free version"; V R23 monthly/yearly; V R34 "free trial" in store text]
- **UI components:** plan cards (monthly, yearly), trial badge, "continue free" option, price shown in local currency [V R23 "app will show you what applies"], renewal legal text [V R34, R35].
- **Buttons and interactions:** pick plan → store purchase sheet. Continue free → S09.
- **Navigation:** S03 → S04 → S09. Also reachable from S29 and S35.
- **Data:** store product list and localized prices. Entitlement written on purchase [A].
- **Loading/error:** prices loading; purchase cancelled; payment failed (bank, international or recurring blocks [V R25]); "can't purchase on kid's tablet" (a kid's Google account under Family Link [V R41, R25]); price differs per device/store [V R41].
- **Mobile vs web:** mobile uses Apple/Google/Amazon in-app purchase [V R35 IAP list; R24]. Web checkout exists separately at app.lingokids.com/users/new (S07) [V R1], and the website billing portal is run by Stripe [V R25]. [P] Web: Stripe Checkout.

---

## Module 2: Parent authentication

### S05 Log in (magic link)
- **Purpose:** passwordless login for returning parents. [V R16, R17]
- **UI components:** email field, Send/confirm, "check your inbox" state, **Use password** link [V R17, R33].
- **Buttons and interactions:** enter email → link emailed → tap the link on the same device → app opens, logged in [V R16].
- **Navigation:** S01 → S05 → (email client) → S09, or S26 when several profiles exist [A].
- **Data:** magic-link token (single use, expiring [A]).
- **Loading/error:** email not arriving (check spam; must be the registered address) [V R16]; link opened on another device [A]; expired link [A]; unregistered email [V R16].
- **Mobile vs web:** mobile relies on universal/app links to open the app [A]. [P] Web: the link opens the web app directly; offer a 6-digit code as a fallback for opening across devices.

### S06 Password login
- **Purpose:** fallback login with a password. [V R17, R18]
- **UI components:** email, password, Log in, **Reset password** link [V R18].
- **Buttons and interactions:** Log in → S09. Reset → web page S43 [V R18 links to a web reset page].
- **Loading/error:** wrong password; locked account [A]; "I can't log in, error message" [V R41].
- **Mobile vs web:** same form. [P] Web: password managers, "show password".

### S43 Password reset (web)
- **Purpose:** set a new password from an emailed link. [V R17, R18: reset happens on a web page]
- **UI components:** email field, then an emailed link, then a new-password form [A beyond the first step].
- **Mobile vs web:** web-only in the original (opened from the app) [V R18]. [P] Same in ours.

### S28 Parental Gate
- **Purpose:** stop children reaching grown-up areas, purchases, permissions and links. [V R9, R13, R14, R20]
- **UI components:** prompt "enter the year you were born", numeric keypad [V R9, R14].
- **Buttons and interactions:** correct answer → continue to the destination. Wrong answer → retry [A].
- **Navigation:** shown before S31 Parents Area [V R9], the S27 timer [V R13], and any device-permission request [V R20]. [A] Also before purchases and external links (store "Kids" category rules require this).
- **Data:** none stored [A]. Validation is "birth year gives an adult age" [A].
- **Loading/error:** wrong answer → shake/retry [A]. A cool-down after repeated failures is unknown [A].
- **Mobile vs web:** [P] the same gate on web. Optionally replace it with a parent PIN, which is stronger.
- **Screenshots [SS-17]:** confirmed. Title "Parents only", "Please enter your year of birth:", **4 underscore digit slots**, a 3×4 keypad (1–9, 0, backspace), close (X) **top-right**, illustration on the left. No submit button, so it probably auto-submits on the 4th digit [A]. Resolves U17 (birth year, no maths problem). Landscape.

### S42 Permission confirmation
- **Purpose:** after the gate, name the device feature an activity needs (microphone, camera, photos) and let the adult enable it. [V R20]
- **UI components:** icon and explanation per feature, Enable button, then the OS permission dialog [V R20 images per feature].
- **Navigation:** triggered from S13 when an activity needs mic, camera or gallery [V R20 examples: Talking Baby Bot (mic), photo booth (camera), save drawing (gallery)].
- **Data:** permission state is held by the OS. The app asks only on demand, never in the background [V R20].
- **Loading/error:** permission denied → the activity can't run; the adult is pointed to device settings [V R20].
- **Mobile vs web:** [P] Web uses browser permission prompts (getUserMedia); you can't send people to OS settings, so show browser-specific help.

---

## Module 3: Child profiles

### S26 Profile switcher
- **Purpose:** switch the active child; entry point to the Parents Area. [V R9, R12]
- **UI components:** child name/avatar chip top-left of the Kids Area; on tap, a list of profiles (≤4) and a **Parents Area** button [V R9, R12].
- **Buttons and interactions:** tap a profile → reload the Kids Area for that child [V R12]. Parents Area → S28 → S31 [V R9].
- **Data:** ChildProfile list. Each profile has its own progress and recommendations [V R12].
- **Loading/error:** feed reload per profile [A].
- **Mobile vs web:** [P] the same, with a "Who's playing?" picker on web load when there are 2+ profiles.
- **Screenshots [SS-15], correction:** it's a **left drawer**, not a small list. Rows show avatar, name and **age in years**; the selected row has **hourglass (screen time)** and **pencil (edit)** quick actions. Below the list: **Progress Reports** (direct shortcut) and **Parents Area** (red notification dot). A dismissible **feature tooltip** announces "All your tools now in one place…". So progress is 2 taps from Home. A test profile shows 13 years old, so ages above 8 are accepted.

### S33 Profiles: list / add / edit
- **Purpose:** manage child profiles. [V R11]
- **UI components:** profile list, **Add a child**, avatar picker, name, birthdate, learning level, Save [V R11].
- **Buttons and interactions:** Add → form → Save. Tap a profile → edit → Save [V R11]. Changing birthdate or level changes the content shown [V R11, R15].
- **Navigation:** S31 → Profile section → S33 [V R11]. Screen Time per profile lives here too (S34) [V R13].
- **Data:** ChildProfile CRUD. Limit 4 on Plus, 1 on Basic [V R11, R21, R22].
- **Loading/error:** cap reached (4) [V R11]; Basic user adding a 2nd profile → upsell S29 [A, based on R21 "one kid profile"]. Deleting a child profile is not documented [A].
- **Mobile vs web:** [P] the same form; the web can show a two-column list and detail.

---

## Module 4: Home screen and navigation

### S09 Kids Home (Play feed)
- **Purpose:** the main child screen. Feeds of activities pitched at the child's age and level, easy to use without reading. [V R2, R3, R4]
- **UI components:**
  - Top-left: child name/avatar chip (→ S26) [V R9, R12]. Top-right: **heart** (Favorites, S22) next to **Explore** (S10) [V R26].
  - Horizontal feed rows: **Daily Picks, Worlds to Explore, Topics, Most Played, What's New** [V R2]. Favourites "front and centre" [V R3].
  - Star counter for the daily reward, and a **Book** icon to claim the gift [V R7]. **Sticker Album** icon in a bottom corner [V R7].
  - **Shuffle** button (blue) at the end of the activity list [V R13].
  - Bottom navigation bar: Play, Theater, Lessons, PlayTogether, plus Explore [V R2 names 5 sections; R3 shows 4 icons in the bottom bar and R26 puts Explore top-right, so where Explore sits is ambiguous, see unknowns U01].
  - Menu (timer and others) [V R13 "Open the Menu… tap the Timer icon"].
- **Buttons and interactions:** tap a card → S12/S13 or the right player. Swipe rows. Heart a card [V R26]. Download a card (Plus) [V R27]. Shuffle → random activity [V R13]. Book → S23 [V R7].
- **Navigation:** default landing after login or profile pick [A]. The bottom nav switches sections. Sections a parent turned off are hidden or disabled [V R14].
- **Data:** active child (age band, level), feed sets and their ordered activities, entitlement (Basic/Plus), Basic's 10-a-day allocation [V R21], favorites, today's stars, downloaded items (offline).
- **Loading/error/states:**
  - loading: skeleton rows [A].
  - **Basic:** 10 games in the main feed, refreshed every 24h, plus extras in Worlds; Plus-only worlds are locked [V R21]. When the 10 are used, the rest show locked → S29 [A, but the "wait a whole day" complaint is verified in reviews, R35].
  - **offline:** only downloaded items are shown, the rest are hidden [V R27].
  - **blocked:** sections switched off; Play can't be switched off [V R14].
  - **limit:** daily limit reached → S30 [A].
  - error: activity fails to load or lags on slow wifi (reviews) [V R35].
- **Mobile vs web:** the original is tablet-first, landscape [A, from store screenshots R34 being 16:9]. Phones are supported from a 4.7"/5" screen [V R19]. [P] Web: the same layout at ≥1024px; on narrow windows rows stack; mouse hover states; keyboard focus for accessibility.
- **Screenshots [SS-01, SS-04, SS-11]:** confirmed on an Android phone in **landscape**. Top bar: avatar (left), logo (centre), **search** and **heart** round outlined buttons (right). **Bottom nav = 4 tabs in a floating pill: Play, Theater, Lessons, PlayTogether**; the selected tab is larger and bold. **Explore is the top-right search icon, not a tab** (resolves U01). Each tab has its **own colour theme** (Play purple, Theater crimson, PlayTogether magenta). Every row title has a **download icon** (whole-row download). Cards show a **skill/theme label pill** (e.g. "Health", "Creativity"), not the activity title, and a **heart** overlapping the bottom-right edge. **Reward widget bottom-right:** an arc of 5 star slots ending in a gift, around a book button. Rows seen: "Your daily picks", "Worlds to explore". The Basic locked state isn't shown (U11 still open).

### S27 Kids menu
- **Purpose:** quick grown-up tools from inside the Kids Area. [V R13]
- **UI components:** menu button; **Timer** icon [V R13]. Other entries unknown [A].
- **Navigation:** Timer → S28 → screen-time setter (the same as S34, scoped to the current child) [V R13].
- **Mobile vs web:** [P] the same.

### S22 Favorites
- **Purpose:** quick replay of saved activities. Plus only. [V R26, R22]
- **UI components:** two lists, **games** and **videos**, newest first; download-all button next to "My Favorite Games" [V R26].
- **Buttons and interactions:** tap → play. Heart off → stays visible until you leave the screen (undo window) [V R26].
- **Navigation:** S09 top-right heart → S22 [V R26].
- **Data:** Favorite {child_id, activity_id, created_at}. Lessons can't be favorited [V R26].
- **States:** empty [A copy]. Lapsed Plus with saved favorites → the icon stays but opens the paywall [V R26].
- **Mobile vs web:** [P] same; the web's "download all" becomes "make available offline" (PWA cache), limited, see platform-comparison.

---

## Module 5: Learning categories

### S10 Explore / Search
- **Purpose:** browse the whole catalogue. [V R2, R4, R8]
- **UI components:** search, **12 subject tiles** (Reading and Literacy, Maths, Science, Engineering, Technology, Geography, History, Art, Music, Practical Life Skills, Amazing Lingokids, Physical Activity) [V R8], age filter, "English learning path" entry [V R2]; Categories also include Audiobooks and eBooks, Handwriting, Music [V R31].
- **Buttons and interactions:** tap a subject → filtered grid. Type a query → results [A on live vs submit].
- **Navigation:** from S09 (top-right or bottom nav) [V R2, R26].
- **Data:** subjects, activity search index, the child's age band.
- **States:** no results; a known weakness where searching "ABC" returns only videos (review) [V R35].
- **Mobile vs web:** [P] Web: a keyboard-first search box, and the URL keeps the query (shareable for teachers or parents).

### S11 Collection / World / Topic page
- **Purpose:** a themed set of activities (a character world, topic, seasonal "drop", brand collection). [V R1 public link `contentPage?feedSetId=310`; V R2 "Worlds to Explore", "Topics"; V R35 weekly drops in the changelog]
- **UI components:** header art, title, activity grid, Plus badges [A].
- **Data:** FeedSet {id, title, kind, ordered activity IDs, plus_only, schedule [A]}.
- **States:** Plus-only world → locked [V R21].
- **Mobile vs web:** [P] Web route `/collections/:id`, with deep links that work as plain URLs.

---

## Module 6: Lessons and courses

### S17 Lessons catalogue
- **Purpose:** structured learning paths by age. [V R5]
- **UI components:** **Recommended** lessons at the top, then more as you scroll [V R5]; grouped by stage (**Preschool Readiness, Kindergarten Readiness, 1st Grade Readiness**) [V R5]; partner badges (e.g. space lessons) [V R2].
- **Subjects:** Literacy, Maths, Science, SEL, Nutrition, Career Lessons, English vocabulary [V R5].
- **Navigation:** bottom nav **Lessons** [V R3, R5].
- **States:** Basic → no full access [V R22 "Full access to all Lessons" is Plus]; blocked by a parent [V R14]; limited by screen time [V R13].
- **Mobile vs web:** [P] the same.

### S18 Lesson path
- **Purpose:** take one skill from start to finish over 1–2 weeks, across several sessions. [V R5]
- **UI components:** ordered nodes (check-in, activities that get harder, final check-in) [V R5]; certificate icon top-right once earned [V R5]; progress marker [A].
- **Buttons and interactions:** tap the next node → S19 or S13 [A]. Resume where the child left off [A].
- **Data:** Lesson {stage, subject, skill, items[]}, LessonEnrollment {current item, done items}.
- **States:** not started, in progress, completed [A naming].
- **Mobile vs web:** [P] the same.
- **Screenshots [SS-07, SS-10], new structure:** Lesson → **Workbook** ("workbook 1" tab) → **Units** (spiral-notebook cards, e.g. "Unit 1: Lowercase Letters 'a-h'") → **nodes** inside a unit: **Knowledge Check** (active, white) → **Collect: …** → **Trace…** (locked, dimmed). Horizontal scroll with dotted connectors on a grid-paper background. Top bar: back (<), a **progress bar from a green check to a book "1" goal**, a **certificate badge (grey until earned)**, lock. Partner credit pill bottom-right. So the data model becomes Lesson → Workbook → Unit → Node(type: knowledge_check | collect | trace | …), with sequential unlocking.

### S19 Check-in (playful assessment)
- **Purpose:** a stress-free pre and post check that gives "something concrete to compare". [V R5]
- **UI components:** game-like questions, encouraging feedback [V R5]; question formats unknown [A].
- **Data:** score per check-in [A], compared pre vs post [V R5 "compare at the end"]; parents get "updates… framed encouragingly" [V R5].
- **Mobile vs web:** [P] the same.
- **Screenshots [SS-10]:** the check-in is called **"Knowledge Check"** and is the **first node of each unit** (not only of the whole lesson). Its inner question screens are not captured (U15 partly open).

### S20 Certificate
- **Purpose:** reward for finishing a lesson; kept for good. [V R5]
- **UI components:** diploma card [V R5 image "Diploma Open Large"], child name and lesson name [A].
- **Navigation:** shown on completion; reopened from top-right in S18 [V R5].
- **Mobile vs web:** [P] Web adds print or download as PDF (useful to parents and teachers).

---

## Module 7: Interactive educational games

### S12 Activity card
- **Purpose:** the unit shown in every feed. [V R26, R27]
- **UI components:** thumbnail, title, type cue (game, video, audio, song) [A], **heart** at the bottom of the card [V R26], **download** button (turns green when done) [V R27], lock for Plus content [A].
- **Interactions:** tap = open. Heart = favorite. Download = save offline.
- **States:** default, locked, new [A], favorited, downloading, downloaded, completed today [A].
- **Mobile vs web:** [P] Web: hover preview; the download control becomes "available offline" where supported.

### S13 Game player
- **Purpose:** play one mini-game. See `game-inventory.md` for mechanics.
- **UI components:** full-screen game canvas; exit/back [A]; voice-over instructions [A]; **celebration animation** at the end [V R7]; star awarded on completion [V R7].
- **Interactions:** tap, drag-and-drop, trace, draw [V R37/R38 activity types: traceables, puzzles, drag-to-place]; voice (mic) and camera in some activities via S28 → S42 [V R20].
- **Navigation:** from any card or deep link `activity?activity_id=` [V R1, R37]; on exit, back to the feed [A].
- **Data:** activity config/content bundle; writes ActivityCompletion; the star counts only for a *different* activity each day [V R7].
- **Loading/error:** asset download progress [A]; lag on poor connection [V R35 review]; missing permission → S42.
- **Mobile vs web:** [P] Web needs the game engine to run in the browser (Canvas/WebGL). Touch and mouse input; drag-and-drop must work with a mouse; audio may need a "tap to start" first (browser autoplay rules).
- **Screenshots [SS-03, SS-05, SS-12, SS-13]:** full-bleed scenes with **only a close (X) top-left**: no score, timer, pause or progress HUD. **Orientation is per activity:** the stacking game runs in **portrait** [SS-12] while the others are landscape. Some games use **on-screen control buttons** (rotate left, drop, rotate right) plus a next-piece preview and counter [SS-12]. A routine/hygiene game uses a **picture-in-picture close-up inset** [SS-05]. A race game marks the player's lane with an arrow [SS-13]. Some games open with a **character pick** (S45) [SS-09].

---

## Module 8: Educational videos

### S14 Theater
- **Purpose:** an ad-free curated video library of 300+ videos. [V R6]
- **UI components:** category rows (e.g. Series & Songs, Song Compilations, Lucas and Me, Curiosity Time, Baby Bot Knows, Sing-along Originals) [V R2, R6]; content types: animated stories, songs, puppetry, activity videos (drawing, dance, yoga), series, inspiring people [V R6].
- **Navigation:** bottom nav **Theater** [V R6].
- **States:** blocked by a parent (but some home-feed videos still show) [V R14]; Theater time limit [V R13]; offline shows downloads only [V R3, R27].
- **Mobile vs web:** [P] the same; the web is good for classroom projection.
- **Screenshots [SS-04]:** the same shell as Home in crimson; rows "Everyday Adventures" and "Baby Bot Knows", each with a row download icon. Video cards add a **duration badge top-right** and a **centred translucent play button**; the label pill shows a skill ("Social Skills", "Curiosity", "Flexibility"). No reward widget visible on this tab.

### S15 Video player
- **Purpose:** watch. [V R6]
- **UI components:** tap anywhere to show controls; **lock** icon top-right stops navigation away; autoplay of the next video unless the screen is touched [V R6].
- **Data:** video stream or downloaded file. Completion is a full watch, which counts toward the star [V R7].
- **Loading/error:** buffering; stream error; offline without a download [A].
- **Mobile vs web:** [P] Web: HLS via a JS player, fullscreen API, keyboard space/arrows; the lock becomes "kid lock" that disables clicks plus a parent unlock.
- **Screenshots [SS-06, SS-08]:** dark navy screen; the video sits in a **centred 16:9 frame** (not full screen); **title top-left with 1–3 skill chips** (e.g. Curiosity, Collaboration, Problem-Solving); **close top-left, lock top-right**; pause button, scrubber, time label; an **"up next" rail of thumbnails** (duration + topic label) along the bottom. Confirms the lock and autoplay [R6]. Videos carry several skills.

---

## Module 9: Music and stories

### S16 Audio player (songs, podcasts)
- **Purpose:** listen to songs and podcast series (Storytime, LingoListen). [V R8]
- **UI components:** play/pause, artwork, progress [A]. Songs are often delivered as video in Theater [A, songs are listed alongside videos in R2/R6]. Format overlap: see U05.
- **Mobile vs web:** [P] the same; background audio on mobile [A].

### S44 Audiobook / eBook reader
- **Purpose:** read or listen to illustrated stories. [V R8 audiobooks; V R31 "Audiobooks and eBooks"; V R38 "Tap the words and read" (Cowy's Cup audiobook)]
- **UI components:** page spread, narration, tappable words that read aloud [V R38], page turn [A].
- **States:** a review says books are hard to find, buried in a "create a story together" area [V R35].
- **Mobile vs web:** [P] the same; arrow keys turn pages on web.

---

## Module 10: Family activities

### S21 PlayTogether
- **Purpose:** activities for a child **with someone**: a grown-up, sibling or friend. [V R2, R3]
- **UI components:** feed rows of **Team challenges**, **Creative adventures** (music-making, storytelling, crafts), **Off-screen inspirations** (yoga, cooking, dancing) [V R3]; "Multiplayer games for big family moments" [V R39].
- **Interactions:** same-device co-play [A: "multiplayer" is likely local, two players on one tablet; no online multiplayer is documented]. Activity IDs with `ptg` (e.g. `game_ptg_stack_farm`, `game_ptg_driver_tractor`) suggest PlayTogether games [A, R37].
- **Navigation:** bottom nav **PlayTogether** [V R3].
- **States:** blocked or limited by a parent [V R13, R14].
- **Mobile vs web:** [P] the same; off-screen cards could be printable on web.
- **Screenshots [SS-11]:** the same shell in magenta; rows **"Think Together"** and **"Drive Together"**. Cards carry **two coloured smiley "player" badges** at the top centre, a 2-player indicator, so same-device 2-player play is strongly suggested. PlayTogether also hosts **Learn Together lessons** (S46) [SS-19].

---

## Module 11: Rewards and achievements

### S23 Reward claim (daily gift)
- **Purpose:** turn 5 stars into a sticker pack. [V R7]
- **Rules [V R7]:** 1 star per *different* activity finished; replays don't count; 5 stars = 1 gift; the counter resets daily; no deadline to claim.
- **UI components:** **Book** icon; gift-open animation; sticker reveal [A for the animation detail].
- **States:** fewer than 5 stars (locked), claimable, claimed.

### S24 Sticker Album
- **Purpose:** the collection of earned stickers. [V R7]
- **UI components:** sticker grid; entry to the Scene Book [V R7].
- **Navigation:** Sticker Album icon in a bottom corner of Home [V R7].
- **States:** empty for a new child [A].

### S25 Scene Book
- **Purpose:** decorate scenes with stickers. [V R7]
- **UI components:** scene background, drag-and-drop stickers, pager between scenes [A].
- **Data:** placements per child [A].

### S38 Monthly achievement card
- **Purpose:** "monthly cards to celebrate how far they've come, together". [V R13]
- **Details:** layout and channel (in-app or email) unknown [A], see U09.

---

## Module 12: Parent dashboard

### S31 Parents Area home
- **Purpose:** the grown-up hub. [V R9]
- **Entry:** S26 (tap child name) → **Parents Area** → S28 gate [V R9].
- **Sections [V R9]:** Progress Center (S32), Profiles (S33), Screen Time (S34), Subscription/Account (S35), My Downloads (S36), Account settings (S37), Printable activities.
- **Other verified details:** **Log out** at the bottom [V R17]; a **Parents Profile** icon bottom-right leads to Settings → Printable worksheets [V R28].
- **Mobile vs web:** [P] Web: a left sidebar dashboard; the natural place for a richer parent experience, since the original has none on the web.
- **Screenshots [SS-16], correction:** the Parents Area **switches to portrait** (the Kids Area is landscape). Layout: back chevron; a **"Your children"** card with an avatar row (selected = yellow ring + pencil badge) and a dashed **"+ Add a child"**; rows **Progress Reports**, **Screen time** (value "Off", red dot), **My Downloads** (count "13"). Then separate cards: **Profile**, **Manage Subscription**, **Invite a friend**, **News** (list continues). **New, not in the help center:** *Invite a friend* (referral) and *News*.

### S34 Screen Time settings
- **Purpose:** daily limit and section controls per child. Plus only. [V R13, R14]
- **UI components:** duration setter; checkboxes for which activity types the limit covers (**Theater, Lessons, PlayTogether**); section on/off toggles; **Remove all time limits**; Save [V R13, R14].
- **Rules:** games are never limited and Play can't be switched off [V R13, R14].
- **Navigation:** S31 → Profile → child → Screen Time [V R13], or S27 Timer → S28 [V R13].
- **Mobile vs web:** [P] the same; it suits a web dashboard.

### S30 Time's-up screen
- **Purpose:** stop play when the limit is reached. **[A, not documented]**; the behaviour is implied by R13.
- **[P]** A friendly message, then a gate to extend.

---

## Module 13: Learning progress reports

### S32 Progress Center / Progress Report
- **Purpose:** show what the child has been doing. [V R10]
- **UI components [V R10]:** **Activities completed** (count), **Skill most practised** plus the most-repeated activity, **Most played subjects** (top 3; overlap allowed), **Top practised skills** with the activity used most for each.
- **Rules:** empty until **5 activities** are completed; then it updates as the child plays [V R10].
- **States:** empty (<5); filled; a review reported the report as "under construction / showing no progress" [V R35]. Plus only for the full report [V R21, R22].
- **Data:** aggregates over ActivityCompletion × activity subjects/skills.
- **Mobile vs web:** [P] Web: date-range filter, a per-lesson pre/post comparison (R5 promises it, R10 doesn't show it), export.
- **Screenshots [SS-14], empty state (portrait):** header **"Last 2 weeks"**; info banner "…progress shown is for the last two weeks. Start playing!"; **Activities** tile "0 Completed / No activities completed yet."; **Mastery** tile "Skill Achieved"; **Most Played Subjects** with 3 placeholder rows (coloured dots); **Top Practiced Skills** carousel of ranked cards ("Skill / Achieved by playing / Game:"); a **"We're here to help" → Go to Support Area** card. **New, verified:** a rolling **14-day window**, and an empty state that keeps **skeleton placeholders** visible instead of hiding sections.

---

## Module 14: Subscription and premium features

### S29 Upsell modal
- **Purpose:** convert when a child or parent hits locked content. [A: the trigger is verified for Favorites after lapse, R26; other triggers are inferred]
- **UI components:** value list (full library, unlimited, favorites, progress, 4 profiles, screen time, offline, all lessons) [V R22 as the benefit list]; CTA → S04 (behind S28) [A].

### S35 Account / Subscription
- **Purpose:** see the plan and renewal date; upgrade; cancel. [V R9, R21]
- **UI components:** current plan (Basic/Plus) [V R21 "Parents Area → Account"], renewal date, Upgrade, **Cancel my subscription** (web subscribers only; store subscribers are sent to their store) [V R24].
- **Rules [V R24]:** cancel where you bought (Apple, Google, website or Amazon); access lasts until the period ends, then Basic; deleting the app doesn't cancel.
- **States:** Basic; Plus active; cancelled but active until a date; lapsed; payment failed [V R25].
- **Mobile vs web:** [P] Web: Stripe customer portal for card updates and invoices (the original already uses Stripe for web subscribers [V R25]).

### S07 Web subscribe
- **Purpose:** buy Plus on the web. [V R1 link "Subscribe" → app.lingokids.com/users/new]
- **UI components:** email, plan, payment (card, PayPal [V R25]), reCAPTCHA [V R41 "payment failed a recaptcha check"].
- **Mobile vs web:** web only.

### S08 Web redeem code
- **Purpose:** unlock Plus with a coupon. [V R33]
- **Flow [V R33]:** enter the code → REDEEM → email → CONTINUE (agree to T&C) → in the app, I have an account → magic link or Use password → Reset.
- **Errors [V R33]:** maximum redemptions reached; code deactivated for fraud; invalid code [A].
- **Mobile vs web:** web only in the original. [P] Ours: allow redemption on web and inside the app (behind the gate, where store rules allow).

---

## Module 15: Offline learning

### S36 My Downloads
- **Purpose:** manage offline content. Plus only. [V R27, R9]
- **UI components:** list of downloaded activities; **Edit** top-right; delete one or all [V R27]; item sizes [A].
- **Rules [V R27]:** download while online; offline mode hides everything not downloaded; downloads appear in Kids Home when offline. The download button turns green when done.
- **States:** empty; downloading; storage full [A]; Plus lapses with downloads present [A, see U07].
- **Mobile vs web:** [P] Web: service-worker cache with a smaller quota, best-effort only. See platform-comparison.

---

## Module 16: Account settings

### S37 Settings (Parents Profile)
- **Purpose:** account-level settings. [V R28, R29, R30, R17]
- **UI components:**
  - **Email** (tap to edit → Save) [V R29]
  - **Printable worksheets** link [V R28]
  - **Delete Account** at the bottom of Profile [V R30]
  - **Log out** at the bottom of the Parents Area [V R17]
  - Push notifications and email preferences [V R43 article titles]; contact support [V R43]
  - Language setting [A]; in-app language choice isn't documented; UI follows the device [A], see U10.
- **Rules:** deleting the account anonymizes data; it doesn't cancel store subscriptions [V R30]. An email change keeps progress and subscription; if the old email is unreachable, support handles it [V R29].
- **Mobile vs web:** [P] the same; the web is where deletion and data export are easiest to offer.

---

## New screens found in the screenshots

### S45 Character pick (pre-game)
- **Purpose:** choose which character to play as before a game starts. [SS-09]
- **UI components:** 3 large round character buttons (rimmed), themed background shared with the game that follows, close (X) top-left [SS-09].
- **Interactions:** tap a character → the game starts with it [A]; in that game the player's lane is marked by an arrow [SS-13].
- **Navigation:** activity card → S45 → S13 [A on the card used].
- **Data:** chosen character per session [A]; no persistence seen.
- **Loading/error:** none seen.
- **Mobile vs web:** [P] the same; keyboard 1/2/3 or arrows on web.
- **Clone note:** use our own characters.

### S46 Learn Together lesson
- **Purpose:** a guided lesson that an adult and child do together. [SS-18, SS-19]
- **UI components:** intro card "Welcome to a Learn Together lesson!" (white centre panel over a themed background), adult and child illustration, the **PlayTogether badge**, a **speaker button** that replays narration, close (X) [SS-19]; then full-bleed lesson scenes with only a close button [SS-18].
- **Navigation:** reached from PlayTogether [A, badge-based]; the intro → scenes sequence is [SS].
- **Data:** a lesson-like sequence of scenes [A]; completion and stars unknown [A].
- **Loading/error:** none seen.
- **Mobile vs web:** [P] the same; on web, the narration needs a user gesture before audio plays.
- **Note:** not in the help center. It's a new lesson type alongside the Lessons tab.

---

## Other web surfaces of the original (reference only)

### S39 Teacher resources hub (web) [V R40]
Free lesson-plan library: filters for subject (13), topic (~45) and level (Multilevel, Pre-A1), plus search. Not connected to the app.

### S40 Lesson plan page (web) [V R40]
Objectives, lesson PDF, worksheet PDFs, related plans.

### S41 Printables library (web) [V R28]
60+ topics; kinds: Coloring, Coloring and Songs, Parents Guide; download PDF or email it.

---

## Count

46 screens: 40 in the app (39 verified, plus S30, which is inferred; S45 and S46 were found in the screenshots) and 6 web-only surfaces (S07, S08, S39, S40, S41, S43). The Stripe billing portal, help center and marketing pages exist too, but are outside our scope.
Screenshot coverage: 13 of the 40 in-app screens have at least one screenshot (S09, S13, S14, S15, S18, S19, S21, S26, S28, S31, S32, S45, S46).
