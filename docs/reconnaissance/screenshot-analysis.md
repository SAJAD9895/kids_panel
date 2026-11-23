# Screenshot analysis

Source: 19 images in `reference/` (WhatsApp exports, 2026-11-17 1:30–1:33 PM), provided by the project owner from their own device.
Device: an **Android phone**. Landscape frames are 1360×612 (≈20:9) and portrait frames are 612×1360. The dark tab on the left edge of every frame is the phone's edge-panel handle, **not app UI**.
New evidence tag used across the docs: **[SS-nn]** = seen in screenshot nn below. Seeing something in a screenshot counts as verified.

Clean-room note: these images are reference only. Characters, art, logos, brand collections (e.g. the Disney-branded card) and copy in them must not be reused. The layout and interaction patterns are what we take.

## Index

| SS | file | screen | maps to | orientation |
| --- | --- | --- | --- | --- |
| 01 | `…1.30.34 PM (1).jpeg` | Kids Home: **Play** tab | S09 | landscape |
| 02 | `…1.30.34 PM.jpeg` | **Not Lingokids**: an Edapt "Pre-Session Guide" page | — exclude | portrait |
| 03 | `…1.30.35 PM.jpeg` | Game in progress (hygiene scene, door) | S13 | landscape |
| 04 | `…1.30.37 PM (1).jpeg` | Kids Home: **Theater** tab | S14 | landscape |
| 05 | `…1.30.37 PM.jpeg` | Game in progress (tooth-brushing, inset close-up) | S13 | landscape |
| 06 | `…1.30.39 PM (1).jpeg` | Video player ("Run for Fun") | S15 | landscape |
| 07 | `…1.30.39 PM (2).jpeg` | Lesson path: workbook of units | S18 | landscape |
| 08 | `…1.30.39 PM.jpeg` | Video player ("The Key To It All") | S15 | landscape |
| 09 | `…1.30.40 PM (1).jpeg` | Character pick before a game | **S45 (new)** | landscape |
| 10 | `…1.30.40 PM.jpeg` | Lesson path: inside a unit (Knowledge Check, then the next nodes) | S18, S19 | landscape |
| 11 | `…1.30.41 PM (1).jpeg` | Kids Home: **PlayTogether** tab | S21 | landscape |
| 12 | `…1.30.41 PM (2).jpeg` | Stacking game | S13 (G20) | **portrait** |
| 13 | `…1.30.41 PM.jpeg` | Swimming race game | S13 (new mechanic G38) | landscape |
| 14 | `…1.30.42 PM (1).jpeg` | Progress Report: **empty state** | S32 | **portrait** |
| 15 | `…1.30.42 PM.jpeg` | Profile drawer + feature tooltip | S26 | landscape |
| 16 | `…1.30.43 PM (1).jpeg` | Parents Area home | S31 | **portrait** |
| 17 | `…1.30.43 PM.jpeg` | Parental gate | S28 | landscape |
| 18 | `…1.33.03 PM (1).jpeg` | Learn Together lesson: activity scene | **S46 (new)** | landscape |
| 19 | `…1.33.03 PM.jpeg` | Learn Together lesson: welcome card | **S46 (new)** | landscape |

**Not covered by any screenshot:** onboarding (S01–S04), login (S05/S06), Explore/search (S10), collections (S11), Lessons catalogue (S17), certificate (S20), Favorites (S22), rewards claim / album / scene book (S23–S25), screen-time settings (S34), subscription (S35), downloads (S36), settings (S37), time's-up (S30), Basic locked state.

---

## Shared shell (seen across SS-01, 04, 11)

The Kids Area is **one shell with a colour theme per tab**: Play = deep purple, Theater = crimson/raspberry, PlayTogether = magenta. [SS-01, 04, 11]

| zone | element | details | interaction |
| --- | --- | --- | --- |
| top-left | **Profile avatar** (circle) | the active child's avatar | tap → profile drawer (SS-15) |
| top-centre | Logo | white wordmark | none [A] |
| top-right | **Search** (magnifier, outlined circle) | this is Explore | → S10. **Resolves U01:** Explore is a top-right icon, not a tab |
| top-right | **Favorites** (heart, outlined circle) | | → S22 |
| body | **Feed rows** | row title (white, bold), with a **download icon button next to every row title** | row download = download the whole row [A on behaviour; the icon is SS] |
| body | **Activity cards** | large (≈350×265 px at 1360w), 24px-ish radius; full-bleed art; **a label pill bottom-left shows the skill or theme** ("Health", "Creativity", "Food", "Social Skills", "Curiosity"…), not the activity title; **heart button** (dark navy circle) overlaps the bottom-right edge | tap card → activity; tap heart → favorite |
| body | rows peek | the next row title and the top of its cards show above the nav ("Worlds to explore", "Baby Bot Knows", "Drive Together") | vertical scroll |
| bottom-centre | **Floating tab bar** (pill, theme-tinted) | **4 tabs: Play, Theater, Lessons, PlayTogether**, each a 3D illustrated icon with a label; the selected tab is **larger with a bold label** | tap → switch tab and theme |
| bottom-right | **Reward widget** (Play tab only in SS) | an arc of **5 star slots** (1 filled yellow in SS-01) ending in a **gift icon**, wrapped around a round **book button** (sticker album) | stars fill as activities finish; book → album/gift (S23/S24) |

