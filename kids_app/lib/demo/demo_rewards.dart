// The badge catalogue (demo mode and supabase/seed.sql §17, generated from this list by
// tool/seed_content_sql.dart) and an in-memory copy of private.apply_rewards for demo mode.
// Badge artwork: content/dev-media/make_dev_media.py (original, drawn in code).
import '../features/learning/domain/catalog.dart';
import '../features/rewards/domain/rewards.dart';

BadgeInfo _b(
  String slug,
  String title,
  String description,
  String howToEarn,
  BadgeRule rule, {
  Map<String, Object?> params = const {},
  int bonus = 0,
  required int sort,
}) => BadgeInfo(
  key: 'badge-$slug',
  title: title,
  description: description,
  howToEarn: howToEarn,
  rule: rule,
  params: params,
  bonusStars: bonus,
  sort: sort,
  art: 'badges/$slug/1/512.webp',
);

/// Every badge, in the order the collection shows them.
final demoBadges = <BadgeInfo>[
  _b(
    'first-game',
    'First game',
    'You finished your very first game.',
    'Finish any game.',
    BadgeRule.firstGame,
    bonus: 1,
    sort: 1,
  ),
  _b(
    'first-island',
    'First island',
    'You finished every step of an island.',
    'Finish all the steps of one island on a learning path.',
    BadgeRule.firstLesson,
    bonus: 2,
    sort: 2,
  ),
  _b(
    'first-course',
    'Course champion',
    'You finished a whole course. Amazing!',
    'Finish every island of a course.',
    BadgeRule.firstCourse,
    bonus: 3,
    sort: 3,
  ),
  _b(
    'goal-1',
    'Goal getter',
    'You reached your goal for the day.',
    'Reach your daily goal once.',
    BadgeRule.dailyGoals,
    params: {'count': 1},
    bonus: 1,
    sort: 10,
  ),
  _b(
    'goal-10',
    'Goal keeper',
    'Ten days of reaching your goal.',
    'Reach your daily goal on 10 different days.',
    BadgeRule.dailyGoals,
    params: {'count': 10},
    bonus: 2,
    sort: 11,
  ),
  _b(
    'week-1',
    'Great week',
    'You learned on lots of days this week.',
    'Reach your weekly goal once.',
    BadgeRule.weeklyGoals,
    params: {'count': 1},
    bonus: 2,
    sort: 12,
  ),
  _b(
    'week-4',
    'Steady learner',
    'Four great weeks of learning, bit by bit.',
    'Reach your weekly goal in 4 different weeks.',
    BadgeRule.weeklyGoals,
    params: {'count': 4},
    bonus: 3,
    sort: 13,
  ),
  _b(
    'streak-3',
    'Three learning days',
    'You learned on three days in a row.',
    'Learn on 3 days in a row. One rest day in between is fine.',
    BadgeRule.streak,
    params: {'days': 3},
    bonus: 1,
    sort: 20,
  ),
  _b(
    'streak-7',
    'Seven learning days',
    'Seven learning days in a row!',
    'Learn on 7 days in a row. One rest day in between is fine.',
    BadgeRule.streak,
    params: {'days': 7},
    bonus: 2,
    sort: 21,
  ),
  _b(
    'streak-30',
    'Thirty learning days',
    'Thirty learning days: learning is your habit!',
    'Learn on 30 days in a row. One rest day in between is fine.',
    BadgeRule.streak,
    params: {'days': 30},
    bonus: 3,
    sort: 22,
  ),
  _b(
    'numbers',
    'Number explorer',
    'You explored lots of number activities.',
    'Finish 5 different number activities.',
    BadgeRule.subjectExplorer,
    params: {'subject': 'numbers', 'count': 5},
    bonus: 2,
    sort: 30,
  ),
  _b(
    'letters',
    'Letter explorer',
    'You explored lots of letter activities.',
    'Finish 4 different letter activities.',
    BadgeRule.subjectExplorer,
    params: {'subject': 'letters', 'count': 4},
    bonus: 2,
    sort: 31,
  ),
  _b(
    'shapes',
    'Shape explorer',
    'You explored lots of shapes and colours.',
    'Finish 4 different shape and colour activities.',
    BadgeRule.subjectExplorer,
    params: {'subject': 'shapes', 'count': 4},
    bonus: 2,
    sort: 32,
  ),
  _b(
    'thinking',
    'Puzzle explorer',
    'You solved lots of thinking puzzles.',
    'Finish 3 different thinking activities.',
    BadgeRule.subjectExplorer,
    params: {'subject': 'thinking', 'count': 3},
    bonus: 2,
    sort: 33,
  ),
  _b(
    'stars-25',
    '25 stars',
    'Stars from 25 finished activities.',
    'Collect 25 activity stars.',
    BadgeRule.stars,
    params: {'count': 25},
    sort: 40,
  ),
  _b(
    'stars-100',
    '100 stars',
    'Stars from 100 finished activities. Wow!',
    'Collect 100 activity stars.',
    BadgeRule.stars100,
    sort: 41,
  ),
];

