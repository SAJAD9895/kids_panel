# Video module

Phase 11, 2026-11-21. Screens K12 (Watch library), the video details page, and K13 (video player). Architecture: `media-architecture.md`. Screenshots: `screens/M01-watch-library.png`, `M02-video-details.png`, `M03-video-player-captions.png`.

## Brief → status

| brief | status | where |
| --- | --- | --- |
| video home screen | done | Watch tab (`MediaLibraryScreen(surface: 'watch')`) |
| categories and subjects | done | category and subject chips; a row per category; category and subject on the details page |
| listing with thumbnails | done | cards with WebP thumbnails (256 / 512 px), drawn art while loading or offline |
| featured and recommended | done | "Featured" hero (collection kind `drop`); "Picked for you" (not watched lately first, nearest the child's age) |
| details screen | done | `/kids/watch/:id`: thumbnail, title, description, length, category, subject, Play / Keep watching ("You stopped at 0:12"), related videos |
| video player | done | `/kids/watch/:id/play`, full screen |
| related videos | done | "More to watch" (same category, then same subject, then the rest); "Next: …" when a video ends |
| recently watched | done | "Watched lately" (from the child's sessions) |
| continue watching | done | "Keep watching" row with a progress bar per video; the player resumes there |
| search and filtering | done | search box (every word must start a word of the title, description, subject or category; any order) + category, subject and "Short ones" (≤ 1 min) filters; "Nothing found" state; Clear |

## The player

| feature | how |
| --- | --- |
| controls | big play / pause, back / forward 10 s, seek bar with times (screen readers: "Video position, 0:12 of 0:36"), close |
| full screen | toggle; hides the system bars; controls hide after 4 s of playing and come back on a tap |
| captions | WebVTT from the `subtitle` asset (the child's locale, else English), on by default, CC toggle; shown large on a dark band and announced to screen readers |
| speed | 0.75× / 1× / 1.25× (tap to change) |
| resume | from the newer of the device's and the server's position, unless it was under 5 s or within the last 5 %; "Carrying on from 0:12 · Start again" |
| loading / buffering | "Loading"; after 8 s "Slow internet… still loading" |
| errors | "Oops! … Try again" reopens at the same position; offline launch shows "You're offline" |
| end | "You watched it all!", Next (related), Watch again, More videos; a completed session (daily star) |
| interruptions | the app going to the background (a call, the home button) pauses; nothing restarts on its own |
| limits | when the daily limit runs out while watching, the video pauses and the child sees "That's all for today!" |
| course steps | opened from an island step, finishing completes the step |

Playback is progressive MP4 (`video_player`), streamed in byte ranges, so a video is never downloaded whole before playing. The web build was checked in Chrome:
- the video plays;
- captions stay in time with the picture;
- the seek bar moves.

Chrome only loads media in a visible tab; a test browser running in the background never starts the video. That's browser behaviour, not an app issue.

## Not done

- **Autoplay of the next video** with a countdown: the child taps "Next" instead.
- **HLS adaptive streaming** (`media/hls`).
- **Offline downloads** (F-073).
- **A "kid lock"** (locking the screen while watching).
- **Skill chips in the player** (F-163).
- **Recorded narration in videos.** The development videos have music and on-screen words only.