Row names seen: Play = "Your daily picks", "Worlds to explore". Theater = "Everyday Adventures", "Baby Bot Knows". PlayTogether = "Think Together", "Drive Together".

## Per-screen analysis

### SS-01 Kids Home: Play  → S09
- Verifies the shell above, plus **Daily Picks** first [R2]. The card label is a theme ("Health"), so a daily pick is presented by skill or theme, not by title.
- **Rewards on Home:** 5-slot star arc + gift + book confirms R7 (5 stars → gift; the Book claims it).
- No lock icons visible: this account appears to be on Plus [A], so the Basic locked state is still unseen (U11).

### SS-04 Kids Home: Theater  → S14
- Video cards add a **duration badge top-right** (e.g. 03:02) and a **centred translucent play button**. The label pill is again a skill ("Social Skills", "Curiosity", "Flexibility", "Emotion…").
- No reward widget visible on this tab [SS]. Whether it's hidden on Theater, or just out of frame, is unknown [A].

### SS-06, SS-08 Video player  → S15
- **Layout:** dark navy background, video in a centred 16:9 frame (not full screen), **title top-left** with **skill chips** below it (e.g. "Actions", "Collaboration"; "Curiosity", "Collaboration", "Problem-Solving"); **close (X) top-left**; **lock (padlock) top-right**.
- **Controls:** pause/play, scrubber with a pink dot, time label at the right (02:14, 05:59 at the start of playback, so it's probably remaining or total duration [A]).
- **"Up next" rail** along the bottom: horizontal thumbnails with a duration badge and a topic label ("Hygiene", "Rhyming", "Human Body", "Cultural Celebrations", "School", "Animals", "Seasons", "Collaboration").
- Confirms R6 (lock icon top-right; autoplay next, as the rail implies). **New:** videos carry several skill tags shown as chips, so the data model needs `skills[]` on videos too.

### SS-03, SS-05 Game in progress  → S13
- **Full-bleed scene, no HUD except a close (X) top-left.** No score, timer, progress bar or pause button visible.
- SS-05 shows an **inset picture-in-picture close-up** (the brushing action) while the child drags the toothbrush. This suggests a drag-and-act "daily routine" mechanic (hygiene) → G24-like role-play [A].
- SS-03: a narrative scene (characters messy, bathroom door open) → story-driven routine game [A].

### SS-12 Stacking game (portrait)  → S13, G20
- **Runs in portrait:** orientation is **per activity**, not fixed. **Resolves U02** partly: kid screens are mostly landscape, but some games lock to portrait.
- UI: close (X) top-left; **next-piece preview + counter bubble ("1")** top-right; a falling piece (vehicle) above a stack; **three big round buttons: rotate left (green), drop (yellow, down arrow), rotate right (blue).**
- Confirms G20 stacking. Adds controls we hadn't documented (rotate and drop buttons instead of drag).

### SS-09 + SS-13 Character pick, then the race  → S45 (new), S13, G38 (new)
- SS-09: three large **round character buttons** (pink rims) on a stadium/beach background; close (X). A **pre-game "choose your player"** step.
- SS-13: **swimming race**: lanes, the chosen character marked by a **pink arrow**, rivals in other lanes, a crowd background (the same one as SS-09, so the same activity).
- New mechanic **G38 Race (tap to move)** [A on the input: probably tap or rapid tap]. Likely a PlayTogether or sports activity; the "Lingokids Games 2026" release had races [R35 changelog].

### SS-11 Kids Home: PlayTogether  → S21
- The same shell in magenta. Rows: **"Think Together", "Drive Together"**.
- Cards carry **two smiley player badges** (two colours) at the top centre: the **2-player indicator**. Labels: "Vehicles", "Comparing", "Problem-Solving", "Shapes". One card carries a licensed-brand logo (out of scope).
- Confirms R39 "multiplayer". The badges strongly suggest **2 players on the same device** [A, but strong evidence; resolves the spirit of B8].

### SS-07, SS-10 Lesson path  → S18, S19
- **Background:** light-blue grid paper. **Top bar:** back (<) top-left; **progress bar** top-centre from a **green check** (start) to a **blue book "1"** (the goal = workbook 1); **certificate/diploma badge** (greyed = not yet earned) and **lock** top-right; partner badge bottom-right "in collaboration with: …" [R2 partner lessons].
- **Structure (new, verified):** Lesson → **Workbook** (tab label "workbook 1") → **Units** shown as spiral-notebook cards ("Unit 1: Lowercase Letters 'a-h'", "Unit 2: … 'i-p'", "Unit 3: … 'q-t'") joined by dotted connectors, scrolling horizontally.
- **Inside a unit (SS-10):** node sequence = **"Knowledge Check"** (white, active: the current node) → **"Collect: Lowercase Letters 'a' and 'b'"** (dimmed: locked) → "Tra…" (Trace, dimmed). So **future nodes are locked and dimmed** until the previous one is done.
- Confirms R5 (check-in at the start, certificate top-right). Names the check-in "Knowledge Check" and shows node types **Collect** and **Trace** (→ E3 trace engine). Partly resolves U15.

### SS-18, SS-19 Learn Together lesson  → S46 (new)
- SS-19: intro card **"Welcome to a Learn Together lesson!"**: a white centred panel over a space background, illustration of an adult and child, the **PlayTogether badge** (two smileys), a **speaker button** (replay narration) bottom-right, close (X) top-left.
- SS-18: the lesson's first scene (space, character in a saucer, rocket); close only.
- **New concept:** a **"Learn Together" lesson type**: a guided lesson for adult and child together, tied to PlayTogether. Not in the help center. The narration button means the text is also read aloud (low-reading UI, R4).

### SS-15 Profile drawer  → S26 (corrected)
- **A drawer sliding in from the left** over the home screen (the home dims behind it), with a close (X) at the top.
- **Profile list:** avatar, name, **age in years**; the **selected row is highlighted** and shows two round actions: **hourglass (screen time)** and **pencil (edit profile)**. The list scrolls (3 profiles visible).
- **Below:** **"Progress Reports"** (a direct shortcut) and **"Parents Area"** (with a **red notification dot**). Both lead through the gate [A, per R9].
- **Feature-tip tooltip:** "All your tools now in one place: manage downloads, screen time, progress & more!" with its own close. So there's an **in-app feature-announcement tooltip** system.
- **Correction to S26/F12:** progress is reachable in 2 taps (avatar → Progress Reports), not 4. Screen time and edit are per-profile quick actions here.
- Note: one test profile shows "13 years old", so the app accepts ages above the 2–8 marketing range [SS].

### SS-17 Parental gate  → S28
- Title **"Parents only"**, prompt **"Please enter your year of birth:"**, **4 underscore digit slots** (one filled: "2"), a **3×4 numeric keypad** (1–9, 0, backspace), close (X) top-right, illustration left.
- Confirms R9 exactly. Resolves U17 for this device: **birth-year keypad**, no maths problem. No submit button visible, so it probably **auto-submits after the 4th digit** [A].

### SS-16 Parents Area home (portrait)  → S31 (corrected)
- **Switches to portrait.** The Parents Area is a portrait, list-style UI while the Kids Area is landscape [SS-16 vs SS-01].
- Back chevron top-left. **"Your children"** card: avatar row (the selected one has a yellow ring and a pencil badge) + a dashed **"+ Add a child"** circle; rows **Progress Reports**, **Screen time** (value "Off", red dot), **My Downloads** (count "13"), each with a chevron.
- Separate cards below: **Profile**, **Manage Subscription**, **Invite a friend**, **News** (more continue off-screen).
- **New features not in the help center:** **Invite a friend** (referral) and **News** (in-app news). Matches the R9 sections otherwise; "Account" in R21 seems to be "Profile" + "Manage Subscription" here.

### SS-14 Progress Report: empty state (portrait)  → S32
- Header **"Last 2 weeks"**; an info banner: "Find your kid's progress once they start playing. The progress shown is for the **last two weeks**. **Start playing!**" (link).
- **Activities** tile: "0 Completed", "No activities completed yet." **Mastery** tile: "Skill Achieved", "This is the skill that [child] practiced the most, by completing times."
- **Most Played Subjects:** 3 placeholder rows with coloured dots (yellow, cyan, red): "Subject – Activities".
- **Top Practiced Skills:** horizontal carousel of numbered cards (1, 2, …): "Skill", star, "Achieved by playing", "Game:".
- **Support card:** "We're here to help", "Go to Support Area" button.
- **New, verified:** the report covers a **rolling 14-day window**. The empty state shows **skeleton placeholders** rather than hiding sections. Matches R10's four blocks. (The R10 "5 activities" threshold isn't contradicted; this child has 0.)