/// What a finished session tells the ledger about the child's learning.
class RewardFacts {
  const RewardFacts({
    this.lessonsDone = 0,
    this.coursesDone = 0,
    this.lessonJustDone,
    this.courseJustDone,
  });

  /// Lessons / courses with every required step done (after this session).
  final int lessonsDone;
  final int coursesDone;

  /// Set when this session finished the lesson / course its step belongs to.
  final String? lessonJustDone;
  final String? courseJustDone;
}

/// One child's rewards, in memory: the same rules and once-only keys as private.apply_rewards.
class DemoRewardLedger {
  DemoRewardLedger(this.childId);

  final String childId;

  /// (activity, household day) pairs that earned a star: `star_awards`.
  final starAwards = <({String activityId, DateTime day})>{};

  /// reason + refKey → transaction (`unique (child, reason, ref_key)`).
  final _ledger = <String, StarTransaction>{};

  /// badge key → earned at (`child_rewards`).
  final earned = <String, DateTime>{};

  /// `day:<date>` / `week:<monday>` → completed at (`goal_progress.completed_at`).
  final goalsDone = <String, DateTime>{};
  final _goalTargets = <String, int>{};
  var _longest = 0;

  GoalSettings settings = const GoalSettings();

  List<StarTransaction> get transactions =>
      _ledger.values.toList()..sort((a, b) => b.at.compareTo(a.at));
  int get balance => _ledger.values.fold(0, (n, t) => n + t.amount);

  /// Records the star for [activityId] on [day]; false if it already had one that day.
  bool awardStar(String activityId, DateTime day) =>
      starAwards.add((activityId: activityId, day: dayOf(day)));

  bool _pay(
    StarReason reason,
    String ref,
    int amount,
    DateTime day,
    DateTime now, {
    BadgeInfo? badge,
  }) {
    if (amount <= 0) return false;
    final k = '${reason.key}|$ref';
    if (_ledger.containsKey(k)) return false;
    _ledger[k] = StarTransaction(
      amount: amount,
      reason: reason,
      refKey: ref,
      day: dayOf(day),
      at: now,
      badgeKey: badge?.key,
      badgeTitle: badge?.title,
    );
    return true;
  }

  Streak streak(DateTime today) {
    final s = StreakRules.of(starAwards.map((a) => a.day), today);
    return Streak(
      current: s.current,
      longest: s.longest > _longest ? s.longest : _longest,
      lastDay: s.lastDay,
    );
  }

  int _dayCount(DateTime day) =>
      starAwards.where((a) => a.day == dayOf(day)).length;

  /// Activity stars on [day] (what the daily goal counts).
  int starsOn(DateTime day) => _dayCount(day);
  int _weekDays(DateTime weekStart) => {
    for (final a in starAwards)
      if (!a.day.isBefore(weekStart) &&
          a.day.isBefore(weekStart.add(const Duration(days: 7))))
        a.day,
  }.length;

  /// A completed, allowed session's rewards. [starNew] = this session got the activity's star
  /// for the day. Returns only what's new.
  RewardEvents apply({
    required String activityId,
    required DateTime day,
    required DateTime now,
    required DateTime today,
    required bool starNew,
    required Catalog catalog,
    required List<BadgeInfo> badges,
    RewardFacts facts = const RewardFacts(),
    List<RewardRule> rules = defaultRewardRules,
  }) {
    int rule(String k) =>
        rules.where((r) => r.key == k).firstOrNull?.stars ?? 0;
    final d = dayOf(day);
    final wk = weekStartOf(d);
    final paid = <({StarReason reason, int amount})>[];
    void pay(StarReason r, String ref, int amount, {BadgeInfo? badge}) {
      if (_pay(r, ref, amount, d, now, badge: badge)) {
        paid.add((reason: r, amount: amount));
      }
    }

    final before = streak(today).current;
    if (starNew) {
      pay(
        StarReason.activity,
        'activity:$activityId:${dayKey(d)}',
        rule('activity_completed'),
      );
    }
    var lessonDone = false, courseDone = false;
    if (facts.lessonJustDone != null) {
      final n = paid.length;
      pay(
        StarReason.lesson,
        'lesson:${facts.lessonJustDone}',
        rule('lesson_completed'),
      );
      lessonDone = paid.length > n;
    }
    if (facts.courseJustDone != null) {
      final n = paid.length;
      pay(
        StarReason.course,
        'course:${facts.courseJustDone}',
        rule('course_completed'),
      );
      courseDone = paid.length > n;
    }

    var dayDone = false, weekDone = false;
    if (settings.enabled) {
      final dk = 'day:${dayKey(d)}', wkk = 'week:${dayKey(wk)}';
      final dt = _goalTargets[dk] ??= settings.dailyActivities;
      final wt = _goalTargets[wkk] ??= settings.weeklyDays;
      if (!goalsDone.containsKey(dk) && _dayCount(d) >= dt) {
        goalsDone[dk] = now;
        dayDone = true;
        pay(StarReason.dailyGoal, 'day:${dayKey(d)}', rule('daily_goal_met'));
      }
      if (!goalsDone.containsKey(wkk) && _weekDays(wk) >= wt) {
        goalsDone[wkk] = now;
        weekDone = true;
        pay(
          StarReason.weeklyGoal,
          'week:${dayKey(wk)}',
          rule('weekly_goal_met'),
        );
      }
    }

    final s = streak(today);
    if (s.longest > _longest) _longest = s.longest;

    final newBadges =
        <({String key, String title, int bonusStars, String art})>[];
    for (final b in [...badges]..sort((a, b) => a.sort.compareTo(b.sort))) {
      if (earned.containsKey(b.key) || !_met(b, catalog, facts)) continue;
      earned[b.key] = now;
      newBadges.add((
        key: b.key,
        title: b.title,
        bonusStars: b.bonusStars,
        art: b.art,
      ));
      pay(StarReason.badge, 'badge:${b.key}', b.bonusStars, badge: b);
    }

    return RewardEvents(
      childId: childId,
      stars: paid.fold(0, (n, t) => n + t.amount),
      transactions: paid,
      badges: newBadges,
      dailyGoalDone: dayDone,
      weeklyGoalDone: weekDone,
      lessonCompleted: lessonDone,
      courseCompleted: courseDone,
      streak: Streak(current: s.current, longest: s.longest),
      streakGrew: s.current > before,
      balance: balance,
    );
  }

