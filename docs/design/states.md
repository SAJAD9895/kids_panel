# Screen states: loading, empty, error, offline, locked

Every screen must design and test each state that applies. Components (`Skeleton`, `EmptyState`, `Toast/Banner`, `ErrorPanel`) are in `components.md`. Error codes come from `docs/architecture/07-api-specification.md`; offline rules from `12-offline-sync.md`.

## 1. Rules for every surface

| state | children's app | parents and admin |
| --- | --- | --- |
| **loading** | never a spinner on a blank screen. Show the shell immediately; skeleton cards in the card shapes; after 2 s, the buddy appears with "Getting it ready…"; after 10 s, the error state | skeletons in the shape of the content; buttons show their own loading state; no layout jump when data arrives |
| **empty** | always a friendly picture + one spoken sentence + one action (never an empty box) | illustration (ours) + one line + one action |
| **error** | no codes, no technical words, no red. Buddy looks puzzled: "Oops, let's try again" + Try again; after 2 failures, "Go back home". Error details go to the crash reporter, not to the child | plain-language message, what to do next, "Try again"; support code (request id) in small text for the help desk |
| **offline** | only downloaded items are shown, with a calm banner "No internet right now. These still work!" (K19); progress is queued and synced later [F-144] | read-only banner "You're offline. Changes will be saved when you're back online" is **not** offered: parent and admin changes need a connection; buttons are disabled with an explanation |
| **locked** | lock badge on the art only; label stays readable; tap opens K30 (never a price) | "Plus" chip + upgrade link |
| **slow** | after 6 s on a launch, show download progress (pack size known from the manifest) | after 5 s, "Still working…" |

## 2. Children's app

| screen | loading | empty | error | offline | other |
| --- | --- | --- | --- | --- | --- |
| K01 Splash | progress dots while bootstrapping (≤ 3 s target) | — | bootstrap fails → K07 from cache if any, else "We need the internet the first time" | first launch needs network; later launches start from cache | `426` → K36 |
| K03/K04 Sign-up, code | button loading | — | wrong code: "That code didn't match. 2 tries left." (K04); expired code → resend; email typo hint ("did you mean gmail.com?") | "Connect to the internet to sign in" | resend timer 0:42 (K04) |
| K05/K06 Child setup | — | — | nickname rules shown inline (1–20 characters, no last names) | kept on device until sign-up completes | — |
| K07 Home | skeleton rows | new child: rows still fill from age defaults (never empty); a row with no items is hidden | row fails → row hidden + retry row at the end; whole feed fails → error state | downloaded rows only + banner; no rows downloaded → K19 empty: "Ask a grown-up to save some games for trips" | Basic used up → K37; section off → its items gone; screen time over → K29 |
| K08 Category | skeleton grid | "More coming soon!" + back to Home | standard | downloaded items of that subject only | filter tab with no items hidden |
| K09/K10 Course, lesson | skeleton path | — | standard | path visible from cache; steps not downloaded show a cloud icon and are not tappable | step locked: dashed border + lock, full-contrast label; completed: check |
| K11 Game | loading card with the buddy idle and real progress | — | pack fails (hash, network) → retry; template crash → "This game needs a rest" + back, auto-reported | works fully offline if downloaded; result queued | paused (K11-pause), complete (K11-done), backgrounded → auto-pause, permission denied → plays without mic |
| K12/K13 Watch, video | skeleton cards; player buffering ring over the last frame | — | playback error → retry, then next video | downloaded videos only; streaming one → "This video needs the internet" | kid lock on; up next auto-plays 5 s after the end unless autoplay is off in the device settings (K20) |
| K14/K15/K32/K33 Listen, book, audio | skeleton | — | standard | downloaded only | end of book: "The end!" + read again / another |
| K16/K24 Rewards, sticker book | skeleton | no stickers yet: "Play 5 games to open your first surprise!" with 5 empty star slots | claim fails → the gift stays ready, "Let's try again" | gift claims are **online only** [P]: "Your surprise is waiting until we're back online" | new sticker glow |
| K17/K18 Me, garden | skeleton | new child: seeds in the garden, "Play to help your garden grow" | standard | last cached state with no banner | — |
| K21 Search | — | no results: "Hmm, I couldn't find that" + 4 suggested subjects | standard | searches downloaded items only, with the offline banner | typing |
| K22 Saved | skeleton | "Tap the heart on a game to save it here" | standard | queued saves shown at once (pending) | Basic: heart opens K30 |
| K29/K30/K37 | — | — | — | work offline (rules from the cached entitlement token and screen-time state) | — |
| K35 Who's playing | — | (never: a child exists before the Kids Area opens) | standard | cached profiles | — |

## 3. Parents Area and parent web

| screen | loading | empty | error | offline / other |
| --- | --- | --- | --- | --- |
| P01 Home | skeleton cards | (always has a child) | standard | app: cached last values + "Updated 2 h ago" |
| P02 Children | skeleton list | — | validation inline; delete fails → toast with retry | add at the plan limit → P07 |
| P03 Screen time | skeleton | — | save fails → toast, values reverted | change saved → toast "Saved"; applies on the child's device at next sync (≤ 1 min online) |
| P04 Progress | skeleton tiles [V SS-14] | fewer than 5 activities: "Your report appears after 5 activities" with progress (2 of 5) [F-124] | standard | — |
| P06/P07/P08 Billing | plan cards skeleton; purchase button loading | — | store cancelled → no message; store error → plain message + retry; paid but no access → "We're checking your purchase" + auto `billing/sync`, then help link | purchase needs network |
| P09 Redeem | button loading | — | invalid / used / expired / too many tries (5 per hour) each with its own message | — |
| P10 Downloads | — | "Nothing saved yet" + how to save a row | delete fails → retry | storage almost full (90 %) warning |
| P12 Privacy | — | — | — | export ready: email + link valid 7 days; deletion scheduled: banner with cancel until the date |
| P14 Devices | skeleton | (always this device) | — | — |

## 4. Admin

| screen | states |
| --- | --- |
| DataTable screens | loading skeleton rows; empty with "Create the first …"; filtered empty: "No results for these filters" + clear; error with retry; partial page error keeps the loaded rows |
| Editors (A04–A06, A08, A10) | unsaved changes guard on leave; autosave draft every 30 s; validation errors listed at the top and inline; conflict (someone else saved) → show both versions, choose; publish blocked with the reasons from `admin/content/validate` |
| Upload (A12) | idle, uploading (%), paused (resumable, network lost), processing, ready, failed (reason + retry) |
| Session | idle 30 min → sign-out warning 2 min before; MFA expired → re-verify without losing the form |
