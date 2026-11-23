# Database schema

**Status: implemented as migrations, verified locally, not yet applied to any Supabase project.**
Source design: `docs/architecture/05-database.md` (ER diagram, entity mapping) and `docs/architecture/database/schema-draft.sql` (reviewed draft). The migrations keep that DDL verbatim. Every deliberate change is marked `-- IMPL:` in the SQL and listed in §5.

## 1. Migrations

`supabase/migrations/`, applied in filename order by `supabase db push` / `supabase db reset` (or `scripts/db-verify.sh` locally).

| file | contents | tables |
| --- | --- | --- |
| `20261118000100_foundation.sql` | `extensions` schema with `pgcrypto`, `pg_trgm`; `private` and `analytics` schemas; `set_updated_at()` | 0 |
| `20261118000200_admin_rbac.sql` | `admin_users`, `admin_roles`, `admin_permissions`, `admin_role_permissions`, `admin_user_roles` + the 10 permissions and 6 roles (reference data) | 5 |
| `20261118000300_family.sql` | `parent_accounts`, `parent_profiles`, `parental_consents`, `media_assets`, `avatars`, `child_profiles`, `devices` | 7 |
| `20261118000400_catalog.sql` | categories, subjects, skills, game templates, activities (+ categories, skills, media), games, questions, answers, courses, modules, lessons (+ island prize), steps, learning paths, collections, reward sets, rewards | 21 |
| `20261118000500_play_progress.sql` | sessions, results, question responses, stars, gift claims, child rewards, scene placements, enrolments, step completions, skill mastery, daily progress, child paths, certificates, favourites, free allocations, screen-time rules and usage, downloads | 18 |
| `20261118000600_billing.sql` | plans, subscriptions, payments, entitlements, webhook events, promo codes, redemptions | 7 |
| `20261118000700_notifications_privacy_audit.sql` | notifications, preferences, export and deletion requests, audit log, feature flags | 6 |
| `20261118000800_analytics.sql` | `analytics.events` (monthly partitions + default), `private.ensure_event_partitions()` | (not public) |
| `20261118000900_helpers_triggers.sql` | authorisation helpers, `updated_at` triggers, publish guard, audit triggers, append-only audit log | 0 |
| `20261118001000_rls.sql` | RLS on every public table, 138 policies, grants hardening | 0 |
| `20261118001100_storage.sql` | 5 Storage buckets with size and type limits; the `admin-staging` upload policy | 0 |
| `20261118001200_family_operations.sql` | onboarding, add/delete child, account deletion (schedule, cancel, execute) as service-only SQL functions | 0 |
| `20261118001300_security_hardening.sql` | fixes from the Phase 6 verification: `local_date` no longer client-executable (F1); **live-content guard** on 20 catalogue tables, so changing published content or its child rows needs `content.publish` (F2) | 0 |
| `20261123000100_admin_cms.sql` | Phase 14 admin CMS: `approved` status + locking; course and lesson fields (objectives, difficulty, category, instructions, duration, prerequisites); `app_config` (settings) + `goal_default`; account suspension in `apply_session` / `launch`; `admin_adjustment` stars; schema `admin_api` (14 functions); `admin_register_media`, `admin_can`; grants for `app_config`, `reward_rules`; audit trigger keys `games` by activity (§5 #22–#29) | 1 |
| `20261122000100_parent_dashboard.sql` | Phase 13: skill mastery model (`update_mastery`), notifications (`notify`, preferences, read, weekly job, subscription and deletion triggers; types + `dedupe_key`), exports (`data_export_requests.child_id`, payload, files), `progress_report`, `family_overview`; `apply_session_core` score fix (§5 #18–#21) | 0 |
| `20261121000100_rewards.sql` | Phase 12: `reward_rules`, `star_transactions`, `learning_goals`, `goal_progress`, `learning_streaks`, view `child_star_totals`, badge columns on `rewards` (§5 #13–#17); `private.apply_rewards`, `streak_of`, `badge_met`, `rewards_summary`, `set_learning_goals`; `apply_session` wraps `apply_session_core`; backfill | 0 |
| `20261120000100_media.sql` | Phase 11: `screen_time_rules.blocked_category_ids`, `activity_media.text` (§5 #11, #12); `private.launch`, `add_screen_time`, `set_screen_time_rules` (+ helpers) | 0 |
| `20261119000100_engine_runtime.sql` | Phase 10: `game_templates.runtime` also allows `'flutter'` (the in-app learning engine); see §5 #10 | 0 |
| `20261118001500_apply_session.sql` | `private.apply_session` for `POST /play/sync` (Phase 9): idempotent session reports, household-day star, daily roll-up, step completion, enrolment / course progress, quiz responses | 0 |
| `20261118001400_child_edit.sql` | `private.update_child` for `PATCH /children/:id` (Phase 7): partial edit, household members only, same validation as add | 0 |

**70 public tables** (Phase 14 added `app_config`; Phase 12 added 5), all with RLS, 148 policies, 127 foreign keys (every one indexed, each with an explicit `ON DELETE`), 62 functions in `private` and 14 in `admin_api` (Phase 14 added require, admin_note, admin_can, admin_register_media, goal_default, not_suspended, super_admins_left, launch_core and two trigger functions; Phase 13 added update_mastery, notify, notification_types, set_notification_preferences, mark_notifications_read, account_of_user, request_export, export_child, export_payload, finish_export, export_file, progress_report, family_overview, queue_due_notifications and two trigger functions; earlier: Phase 11 added launch, add_screen_time, set_screen_time_rules, section_of, household_of_child, screen_time_left; Phase 12 added apply_rewards, streak_of, badge_met, rewards_summary, set_learning_goals and the apply_session wrapper over apply_session_core).

## 2. Brief entities → tables

| brief | tables |
| --- | --- |
| Parent accounts | `parent_accounts` (the household: timezone, country, locales, status) |
| Parent profiles | `parent_profiles` (one per signed-in adult, role `owner` / `co_parent`) |
| Child profiles | `child_profiles` (nickname ≤ 20, avatar, **birth year + month only**, stage, `analytics_id`) |
| Subjects and categories | `subjects`, `categories` (tree), `activity_categories` |
| Skills and learning paths | `skills` (5 groups), `activity_skills`, `learning_paths`, `learning_path_courses`, `child_learning_paths` |
| Courses and lessons | `courses`, `course_modules`, `lessons` ("islands", optional `prize_reward_id`), `lesson_steps` |
| Activities and games | `activities` (supertype), `games` (template + config + pack), `game_templates` (E1–E12), `activity_media` |
| Questions and answers | `questions`, `answers`, `question_responses` |
| Media assets | `media_assets` (bucket, path, kind, sha256, access), `avatars` |
| Learning sessions | `activity_sessions` (id generated on the device → idempotent replays) |
| Activity results | `activity_results` |
| Learning progress | `skill_mastery`, `daily_progress`, `course_enrollments`, `lesson_step_completions`, `certificates` |
| Rewards and achievements | `reward_sets`, `rewards` (sticker, scene, badge, avatar item), `star_awards`, `gift_claims`, `child_rewards`, `scene_placements` |
| Subscriptions and payments | `subscription_plans`, `subscriptions`, `payments`, `entitlements`, `billing_webhook_events`, `promo_codes`, `promo_redemptions` |
| Notifications | `notifications`, `notification_preferences` (parents only) |
| Also (security brief) | `parental_consents`, `data_export_requests`, `deletion_requests`, `audit_logs`, `admin_*`, `feature_flags`, `devices`, `content_downloads`, `screen_time_*`, `analytics.events` |

The ER diagram is in `docs/architecture/05-database.md` §5.2. It is unchanged except for the design-review additions (`lessons.prize_reward_id`, the section names).

## 3. Conventions

- `uuid` primary keys (`gen_random_uuid()`); natural composite keys for tally / join tables (`star_awards (child_id, local_date, activity_id)` *is* the one-star-per-day rule).
- `created_at` / `updated_at` (`timestamptz`, UTC) on every mutable table; `updated_at` is set by trigger.
- The household day (`local_date`) is computed **server-side** from `parent_accounts.timezone`, never from a device clock.
- Status fields are `text` + `CHECK` (easier to evolve than enums).
- Money: `amount_minor bigint` + ISO 4217 currency. Localised text: `jsonb {"en": …, "es": …}`.
- Every foreign key has an explicit `ON DELETE`. Child data cascades from `child_profiles`; family data cascades from `parent_accounts`. Content is retired, never hard-deleted once published (`on delete restrict` from history tables).
- Children's personal data is minimised **in the schema**: month-precision birth date (DB check), 20-character nickname, no free text, no photos, no contact details.

## 4. Verification (2026-11-18; extended in Phase 6, see `backend-test-report.md`)

`scripts/db-verify.sh` builds a throwaway Postgres 17 with a stand-in for Supabase's `auth` and `storage` schemas and its default grants (`supabase/tests/local/00_supabase_stub.sql`), applies all migrations, the seed, and `supabase/tests/01_rls_and_operations.sql`:

```
T1 ok: 64 tables, RLS + policies everywhere, writes and privileged functions locked
T2 ok: Bob sees only his own rows in 29 family/child tables
T3 ok: parents read their own data; every direct write is refused
T4 ok: anon sees the published catalogue and nothing else
T5 ok: MFA required, editor ≠ publisher, support read-only, no self-grant
T6 ok: storage writes limited to admin-staging, own folder, content.write
T7 ok: onboarding (validated, idempotent), plan limit, isolation, child + account deletion
T8 ok: audit redacts child values and is append-only
✓ all migrations, seed and tests passed
```

The tests found and fixed two bugs in the new functions while they were being written: an empty consent list passed the required-consents check (a NULL comparison), and child deletion violated the deletion-request constraint (it now records the request after the delete).

**Limit of this verification:** the stand-in is not the real Supabase platform. The first `supabase db reset` (local CLI) or a preview branch must re-run the same tests against real Supabase (`setup-guide.md` §3).

## 5. Changes from the reviewed draft (and why)

| # | change | where | reason |
| --- | --- | --- | --- |
| 1 | extensions created `with schema extensions`; `gin_trgm_ops` schema-qualified | foundation, catalog | Supabase installs extensions in `extensions`, not `public` |
| 2 | analytics partitions created by `private.ensure_event_partitions()` + a `DEFAULT` partition, instead of two hard-coded months | analytics | a later first deploy would otherwise have no current partition; a default partition means an insert is never lost |
| 3 | `user_id = (select auth.uid())` in the four self-read policies | rls | evaluated once per query instead of once per row (Supabase performance advisor) |
| 4 | client **write privileges revoked** on all family, child and billing tables (kept only on tables admins edit); default privileges changed so new tables start read-only for clients | rls | defence in depth: a missing or wrong policy can't open a write path. Supabase grants ALL to `anon`/`authenticated` by default |
| 5 | `deletion_requests.child_id` `ON DELETE CASCADE` → `SET NULL`; constraint allows a completed child request without a child | notifications_privacy_audit | the draft deleted the record of a child deletion together with the child; §14.6 requires the record to be kept |
| 6 | audit rows for `parent_accounts` get `account_id` = the row's id | helpers_triggers | so a family's full history, including its own deletion, is found by account |
| 7 | Storage buckets and the `admin-staging` policy | storage (new) | documented in `11-media-storage.md` but had no DDL |
| 8 | family operations as `private` SQL functions, `EXECUTE` for `service_role` only | family_operations (new) | `04-backend` §4.3: multi-row writes in one SQL function |
| 11 | `screen_time_rules.blocked_category_ids uuid[]` (Phase 11) | play_progress | parents switch media categories off (brief); one column on the existing per-child rules row, same RLS and write path; `'{}'` = nothing blocked |
| 12 | `activity_media.text jsonb` (Phase 11) | catalog | a story page's words, next to its picture; localized; null for other roles |
| 13 | `reward_rules` (Phase 12) | rewards | the brief's "configurable reward rules"; amounts were hard-coded. Admin-edited (`content.write`), read by all |
| 14 | `star_transactions` + view `child_star_totals` (Phase 12) | rewards | the star ledger the brief asks for (transaction history, no duplicates). `star_awards` stays the one-per-activity-per-day rule; the ledger records it and the bonuses, `unique (child_id, reason, ref_key)` |
| 15 | `learning_goals`, `goal_progress` (Phase 12) | rewards | parent-configurable daily / weekly goals; the old daily goal was a constant (3) in the app. Progress per period, `completed_at` once |
| 16 | `learning_streaks` (Phase 12) | rewards | current and best learning-days streak, one row per child, recomputed from `star_awards` (no daily rows to duplicate) |
| 17 | `rewards.description, how_to_earn, rule_params, bonus_stars, sort` + `badge_rule_known` (Phase 12) | catalog | badge details the brief asks for (descriptions, unlock conditions) on the existing catalogue table instead of a new achievements table |
| 18 | `skill_mastery` now written by `private.update_mastery` (Phase 13) | play_progress | the table existed but nothing computed it; the 09 §9.3 model is applied after each completed session so skill analytics are real |
| 19 | `notifications`: types `goal_reached`, `subscription_changed`; column `dedupe_key` + unique `(user_id, dedupe_key)` (Phase 13) | notifications | the brief's goal and subscription notices; jobs and triggers can run again without sending twice |
| 20 | `data_export_requests.child_id` (Phase 13) | privacy | a parent can export one child's data (null = whole account) |
| 21 | `exports` bucket also accepts `application/json`; `apply_session_core` keeps a missing score null (Phase 13) | storage, play | exports are JSON documents; unscored sessions were stored as 0 (a Phase 9 bug that would skew averages) |
| 22 | `activities.status` / `courses.status` gain `approved`; `is_live` treats approved as live (Phase 14) | catalog | the brief's Draft → In review → Approved → Published → Archived ("Archived" = existing `retired`); approved content is locked like published, so what was reviewed is what gets published |
| 23 | `courses.category_id, difficulty, objectives`; `lessons.description, objectives, instructions, estimated_minutes, prerequisite_lesson_ids` + trigger (same course, not itself) (Phase 14) | catalog | the brief's course and lesson fields; prerequisites are an id array on the lesson (≤ 10) rather than a join table: small, ordered, and read with the lesson. The app enforces them |
| 24 | `app_config` (key, value jsonb, description) with a validation trigger, admin-only RLS, audit (Phase 14) | settings | content, media and goal settings an admin changes; the goal defaults were constants in Phase 12 functions (now `private.goal_default`) |
| 25 | `star_transactions.reason` gains `admin_adjustment` (Phase 14) | rewards | support can add stars with a reason through `admin_api.grant_stars` (bounded, idempotent, audited); balances are never edited |
| 26 | `apply_session` and `launch` refuse a suspended household (`ACCOUNT_SUSPENDED`) (Phase 14) | play | the brief's account restrictions; `parent_accounts.status` existed but nothing enforced it |
| 27 | schema `admin_api`, exposed to signed-in users only (Phase 14) | admin | the admin app's privileged reads and actions run as security-definer functions that check the permission first, so the app needs no service key. Not in `public` (schema audit A7) |
| 28 | write grants on `app_config` and `reward_rules` to `authenticated` (Phase 14) | rls | admins edit them with their own JWT; RLS decides. `reward_rules` had policies but no grant since Phase 12 (a bug) |
| 29 | the audit trigger keys a row by `activity_id` when it has no `id` (Phase 14) | helpers_triggers | `games` rows were logged without an entity, so a game's edits were missing from its activity's history and from the four-eyes check |
| 10 | `game_templates.runtime` gains `'flutter'` (Phase 10) | catalog | the learning engine plays games with Flutter widgets, not Flame (`docs/games/game-engine-integration.md` §2); recording them as `flame` would be false. The check is only widened, so no data changes |
| 9 | Edge Functions call those functions over the **database connection** (`SUPABASE_DB_URL`, Supavisor transaction mode), not PostgREST RPC | `api-design.md` §3 | `04-backend` said "PostgREST/RPC", but `private` is deliberately not exposed through the Data API. Exposing it just for RPC would widen the attack surface |

No table, column or relationship from the reviewed design was removed or renamed.

## 6. Rules for the next migration

1. New file `supabase/migrations/<UTC timestamp>_<name>.sql`; never edit an applied migration.
2. Every new public table: `enable row level security`, at least one policy, an `updated_at` trigger (`create trigger set_updated_at before update on … execute function private.set_updated_at()`), indexes on every FK. Add it to the audit trigger list if it holds family, billing or content data.
3. Client grants are read-only by default (change 4). If admins must edit the table with their JWT, `grant insert, update, delete … to authenticated` explicitly **and** add `has_permission('content.write')` policies.
4. Privileged functions: `security definer`, `set search_path = ''`, `revoke all … from public, anon, authenticated`, `grant execute … to service_role`.
5. Run `scripts/db-verify.sh`. T1 fails automatically for a table without RLS or a policy, or with client write grants.
