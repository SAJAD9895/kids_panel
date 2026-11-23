/// Parent dashboard and progress reports (Phase 13). Pure Dart.
///
/// Every number comes from the server (GET /progress/overview, GET /progress/report), computed
/// from recorded sessions, results, stars, goals and skill mastery: nothing here estimates or
/// fills in data. Definitions: docs/parent-dashboard/analytics.md.
library;

import '../../rewards/domain/rewards.dart';

int _n(Object? v) => (v as num?)?.toInt() ?? 0;
double? _d(Object? v) => (v as num?)?.toDouble();
List<Map> _list(Object? v) => [
  for (final x in (v as List?) ?? const []) x as Map,
];

enum ReportPeriod {
  day,
  week,
  month;

  String get label => switch (this) {
    day => 'Day',
    week => 'Week',
    month => 'Month',
  };

  /// The first day of the period containing [d] (weeks start on Monday).
  DateTime startOf(DateTime d) => switch (this) {
    day => dayOf(d),
    week => weekStartOf(d),
    month => DateTime.utc(d.year, d.month),
  };

  /// The same position one period earlier (-1) or later (+1).
  DateTime shift(DateTime start, int by) => switch (this) {
    day => start.add(Duration(days: by)),
    week => start.add(Duration(days: 7 * by)),
    month => DateTime.utc(start.year, start.month + by),
  };

  static ReportPeriod parse(String? s) =>
      values.where((p) => p.name == s).firstOrNull ?? week;
}

/// "1 h 05 min", "12 min", "45 s", "0 min".
String formatDuration(int seconds) {
  if (seconds <= 0) return '0 min';
  if (seconds < 60) return '$seconds s';
  final m = seconds ~/ 60;
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')} min';
}

class RecentActivity {
  const RecentActivity({
    required this.activityId,
    required this.title,
    required this.type,
    required this.status,
    required this.startedAt,
    this.seconds,
    this.score,
    this.level,
  });

  final String activityId;
  final String title;
  final String type;

  /// `completed`, `abandoned` or `started`.
  final String status;
  final DateTime startedAt;
  final int? seconds;
  final double? score;
  final String? level;

  factory RecentActivity.fromJson(Map j) => RecentActivity(
    activityId: '${j['activityId']}',
    title: j['title'] as String? ?? '',
    type: j['type'] as String? ?? '',
    status: j['status'] as String? ?? '',
    startedAt: DateTime.tryParse('${j['startedAt']}') ?? DateTime.utc(2000),
    seconds: (j['seconds'] as num?)?.toInt(),
    score: _d(j['score']),
    level: j['level'] as String?,
  );
}

/// One child's card on the dashboard.
class ChildOverview {
  const ChildOverview({
    required this.childId,
    this.secondsToday = 0,
    this.secondsWeek = 0,
    this.secondsTotal = 0,
    this.lessonsCompleted = 0,
    this.gamesCompleted = 0,
    this.badgesEarned = 0,
    required this.rewards,
    this.recent = const [],
  });

  final String childId;
  final int secondsToday;
  final int secondsWeek;
  final int secondsTotal;
  final int lessonsCompleted;
  final int gamesCompleted;
  final int badgesEarned;

  /// Stars, streak and goals (the rewards summary without its long lists).
  final RewardsSummary rewards;
  final List<RecentActivity> recent;

  factory ChildOverview.fromJson(Map j) => ChildOverview(
    childId: '${j['childId']}',
    secondsToday: _n(j['secondsToday']),
    secondsWeek: _n(j['secondsWeek']),
    secondsTotal: _n(j['secondsTotal']),
    lessonsCompleted: _n(j['lessonsCompleted']),
    gamesCompleted: _n(j['gamesCompleted']),
    badgesEarned: _n(j['badgesEarned']),
    rewards: RewardsSummary.fromJson((j['rewards'] as Map?) ?? const {}),
    recent: [for (final r in _list(j['recent'])) RecentActivity.fromJson(r)],
  );
}

