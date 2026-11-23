# Parental controls

Phase 13, 2026-11-22. Every control is per child, saved through an Edge Function that checks the household, and enforced on the server where it matters.

| brief | where | server | status |
| --- | --- | --- | --- |
| add and edit child profiles | P02: Manage children → Add a child / a child | `POST /children`, `PATCH /children/:id` (Phase 7) | done (plan limit: Basic 1) |
| change child avatars | P02 → a child → buddy | `PATCH /children/:id` | done |
| configure daily learning goals | P18 Rewards and goals | `PUT /children/:id/goals` (Phase 12) | done (daily 1–10, weekly 1–7, or off) |
| age-appropriate content | automatic, from the birth month and year (P02); P03 says so | `private.launch` refuses content outside the child's age window (Phase 11); feeds filter by age | done. A **learning-stage override** exists in the schema but the app doesn't use it to filter, so it isn't offered (it would be a control that does nothing) |
| section access | P03: Learn, Watch, Listen, Together (games always on) | `PUT /children/:id/screen-time` | done (Learn and Together switches **added this phase**) |
| video and audio access | P03: Videos on / off, Songs and stories on / off, categories | `private.launch` → `SECTION_DISABLED`, `CATEGORY_BLOCKED` | done (Phase 11) |
| screen-time limits | P03: daily limit (none, 15–180 min), which sections count | heartbeats → `SCREEN_TIME_OVER` | done (Phase 11) |
| notification preferences | P11 settings: a switch per type | `PUT /account/notification-preferences` | in-app done; email and push not connected (`dashboard.md` §4) |
| view consent settings | P12: each consent, its version, when it was given or withdrawn | Data API (RLS) | done (view only; withdrawing a consent isn't built) |
| child data export | P12: "<child>'s data" or "The whole account" | `POST /account/export`, `GET /account/exports/:id/url` | done |
| child data deletion | P02 → a child → Delete (immediate) | `DELETE /children/:id` | done (Phase 7) |
| account deletion | P12: delete in 7 days, keep my account (cancel) | `POST /account/deletion`, `DELETE /account/deletion/:id` | done (route written this phase; the SQL is from Phase 5) |

## Protection

- **Children can't get in.** The parental gate guards every `/parents/...` route, and the gate locks again when the parent goes back to the kid zone.
- **Recent sign-in.** Sensitive operations need the last sign-in to be within 10 minutes; otherwise the server answers `REAUTH_REQUIRED` and the app asks for an email code (P17):
  - deleting a child;
  - exporting data;
  - scheduling account deletion.
- **Owner only.** Account deletion is for the account owner (`schedule_account_deletion` refuses a co-parent).

## Exports

- **What's in it.** A JSON document (`kids-learning-export/1`) built by `private.export_payload`:
  - **child:** profile (nickname, birth month, buddy, stage, locale, analytics id), every session with result, stars, badges, goals and progress, streak, skills, courses, favourites, screen-time rules;
  - **account:** settings, the parents' emails, consents, subscriptions, notification preferences, and every child.
- **A child's export holds only that child** (tested).
- **Storage.** It's uploaded to the private `exports` bucket, at `<account>/<request>.json`, and kept 7 days. Download links are signed and last **1 hour**; "Download" makes a new one.
- **Limits.** 5 exports a day per account (`RATE_LIMITED`). An `export_ready` notice is sent.
- **Demo mode** has no Storage. It builds the same document and says "no file is stored".
- **Still to do.** The 7-day clean-up of old files (a retention job) isn't written. Expired files stay in the bucket until it is (`subscriptions.md` lists other jobs).

## Multiple children

- **Separate everything.** Each child has their own goals, controls, reports, exports and rewards.
- **Switching children.** The dashboard has a card each; the report has a child picker.
- **Isolation.** The household check runs in every SQL function, and RLS applies on every read. It's tested for another family's child in D1, R1 and T2, and in the demo unit tests.