### SS-02 Excluded
An Edapt "AI for Business Leaders – Pre-Session Guide" page. Unrelated to Lingokids; probably sent by mistake. Suggest removing it from `reference/`.

---

## Components confirmed by the screenshots

These feed `/replica-design`. Describe the pattern only, never copy the art.

| component | variants seen | states seen | SS |
| --- | --- | --- | --- |
| Floating tab bar (4 tabs, theme-tinted pill) | Play / Theater / Lessons / PlayTogether | selected (larger icon, bold label), default | 01, 04, 11 |
| Round icon button (outlined, top bar) | search, favorites | default | 01, 04, 11 |
| Close button (navy circle, white X) | top-left in activities/players; top-right on the gate | default | 03, 05, 06, 09, 12, 17, 18, 19 |
| Lock button (navy circle, padlock) | video player, lesson path | unlocked | 06, 07, 08, 10 |
| Back button (navy circle, chevron) | lesson path | default | 07, 10 |
| Row header with download icon | all tabs | default | 01, 04, 11 |
| Activity card (game) | skill label pill, heart | default | 01 |
| Activity card (video) | + duration badge, centre play overlay | default | 04 |
| Activity card (multiplayer) | + two-player badges | default | 11 |
| Heart button (navy circle overlapping the card edge) | | off | 01, 04, 11 |
| Reward widget (5-star arc + gift + book) | | 1 of 5 filled | 01 |
| Video frame + scrubber | | playing | 06, 08 |
| Skill chip (white pill) | 1–3 per video | — | 06, 08 |
| Up-next rail (small video cards) | | — | 06, 08 |
| Lesson progress bar (check → book goal) | | start | 07, 10 |
| Certificate badge | | not earned (grey) | 07, 10 |
| Workbook/unit card (spiral notebook) | unit; "workbook N" tab | default | 07, 10 |
| Lesson node card | Knowledge Check (active), Collect / Trace (locked, dimmed) | active, locked | 10 |
| Partner badge (bottom-right pill) | | — | 07, 10 |
| Character select button (large round) | ×3 | default | 09 |
| Game control buttons (big round 3D) | rotate left, drop, rotate right | default | 12 |
| Next-piece preview + counter bubble | | — | 12 |
| Lane indicator arrow | | — | 13 |
| Intro card with narration (speaker) button | | — | 19 |
| Profile drawer row | selected (with hourglass + pencil), default | | 15 |
| Feature tooltip (dismissible callout) | | shown | 15 |
| Notification dot (red) | on Parents Area, Screen time | | 15, 16 |
| Parental gate keypad + 4-slot input | | 1 digit entered | 17 |
| Parent list card (icon, label, value, chevron) | value text ("Off"), count ("13") | | 16 |
| Avatar picker row + dashed add-circle | selected ring + edit badge | | 16 |
| Stat tile (icon ribbon, big number, caption) | Activities, Mastery | empty | 14 |
| Ranked list with colour dots | | placeholder | 14 |
| Skill carousel card (rank number) | | placeholder | 14 |
| Info banner with inline link | | — | 14 |
| Support card with outline button | | — | 14 |

