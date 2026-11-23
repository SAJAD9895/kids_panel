# Web platform testing report (Phase 15)

Date: 2026-11-21. Machine: macOS, Node 24, Postgres 17, PostgREST 16.6, Deno 2, Chrome (Playwright 1.51), Dart (for the engine parity golden file).

## 1. Summary

| check | result |
| --- | --- |
| `npm run lint` (ESLint, Next rules) | 0 problems |
| `npm run typecheck` (`tsc --noEmit`, strict) | 0 errors |
| `next build` (production; part of every e2e run) | builds; 39 routes and middleware |
| Vitest **unit** | **84 / 84**:<br>• engine port 70 (`engine.test.ts` 28, `engine-session.test.ts` 23, `engine-parity.test.ts` 19);<br>• web rules 14 (`web.test.ts`) |
| Playwright **journeys** against the local stack | **60 / 60**: desktop 40, phone (touch) 18, laptop 1, tablet (touch) 1; the last two full runs green (the latest after the final code change) |
| design tokens only (unit test over every component) | pass |
| no service key or database address in the browser bundle (e2e) | pass |
| admin CMS suites after the shared test-stack changes | unit and integration 63 / 63 |
| live Supabase project, real devices | **not run** (§6) |

## 2. How it runs

`web_app/test/stack/stack.mjs` stands in for a Supabase project, as in Phase 14:

| piece | real or stand-in |
| --- | --- |
| Postgres 17 with **every migration** and `seed.sql` (Alice: Mia and Leo; Bob: Sam) | **real** schema, RLS and functions |
| PostgREST 16.6 | **real** Data API |
| Edge Functions `onboarding`, `children`, `play`, `progress`, `account` (Deno) | **real** code |
| Auth: password, email codes for sign-up / sign-in / recovery (to an in-memory mailbox the tests read), refresh, update password, sign-out (incl. global) | stand-in for GoTrue's HTTP API |
| Storage: signed and public URLs, byte ranges, uploads by the service role | stand-in; files come from the dev media library (`kids_app/assets/dev_media`) |

`playwright test` builds the real app against it and serves it with `next start`. A global teardown stops the stack afterwards. Earlier runs left database clusters running; that's fixed in both apps' stacks.

## 3. What the brief asked to test

| brief | tests |
| --- | --- |
| **parent registration and login** | `auth.spec.ts`:<br>• signed-out redirects for every protected area;<br>• registration: wrong code, then the mailed code → family form (refused without the consents) → 3 consents, 1 child and the time zone in the database → a weak password refused → password saved → *Who's playing?*;<br>• wrong password; right password; the session survives a reload; sign-out ends it;<br>• sign-in with an emailed code;<br>• **password recovery** → new password works, old one doesn't |
| **child profile selection** | choose Mia or Leo (the kid zone follows); another family's child is refused (security) |
| **learning navigation** | `learning.spec.ts` (desktop and phone):<br>• subjects → a subject's games;<br>• learn → course map (lesson 1 ready, lesson 2 locked by its prerequisite, progress 0 %) → lesson → step → play the game to the end → back → "Next lesson" → map shows 1 done, 2 ready, progress 50 %;<br>• a locked lesson's address sends you back;<br>• buddy change; rewards page |
| **game interactions** | `games.spec.ts`:<br>• **all 16 engine kinds**, from the admin builder's content, played through the real UI on desktop (mouse drags) and **15 on the phone with touch taps** (tracing is mouse only);<br>• memory, picture matching, word building, number, alphabet (choice and tracing), sorting, puzzle, jigsaw, quizzes, drag and drop, fill the gap, finish the shape;<br>• each must end with a **completed web session** of that kind in the database;<br>• leaving mid-game is saved as *abandoned*;<br>• the seeded quiz saves per-question responses |
| **video and audio playback** | `media.spec.ts`:<br>• a video plays from a short-lived URL past 5 s; leaving saves the position;<br>• "Keep watching" resumes at it; seeking to the end shows "Well done!" and a completed session;<br>• a song plays and resumes;<br>• a story: buttons and arrow keys, stopped on page 2 → "You were on page 2" → read to "The end" → completed;<br>• a parent's switch is enforced by `play/launch`, not just hidden |
| **progress sync, web ↔ Flutter** | `sync.spec.ts`:<br>• **app → web:** what the phone app sends to `/play/sync` (`platform: ios`) appears on the web — the video in "Keep watching" at 0:08, the game in the parent report;<br>• **web → app:** a web game is read back with the app's own query (`supabase_learning_repositories.dart`, the parent's token), counts in the star total, and appears in the report endpoint the app's dashboard uses.<br>Plus `engine-parity.test.ts`: the web engine reproduces the **real Dart engine's** output for all 16 seeded games, at 3 ages and every level (375 items), and builds byte-identical sync items |
| **parent dashboard** | `parent.spec.ts`:<br>• the gate (wrong answer stays out; the kid zone locks it again);<br>• overview of both children; report day / week / month, child switch, earlier periods, "Show as a table";<br>• goals saved → database; controls (songs off, 30-minute limit) → database → the child's Listen section disappears → restored;<br>• add a child (redirect), rename; notification preference off → database;<br>• data export built and downloadable; subscription shown with no purchase |
| **responsive layouts** | `responsive.spec.ts` on desktop, laptop, tablet and phone:<br>• no sideways scrolling on 12 screens;<br>• the rail on laptop and desktop, the bottom bar on tablet and phone;<br>• 48 screenshots in `docs/web/screens/`.<br>Keyboard-only: sign in → child → gate → report, with a visible focus ring |
| **unauthorized data access** | `security.spec.ts`:<br>• Bob with Mia's id in the child cookie → *Who's playing?*;<br>• Bob posting a play report → **403** and no session written;<br>• Bob opening Mia's report → **404**;<br>• Bob's token reading Mia's profile from the Data API → `[]`;<br>• grown-up pages need the gate;<br>• `?next=//evil.example` stays inside the app;<br>• no service key or database URL in the browser code (only the anon key) |

