# Web platform: features

Phase 15, 2026-11-21. Every feature in this file works against the backend and is covered by a journey test (`testing-report.md`). The table at the end lists what isn't on the web yet.

## 1. Parent authentication

| brief | how |
| --- | --- |
| registration | `/sign-up`:<br>1. the grown-up's email gets a 6-digit code;<br>2. the code is checked;<br>3. family set-up: a child's nickname and birth month, a buddy, country, and **the three required consents** (`child_data_collection` by `email_plus`), sent to `POST /onboarding/complete`;<br>4. an optional password.<br>Children never have an email or password |
| login | email and password; or **an emailed code** (no password needed, as in the app) |
| password recovery | `/forgot-password`: a code by email, then a new password. The answer is the same whether or not the address has an account |
| session persistence | Supabase session in cookies, refreshed by middleware; survives reloads and restarts |
| secure logout | Account settings → Sign out, optionally **on every device** (`scope: global`). Also forgets the chosen child and closes the gate |
| protected routes | middleware for signed-out visitors; `requireFamily` / `requireChild` / `requireGrownUp` on every page; RLS on every query. `next=` only accepts local paths, so there's no open redirect |

**Password rules.** At least 10 characters, with an upper-case letter, a lower-case letter and a digit (`docs/backend/authentication.md`). Error results never echo passwords or codes back to the page.

## 2. The child experience

