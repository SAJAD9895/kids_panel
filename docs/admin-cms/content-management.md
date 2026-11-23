# Content management

Phase 14, 2026-11-21. These pages are for content editors and content managers. "Content manager" is the `content_publisher` role.

## 1. Publishing workflow

```
draft ──send for review──▶ in_review ──approve──▶ approved ──publish──▶ published ──archive──▶ retired ("Archived")
  ▲                          │  send back (note)     │ send back (note)                         │
  └──────────────────────────┴───────────────────────┘◀────────────── reopen as draft ──────────┘
```

| move | who | rule |
| --- | --- | --- |
| draft → in review | `content.write` | — |
| in review → draft | `content.write` (the editor withdraws it) or `content.publish` (sends it back) | a content manager must say what needs changing (≥ 3 characters, kept in the audit log) |
| in review → approved | `content.publish` | passes **validation** (§2); **four-eyes**: whoever made the last content change can't approve it while the `content.review_required` setting is on (default) |
| approved → published | `content.publish` | validation again; sets `published_at` and `published_by`, and bumps `content_version` for a republish |
| approved → draft | `content.publish` | with a note |
| published → archived | `content.publish` | children stop seeing it; saved progress stays |
| archived → draft | `content.write` | editable again, still hidden |

**Where it's enforced.**
- All of it is in `admin_api.transition()`, in the database. The buttons on the page are only the moves the admin's permissions allow.
- **Approved and published content is locked.** The Phase 6 live-content guard (now including `approved`) refuses changes without `content.publish`. This also covers child rows: game config, questions, answers, media, skills and categories.

**What counts as an edit for four-eyes.** Any change to the item or its game config, from the audit log. Workflow moves don't count.

**Limitation.** Question and answer edits are logged under the question's id, so they don't count as edits for four-eyes.

**Courses** use the same workflow. Subjects have no workflow. **Categories** are enabled (published) or disabled (retired) by a content manager. Badges go draft → active → retired, and activating one needs `content.publish`.

## 2. Validation before approving and publishing (`admin_api.validate`)

Each page shows its problems. An empty list means "All publishing checks pass".

| content | checks |
| --- | --- |
| every activity | English title; a subject |
| video, song, audio story, illustrated story | a thumbnail (cover) |
| game | the config has at least one item. The **game builder** also checks every item against the engine's JSON Schema before it saves (`game-builder.md`) |
| quiz | at least one question; every question has a correct answer |
| video | a ready `video_main` file |
| song, audio story | a ready `audio_main` file |
| illustrated story | at least one story page |
| any | every attached file is `ready` |
| course | English title; a subject; at least one lesson with an activity; every lesson has an activity; **every activity in it is published** |

## 3. Pages

| page | path | does |
| --- | --- | --- |
| Review queue | `/content/review` | everything in review and approved, oldest first, with links |
| Activities and games | `/content/activities` | search (title, slug, keywords), filter by kind and status, pagination (20) |
| New activity | `/content/activities/new` | creates a draft. A game also gets its `games` row on the latest `learning_engine` template, with `{items: []}` |
| Activity | `/content/activities/:id` | workflow; details; game builder (games), questions (quizzes), media and pages (media kinds); history (audit); delete a draft |
| Courses | `/content/courses`, `/new`, `/:id` | details (title, description, subject, category, age range = stage, thumbnail, objectives, difficulty, order, Plus); modules (add, rename, reorder, remove); lessons (add, reorder) |
| Lesson | `/content/courses/:id/lessons/:lessonId` | title, description, objectives, grown-up instructions, estimated minutes, island picture, **prerequisite lessons** (same course); activities (steps: add from the 100 most recent activities, required or optional, reorder, remove); media come from each activity |
| Subjects and categories | `/content/taxonomy` | subjects (key, name, order); categories with **sub-categories** (parent), icon (image asset), order, enable or disable; delete only when unused |
| Media library | `/media` | `media-management.md` |
| Rewards | `/rewards` | badge definitions (rule, threshold, art, bonus stars, order, status) and reward rules (stars per event, on or off). Daily and weekly goal **defaults** are in System settings |

**Fields from the brief and where they live.**
- **Age range.** An activity has `age_min_months` and `age_max_months` (enforced by `launch`). A course has a **stage** (preschool, kindergarten or early school), the existing age band.
- **Course ordering.** `courses.sort`. Lesson ordering is by position, using swap buttons.
- **Points and reward rules** for games are the star rules: 1 star per activity per day, plus goal and badge bonuses. They are configured in Rewards. The game builder states the rule; there are no per-game points (see `game-builder.md` §5).

## 4. States and feedback (every page)

| state | how it's shown |
| --- | --- |
| loading | server-rendered pages; buttons show "Saving…", "Checking…", "Uploading…" and are disabled while busy |
| empty | an `EmptyState` with a next step ("No activities match", "No modules yet…") |
| error | the database error as a sentence next to the form (`errors.ts friendly()`); field errors under fields. **Nothing typed is lost** (values come back) |
| silent RLS refusal | a write that changed no row (RLS hides it) is an error, "You don't have permission for this, or it no longer exists", never a fake success (`mustOne`) |
| confirmation | workflow moves, deletes, suspensions, star grants, role changes and archive all open a dialog (`ConfirmAction`); some need a written reason |
| no permission | the menu shows only permitted sections; a page you can't use sends you to `/no-access?reason=permission` |

## 5. Audit

Every change to content is in `audit_logs`: who, when, and before and after values. It's written by the existing triggers on activities, games, courses, lesson steps, rewards, media, collections and learning paths, and by `admin_note` for workflow moves (with the note).

**Where you see it.**
- Each activity and course page shows its history.
- The dashboard shows recent admin activity.
- Settings → Audit log shows everything (`audit.read`).
