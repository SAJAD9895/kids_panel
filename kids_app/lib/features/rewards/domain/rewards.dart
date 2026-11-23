/// Rewards: stars (a ledger), badges, daily and weekly goals, the learning streak. Pure Dart.
///
/// The server decides every reward (private.apply_rewards, docs/gamification/). The app only
/// shows what it's told: the summary (GET /children/:id/rewards) and the new rewards a finished
/// session earned (POST /play/sync → `rewards`), which drive the celebrations.
///
/// Kept gentle on purpose: stars are never taken away or spent, a rest day doesn't break a
/// streak, goals are small and set by a parent, nothing compares children.
library;

/// A household calendar day (no time, no zone). The server sends days as `yyyy-mm-dd`.
DateTime dayOf(DateTime d) => DateTime.utc(d.year, d.month, d.day);

DateTime? parseDay(Object? v) {
  if (v is! String || v.length < 10) return null;
  final d = DateTime.tryParse(v.substring(0, 10));
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The Monday of [day]'s week (ISO weeks, like Postgres `date_trunc('week', …)`).
DateTime weekStartOf(DateTime day) =>
    dayOf(day).subtract(Duration(days: day.weekday - DateTime.monday));

int daysBetween(DateTime a, DateTime b) =>
    dayOf(b).difference(dayOf(a)).inHours ~/ 24;

/// Why stars were given (`star_transactions.reason`).
enum StarReason {
  activity('activity_completed'),
  lesson('lesson_completed'),
  course('course_completed'),
  dailyGoal('daily_goal_met'),
  weeklyGoal('weekly_goal_met'),
  badge('badge');

  const StarReason(this.key);
  final String key;

  static StarReason fromKey(String? k) =>
      values.firstWhere((r) => r.key == k, orElse: () => activity);

  /// For children (short) and for grown-ups (the history).
  String get kidLabel => switch (this) {
    activity => 'Finished an activity',
    lesson => 'Finished an island',
    course => 'Finished a course',
    dailyGoal => "Reached today's goal",
    weeklyGoal => "Reached this week's goal",
    badge => 'New badge',
  };
}

/// A configurable rule (`reward_rules`): how many stars an event gives.
class RewardRule {
  const RewardRule({
    required this.key,
    required this.stars,
    required this.description,
  });

  final String key;
  final int stars;
  final String description;
}

/// The default rules (the migration's values). The server's are shown when it sends them.
const defaultRewardRules = [
  RewardRule(
    key: 'activity_completed',
    stars: 1,
    description:
        'Finish a game, video, song or story: 1 star (once a day for each one)',
  ),
  RewardRule(
    key: 'daily_goal_met',
    stars: 1,
    description: 'Reach the daily goal: 1 bonus star',
  ),
  RewardRule(
    key: 'lesson_completed',
    stars: 2,
    description: 'Finish every step of an island: 2 bonus stars',
  ),
  RewardRule(
    key: 'weekly_goal_met',
    stars: 2,
    description: 'Reach the weekly goal: 2 bonus stars',
  ),
  RewardRule(
    key: 'course_completed',
    stars: 5,
    description: 'Finish a whole course: 5 bonus stars',
  ),
];

class StarTransaction {
  const StarTransaction({
    required this.amount,
    required this.reason,
    required this.refKey,
    required this.day,
    required this.at,
    this.badgeKey,
    this.badgeTitle,
  });

  final int amount;
  final StarReason reason;

  /// What it was for (`activity:<id>:<day>`, `lesson:<id>`, `day:<date>`, …): one row per key.
  final String refKey;
  final DateTime day;
  final DateTime at;
  final String? badgeKey;
  final String? badgeTitle;

  factory StarTransaction.fromJson(Map j) => StarTransaction(
    amount: (j['amount'] as num).toInt(),
    reason: StarReason.fromKey(j['reason'] as String?),
    refKey: j['refKey'] as String? ?? '',
    day: parseDay(j['localDate']) ?? DateTime.utc(2000),
    at: DateTime.tryParse('${j['at']}') ?? DateTime.utc(2000),
    badgeKey: j['badgeKey'] as String?,
    badgeTitle: _en(j['badgeTitle']),
  );
}

String? _en(Object? v) => switch (v) {
  String s => s,
  Map m => (m['en'] ?? (m.values.isEmpty ? null : m.values.first)) as String?,
  _ => null,
};

/// The unlock rules the server knows (`rewards.unlock_rule`).
enum BadgeRule {
  firstGame('first_game'),
  firstLesson('first_lesson'),
  firstCourse('first_course'),
  dailyGoals('daily_goals'),
  weeklyGoals('weekly_goals'),
  streak('streak'),
  subjectExplorer('subject_explorer'),
  stars('stars'),
  stars100('stars_100');

  const BadgeRule(this.key);
  final String key;

  static BadgeRule? fromKey(String? k) =>
      values.where((r) => r.key == k).firstOrNull;
}

/// A badge: its picture, words, how to earn it, and when this child earned it (if they did).
class BadgeInfo {
  const BadgeInfo({
    required this.key,
    required this.title,
    required this.description,
    required this.howToEarn,
    required this.rule,
    this.params = const {},
    this.bonusStars = 0,
    this.sort = 0,
    required this.art,
    this.earnedAt,
  });

  final String key;
  final String title;
  final String description;
  final String howToEarn;
  final BadgeRule? rule;
  final Map<String, Object?> params;
  final int bonusStars;
  final int sort;

  /// `badges/<slug>/1/512.webp` in public-assets.
  final String art;
  final DateTime? earnedAt;

  bool get earned => earnedAt != null;

  /// The number the rule counts to (days, goals, activities, stars), if any.
  int get target => switch (rule) {
    BadgeRule.stars100 => 100,
    _ => ((params['count'] ?? params['days'] ?? 1) as num).toInt(),
  };

  BadgeInfo earnedOn(DateTime? at) => BadgeInfo(
    key: key,
    title: title,
    description: description,
    howToEarn: howToEarn,
    rule: rule,
    params: params,
    bonusStars: bonusStars,
    sort: sort,
    art: art,
    earnedAt: at,
  );

  factory BadgeInfo.fromJson(Map j) => BadgeInfo(
    key: j['key'] as String,
    title: _en(j['title']) ?? '',
    description: _en(j['description']) ?? '',
    howToEarn: _en(j['howToEarn']) ?? '',
    rule: BadgeRule.fromKey(j['rule'] as String?),
    params: ((j['params'] as Map?) ?? const {}).cast<String, Object?>(),
    bonusStars: (j['bonusStars'] as num?)?.toInt() ?? 0,
    sort: (j['sort'] as num?)?.toInt() ?? 0,
    art: j['art'] as String? ?? '',
    earnedAt: j['earnedAt'] == null
        ? null
        : DateTime.tryParse('${j['earnedAt']}'),
  );
}

/// A parent's goals for one child (`learning_goals`; defaults when none are set).
class GoalSettings {
  const GoalSettings({
    this.enabled = true,
    this.dailyActivities = 3,
    this.weeklyDays = 4,
  });

  final bool enabled;

  /// Different activities to finish in a day (1–10).
  final int dailyActivities;

  /// Days with some learning in a week (1–7).
  final int weeklyDays;

  static const dailyRange = (min: 1, max: 10);
  static const weeklyRange = (min: 1, max: 7);

  GoalSettings copyWith({
    bool? enabled,
    int? dailyActivities,
    int? weeklyDays,
  }) => GoalSettings(
    enabled: enabled ?? this.enabled,
    dailyActivities: dailyActivities ?? this.dailyActivities,
    weeklyDays: weeklyDays ?? this.weeklyDays,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'dailyActivities': dailyActivities,
    'weeklyDays': weeklyDays,
  };

  factory GoalSettings.fromJson(Map? j) => GoalSettings(
    enabled: j?['enabled'] as bool? ?? true,
    dailyActivities: (j?['dailyActivities'] as num?)?.toInt() ?? 3,
    weeklyDays: (j?['weeklyDays'] as num?)?.toInt() ?? 4,
  );

  @override
  bool operator ==(Object other) =>
      other is GoalSettings &&
      other.enabled == enabled &&
      other.dailyActivities == dailyActivities &&
      other.weeklyDays == weeklyDays;

  @override
  int get hashCode => Object.hash(enabled, dailyActivities, weeklyDays);
}

/// Today's or this week's goal.
class GoalStatus {
  const GoalStatus({
    required this.target,
    required this.progress,
    this.completedAt,
  });

  final int target;
  final int progress;
  final DateTime? completedAt;

  /// Reached now, or reached earlier (a goal reached stays reached if the target changes).
  bool get done => completedAt != null || progress >= target;
  double get fraction => target <= 0 ? 1 : (progress / target).clamp(0, 1);
  int get left => (target - progress).clamp(0, target);

  factory GoalStatus.fromJson(Map? j, int fallbackTarget) => GoalStatus(
    target: (j?['target'] as num?)?.toInt() ?? fallbackTarget,
    progress: (j?['progress'] as num?)?.toInt() ?? 0,
    completedAt: j?['completedAt'] == null
        ? null
        : DateTime.tryParse('${j!['completedAt']}'),
  );
}

class Streak {
  const Streak({this.current = 0, this.longest = 0, this.lastDay});

  final int current;
  final int longest;
  final DateTime? lastDay;
}

/// The streak rule (the same as private.streak_of). A learning day is a day with at least one
/// star. Learning days count while there's never a gap of two days in a row without one: ONE
/// rest day between learning days keeps the streak (children have off days), and rest days
/// aren't counted. The streak is still "current" up to the end of the day after a rest day,
/// so nobody is told they lost it in the middle of a day.
class StreakRules {
  const StreakRules._();

  /// The longest gap (in days, between two learning days) that keeps a streak: one rest day.
  static const maxGap = 2;

  static Streak of(Iterable<DateTime> learningDays, DateTime today) {
    final t = dayOf(today);
    final days = {
      for (final d in learningDays)
        if (!dayOf(d).isAfter(t)) dayOf(d),
    }.toList()..sort();
    DateTime? prev;
    var run = 0, best = 0;
    for (final d in days) {
      run = prev == null || daysBetween(prev, d) > maxGap ? 1 : run + 1;
      if (run > best) best = run;
      prev = d;
    }
    final current = prev != null && daysBetween(prev, t) <= maxGap ? run : 0;
    return Streak(current: current, longest: best, lastDay: prev);
  }

  /// Streak lengths that get their own celebration (badges exist for 3, 7 and 30).
  static const milestones = [3, 7, 14, 30, 50, 100];
}

/// Everything the Rewards screen and the parent page show.
class RewardsSummary {
  const RewardsSummary({
    required this.today,
    this.balance = 0,
    this.streak = const Streak(),
    this.goals = const GoalSettings(),
    this.day = const GoalStatus(target: 3, progress: 0),
    this.week = const GoalStatus(target: 4, progress: 0),
    this.learningDays = const {},
    this.transactions = const [],
    this.badges = const [],
    this.counts = const RewardCounts(),
    this.rules = defaultRewardRules,
  });

  /// The household's today (server), and the Monday of this week.
  final DateTime today;
  DateTime get weekStart => weekStartOf(today);

  final int balance;
  final Streak streak;
  final GoalSettings goals;
  final GoalStatus day;
  final GoalStatus week;

  /// Learning days of the last six weeks (the calendar).
  final Set<DateTime> learningDays;

  /// Newest first (the last 50).
  final List<StarTransaction> transactions;

  /// Every badge, earned or not, in catalogue order.
  final List<BadgeInfo> badges;
  final RewardCounts counts;
  final List<RewardRule> rules;

  List<BadgeInfo> get earnedBadges =>
      badges.where((b) => b.earned).toList()
        ..sort((a, b) => b.earnedAt!.compareTo(a.earnedAt!));

  factory RewardsSummary.fromJson(Map j) {
    final goals = GoalSettings.fromJson(j['goals'] as Map?);
    final s = (j['streak'] as Map?) ?? const {};
    final c = (j['counts'] as Map?) ?? const {};
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return RewardsSummary(
      today: parseDay(j['today']) ?? dayOf(DateTime.now()),
      balance: n(j['balance']),
      streak: Streak(
        current: n(s['current']),
        longest: n(s['longest']),
        lastDay: parseDay(s['lastDay']),
      ),
      goals: goals,
      day: GoalStatus.fromJson(j['day'] as Map?, goals.dailyActivities),
      week: GoalStatus.fromJson(j['week'] as Map?, goals.weeklyDays),
      learningDays: {
        for (final d in (j['learningDays'] as List?) ?? const []) ?parseDay(d),
      },
      transactions: [
        for (final t in (j['transactions'] as List?) ?? const [])
          StarTransaction.fromJson(t as Map),
      ],
      badges: [
        for (final b in (j['badges'] as List?) ?? const [])
          BadgeInfo.fromJson(b as Map),
      ],
      counts: RewardCounts(
        islands: n(c['islands']),
        courses: n(c['courses']),
        dailyGoals: n(c['dailyGoals']),
        weeklyGoals: n(c['weeklyGoals']),
        learningDays: n(c['learningDays']),
      ),
      rules: [
        for (final r in (j['rules'] as List?) ?? const [])
          RewardRule(
            key: (r as Map)['key'] as String,
            stars: n(r['stars']),
            description: _en(r['description']) ?? '',
          ),
      ],
    );
  }
}

/// The achievements children collect (counted on the server).
class RewardCounts {
  const RewardCounts({
    this.islands = 0,
    this.courses = 0,
    this.dailyGoals = 0,
    this.weeklyGoals = 0,
    this.learningDays = 0,
  });

  final int islands;
  final int courses;
  final int dailyGoals;
  final int weeklyGoals;
  final int learningDays;
}

/// What ONE finished session newly earned (POST /play/sync → `rewards`). Empty when it was a
/// replay or earned nothing: celebrations only ever show for new rewards.
class RewardEvents {
  const RewardEvents({
    required this.childId,
    this.stars = 0,
    this.transactions = const [],
    this.badges = const [],
    this.dailyGoalDone = false,
    this.weeklyGoalDone = false,
    this.lessonCompleted = false,
    this.courseCompleted = false,
    this.streak = const Streak(),
    this.streakGrew = false,
    this.balance,
  });

  final String childId;
  final int stars;
  final List<({StarReason reason, int amount})> transactions;
  final List<({String key, String title, int bonusStars, String art})> badges;
  final bool dailyGoalDone;
  final bool weeklyGoalDone;
  final bool lessonCompleted;
  final bool courseCompleted;
  final Streak streak;
  final bool streakGrew;
  final int? balance;

  /// A streak length worth its own moment (the day it's reached).
  int? get streakMilestone =>
      streakGrew && StreakRules.milestones.contains(streak.current)
      ? streak.current
      : null;

  bool get isEmpty =>
      stars == 0 &&
      badges.isEmpty &&
      !dailyGoalDone &&
      !weeklyGoalDone &&
      !lessonCompleted &&
      !courseCompleted &&
      streakMilestone == null;

  static RewardEvents? fromJson(String childId, Map? j) {
    if (j == null) return null;
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    final goals = (j['goals'] as List?) ?? const [];
    bool just(String period) => goals.any(
      (g) => (g as Map)['period'] == period && g['justCompleted'] == true,
    );
    final s = (j['streak'] as Map?) ?? const {};
    return RewardEvents(
      childId: childId,
      stars: n(j['stars']),
      transactions: [
        for (final t in (j['transactions'] as List?) ?? const [])
          (
            reason: StarReason.fromKey((t as Map)['reason'] as String?),
            amount: n(t['amount']),
          ),
      ],
      badges: [
        for (final b in (j['badges'] as List?) ?? const [])
          (
            key: (b as Map)['key'] as String,
            title: _en(b['title']) ?? '',
            bonusStars: n(b['bonusStars']),
            art: b['art'] as String? ?? '',
          ),
      ],
      dailyGoalDone: just('day'),
      weeklyGoalDone: just('week'),
      lessonCompleted: j['lessonCompleted'] == true,
      courseCompleted: j['courseCompleted'] == true,
      streak: Streak(current: n(s['current']), longest: n(s['longest'])),
      streakGrew: s['grew'] == true,
      balance: (j['balance'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toJson() => {
    'stars': stars,
    'transactions': [
      for (final t in transactions)
        {'reason': t.reason.key, 'amount': t.amount},
    ],
    'badges': [
      for (final b in badges)
        {
          'key': b.key,
          'title': b.title,
          'bonusStars': b.bonusStars,
          'art': b.art,
        },
    ],
    'goals': [
      if (dailyGoalDone) {'period': 'day', 'justCompleted': true},
      if (weeklyGoalDone) {'period': 'week', 'justCompleted': true},
    ],
    'lessonCompleted': lessonCompleted,
    'courseCompleted': courseCompleted,
    'streak': {
      'current': streak.current,
      'longest': streak.longest,
      'grew': streakGrew,
    },
    'balance': ?balance,
  };
}
