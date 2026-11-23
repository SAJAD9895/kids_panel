// Demo mode's copy of private.progress_report / family_overview / update_mastery (Phase 13):
// the same definitions (docs/parent-dashboard/analytics.md), over the sessions the demo server
// received plus Mia's seeded history.
import '../features/learning/domain/catalog.dart';
import '../features/parents/domain/parent_reports.dart';
import '../features/rewards/domain/rewards.dart';
import 'demo_rewards.dart';

/// One recorded session (`activity_sessions` + `activity_results`).
class DemoSession {
  const DemoSession({
    required this.childId,
    required this.activityId,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.score,
    this.correct,
    this.total,
    this.level,
    this.lessonStepId,
  });

  final String childId;
  final String activityId;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double? score;
  final int? correct;
  final int? total;
  final String? level;
  final String? lessonStepId;

  /// The household day (demo: the device's zone).
  DateTime get day => dayOf(startedAt.toLocal());
  int get seconds => endedAt == null
      ? 0
      : endedAt!.difference(startedAt).inSeconds.clamp(0, 4 * 3600);
}

/// A skill's running estimate (`skill_mastery`).
class DemoMastery {
  DemoMastery(
    this.key,
    this.name,
    this.group, [
    this.mastery = 0,
    this.evidence = 0,
  ]);
  final String key;
  final String name;
  final String group;
  double mastery;
  int evidence;
  final days = <DateTime>{};

  /// 09 §9.3 (weight 1 in the demo catalogue).
  void update(double e, {required bool again}) {
    final a = (1 / (evidence + 2)).clamp(0.1, 1.0) * (again ? 0.5 : 1);
    mastery = (mastery + a * (e - mastery)).clamp(0.0, 1.0);
    evidence++;
  }
}

/// Evidence of one completed session: correct/total, else score/100, else 0.7.
double evidenceOf(DemoSession s) {
  if ((s.total ?? 0) > 0) return ((s.correct ?? 0) / s.total!).clamp(0.0, 1.0);
  if (s.score != null) return s.score! / 100;
  return 0.7;
}

