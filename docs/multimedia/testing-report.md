# Multimedia testing report (Phase 11)

Date: 2026-11-21. Machine: macOS, Flutter 3.47, Postgres 17, Chrome (web build).

## 1. Summary

| check | result |
| --- | --- |
| `flutter analyze` | 0 issues |
| `flutter test` | **219 / 219 passed** (46 new: `test/unit/media_test.dart` 26, `test/widget/media_test.dart` 20) |
| SQL suites (`scripts/db-verify.sh`), incl. **M1** (new) | all pass, with migration `20261120000100_media.sql` and the generated seed §16 |
| Edge Functions type-check (`deno check`): play (launch, heartbeat, sync), children (screen-time), onboarding | pass |
| `scripts/check-secrets.sh` | no secrets |
| web release build + Chrome | Watch library, details, **real video playback with captions in time**, song playing with the mini player while browsing, story narration with highlighting (screenshots in `screens/`) |
| live Supabase project (signed URLs from real Storage, RLS reads of the new columns) | **not run**: no project exists |
| iOS / Android devices (background audio, lock screen, calls, TTS voices) | **not run** |

## 2. What the brief asked to test

| brief | tests |
| --- | --- |
| **video playback** | the player opens the MP4 and its captions; plays by itself; captions show and toggle; speed changes; back / forward 10 s; full screen hides and shows controls; pause / play; playing to the end → "You watched it all!", completed session with position, local position cleared, star; Watch again; a course step is completed when opened from an island |
| **audio playback** | the opened song plays, with every visible song in the list; pause / play; next; previous (song before under 3 s, restart over 3 s); repeat all / this song; a song ending plays the same song (repeat one) or the next; shuffle; picking a song from the list; one player for every song; the mini player keeps the music on while browsing, pauses, opens the player, stops and closes the session |
| **story navigation** | narration sentence by sentence (held and released in the test), pause stops it, next / previous page, swipe, tap a sentence to hear it, "Read to me" turns the page, the last page → "The end!" and a completed session, Read again |
| **progress persistence** | leaving a video at 0:12 → abandoned session with `positionMs` 12000 → "Keep watching" row with progress → details "You stopped at 0:12" → the player opens at 0:12 → Start again; leaving a story on page 3 → "Keep reading" → opens on page 3; unit: positions from sessions (newest decisive session wins), device store (corrupt data forgotten), report metrics round trip; SQL: resume returned by launch, cleared after finishing |
| **interruptions** | app to the background pauses the video and stops story narration (nothing restarts by itself); daily limit reached mid-video pauses it with "That's all for today!"; session tracker: heartbeats every 30 s, offline heartbeats keep the time for later, the end is sent once |
| **network failures** | a file that fails to open → "Oops!" → Try again; failing mid-video → Try again reopens at the same position; buffering → "Loading" → after 8 s "Slow internet"; launch while offline → "You're offline" → Try again |
| **responsive layouts** | Watch, Listen, video details, video player (with a caption), song player, mini player, story reader at **phone held sideways, tablet, desktop**: tap targets ≥ 44 dp, labelled buttons, text contrast, no overflow |
| parental controls | videos off → Watch gone from the rail, opening a video shows "Not today"; a blocked category hides its songs and stories and refuses to open them; the P03 screen switches, blocks a category, sets a limit and saves; daily limit (with games still open); a Basic family sees "Ask a grown-up!" for a Plus story, free stories open |
| server (SQL M1) | launch returns MP4 + captions, story pages in order with words; another family's child 404; retired content 404; Plus → `NEEDS_PLUS`; age window; section off → `SECTION_DISABLED`; blocked category → `CATEGORY_BLOCKED`; games never blocked; rules validated (limit range, unknown category), household-only, partial updates keep the rest; heartbeats add up and lock at the limit → `SCREEN_TIME_OVER`, games stay open; resume; service-only |
| content | every generated file exists with the size and sha256 the seed registers; every item has its files (video + captions, song, a page per text); captions are timed WebVTT; the seed registers every file and item |
| startup wiring | every repository resolves in demo mode **and** with Supabase (new test, see §3) |

Contrast is not checked on the mini-player screen only: the contrast checker misreads text cut by the edge of the scrolling page above the bar. The bar itself is ink on listen-soft, a design-token pair already checked.

## 3. Bugs found and fixed

| bug | found by | fix |
| --- | --- | --- |
| **Supabase mode had no game content and no `play/sync` repositories** (Phase 9 wired them for demo mode only, so playing a game against a real project would have crashed) | reading bootstrap for this phase | wired; a test now resolves every repository in both modes |
| the video player's bottom bar grew to full height and swallowed every tap (Close did nothing) | widget test (hit test) | fixed-height bars |
| an "Almost ready" spinner animating forever behind a story picture | widget test | still placeholder |
| the story controller read its state while being disposed (Riverpod forbids it) | widget test | page kept in fields |
| a session report sent after shutdown crashed | widget test | sends are best-effort (the outbox keeps the report) |
| song player controls overflowed by 59 px on a phone held sideways | layout test | the controls wrap |
| the loading indicator merged into the video's label for screen readers | widget test | its own semantics node |
| duplicate filter chips: category "Colours and shapes" next to subject "Shapes and colours", and "Feelings" twice | browser | categories renamed "Colour fun" and "Calm and kind" |
| a "Bedtime" row next to the "Bedtime" category | review | row keeps its title "Bedtime stories" |

## 4. Performance and memory

- **Thumbnails.** The 256 px file is picked when it's sharp enough and decoded at the size shown (unit-tested).
- **Lists.** Shelves build lazily.
- **Players.** One video player per screen, disposed on leaving (checked: the fake reports `disposed`). One audio player for the whole app (checked: one instance for every song).
- **Timers.** Periodic tickers are cancelled on dispose. Every widget test fails on a pending timer, and none did.
- **File sizes.** Videos 360–540 KB, songs 370–490 KB.
- **On devices** (memory, frame rate during video, battery with background audio): **not measured yet**. Use `flutter run --profile` with DevTools on the floor device.

## 5. Not covered

- A live Supabase project: real signed URLs, Storage range requests, RLS on `blocked_category_ids` and the activity_media `text` column.
- Devices: background audio, lock-screen controls, phone-call interruptions, TTS voices, Safari autoplay rules.
- Golden images.