## Navigation map confirmed

```
Kids Home (tabs: Play | Theater | Lessons | PlayTogether)        [SS-01,04,11]
 ├─ top-left avatar ─▶ Profile drawer                            [SS-15]
 │    ├─ profile row ─▶ switch child
 │    ├─ hourglass ─▶ (gate) ─▶ screen time for that child       [A gate]
 │    ├─ pencil ─▶ (gate) ─▶ edit profile                        [A gate]
 │    ├─ Progress Reports ─▶ (gate?) ─▶ Progress Report (portrait) [SS-14]
 │    └─ Parents Area ─▶ Parental gate ─▶ Parents Area (portrait) [SS-17, SS-16]
 ├─ top-right search ─▶ Explore                                   [SS icon; screen unseen]
 ├─ top-right heart ─▶ Favorites                                  [SS icon; screen unseen]
 ├─ card ─▶ [character pick] ─▶ game (landscape or portrait) ─▶ X back   [SS-09,12,13,03,05]
 ├─ video card ─▶ player (X, lock, up-next rail)                 [SS-04,06,08]
 ├─ Lessons ─▶ lesson ─▶ workbook/units ─▶ unit nodes (Knowledge Check → Collect → Trace…) [SS-07,10]
 ├─ PlayTogether card ─▶ Learn Together intro ─▶ lesson scenes   [SS-11,19,18]
 └─ reward widget book ─▶ gift / album                           [SS icon; screen unseen]
```