class FamilyOverview {
  const FamilyOverview({
    required this.today,
    this.children = const [],
    this.unread = 0,
    this.plusUntil,
  });

  final DateTime today;
  final List<ChildOverview> children;

  /// Unread in-app notifications for this parent.
  final int unread;

  /// Plus is active until then (null = Basic).
  final DateTime? plusUntil;

  int get secondsWeek => children.fold(0, (n, c) => n + c.secondsWeek);
  int get starsTotal => children.fold(0, (n, c) => n + c.rewards.balance);

  ChildOverview? child(String id) =>
      children.where((c) => c.childId == id).firstOrNull;

  factory FamilyOverview.fromJson(Map j) => FamilyOverview(
    today: parseDay(j['today']) ?? dayOf(DateTime.now()),
    unread: _n(j['unread']),
    plusUntil: j['plusUntil'] == null
        ? null
        : DateTime.tryParse('${j['plusUntil']}'),
    children: [for (final c in _list(j['children'])) ChildOverview.fromJson(c)],
  );
}

class DailyPoint {
  const DailyPoint(this.date, this.seconds, this.completed);
  final DateTime date;
  final int seconds;
  final int completed;
}

class TypeCompletion {
  const TypeCompletion(this.type, this.started, this.completed);
  final String type;
  final int started;
  final int completed;
  double get rate => started == 0 ? 0 : completed / started;
}

class SubjectStat {
  const SubjectStat({
    required this.key,
    required this.name,
    this.completed = 0,
    this.seconds = 0,
    this.scored = 0,
    this.avgScore,
  });

  final String key;
  final String name;
  final int completed;
  final int seconds;

  /// Completed sessions that had a score (games, quizzes); videos and songs don't.
  final int scored;
  final double? avgScore;
}

class GameStat {
  const GameStat({
    required this.slug,
    required this.title,
    this.plays = 0,
    this.completed = 0,
    this.avgScore,
    this.bestScore,
    this.accuracy,
    this.levels = const [],
  });

  final String slug;
  final String title;
  final int plays;
  final int completed;
  final double? avgScore;
  final double? bestScore;

  /// Right answers out of all answers, in percent (games that count answers).
  final double? accuracy;
  final List<String> levels;
}

class QuizStat {
  const QuizStat({
    required this.slug,
    required this.title,
    this.attempts = 0,
    this.lastScore,
    this.bestScore,
    this.avgScore,
    this.firstTryCorrect,
  });

  final String slug;
  final String title;
  final int attempts;
  final double? lastScore;
  final double? bestScore;
  final double? avgScore;

  /// Questions answered right on the first try, in percent.
  final double? firstTryCorrect;
}

enum MasteryBand {
  gettingStarted('Getting started'),
  practising('Practising'),
  confident('Confident');

  const MasteryBand(this.label);
  final String label;

  /// The §9.3 bands: < 0.4, 0.4–0.75, > 0.75.
  static MasteryBand of(double mastery) => mastery > 0.75
      ? confident
      : mastery >= 0.4
      ? practising
      : gettingStarted;
}

class SkillStat {
  const SkillStat({
    required this.key,
    required this.name,
    required this.group,
    required this.mastery,
    required this.evidence,
    this.practisedInPeriod = false,
  });

  final String key;
  final String name;
  final String group;

  /// 0..1 (09 §9.3). Parents see the band; the number drives the bar.
  final double mastery;

  /// How many finished activities have updated it.
  final int evidence;
  final bool practisedInPeriod;

  MasteryBand get band => MasteryBand.of(mastery);
}

class GoalReport {
  const GoalReport({
    this.enabled = true,
    this.dailyTarget = 3,
    this.weeklyTarget = 4,
    this.daysReached = 0,
    this.daysElapsed = 0,
    this.weeks = const [],
  });

