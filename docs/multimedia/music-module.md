# Music module

Phase 11, 2026-11-21. Screens K14 (Listen library, the songs part) and K33 (audio player), plus the mini player. Screenshots: `screens/M04-listen-library-mini-player.png`, `M05-song-player.png`.

## Brief → status

| brief | status | notes |
| --- | --- | --- |
| children's music library | done | Listen tab: Featured, Keep reading and listening, Picked for you, Played lately, the Songs row, Bedtime stories row, a row per category; search and filters as on Watch |
| song categories | done | Music time, Garden, Bedtime, Calm and kind (`categories`), filter chips |
| listing and artwork | done | square covers (WebP), titles, lengths |
| audio player | done | `/kids/listen/songs/:id`, full screen |
| play, pause, resume | done | play / pause; leaving mid-song saves the position, and opening that song again resumes there |
| previous and next | done | Previous restarts the song if it has played more than 3 s, else goes back one; Next moves on; tap any song in the list |
| repeat and shuffle | done | repeat off → all → this song; shuffle keeps the current song first and plays each once (deterministic per session); shuffle off returns to the list order |
| background audio where supported | done (config), **not tried on devices** | `just_audio_background`: Android foreground media service + `AudioServiceActivity`, iOS `UIBackgroundModes audio`, lock-screen title; `audio_session` pauses for calls. In the app the music keeps playing while the child browses (mini player). On the web, audio plays while the tab is open |
| recently played | done | "Played lately" (sessions, newest first) |

## How it works

- **One app-wide audio player** (`AudioController`, kept alive). Closing the player screen leaves the music on, and the **mini player** appears under every kid screen with the title, progress, play / pause, next and stop. Stop (✕) saves the position and closes the session. Switching child or signing out stops the music.
- **The queue is the visible song list** (age, the parent's switches, categories; Plus songs for Plus families). It starts at the song the child opened.
- **Each song is its own session:**
  - started when it begins;
  - completed when it plays to the end, which can earn the day's star for that song;
  - abandoned with its position when the child skips or stops.
- A song ending moves on by the repeat rule. At the end of the list without repeat, it stops.
- **Limits.** Listening counts towards the daily limit if the parent included songs and stories. When the time runs out, the music pauses and "That's all for today!" shows.

## Not done

- **Sung lyrics and a sing-along line** (K33 spec). The development songs are instrumental, and no lyric timing format exists yet.
- **Podcasts and audiobooks** (F-081, F-082). The player supports the `audiobook` type with the same controls, but there is no audiobook content: it needs recorded narration.
- **Playback speed for songs.** Deliberately off: songs play at 1×. Speed is offered for videos and story narration.
- **Device checks** for background playback and lock-screen controls.
