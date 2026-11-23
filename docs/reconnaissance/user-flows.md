# User flows

Each flow is a goal and the screens it passes through (IDs from `screen-inventory.md`).
**Taps** count the happy path for the original where the steps are verified. It's the number to beat. Typing a field counts as one.
Legend: **[V Rn]** verified, **[A]** assumption, **[P]** proposal.

---

### F01 New family signs up and starts free  (modules 1, 3, 4)
```
S01 Welcome -> S02 Child setup -> S03 Email -> S04 Plan picker (Continue free) -> S09 Home
```
- Order verified: profile, then email, then plan choice [V R21].
- Taps ≈ 8: Next, avatar, name, birthdate, level, email + Send, Continue free, first card. [A on the exact number of fields per step]
- Edge: Apple relay email [V R41]; email already registered → should offer login [A]; app closed mid-onboarding (resume or restart?) [A, U13]; device below the minimum OS [V R19].
- Web [P]: the same steps; no install; Google/Apple sign-in buttons.

### F02 New family starts the Plus trial  (1, 14)
```
S01 -> S02 -> S03 -> S04 (pick monthly/yearly trial) -> store sheet -> S09 (Plus)
```
- Taps ≈ 8 + store confirm. [A]
- Edge: purchase cancelled; payment failed (bank blocks international or recurring) [V R25]; a kid's Google account can't pay (Family Link) [V R41, R25]; Ask-to-Buy pending [A]; trial already used [A].
- Web [P]: Stripe Checkout; trial with a card on file.

### F03 Returning parent logs in on a new device  (2)
```
S01 -> "I have an account" -> S05 (email) -> email client -> magic link -> app -> S26/S09
```
- Taps: 3 + email + tap the link [V R16, R17].
- Alternative: S05 → Use password → S06 → (forgot) → S43 web reset [V R17, R18].
- Edge: email in spam; unregistered email [V R16]; link opened on another device [A]; subscription not syncing on the new device → "delete and reinstall" is the official advice [V R18].

### F04 Child plays an activity and earns a star  (4, 7, 11)
```
S09 -> S12 card -> S13 game -> celebration -> star +1 -> back to S09
```
- Taps: 1 to start [V R7 for the star rules].
- Edge: replaying the same activity today gives no star [V R7]; exiting before the "main learning bit" gives no star [V R7]; Basic allocation used up → locked [V R21]; slow network lag [V R35].

### F05 Child claims the daily reward and decorates a scene  (11)
```
(5 distinct completions) -> S09 Book icon -> S23 gift -> S24 Sticker Album -> S25 Scene Book (drag stickers)
```
- Taps: 1 (Book) + 1 (album) + drags [V R7].
- Edge: day boundary at local midnight [A]; several gifts stacked when stars exceed 5 [A, U08]; unclaimed gifts carry over [V R7 "no time limit on claiming"].

### F06 Child browses by subject  (5)
```
S09 -> S10 Explore -> subject tile -> results -> S12/S13
```
- Taps: 3 [V R8].
- Edge: no results; a search returning only videos [V R35 review].

### F07 Child opens a character world or collection  (5)
```
S09 "Worlds to Explore" row -> S11 -> S13
```
- Taps: 2 [V R2]. Edge: Plus-only world (locked on Basic) [V R21].

### F08 Child completes a lesson  (6, 11)
```
S17 Lessons -> S18 path -> S19 check-in (pre) -> S13 activities in order (several sessions) -> S19 check-in (post) -> S20 certificate
```
- Taps: 2 to start, then 1 per node [V R5 for structure; A for taps].
- Edge: resume mid-lesson after days [A]; Lessons switched off or limited [V R13, R14]; Basic can't fully access [V R22]; birthdate changed mid-lesson [A].

### F09 Child watches videos  (8)
```
S09 -> Theater (bottom nav) -> S14 category -> S15 player -> autoplay next
```
- Taps: 3 [V R6]. Lock: 1 tap on the lock icon [V R6].
- Edge: Theater switched off (some home-feed videos still visible) [V R14]; Theater time limit hit [V R13]; offline without downloads [V R27].

### F10 Child listens to a story  (9)
```
S09/S10 (Audiobooks and eBooks) -> S44 reader (tap words to hear them)
```
- Taps: 2–3 [V R31, R38].
- Edge: books are hard to find; one parent says they're buried in a "create a story together" area [V R35]. This is a navigation gap the clone can fix.

### F11 Family plays together  (10)
```
S09 -> PlayTogether (bottom nav) -> S21 -> team challenge / creative / off-screen card -> S13 or an instruction card
```
- Taps: 2 [V R3].
- Edge: two players on one device [A]; off-screen activity: how is completion counted? [A, U06]

### F12 Parent checks progress  (12, 13)
```
S09 -> S26 (tap child name) -> Parents Area -> S28 gate -> S31 -> S32 Progress
```
- Taps: 4 + gate [V R9, R10].
- Edge: fewer than 5 activities → empty [V R10]; Basic → limited [V R21]; report broken [V R35 review]; switching between children [A].

- **Screenshot correction [SS-15]:** there is a shorter path: S09 → avatar → **Progress Reports** (in the profile drawer) → S32. **2 taps** (+ gate, if any: U21). The report opens in portrait and covers the last 2 weeks [SS-14].

