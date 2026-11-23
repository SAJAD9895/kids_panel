# Reports and learning analytics

Phase 13, 2026-11-22. P04 (`/parents/children/:id/report`), served by `GET /progress/report?childId&period&date` → `private.progress_report`. The dashboard numbers come from `private.family_overview`.

**Rule for every number.** It is a count, sum or average of recorded rows. Nothing is estimated, extrapolated or filled in:
- if a number can't be known, it shows "—";
- a period with no activity says so;
- strengths and weaknesses are named only with enough evidence.

## 1. Periods

| period | window (household days, `parent_accounts.timezone`) | compared with |
| --- | --- | --- |
| day | that day | the day before |
| week | Monday–Sunday containing the date | the week before |
| month | the calendar month containing the date | the month before |

- **Days.** Sessions count on the household day they **started** (`activity_sessions.local_date`).
- **Unfinished periods.** If the period contains today, the report says "isn't over yet: numbers can still grow".
- **Goal rates** only count the days of the period that have already happened (`daysElapsed`).

## 2. Definitions

| number | definition |
| --- | --- |
| **learning time** | sum of `ended_at − started_at` of completed and stopped sessions (the 4-hour cap from `apply_session` applies). This is time **in activities**, including pauses inside one; time on menus isn't counted. It's the same figure as `daily_progress.seconds_played`, which the dashboard uses |
| activities finished | completed sessions |
| different activities | distinct activities completed |
| learning days | days with at least one activity star (as for streaks) |
| stars earned | sum of the star ledger in the period, bonuses included |
| lessons completed (in period) | lessons whose last required step was completed in the period; also shown: lesson steps completed, and lessons completed in all |
| lessons completed (dashboard) | lessons with every required step done, all time |
| games completed | completed sessions of activities of type `game` |
| completion by kind | per activity type: sessions started (completed + stopped + still open) vs completed |
| by subject | per subject: completed, time, number of **scored** completed sessions, average score of those |
| game performance | per game: plays, completed, average and best score, **right answers** (sum correct ÷ sum answered, for games that count answers), levels played |
| quiz scores | per quiz: attempts, last, best, average score; **right first time** (first attempts of questions answered correctly, from `question_responses`) |
| skill mastery | `skill_mastery` (see §3), all time, skills with evidence only; whether each was practised in this period |
| goal completion | daily goals reached ÷ days elapsed in the period; weekly goals reached per week |
| weekly consistency | learning days in each of the 8 weeks ending with the period |
| recent activity | the period's last 50 sessions: title, kind, finished or stopped, time, score, level |

**Scores.** Only activities that report a score are scored: games and quizzes. Videos, songs and stories are **not scored**. Since this phase they are stored as no score (see the bug in `dashboard.md` §5), so they never pull averages down.

## 3. Skill mastery

Until this phase **nothing computed `skill_mastery`**, so a mastery chart would have had no honest data. `private.update_mastery` now applies the documented model (09-learning-progress-engine.md §9.3) after each completed, allowed session:

```
e = correct/total if counted, else score/100 if scored, else 0.7 (finished, unscored)
α = max(0.1, 1/(n+2)), halved if the same activity was already finished that day
mastery ← mastery + α · weight · (e − mastery)
```

- **Parents see bands, not percentages:**
  - Getting started: under 0.4;
  - Practising: 0.4 to 0.75;
  - Confident: over 0.75.
- **No backdating.** Existing sessions are not replayed into mastery: the seed's values stay as they are, and new sessions update them.
- **Limitation.** Question-level skills (`questions.skill_id`) aren't used yet. Every activity skill gets the session's evidence.

## 4. Charts (P04)

Every chart card has a one-line summary for screen readers and **"Show as a table"** with the exact numbers.

| chart | form | data |
| --- | --- | --- |
| learning time | a bar per day (today darker) | `daily` |
| activity completion | a bar per kind (finished ÷ started) | `byType` |
| progress by subject | a bar per subject (finished), average score as text | `bySubject` |
| skill mastery | a bar per skill (the estimate), band as text | `skills` |
| weekly learning consistency | a bar per week, out of 7 days | `consistency` |
| goal completion | daily rate; weekly reached ÷ weeks | `goals` |

The charts are drawn with design-token colours (`uiChart1`–`uiChart4`, `uiSuccess`). Tables cover games, quizzes and lessons.

## 5. Strengths and things to practise

`ReportInsights.of(report)` applies a fixed rule. The screen shows the rule's wording above the list.

| | subject (this period) | skill (all time) |
| --- | --- | --- |
| evidence needed | ≥ 3 scored completed activities | ≥ 3 updates |
| strength | average ≥ 80 % | Confident |
| to practise | average < 60 % | Getting started |

If nothing reaches the evidence bar, the screen says "Not enough scored activity yet to say", rather than guessing.

## 6. What isn't measured

- **Time outside activities** (browsing menus).
- **Learning offline** before it syncs: it appears once uploaded, on the day it happened.
- **Course pre/post scores** (P04 spec): not built.
- **The 7/14/30/90-day window picker** (P04 spec): replaced by day, week and month, as the brief asked.
- **Comparisons with other children.** Deliberately none, anywhere.