| brief | screens |
| --- | --- |
| child profile selection | `/who`: a big tile per child with their buddy |
| child home | `/kids`:<br>• a greeting, stars today and the daily goal (from the server);<br>• **Keep going** (unfinished videos, songs, stories and started courses);<br>• the published home collections, filtered to the child |
| avatar and profile | `/kids/me`: choose a buddy (the app's 12 buddies, drawn in SVG from the same design) and switch child. The grown-up area edits name and birth month |
| subjects and categories | `/kids/subjects`: tiles per subject and category; `/kids/subjects/:key`: everything in it, grouped by kind |
| learning paths | `/kids/learn` lists the paths for the child's age; `/kids/paths/:id` shows its courses in order, started or finished |
| course listings | `/kids/learn`: courses for the child's stage, with lesson counts and status |
| lesson navigation | `/kids/courses/:id` is the course map:<br>• lessons are done, started, ready or **locked**;<br>• locked means the lesson before isn't finished, or a **prerequisite** isn't (Phase 14);<br>• a course progress bar.<br>`/kids/courses/:id/lessons/:id` lists the steps: the next required one is highlighted, done ones can be replayed, and "Next lesson" appears when it's finished. A locked lesson can't be opened by its address |
| activity player | `/kids/play/:id` for games and quizzes:<br>• intro, then items with a progress strip;<br>• Listen (speech), Help me (hints from the engine);<br>• Try again / Next, then a summary with the stars earned and Play again |
| interactive games | §3 |
| progress indicators | course and lesson states, course progress, story page counts, video and audio positions, "done" stars on cards, the daily goal bar, the item strip in the player |
| rewards and achievements | `/kids/me/rewards`: star balance, today's and this week's goal, streak, and badges (earned, or locked with how to earn them). Stars come from the server for every finished activity, the same as on the phone |

**Filtering.** What a child sees follows their age, the parent's section and category switches, and Plus. The server refuses the rest anyway: `play/launch` for media, and RLS plus an age and Plus check for games.

## 3. Educational games on the web

The 16 engine kinds are each drawn by a web view. Every view works with **a mouse, a finger and a keyboard**:
- dragging uses Pointer Events;
- the alternative to dragging is tap (or Enter) to pick, then tap where it goes;
- every piece is a real button.

| brief | kinds | interaction |
| --- | --- | --- |
| memory matching | `memory` | flip two cards; a match stays face up, a miss turns back; optional timer |
| picture matching | `image_choice`, `match_pairs` | pick the picture; drag each left item to its partner |
| word building | `word_build`, `fill_blank` | tap letters into the spaces (tap a filled space to take it back); pick the missing word |
| number games | `number_recognition`, `arithmetic` | count the pictures; small sums shown with pictures |
| alphabet games | `letter_recognition`, `trace` | find the letter; **trace** it with mouse or finger (judged geometrically, as in the app) |
| sorting | `sort` | drag (or tap) each thing into its group; wrong drops bounce back and count as mistakes |
| puzzles | `puzzle`, `jigsaw`, `shape_complete` | swap tiles (tap two, or drag one onto another); drag pieces onto the board; pick the missing half |
| quizzes | activity type `quiz` (`questions` / `answers`) and `multiple_choice`, `audio_choice` | choose; per-question responses are saved (`question_responses`) |
| drag and drop | `drag_to_target`, `sort`, `match_pairs`, `jigsaw` | as above |

**Content and reporting.**
- **No placeholders.** Pictures are drawn from the content's references (shapes, icons, characters, letters, counted groups). Thumbnails are the real files.
- **Same report as the app.** Every game reports `started`, then `completed` or `abandoned` (leaving mid-game), through `/play/sync` with `platform: "web"`. The server awards the same daily star and counts the same goals and lesson steps.

## 4. Multimedia

| brief | how |
| --- | --- |
| educational video library | `/kids/watch`: Keep watching, the watch collections, all videos |
| video player | `/kids/watch/:id`:<br>• the MP4 and its **captions** (on by default, can be switched off), using short-lived URLs from `play/launch`;<br>• big play and pause controls, a position slider, the time;<br>• `preload="metadata"`, a poster image |
| music library and audio player | `/kids/listen`: songs, stories, listen collections. `/kids/listen/songs/:id`: cover, play and pause, a slider |
| story library and reader | `/kids/listen/stories/:id`:<br>• one page at a time: the picture and its words in the reading font;<br>• arrows, ← → keys, or a swipe;<br>• **Read to me** plays the page's narration if it has one, otherwise the browser's speech;<br>• "The end" finishes it |
| playback progress | positions are saved every 5 s in the browser and **on the server in the session** (`abandoned` with `{positionMs, durationMs}` or `{page, pages}`). Media counts as finished at 95 % or the last page |
| continue watching and reading | "Keep watching" / "Keep listening and reading" rows with progress bars. The player resumes from the newer of the browser's and the server's position (not under 5 s or in the last 5 %), with "Start again". **It works across devices**: a video stopped on the phone resumes on the web (tested) |
| screen time | a heartbeat every 30 s of playback. When the server says the day's time is used up, playback stops and "That's all for today!" shows. Section switches and blocked categories are refused at launch |

## 5. Parent dashboard (`/parents`, behind the gate)

| brief | where | backend |
| --- | --- | --- |
| multiple child profiles | Overview: a card per child; Children: list, add, edit (name, birth month, buddy), delete (with a recent sign-in) | `POST`, `PATCH` and `DELETE /children` |
| learning progress | Overview: today, this week, stars, streak, goal, recent activity | `progress/overview` |
| daily and weekly reports | `/parents/children/:id/report`:<br>• **day, week or month**, earlier and later, child switcher;<br>• totals compared with the previous period;<br>• learning time, finished by kind, subjects, weekly consistency, skills (each with "Show as a table");<br>• games and quizzes tables, recent activity | `progress/report` (the same numbers as the app's P04) |
| subject performance | the Subjects chart (finished, average of scored), plus "What stands out", named only with enough evidence (the app's rule) | same |
| learning goals | Goals and rewards: on or off, activities a day, learning days a week | `PUT /children/:id/goals` |
| achievements | badges earned and to earn, recent stars and why | `children/:id/rewards` |
| screen-time settings and parental controls | Screen time and controls:<br>• Learn, videos, songs and stories, play together on or off;<br>• a daily limit and what it counts;<br>• today's use;<br>• categories on or off | `PUT /children/:id/screen-time`; enforced by `play/launch` and heartbeats |
| subscription information | plan, status, store, renewal or end date, "Plus works until", plans. **No purchase or payment is faked**: it says buying isn't connected yet | `subscriptions`, `entitlements`, `subscription_plans` |
| (also) notifications | inbox with "mark all as read", and a switch per type | `account/*` |
| (also) privacy and data | consents, data export (one child or the whole account, download), account deletion in 7 days or keep it | `account/*` |

## 6. Not supported on the web yet

| feature | why | where it works |
| --- | --- | --- |
| buying or changing a subscription | no store or Stripe checkout is connected in any app yet (`docs/parent-dashboard/subscriptions.md`) | nowhere yet |
| Sign in with Apple or Google | needs the Apple and Google client set-up (manual, `docs/backend/integration-readiness.md`) | nowhere yet |
| magic-link sign-in in the test stack | the route `/auth/callback` exists for real projects; the local test stack only does codes | real Supabase |
| offline play and downloads | a browser tab isn't a reliable place for an outbox. A session that can't be sent is lost (shown as stopped early) | Flutter app |
| "Play together" two-player mode, printables | not built in Phase 10–11 for any client | — |
| `asset:` pictures inside game items | not wired in either app; a neutral placeholder is drawn | — |
| per-item recorded voice clips | not in the engine format; the browser's speech reads prompts | — |
| co-parents (inviting a second grown-up) | not built yet | — |
| email and push notifications | not connected; notices are in-app only | — |
| consent withdrawal | view only, as in the app | — |

Two content quirks are kept the same as the app (engine parity) and are listed in `testing-report.md` §5.