### F13 Parent adds a second child  (3)
```
S26 -> Parents Area -> S28 -> S31 -> Profile -> Add a child -> avatar / name / birthdate / level -> Save
```
- Taps ≈ 9 [V R11].
- Edge: Basic allows 1 profile [V R21] → S29 [A]; 4-profile cap [V R11].

### F14 Parent sets a daily limit / blocks sections  (12)
```
Path A: S27 Menu -> Timer -> S28 -> set limit -> Save                      [V R13]
Path B: S31 -> Profile -> child -> Screen Time -> limit + types -> Save      [V R13]
Block:  S31 -> Screen Time -> toggle Theater / Lessons / PlayTogether off    [V R14]
```
- Taps: Path A 4 + gate; Path B 6.
- Edge: games are always allowed [V R13]; what happens mid-activity when time runs out [A, U04]; time-zone or day reset [A].

### F15 Parent downloads content for a trip and the child plays offline  (15)
```
S12 download (x N) -> button turns green -> (device offline) -> S09 shows only downloads -> S13
Manage: S31 -> S36 My Downloads -> Edit -> delete one / all
```
- Taps: 1 per item [V R27]; or 1 for all favorites [V R26].
- Edge: storage full; interrupted download; stars and progress earned offline must sync [A, U07]; Plus lapses while content is downloaded [A].

### F16 Basic child uses up today's activities  (4, 14)
```
S09 -> 10 completions -> remaining cards locked -> (child) wait until tomorrow | (parent) S29 -> S28 -> S04
```
- [V R21] the allocation; the frustration is verified in reviews [V R35]. The locked-card state is [A].

### F17 Parent upgrades from Basic  (14)
```
S29 upsell (or S31 -> S35 Upgrade) -> S28 -> S04 -> store sheet -> S09 unlocked
```
- Taps ≈ 4 + store confirm [A].
- Edge: bought on the web, then logging in on a device → must pick up the entitlement [V R18]; "I paid but can't access Plus" [V R41]; different price on another device [V R41].

### F18 Redeem a gift code  (14)
```
Web S08: code -> REDEEM -> email -> CONTINUE -> (app) S01 -> I have an account -> S05 -> magic link -> S09 (Plus)
```
- Taps ≈ 6 + install [V R33].
- Edge: redemption cap reached; code deactivated for fraud [V R33]; email already has a store subscription [A].

### F19 Parent cancels  (14)
```
Web subscriber: S31 -> Profile -> Account -> Cancel my subscription -> confirm      [V R24]
Store subscriber: device Settings / Play Store / Amazon account -> cancel            [V R24]
```
- Edge: deleting the app doesn't cancel [V R24]; access lasts until period end, then Basic [V R24]; refunds are separate [V R24].

### F20 Parent changes email  (16)
```
S31 -> Profile -> tap email -> type -> Save
```
- Taps: 4 [V R29]. Edge: old email unreachable → support [V R29].

### F21 Parent deletes the account  (16)
```
S31 -> Profile -> Delete Account (bottom) -> confirm
```
- Taps: 3–4 [V R30]. Edge: an active store subscription keeps renewing [V R30]; data is anonymized, not purged [V R30].

### F22 Activity needs the microphone or camera  (2, 7)
```
S13 -> needs mic -> S28 gate -> S42 confirmation (Enable) -> OS dialog -> activity continues
```
- [V R20]. Edge: denied → fix it in device settings [V R20]; [P] web: browser prompt; on iOS Safari the prompt repeats per session.

### F23 Child and adult do a Learn Together lesson  (6, 10), from screenshots
```
S09 -> PlayTogether tab (S21) -> card -> S46 intro "Welcome to a Learn Together lesson!" (speaker replays narration) -> lesson scenes -> X
```
- [SS-11, SS-19, SS-18]. Taps ≈ 3. Edge: narration replay; leaving mid-lesson; completion and stars unknown (U24).

### F24 Child picks a character and races  (7, 10), from screenshots
```
S09/S21 card -> S45 character pick (3 choices) -> S13 race (own lane marked by an arrow) -> X
```
- [SS-09, SS-13]. Taps: 2 to start. Edge: 2-player same-device (U25).

### F25 Child works through a lesson unit  (6), from screenshots
```
Lessons tab -> lesson -> workbook (units: "Unit 1: Lowercase Letters a-h", ...) -> Unit 1 -> Knowledge Check (active) -> Collect (unlocks) -> Trace (unlocks) -> ... -> book goal on progress bar -> certificate badge lights up
```
- [SS-07, SS-10]. Locked nodes are dimmed until the previous node is done. The certificate badge is grey until earned. Edge: resume at the current node; back (<) exits to the lesson list.

---

## Tap counts to beat (summary)

| flow | original taps | our target [P] |
| --- | --- | --- |
| F01 sign up to first play | ~8 | ≤ 7 (combine name + avatar; birthdate as an age slider) |
| F03 log in on a new device | 3 + email | 3 + email, plus a 6-digit code fallback |
| F04 start an activity | 1 | 1 |
| F10 find a story | 2–3, but hard to discover | 2, with a dedicated Stories entry |
| F12 see progress | 2 via the drawer shortcut [SS-15] (4 + gate via the Parents Area) | 2, matching it; add the pre/post lesson comparison they lack |
| F14 set a limit | 4 + gate | 4 + gate |