## 4. Bugs found and fixed

| bug | severity | found by | fix |
| --- | --- | --- | --- |
| the game player's "save when leaving" ran **after every answer**: it sent *abandoned* after the first move and then skipped the real *completed* report | high | games journeys ("Saving…" never finished) | the effect uses refs and runs only on unmount or page hide |
| another family's child id in the cookie reached the play API (the Edge Function refused it, but the route answered 200) | medium | security journey | the route checks the child is the parent's own (RLS) and answers 403 / 404 / 422 for refused items |
| adding a child saved but didn't open it (the function returns `childId`) | medium | parent journey | read `childId` |
| the birth month was empty when editing a child (a `date` from the database in a month input) | medium | parent journey | normalised to `YYYY-MM` |
| any "too short" value said "Fill this in first" (even a short password) | low | auth journey | the rule's own message is shown |
| form errors echoed **passwords and codes** back into the page | low (security hygiene) | auth journey | never returned |
| the home goal bar compared stars with a goal counted in activities | low | screenshots | the goal comes from the server's rewards summary, as in the app |
| seeded thumbnails that don't exist showed broken images | low | screenshots | a letter fallback |
| answer tiles grew huge on desktop (letters looked tiny) | low | screenshots | the answer grid is capped at the form width |
| a client component pulled a server-only module into the browser bundle | build | first build | link helper moved to a shared module |
| test stacks left Postgres, PostgREST and Deno running after Playwright stopped them (dozens of clusters) | test infrastructure | disk / `initdb` failures | exit handlers and a Playwright global teardown (web and admin) |

## 5. Behaviour kept identical to the app (worth fixing in both)

The engine port is exact, so these app quirks also exist on the web:
1. **`word_build` extra letters:** the admin builder writes `extra` as a list (`["x","z"]`), and the engine reads it as text, giving tiles `[ x , z ]`. The tests use a string. Fix the builder or the engine.
2. **Quiz responses:** only choice-type questions save per-question responses (not match or order questions).
3. **Picture-only order pieces** are interchangeable, so any order counts as right.
4. **Games with levels** drop extra quiz items.
5. **"Play again"** doesn't keep the chosen level.
6. **Memory time** includes paused time.

## 6. Not covered

- **A live Supabase project:**
  - Auth's real emails, magic links (`/auth/callback`), rate limits and refresh-token rotation;
  - Storage's CDN and range behaviour;
  - deployed Edge Functions.

  The stand-in reproduces their HTTP contracts as supabase-js uses them, not their internals.
- **Real phones, tablets and screen readers.** Touch was emulated in Chrome (taps). Assistive technology was checked by role and name queries, not with VoiceOver or TalkBack.
- **Browsers other than Chrome.** Safari's video (H.264) and Web Speech differ, and Firefox's speech voices vary.
- **Long sessions and slow networks.** The heartbeat and daily-limit lock were exercised only through the server tests from Phase 11.
- **Intermittent hydration warning.** An early smoke run once logged React error #418 (a hydration mismatch). It didn't recur in later runs and wasn't traced.