  bool _met(BadgeInfo b, Catalog catalog, RewardFacts facts) {
    final n = b.target;
    switch (b.rule) {
      case BadgeRule.firstGame:
        return starAwards.any(
          (a) => catalog.activity(a.activityId)?.type == ActivityType.game,
        );
      case BadgeRule.firstLesson:
        return facts.lessonsDone >= 1;
      case BadgeRule.firstCourse:
        return facts.coursesDone >= 1;
      case BadgeRule.dailyGoals:
        return goalsDone.keys.where((k) => k.startsWith('day:')).length >= n;
      case BadgeRule.weeklyGoals:
        return goalsDone.keys.where((k) => k.startsWith('week:')).length >= n;
      case BadgeRule.streak:
        return _longest >= n;
      case BadgeRule.subjectExplorer:
        final subject = b.params['subject'];
        return {
              for (final a in starAwards)
                if (catalog
                        .subject(catalog.activity(a.activityId)?.subjectId)
                        ?.key ==
                    subject)
                  a.activityId,
            }.length >=
            n;
      case BadgeRule.stars:
      case BadgeRule.stars100:
        return starAwards.length >= n;
      case null:
        return false;
    }
  }

  /// A parent changed the goals: today's and this week's targets follow (unless reached).
  void setGoals(GoalSettings g, DateTime today) {
    settings = g;
    final dk = 'day:${dayKey(today)}',
        wk = 'week:${dayKey(weekStartOf(today))}';
    if (!goalsDone.containsKey(dk)) _goalTargets[dk] = g.dailyActivities;
    if (!goalsDone.containsKey(wk)) _goalTargets[wk] = g.weeklyDays;
  }

  RewardsSummary summary({
    required DateTime today,
    required List<BadgeInfo> badges,
    int courses = 0,
  }) {
    final t = dayOf(today);
    final wk = weekStartOf(t);
    final dk = 'day:${dayKey(t)}', wkk = 'week:${dayKey(wk)}';
    return RewardsSummary(
      today: t,
      balance: balance,
      streak: streak(t),
      goals: settings,
      day: GoalStatus(
        target: _goalTargets[dk] ?? settings.dailyActivities,
        progress: _dayCount(t),
        completedAt: goalsDone[dk],
      ),
      week: GoalStatus(
        target: _goalTargets[wkk] ?? settings.weeklyDays,
        progress: _weekDays(wk),
        completedAt: goalsDone[wkk],
      ),
      learningDays: {
        for (final a in starAwards)
          if (daysBetween(a.day, t) < 42 && !a.day.isAfter(t)) a.day,
      },
      transactions: transactions.take(50).toList(),
      badges: [
        for (final b in [...badges]..sort((a, b) => a.sort.compareTo(b.sort)))
          b.earnedOn(earned[b.key]),
      ],
      counts: RewardCounts(
        islands: _ledger.values
            .where((x) => x.reason == StarReason.lesson)
            .length,
        courses: courses,
        dailyGoals: goalsDone.keys.where((k) => k.startsWith('day:')).length,
        weeklyGoals: goalsDone.keys.where((k) => k.startsWith('week:')).length,
        learningDays: {for (final a in starAwards) a.day}.length,
      ),
    );
  }
}
