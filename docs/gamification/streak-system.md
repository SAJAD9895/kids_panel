# Streak system (learning days in a row)

Phase 12, 2026-11-21. Rewards overview: `reward-system.md`.

## 1. The rule

A **learning day** is a household day on which the child finished at least one activity that earned a star. That is any `star_awards` row; abandoned sessions don't count.

The **streak** counts learning days in a row, with one kindness: **one rest day between learning days doesn't break it**. Rest days aren't counted. Two rest days in a row start a new streak, and the **best (longest) streak is kept forever**.

| learning days (✓) and rest days (·), ending today | current | best |
| --- | --- | --- |
| ✓ ✓ ✓ | 3 | 3 |
| ✓ ✓ · ✓ ✓ | 4 | 4 |
| ✓ ✓ ✓ · · ✓ | 1 | 3 |
| ✓ ✓ · (today, nothing yet) | 2 | 2 (still current, see below) |
| ✓ ✓ · · (today, nothing yet) | 0 | 2 |

**Still current until the end of the next day.** A streak whose last learning day was yesterday or the day before is still shown as current. A child opening the app in the morning never sees it reset before they've had the chance to learn that day.

The same rule is written twice: `private.streak_of(child, today)` in SQL, and `StreakRules.of` in Dart (demo mode and tests). Both are tested with the same cases.

## 2. Fair to children

- **No loss messages.** The app never says a streak was "lost" or "broken".
  - When it starts over, the screen simply shows the new count next to "My best: N days".
  - The card says "Resting for a day is fine. It keeps your days in a row."
- **No pressure.** There are no streak reminders or notifications, no "don't lose your streak" countdowns, and no streak-freeze purchases.
- **Badges reward the longest streak** (3, 7 and 30 days). Once earned, a badge stays.
- **The calendar** shows six weeks:
  - a star on learning days;
  - a plain dot on other days, never a cross or a red mark;
  - today outlined;
  - future days faded.

## 3. Time zones and day boundaries

- **The household's day.** Every day is the household's day: `private.local_date(account, instant)` uses `parent_accounts.timezone` (an IANA name, set at onboarding). It never uses the device's zone or UTC.
- **Which day a session counts for.** The day it **started** (`activity_sessions.local_date`, Phase 9). A game started at 23:58 and finished at 00:03 counts for the evening it started.
- **Clock checks** (Phase 9):
  - session times are corrected by the device's measured clock offset;
  - times more than 5 minutes in the future are refused;
  - times more than 30 days old are refused.

  Changing the device's clock or zone can't create extra days.
- **Weeks** are ISO weeks, **Monday to Sunday** (`date_trunc('week', …)`). A check constraint keeps every weekly `goal_progress` row on a Monday.
- **Daylight saving.** Days are calendar dates (`date`), not 24-hour blocks, so a 23- or 25-hour day is still one day. In Dart, days are UTC calendar dates, so a DST change can't shift them.
- **Tested** (R1 §7): Dubai midnight.
  - 23:57 counts for the previous day; 00:01 for the new day. Both earn the same activity's star, once per day.
  - The same instant played by a London family counts for *their* day, 20:01 the evening before.

## 4. No duplicate streak records

- **One row per child.** `learning_streaks` has one row per child (primary key `child_id`).
- **Recomputed, never incremented.** `apply_rewards` recomputes it from the learning days each time. A day can only be counted once, because the days are a set of distinct `star_awards.local_date`, and `star_awards` itself allows one row per activity per day.
- **Late uploads.** A session synced days later (offline) lands on its own day and the streak is recomputed: R1 §5 fills in a missing day afterwards.
- **The stored best never goes down.** `longest_days = greatest(stored, computed)`. It only looks back 400 days, so an older best streak is kept as stored.
- **The summary recomputes the current streak for today** (`rewards_summary`). So a streak that ended shows 0 on the screen even if the child hasn't played since, without a nightly job.

## 5. Where it shows

| where | what |
| --- | --- |
| K16 "My learning days" | big number "N days in a row", "My best: N days", the gentle line, the 6-week calendar |
| celebration | at 3, 7, 14, 30, 50, 100 days, the day the streak reaches it ("7 learning days!"), plus the badge |
| P18 | "Learning days in a row: N (best M)", the calendar |
