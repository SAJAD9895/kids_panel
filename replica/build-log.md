# Build log

| id | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| shell | 2026-11-18 | done | K07 rail and feeds (M2), l10n, Sentry | Riverpod 3 + GoRouter redirect wiring; one pure redirect function made it testable |
| K01 splash | 2026-11-18 | done | — | an offline start would have spun forever; now error + retry |
| K02 welcome | 2026-11-18 | done | language chip | — |
| K05 child details | 2026-11-18 | done | — | year chips stretched full width on the web (found in the browser, fixed) |
| K06 buddy picker | 2026-11-18 | done | commissioned buddy art (drawn placeholders), "hear the name" button | — |
| K03 sign-up + consents | 2026-11-18 | done | Apple / Google hidden until keys exist | overflowed on phones in landscape (a11y test), fixed |
| K04 code | 2026-11-18 | done | magic-link deep link untested without a project | — |
| P16 password sign-in | 2026-11-18 | partial | password reset page | — |
| finish setup | 2026-11-18 | done | consent confirmation email (Edge Function TODO) | submit was ignored on first call (provider still starting); found by the flow test |
| K35 who's playing | 2026-11-18 | done | — | — |
| K07 kids home | 2026-11-18 | done (Phase 8) | Together row, search, games | previous child's data flashed on switch (fixed) |
| K20 gate | 2026-11-18 | done | — | — |
| P01 parents home | 2026-11-18 | partial | progress, screen time, subscription, settings | — |
| P02 children | 2026-11-18 | done | stage override, content language, archive | snack bars queued behind each other; now replace |
| P17 re-auth | 2026-11-18 | done | — | — |

Backend added for these screens: migration 0014 `private.update_child` (+ SQL test C1), Edge Functions `onboarding` and `children` (type-checked, not deployed).
Not yet run against a real Supabase project: no dev project exists (docs/backend/integration-readiness.md §4).

## Phase 8 (2026-11-18)

| id | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| Kids shell | 2026-11-18 | done | — | rail button shadow animated with a bounce curve went negative and asserted |
| K21 subjects | 2026-11-18 | partial | search | caption + coloured tile failed the contrast heuristic as one node |
| K08 subject | 2026-11-18 | done | — | — |
| Learn | 2026-11-18 | done | Learn Together courses | — |
| Course list | 2026-11-18 | done | — | — |
| Learning path | 2026-11-18 | done | — | — |
| K09 course | 2026-11-18 | done | certificate | — |
| K10 island | 2026-11-18 | done | prize opening (K23) | continuous Pip bounce: tests need "reduce motion" |
| Activity | 2026-11-18 | done | real Play (game engine) | message bar covered sheet buttons |
| K17 me | 2026-11-18 | done | garden K18, sticker book | — |
| Watch / Listen | 2026-11-18 | partial | players K13 / K33 | — |

The data layer reads the real schema (Data API under RLS) but hasn't run against a live project. Composition of Home happens in the app until `catalog/home` exists (docs/flutter/home-screen.md §5).
| K11 player (learning engine) | 2026-11-18 | done | real artwork and recorded voice; video/song/story players; play/launch | tracing judge needed an ink-length rule (a scribble passed); memory board on phone landscape; Riverpod read during dispose |
| play/sync + apply_session | 2026-11-18 | done (local) | not run on a live project; gifts, mastery, badges | idempotency and household-day star rules in one function |

Phase 9 (learning engine): 13 activity types behind one player, pure session engine, progress via `POST /play/sync` → `private.apply_session` (migration 20261118001500). Interrupted runs resume within 24 h; offline reports wait in an outbox. 134 Flutter tests, SQL P1. Docs: docs/flutter/learning-engine.md, activity-types.md, progress-tracking.md, testing-report.md.
| Game collection (8 games) | 2026-11-19 | done (local) | real art and recorded voice; device profiling; live Supabase run; Flame mechanics (runner, rhythm, stacking) | tracing on phones: the page scroll stole vertical strokes and the box didn't fit (both fixed); memory board layout at 16 cards |