ProgressReport buildReport({
  required String childId,
  required ReportPeriod period,
  required DateTime anchor,
  required DateTime today,
  required List<DemoSession> sessions,
  required DemoRewardLedger ledger,
  required Catalog catalog,
  required Map<String, DemoMastery> mastery,
  required Map<String, List<String>> skillsOfActivity,
  required int lessonsInPeriod,
  required int lessonsTotal,
  required int stepsInPeriod,
}) {
  final d0 = period.startOf(anchor);
  final d1 = switch (period) {
    ReportPeriod.day => d0,
    ReportPeriod.week => d0.add(const Duration(days: 6)),
    ReportPeriod.month => DateTime.utc(d0.year, d0.month + 1, 0),
  };
  final p0 = period.shift(d0, -1);
  bool inWin(DateTime d, DateTime a, DateTime b) =>
      !d.isBefore(a) && !d.isAfter(b);
  final mine = sessions.where((s) => s.childId == childId).toList();
  final win = mine.where((s) => inWin(s.day, d0, d1)).toList();
  final prev = mine.where(
    (s) => inWin(s.day, p0, d0.subtract(const Duration(days: 1))),
  );
  final done = win.where((s) => s.status == 'completed').toList();
  final elapsed = today.isBefore(d0)
      ? 0
      : daysBetween(d0, today.isAfter(d1) ? d1 : today) + 1;
  double? avg(Iterable<double?> v) {
    final xs = v.whereType<double>().toList();
    return xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
  }

  String typeOf(String id) => catalog.activity(id)?.type.name ?? 'game';
  final types = <String, ({int n, int c})>{};
  for (final s in win) {
    final t = types[typeOf(s.activityId)] ?? (n: 0, c: 0);
    types[typeOf(s.activityId)] = (
      n: t.n + 1,
      c: t.c + (s.status == 'completed' ? 1 : 0),
    );
  }
  final subjects = <String, List<DemoSession>>{};
  for (final s in win) {
    final sub = catalog.subject(catalog.activity(s.activityId)?.subjectId);
    if (sub != null) (subjects[sub.key] ??= []).add(s);
  }
  final starDays = ledger.starAwards.map((a) => a.day);
  final goalDays = ledger.goalsDone.keys.where((k) => k.startsWith('day:'));
  return ProgressReport(
    childId: childId,
    period: period,
    from: d0,
    to: d1,
    today: today,
    seconds: win.fold(0, (n, s) => n + s.seconds),
    sessions: win.length,
    completed: done.length,
    activities: {for (final s in done) s.activityId}.length,
    learningDays: {
      for (final d in starDays)
        if (inWin(d, d0, d1)) d,
    }.length,
    stars: ledger.transactions
        .where((t) => inWin(t.day, d0, d1))
        .fold(0, (n, t) => n + t.amount),
    previousSeconds: prev.fold(0, (n, s) => n + s.seconds),
    previousCompleted: prev.where((s) => s.status == 'completed').length,
    daily: [
      for (var d = d0; !d.isAfter(d1); d = d.add(const Duration(days: 1)))
        DailyPoint(
          d,
          win.where((s) => s.day == d).fold(0, (n, s) => n + s.seconds),
          done.where((s) => s.day == d).length,
        ),
    ],
    byType: [
      for (final e
          in types.entries.toList()
            ..sort((a, b) => b.value.n.compareTo(a.value.n)))
        TypeCompletion(e.key, e.value.n, e.value.c),
    ],
    bySubject: [
      for (final e in subjects.entries)
        SubjectStat(
          key: e.key,
          name: catalog.subjects.firstWhere((x) => x.key == e.key).name.of(),
          completed: e.value.where((s) => s.status == 'completed').length,
          seconds: e.value.fold(0, (n, s) => n + s.seconds),
          scored: e.value
              .where((s) => s.status == 'completed' && s.score != null)
              .length,
          avgScore: avg(
            e.value.where((s) => s.status == 'completed').map((s) => s.score),
          ),
        ),
    ]..sort((a, b) => b.completed.compareTo(a.completed)),
    games: [
      for (final id in {
        for (final s in win)
          if (typeOf(s.activityId) == 'game') s.activityId,
      })
        () {
          final all = win.where((s) => s.activityId == id).toList();
          final ok = all.where((s) => s.status == 'completed').toList();
          final tot = ok.fold(0, (n, s) => n + (s.total ?? 0));
          final cor = ok.fold(0, (n, s) => n + (s.correct ?? 0));
          final scores = ok.map((s) => s.score).whereType<double>();
          return GameStat(
            slug: id,
            title: catalog.activity(id)?.title.of() ?? id,
            plays: all.length,
            completed: ok.length,
            avgScore: avg(ok.map((s) => s.score)),
            bestScore: scores.isEmpty
                ? null
                : scores.reduce((a, b) => a > b ? a : b),
            accuracy: tot == 0 ? null : 100 * cor / tot,
            levels: ({for (final s in ok) ?s.level}.toList()..sort()),
          );
        }(),
    ]..sort((a, b) => b.plays.compareTo(a.plays)),
    quizzes: [
      for (final id in {
        for (final s in win)
          if (typeOf(s.activityId) == 'quiz') s.activityId,
      })
        () {
          final ok =
              win
                  .where((s) => s.activityId == id && s.status == 'completed')
                  .toList()
                ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
          final scores = ok.map((s) => s.score).whereType<double>();
          return QuizStat(
            slug: id,
            title: catalog.activity(id)?.title.of() ?? id,
            attempts: ok.length,
            lastScore: ok.isEmpty ? null : ok.last.score,
            bestScore: scores.isEmpty
                ? null
                : scores.reduce((a, b) => a > b ? a : b),
            avgScore: avg(ok.map((s) => s.score)),
          );
        }(),
    ],
    stepsCompleted: stepsInPeriod,
    lessonsInPeriod: lessonsInPeriod,
    lessonsTotal: lessonsTotal,
    skills: [
      for (final m
          in mastery.values.where((m) => m.evidence > 0).toList()
            ..sort((a, b) => b.mastery.compareTo(a.mastery)))
        SkillStat(
          key: m.key,
          name: m.name,
          group: m.group,
          mastery: m.mastery,
          evidence: m.evidence,
          practisedInPeriod: done.any(
            (s) => (skillsOfActivity[s.activityId] ?? const []).contains(m.key),
          ),
        ),
    ],
    goals: GoalReport(
      enabled: ledger.settings.enabled,
      dailyTarget: ledger.settings.dailyActivities,
      weeklyTarget: ledger.settings.weeklyDays,
      daysReached: goalDays
          .where((k) => inWin(parseDay(k.substring(4))!, d0, d1))
          .length,
      daysElapsed: elapsed,
      weeks: [
        for (
          var w = weekStartOf(d0);
          !w.isAfter(today.isAfter(d1) ? d1 : today);
          w = w.add(const Duration(days: 7))
        )
          (
            weekStart: w,
            reached: ledger.goalsDone.containsKey('week:${dayKey(w)}'),
          ),
      ],
    ),
    consistency: [
      for (var i = 7; i >= 0; i--)
        () {
          final w = weekStartOf(d1).subtract(Duration(days: 7 * i));
          return (
            weekStart: w,
            learningDays: {
              for (final d in starDays)
                if (inWin(d, w, w.add(const Duration(days: 6)))) d,
            }.length,
          );
        }(),
    ],
    scoredSessions: done.where((s) => s.score != null).length,
    recent: [
      for (final s
          in (win.toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt)))
              .take(50))
        RecentActivity(
          activityId: s.activityId,
          title: catalog.activity(s.activityId)?.title.of() ?? s.activityId,
          type: typeOf(s.activityId),
          status: s.status,
          startedAt: s.startedAt,
          seconds: s.seconds,
          score: s.score,
          level: s.level,
        ),
    ],
  );
}