  final bool enabled;
  final int dailyTarget;
  final int weeklyTarget;
  final int daysReached;

  /// Days of the period up to today (future days don't count against the rate).
  final int daysElapsed;
  final List<({DateTime weekStart, bool reached})> weeks;

  /// Null when no day of the period has happened yet.
  double? get dayRate => daysElapsed == 0 ? null : daysReached / daysElapsed;
}

class ProgressReport {
  const ProgressReport({
    required this.childId,
    required this.period,
    required this.from,
    required this.to,
    required this.today,
    this.seconds = 0,
    this.sessions = 0,
    this.completed = 0,
    this.activities = 0,
    this.learningDays = 0,
    this.stars = 0,
    this.previousSeconds = 0,
    this.previousCompleted = 0,
    this.daily = const [],
    this.byType = const [],
    this.bySubject = const [],
    this.games = const [],
    this.quizzes = const [],
    this.stepsCompleted = 0,
    this.lessonsInPeriod = 0,
    this.lessonsTotal = 0,
    this.skills = const [],
    this.goals = const GoalReport(),
    this.consistency = const [],
    this.scoredSessions = 0,
    this.recent = const [],
  });

  final String childId;
  final ReportPeriod period;
  final DateTime from;
  final DateTime to;
  final DateTime today;
  final int seconds;
  final int sessions;
  final int completed;
  final int activities;
  final int learningDays;
  final int stars;
  final int previousSeconds;
  final int previousCompleted;
  final List<DailyPoint> daily;
  final List<TypeCompletion> byType;
  final List<SubjectStat> bySubject;
  final List<GameStat> games;
  final List<QuizStat> quizzes;
  final int stepsCompleted;
  final int lessonsInPeriod;
  final int lessonsTotal;

  /// Every skill with evidence (all time: mastery is a running estimate, not per period).
  final List<SkillStat> skills;
  final GoalReport goals;

  /// Learning days in each of the 8 weeks ending with this period.
  final List<({DateTime weekStart, int learningDays})> consistency;
  final int scoredSessions;
  final List<RecentActivity> recent;

  bool get isEmpty => sessions == 0;

  /// The period hasn't ended yet (numbers can still grow).
  bool get inProgress => !today.isAfter(to);