Phase 10 (games): Memory match, Picture match, Word builder, Number fun, Alphabet adventure, Sort it out, Puzzle time, Quiz time, each Easy/Medium/Hard on the learning engine, in a Home "Game room". New engine pieces: levels and Next level, sound effects (synthesised, switchable), memory moves and clock with a card flip, pictures with colour and size, adding and taking away, shape completion, jigsaw, letter sounds and big/small letters, capitals to trace. Migration 20261119000100 (runtime 'flutter'), JSON Schema for games.config, seed §15 generated. 173 Flutter tests, SQL G1. Docs: docs/games/.
| K12 Watch + K13 video player | 2026-11-21 | done (local) | HLS, offline downloads, autoplay-next countdown, live Supabase run | a full-height control bar swallowed every tap (Close didn't work); Chrome defers video loading in background tabs (browser check) |
| K14 Listen + K33 song player + mini player | 2026-11-21 | done (local) | sung lyrics, audiobooks (need recorded narration), background audio not tried on devices | one audio player shared across screens |
| K32 story reader | 2026-11-21 | done (local) | recorded narration files | narration via device voice sentence by sentence (pause = stop the sentence) |
| P03 media and screen time | 2026-11-21 | done (local) | learn/together switches UI, gift of extra time | — |
| K16 my rewards | 2026-11-21 | done (local) | certificate view, sticker album (F-101–F-103 not in this brief) | lazy lists: tests must scroll to what they check |
| celebrations | 2026-11-21 | done (local) | sounds for celebrations | a layer above the router rebuilt mid-mount; it now listens and updates after the frame |
| P18 rewards and goals | 2026-11-21 | done (local) | per-family rule overrides (rules are global, admin-edited) | — |
| P01 parent dashboard | 2026-11-22 | done (local) | — | lazy lists push links below the fold; "Manage children" moved into the header |
| P04 report + analytics | 2026-11-22 | done (local) | course pre/post scores, 7/14/30/90 picker (day / week / month instead) | skill mastery had to be built first (nothing computed it); found the Phase 9 score-0 bug |
| P11 notifications | 2026-11-22 | partial (local) | email and push senders | — |
| P12 privacy and data | 2026-11-22 | done (local) | consent withdrawal, export retention job | — |
| P06 subscription | 2026-11-22 | partial (local) | store purchase / restore, Stripe portal | — |

Phase 11 (multimedia): original development media (5 videos with captions, 5 songs, 4 illustrated stories, thumbnails) generated by content/dev-media/make_dev_media.py; play/launch (gate + signed URLs), play/heartbeat, children/:id/screen-time; migration 20261120000100 (blocked categories, story page text, launch / heartbeat / rules functions); resume positions in session metrics. Found and fixed a Phase 9 wiring bug (Supabase mode had no game content / play sync repositories). 219 Flutter tests, SQL M1. Docs: docs/multimedia/.

Phase 12 (rewards): one reward step after apply_session (private.apply_rewards): star ledger with once-only keys, configurable reward_rules, daily/weekly goals set by parents, a learning-days streak that forgives a rest day (household time zone), 16 badges with original art (make_dev_media.py --only badges); GET /children/:id/rewards, PUT /children/:id/goals; K16 My rewards, celebrations (reduced motion), P18. Migration 20261121000100 (5 tables, 1 view, rewards columns), seed §17 (generated) + §18. Found and fixed: badge art not bundled (pubspec) — now a unit test. 260 Flutter tests, SQL R1. Docs: docs/gamification/.

Phase 13 (parent dashboard): P01 dashboard (overview of every child), P04 day/week/month report with six charts and tables, P11 in-app notifications with preferences, P12 consents / export / account deletion, P06 subscription (no payment faked), P03 Learn and Together switches. Migration 20261122000100 (skill mastery model, notify + weekly job, exports, reports); Edge Functions `progress` and `account`. Fixed: unscored sessions stored as score 0 (Phase 9). 293 Flutter tests, SQL D1. Docs: docs/parent-dashboard/.

Phase 14 (admin CMS): `admin_panel/` (Next.js 15, Tailwind 4 from the design tokens, the admin's own Supabase session — no service key). 19 pages: dashboard, review queue, activities with game builder (16 engine kinds, Ajv against the engine schema) / quiz editor / media, courses → modules → lessons (prerequisites enforced in the app), subjects and categories, media library (staged upload → `admin` Edge Function), rewards, families, data requests, subscriptions, admin users, settings, audit log. Migration 20261123000100 (approved status + lock, course/lesson fields, app_config, suspension, admin star grants, schema admin_api with 14 functions). Harder than expected: no Supabase CLI or Docker, so a local stack (Postgres + PostgREST + stub Auth/Storage + the real Deno function) was built to test for real; it exposed a pre-existing high-severity bug — every Edge Function double-encoded its JSON parameters (play, children, account) — now fixed, plus a missing reward_rules grant (Phase 12), duplicate form ids, and a parent being offered admin MFA. Tests: 33 unit, 30 integration, 11 e2e, SQL X1, Flutter 297 (contract test on a CMS-built game). Partial: media (no transcoding / resumable upload), subscriptions (no payment processing), game preview is a description, not the Flutter rendering; not run on a live Supabase project. Docs: docs/admin-cms/.

Phase 15 (web platform): `web_app/` (Next.js 15, separate from the admin CMS), on the existing backend with the parent's own session — no migration, no new Edge Function, no service key. Parent auth (email code sign-up with consents, password, code sign-in, recovery, global sign-out); child zone (who's playing, home, buddies, subjects, paths, courses with prerequisites, games, video, songs, stories, rewards); parent area behind the gate (overview, day/week/month reports, goals, controls, children, notifications, privacy, subscription). Harder than expected: the games — the Flutter engine was ported to TypeScript (16 kinds, ~2,600 lines) and proven identical to the Dart engine with a golden file (375 items, byte-identical sync reports); every kind has a mouse/touch/keyboard view. Found and fixed: the player reported "abandoned" after every answer (an effect cleanup), another family's child id reached the play API (now 403), test stacks leaking Postgres clusters. Tests: 84 unit, 60 Playwright journeys on desktop/laptop/tablet/phone. Not on web: purchases, offline play, Apple/Google sign-in; not run on a live Supabase project. Docs: docs/web/.
