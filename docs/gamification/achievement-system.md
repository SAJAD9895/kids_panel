# Achievement system (badges)

Phase 12, 2026-11-21. Badges mark milestones in a child's learning. They're never bought, never lost, and never compared between children. Stars and goals: `reward-system.md`.

## 1. Where badges live

- **Catalogue.** `rewards` rows with `type = 'badge'`: the existing Phase 5 table. Phase 12 adds `description`, `how_to_earn`, `rule_params`, `bonus_stars` and `sort`. `unlock_rule` existed and must be a known rule (constraint `badge_rule_known`).
- **Earned.** `child_rewards (child_id, reward_id)`, source `badge_rule`. The **primary key makes each badge once-only**. `first_earned_at` is the **earned date** shown to children and parents.
- **Checked by.** `private.apply_rewards`, after every completed, allowed session. It checks the active badges the child doesn't have yet, in `sort` order, against `private.badge_met(child, rule, params)`.
  - **A new badge** is inserted, its bonus stars go into the ledger (`ref_key = badge:<id>`, once), and it is returned in the sync's `rewards.badges` for the celebration.
- **Source list.** The badges are defined once, in `kids_app/lib/demo/demo_rewards.dart`. They're used:
  - by demo mode;
  - to generate seed §17 (`dart run tool/seed_content_sql.dart --write`).

  A unit test checks the seed matches the list.

## 2. The badges (16)

| badge | rule | condition | bonus | the brief's item |
| --- | --- | --- | --- | --- |
| First game | `first_game` | finish any game (an activity star on a `game`) | 1 | first completed game |
| First island | `first_lesson` | every required step of one island (lesson) done | 2 | first completed lesson |
| Course champion | `first_course` | a course completed | 3 | course completion |
| Goal getter | `daily_goals` `{count: 1}` | reach the daily goal once | 1 | daily learning goal achieved |
| Goal keeper | `daily_goals` `{count: 10}` | daily goal on 10 days | 2 | daily learning goal achieved |
| Great week | `weekly_goals` `{count: 1}` | reach the weekly goal once | 2 | consistent learning progress |
| Steady learner | `weekly_goals` `{count: 4}` | weekly goal in 4 weeks | 3 | consistent learning progress |
| Three learning days | `streak` `{days: 3}` | longest streak ≥ 3 | 1 | streak milestones |
| Seven learning days | `streak` `{days: 7}` | longest streak ≥ 7 | 2 | streak milestones |
| Thirty learning days | `streak` `{days: 30}` | longest streak ≥ 30 | 3 | streak milestones |
| Number explorer | `subject_explorer` `{subject: numbers, count: 5}` | 5 different number activities finished | 2 | subject mastery (see §4) |
| Letter explorer | `subject_explorer` `{letters, 4}` | 4 different letter activities | 2 | subject mastery |
| Shape explorer | `subject_explorer` `{shapes, 4}` | 4 different shape and colour activities | 2 | subject mastery |
| Puzzle explorer | `subject_explorer` `{thinking, 3}` | 3 different thinking activities | 2 | subject mastery |
| 25 stars | `stars` `{count: 25}` | 25 activity stars | 0 | — |
| 100 stars | `stars_100` | 100 activity stars (the Phase 5 badge, kept) | 0 | — |

How the counts work:
- **Streak badges** use the **longest** streak. A badge is earned when the streak is reached, and resting afterwards changes nothing.
- **Star badges** count activity stars (one per different activity per day), not bonus stars, so badges don't feed themselves.
- **Explorer counts** were set to what the development catalogue holds. It has 7 number, 5 letter, 5 shape and 4 thinking activities, so every explorer badge can be earned with today's content.

## 3. Artwork

Every badge has original artwork, generated in code by `content/dev-media/make_dev_media.py --only badges`:
- a scalloped rosette in the badge's colour;
- a white disc with an emblem (a dice, an island, a trophy, targets, a calendar, a sprout, stepping stones, a rainbow, a tree, "123", "Abc", shapes, a light bulb, stars);
- ribbon tails;
- a transparent background.

| | |
| --- | --- |
| files | WebP at 256 and 512 px, under `public-assets/badges/<slug>/1/`: public, versioned, CDN-cached |
| registered in | `media_assets` (seed §16) |
| in the app | `BadgeArt` shows the 256 or 512 file (whichever is sharp enough), decoded at the size shown; a medal icon stands in while loading or offline |
| not earned yet | the **same picture in grey**, faded; never hidden, so children see what they can look forward to |
| screenshots | `screens/G02-badge-collection.png`, `screens/G03-celebration-badge.png` |

During review, one first draft emblem (a play button on a red rounded rectangle) was replaced by a dice, because it looked too much like a well-known video service's logo.

## 4. "Subject mastery": what is honest today

The brief asks for subject-mastery achievements. The schema has `skill_mastery` (0–1 per skill), but **nothing computes it yet**:
- `apply_session` doesn't update it;
- the mastery model in `docs/architecture/09-learning-progress-engine.md` §9.3 isn't built.

Calling a badge "mastery" without measuring mastery would be misleading. So these badges are **explorer** badges: "finished N different activities in this subject". When the mastery model is built, a `subject_mastery` rule can be added (for example, "every skill in Numbers is Confident") with no schema change.

## 5. Where children and parents see them

- **K16 My rewards → My badges (n of 16).**
  - Earned badges come first.
  - Tapping a badge opens a sheet:
    - earned: the picture, what it's for, "Earned 18 Nov 2026" and its bonus stars;
    - not earned: "Not yet. <how to earn>".
  - Screen readers hear "First game, earned 18 Nov 2026" or "Seven learning days, not yet. Learn on 7 days in a row…".
- **The celebration card** shows the newly earned badge's picture with "New badge: <title>!".
- **P18 (parents).**
  - "Badges earned (n of 16)", each with its date and description.
  - "Still to earn", each with its condition.
  - The star history shows each bonus as "Badge: <title>".
- **Elsewhere.** The Me screen's badge chips and Home's treasures count read `child_rewards`.

## 6. Adding or changing a badge

1. **Artwork.** Add the slug to `BADGES` in `make_dev_media.py` and run `--only badges`. Then add its folder to `kids_app/pubspec.yaml`; a unit test fails if a folder is missing.
2. **Definition.** Add the badge to `demoBadges` (key `badge-<slug>`, rule, params, bonus, sort, words).
3. **Seed.** `dart run tool/seed_content_sql.dart --write` regenerates §17, which upserts by key.
4. **Upload.** `scripts/upload-dev-media.sh` uploads the art.
5. **A new kind of rule** also needs:
   - a branch in `private.badge_met`;
   - the value in the `badge_rule_known` constraint;
   - the `BadgeRule` enum and the demo ledger's `_met`.

**Retiring a badge** (`status = 'retired'`) stops new awards. Children who earned it keep it, and the summary still returns it to them.