  factory ProgressReport.fromJson(Map j) {
    final t = (j['totals'] as Map?) ?? const {};
    final p = (j['previous'] as Map?) ?? const {};
    final l = (j['lessons'] as Map?) ?? const {};
    final g = (j['goals'] as Map?) ?? const {};
    return ProgressReport(
      childId: '${j['childId']}',
      period: ReportPeriod.parse(j['period'] as String?),
      from: parseDay(j['from'])!,
      to: parseDay(j['to'])!,
      today: parseDay(j['today']) ?? dayOf(DateTime.now()),
      seconds: _n(t['seconds']),
      sessions: _n(t['sessions']),
      completed: _n(t['completed']),
      activities: _n(t['activities']),
      learningDays: _n(t['learningDays']),
      stars: _n(t['stars']),
      previousSeconds: _n(p['seconds']),
      previousCompleted: _n(p['completed']),
      daily: [
        for (final d in _list(j['daily']))
          DailyPoint(
            parseDay(d['date'])!,
            _n(d['seconds']),
            _n(d['completed']),
          ),
      ],
      byType: [
        for (final x in _list(j['byType']))
          TypeCompletion('${x['type']}', _n(x['started']), _n(x['completed'])),
      ],
      bySubject: [
        for (final x in _list(j['bySubject']))
          SubjectStat(
            key: '${x['key']}',
            name: x['name'] as String? ?? '${x['key']}',
            completed: _n(x['completed']),
            seconds: _n(x['seconds']),
            scored: _n(x['scored']),
            avgScore: _d(x['avgScore']),
          ),
      ],
      games: [
        for (final x in _list(j['games']))
          GameStat(
            slug: '${x['slug']}',
            title: x['title'] as String? ?? '',
            plays: _n(x['plays']),
            completed: _n(x['completed']),
            avgScore: _d(x['avgScore']),
            bestScore: _d(x['bestScore']),
            accuracy: _d(x['accuracy']),
            levels: [for (final v in (x['levels'] as List?) ?? const []) '$v'],
          ),
      ],
      quizzes: [
        for (final x in _list(j['quizzes']))
          QuizStat(
            slug: '${x['slug']}',
            title: x['title'] as String? ?? '',
            attempts: _n(x['attempts']),
            lastScore: _d(x['lastScore']),
            bestScore: _d(x['bestScore']),
            avgScore: _d(x['avgScore']),
            firstTryCorrect: _d(x['firstTryCorrect']),
          ),
      ],
      stepsCompleted: _n(l['stepsCompleted']),
      lessonsInPeriod: _n(l['completedInPeriod']),
      lessonsTotal: _n(l['completedTotal']),
      skills: [
        for (final x in _list(j['skills']))
          SkillStat(
            key: '${x['key']}',
            name: x['name'] as String? ?? '${x['key']}',
            group: '${x['group']}',
            mastery: _d(x['mastery']) ?? 0,
            evidence: _n(x['evidence']),
            practisedInPeriod: x['practisedInPeriod'] == true,
          ),
      ],
      goals: GoalReport(
        enabled: g['enabled'] as bool? ?? true,
        dailyTarget: _n(g['dailyTarget']),
        weeklyTarget: _n(g['weeklyTarget']),
        daysReached: _n(g['daysReached']),
        daysElapsed: _n(g['daysElapsed']),
        weeks: [
          for (final w in _list(g['weeks']))
            (
              weekStart: parseDay(w['weekStart'])!,
              reached: w['reached'] == true,
            ),
        ],
      ),
      consistency: [
        for (final w in _list(j['consistency']))
          (
            weekStart: parseDay(w['weekStart'])!,
            learningDays: _n(w['learningDays']),
          ),
      ],
      scoredSessions: _n(j['scoredSessions']),
      recent: [for (final r in _list(j['recent'])) RecentActivity.fromJson(r)],
    );
  }
}

/// Strengths and areas to practise, by a fixed, explainable rule (analytics.md §5). Nothing is
/// said without enough evidence: a subject needs at least [minScored] scored activities in the
/// period, a skill at least [minEvidence] updates.
class ReportInsights {
  const ReportInsights({
    required this.strengths,
    required this.practise,
    required this.enoughData,
  });

  static const minScored = 3;
  static const minEvidence = 3;
  static const strongScore = 80.0;
  static const weakScore = 60.0;

  final List<String> strengths;
  final List<String> practise;

  /// False when nothing met the evidence bar (the screen says so instead of guessing).
  final bool enoughData;

  static ReportInsights of(ProgressReport r) {
    final strengths = <String>[], practise = <String>[];
    var judged = false;
    for (final s in r.bySubject) {
      if (s.scored < minScored || s.avgScore == null) continue;
      judged = true;
      final avg = s.avgScore!.round();
      if (s.avgScore! >= strongScore) {
        strengths.add(
          '${s.name}: $avg % on average in ${s.scored} scored activities',
        );
      } else if (s.avgScore! < weakScore) {
        practise.add(
          '${s.name}: $avg % on average in ${s.scored} scored activities',
        );
      }
    }
    for (final k in r.skills) {
      if (k.evidence < minEvidence) continue;
      judged = true;
      if (k.band == MasteryBand.confident) {
        strengths.add('${k.name}: confident (${k.evidence} activities)');
      } else if (k.band == MasteryBand.gettingStarted) {
        practise.add('${k.name}: getting started (${k.evidence} activities)');
      }
    }
    return ReportInsights(
      strengths: strengths,
      practise: practise,
      enoughData: judged,
    );
  }
}
