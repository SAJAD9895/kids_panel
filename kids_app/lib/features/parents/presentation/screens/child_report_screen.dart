import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/grown_up.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../child_profiles/presentation/child_providers.dart';
import '../../../rewards/domain/rewards.dart';
import '../../domain/parent_reports.dart';
import '../parent_providers.dart';
import '../widgets/charts.dart';
import 'parents_home_screen.dart' show typeLabel, statusLabel;

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String periodLabel(ReportPeriod p, DateTime from, DateTime to) => switch (p) {
  ReportPeriod.day =>
    '${_days[from.weekday - 1]} ${from.day} ${_months[from.month - 1]} ${from.year}',
  ReportPeriod.week =>
    '${from.day} ${_months[from.month - 1]} – ${to.day} ${_months[to.month - 1]} ${to.year}',
  ReportPeriod.month => '${_months[from.month - 1]} ${from.year}',
};

String _pct(double? v) => v == null ? '—' : '${v.round()} %';

/// P04 Progress report and learning analytics for one child, by day, week or month.
/// Data: GET /progress/report (household days). Empty periods say so; nothing is estimated.
class ChildReportScreen extends ConsumerWidget {
  const ChildReportScreen({
    super.key,
    required this.childId,
    this.period = ReportPeriod.week,
    this.date,
  });

  final String childId;
  final ReportPeriod period;
  final DateTime? date;

  void _go(
    BuildContext context, {
    String? child,
    ReportPeriod? p,
    DateTime? d,
  }) {
    final q = {
      'period': (p ?? period).name,
      if ((d ?? date) != null) 'date': dayKey(d ?? date!),
    };
    context.replace(
      Uri(
        path: Routes.childReport(child ?? childId),
        queryParameters: q,
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kids = ref.watch(childrenProvider).value ?? const [];
    final child = kids.where((c) => c.id == childId).firstOrNull;
    final args = (childId: childId, period: period, date: date);
    final report = ref.watch(reportProvider(args));
    final r = report.value;
    return OrientationScope(
      policy: OrientationPolicy.grownUps,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${child?.nickname ?? 'Child'}: progress report'),
          leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(Routes.parents),
          ),
        ),
        body: GrownUpPage(
          children: [
            Wrap(
              spacing: Space.s4,
              runSpacing: Space.s4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (kids.length > 1)
                  DropdownButton<String>(
                    value: childId,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final c in kids)
                        DropdownMenuItem(value: c.id, child: Text(c.nickname)),
                    ],
                    onChanged: (id) =>
                        id == null ? null : _go(context, child: id),
                  ),
                SegmentedButton<ReportPeriod>(
                  segments: [
                    for (final p in ReportPeriod.values)
                      ButtonSegment(value: p, label: Text(p.label)),
                  ],
                  selected: {period},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => _go(context, p: s.first),
                ),
              ],
            ),
            const SizedBox(height: Space.s4),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous ${period.name}',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: r == null
                      ? null
                      : () => _go(context, d: period.shift(r.from, -1)),
                ),
                Expanded(
                  child: Text(
                    r == null ? ' ' : periodLabel(period, r.from, r.to),
                    style: UiText.bodyStrong,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Next ${period.name}',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: r == null || r.inProgress
                      ? null
                      : () => _go(context, d: period.shift(r.from, 1)),
                ),
              ],
            ),
            const SizedBox(height: Space.s5),
            ...switch (report) {
              AsyncValue(:final value?, isLoading: false) => _Body(
                report: value,
                name: child?.nickname ?? 'Your child',
              ).build(context),
              AsyncValue(hasError: true, isLoading: false) => [
                GrownUpErrorView(
                  error: report.error ?? const ServerFailure(),
                  onRetry: () => ref.invalidate(reportProvider(args)),
                ),
              ],
              _ => [
                const LoadingRegion(
                  label: 'Loading the report',
                  child: Column(
                    children: [
                      Skeleton(
                        height: Sizes.kidsNode,
                        color: AppColors.uiBorder,
                      ),
                      SizedBox(height: Space.s5),
                      Skeleton(
                        height: Sizes.kidsHeroH,
                        color: AppColors.uiBorder,
                      ),
                    ],
                  ),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}

class _Body {
  const _Body({required this.report, required this.name});
  final ProgressReport report;
  final String name;

  List<Widget> build(BuildContext context) {
    final r = report;
    final wide = WindowClass.of(context).isAtLeastMedium;
    final tileW = wide ? Sizes.kidsCardW - Space.s5 : null;
    final per = r.period.name;
    String vs(int now, int before, String Function(int) fmt) {
      if (before == 0 && now == 0) return 'same as last $per';
      final d = now - before;
      return d == 0
          ? 'same as last $per'
          : '${d > 0 ? '+' : '−'}${fmt(d.abs())} vs last $per';
    }

    final out = <Widget>[
      if (r.inProgress)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s4),
          child: Text(
            'This $per isn’t over yet: numbers can still grow.',
            style: UiText.small,
          ),
        ),
      Wrap(
        spacing: Space.s4,
        runSpacing: Space.s4,
        children: [
          StatTile(
            icon: Icons.schedule_rounded,
            label: 'Learning time',
            value: formatDuration(r.seconds),
            note: vs(r.seconds, r.previousSeconds, formatDuration),
            width: tileW,
          ),
          StatTile(
            icon: Icons.check_circle_outline_rounded,
            label: 'Activities finished',
            value: '${r.completed}',
            note: vs(r.completed, r.previousCompleted, (n) => '$n'),
            width: tileW,
          ),
          StatTile(
            icon: Icons.category_outlined,
            label: 'Different activities',
            value: '${r.activities}',
            width: tileW,
          ),
          StatTile(
            icon: Icons.wb_sunny_outlined,
            label: 'Learning days',
            value: '${r.learningDays}',
            width: tileW,
          ),
          StatTile(
            icon: Icons.star_outline_rounded,
            label: 'Stars earned',
            value: '${r.stars}',
            width: tileW,
          ),
          StatTile(
            icon: Icons.landscape_outlined,
            label: 'Lessons completed',
            value: '${r.lessonsInPeriod}',
            note:
                '${r.stepsCompleted} lesson steps · ${r.lessonsTotal} lessons in all',
            width: tileW,
          ),
        ],
      ),
      const SizedBox(height: Space.s6),
    ];

    if (r.isEmpty) {
      out.add(
        EmptyStateView(
          title: 'No activity in this ${r.period.name}',
          message:
              '$name didn’t play anything in this period. Earlier periods may have activity.',
        ),
      );
      out.addAll([
        const SizedBox(height: Space.s6),
        _consistency(r),
        const SizedBox(height: Space.s5),
        ..._skills(r),
      ]);
      return out;
    }

    // learning time over time
    final daily = r.daily;
    final todayIx = daily.indexWhere((d) => d.date == r.today);
    out.add(
      ChartCard(
        title: 'Learning time',
        subtitle: 'Minutes per day',
        summary:
            'Learning time per day: ${formatDuration(r.seconds)} in total over ${daily.length} days; most on ${() {
              final best = daily.reduce((a, b) => b.seconds > a.seconds ? b : a);
              return '${best.date.day} ${_months[best.date.month - 1]} (${formatDuration(best.seconds)})';
            }()}.',
        columns: const ['Day', 'Time', 'Finished'],
        rows: [
          for (final d in daily)
            [
              '${_days[d.date.weekday - 1]} ${d.date.day} ${_months[d.date.month - 1]}',
              formatDuration(d.seconds),
              '${d.completed}',
            ],
        ],
        child: ColumnChart(
          values: [for (final d in daily) d.seconds / 60],
          labels: [
            for (final d in daily)
              r.period == ReportPeriod.week
                  ? _days[d.date.weekday - 1].substring(0, 1)
                  : '${d.date.day}',
          ],
          highlight: todayIx < 0 ? null : todayIx,
        ),
      ),
    );
    out.add(const SizedBox(height: Space.s5));

    // activity completion
    out.add(
      ChartCard(
        title: 'Activity completion',
        subtitle: 'Finished out of started, by kind',
        summary:
            'Activity completion: ${[for (final t in r.byType) '${typeLabel(t.type)} ${t.completed} of ${t.started}'].join(', ')}.',
        columns: const ['Kind', 'Started', 'Finished'],
        rows: [
          for (final t in r.byType)
            [typeLabel(t.type), '${t.started}', '${t.completed}'],
        ],
        child: BarList(
          color: AppColors.uiChart1,
          rows: [
            for (final t in r.byType)
              (
                label: typeLabel(t.type),
                fraction: t.rate,
                value: '${t.completed} of ${t.started}',
              ),
          ],
        ),
      ),
    );
    out.add(const SizedBox(height: Space.s5));

    // subjects
    final maxSub = r.bySubject.fold<int>(
      1,
      (m, s) => s.completed > m ? s.completed : m,
    );
    out.add(
      ChartCard(
        title: 'Progress by subject',
        subtitle: 'Activities finished, with the average score where activities are scored',
        summary:
            'Progress by subject: ${[for (final s in r.bySubject) '${s.name} ${s.completed} finished${s.avgScore == null ? '' : ', average ${s.avgScore!.round()} %'}'].join('; ')}.',
        columns: const ['Subject', 'Finished', 'Time', 'Average score'],
        rows: [
          for (final s in r.bySubject)
            [
              s.name,
              '${s.completed}',
              formatDuration(s.seconds),
              s.scored == 0
                  ? 'not scored'
                  : '${_pct(s.avgScore)} (${s.scored})',
            ],
        ],
        child: BarList(
          color: AppColors.uiChart3,
          rows: [
            for (final s in r.bySubject)
              (
                label: s.name,
                fraction: s.completed / maxSub,
                value:
                    '${s.completed}${s.avgScore == null ? '' : ' · ${s.avgScore!.round()} %'}',
              ),
          ],
        ),
      ),
    );
    out.add(const SizedBox(height: Space.s5));
    out.addAll(_skills(r));
    out.add(const SizedBox(height: Space.s5));
    out.add(_consistency(r));
    out.add(const SizedBox(height: Space.s5));

    // goals
    final g = r.goals;
    out.add(
      ChartCard(
        title: 'Goal completion',
        subtitle: g.enabled
            ? 'Daily goal: ${g.dailyTarget} activities · weekly goal: ${g.weeklyTarget} learning days'
            : 'Learning goals are switched off',
        summary: !g.enabled
            ? 'Learning goals are switched off.'
            : g.dayRate == null
            ? 'No days of this period have passed yet.'
            : 'Daily goal reached on ${g.daysReached} of ${g.daysElapsed} days; weekly goal reached in ${g.weeks.where((w) => w.reached).length} of ${g.weeks.length} weeks.',
        columns: const ['Week starting', 'Weekly goal'],
        rows: [
          for (final w in g.weeks)
            [
              '${w.weekStart.day} ${_months[w.weekStart.month - 1]}',
              w.reached ? 'reached' : 'not reached',
            ],
        ],
        child: !g.enabled || g.dayRate == null
            ? Text(
                !g.enabled
                    ? 'Switch goals on under Rewards and goals.'
                    : 'Come back when the period has started.',
                style: UiText.small,
              )
            : BarList(
                color: AppColors.uiSuccess,
                rows: [
                  (
                    label: 'Days the daily goal was reached',
                    fraction: g.dayRate!,
                    value: '${g.daysReached} of ${g.daysElapsed}',
                  ),
                  if (g.weeks.isNotEmpty)
                    (
                      label: 'Weeks the weekly goal was reached',
                      fraction:
                          g.weeks.where((w) => w.reached).length /
                          g.weeks.length,
                      value:
                          '${g.weeks.where((w) => w.reached).length} of ${g.weeks.length}',
                    ),
                ],
              ),
      ),
    );
    out.add(const SizedBox(height: Space.s7));

    // games and quizzes
    if (r.games.isNotEmpty) {
      out.addAll([
        Text('Game performance', style: UiText.h3),
        const SizedBox(height: Space.s3),
        _table(
          const [
            'Game',
            'Played',
            'Finished',
            'Average',
            'Best',
            'Right answers',
            'Levels',
          ],
          [
            for (final x in r.games)
              [
                x.title,
                '${x.plays}',
                '${x.completed}',
                _pct(x.avgScore),
                _pct(x.bestScore),
                _pct(x.accuracy),
                x.levels.isEmpty ? '—' : x.levels.join(', '),
              ],
          ],
        ),
        const SizedBox(height: Space.s6),
      ]);
    }
    if (r.quizzes.isNotEmpty) {
      out.addAll([
        Text('Quiz scores', style: UiText.h3),
        const SizedBox(height: Space.s3),
        _table(
          const [
            'Quiz',
            'Attempts',
            'Last',
            'Best',
            'Average',
            'Right first time',
          ],
          [
            for (final q in r.quizzes)
              [
                q.title,
                '${q.attempts}',
                _pct(q.lastScore),
                _pct(q.bestScore),
                _pct(q.avgScore),
                _pct(q.firstTryCorrect),
              ],
          ],
        ),
        const SizedBox(height: Space.s6),
      ]);
    }

    // strengths and practice
    final ins = ReportInsights.of(r);
    out.addAll([
      Text('Strengths and things to practise', style: UiText.h3),
      const SizedBox(height: Space.s2),
      Text(
        'Based on subjects with at least ${ReportInsights.minScored} scored activities in this period (strong: '
        '${ReportInsights.strongScore.round()} % or more, to practise: under ${ReportInsights.weakScore.round()} %) '
        'and skills with at least ${ReportInsights.minEvidence} activities.',
        style: UiText.small,
      ),
      const SizedBox(height: Space.s3),
      if (!ins.enoughData)
        Text(
          'Not enough scored activity yet to say. Keep playing and check again later.',
          style: UiText.body,
        )
      else ...[
        for (final s in ins.strengths)
          _bullet(Icons.thumb_up_alt_outlined, AppColors.uiSuccess, s),
        if (ins.strengths.isEmpty)
          Text('No clear strengths yet.', style: UiText.body),
        const SizedBox(height: Space.s3),
        for (final s in ins.practise)
          _bullet(Icons.refresh_rounded, AppColors.uiWarningText, s),
        if (ins.practise.isEmpty)
          Text('Nothing stands out as needing practice.', style: UiText.body),
      ],
      const SizedBox(height: Space.s7),
      Text('Recent activity', style: UiText.h3),
      const SizedBox(height: Space.s2),
      for (final a in r.recent.take(20))
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(a.title),
          subtitle: Text(
            '${typeLabel(a.type)}, ${statusLabel(a.status)} · ${formatDuration(a.seconds ?? 0)}'
            '${a.score == null ? '' : ' · ${a.score!.round()} %'}${a.level == null ? '' : ' · ${a.level}'}',
            style: UiText.small,
          ),
          trailing: Text(
            '${a.startedAt.toLocal().day} ${_months[a.startedAt.toLocal().month - 1]}',
            style: UiText.small,
          ),
        ),
    ]);
    return out;
  }

  Widget _bullet(IconData icon, Color color, String text) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: Sizes.iconMd, color: color),
        const SizedBox(width: Space.s3),
        Expanded(child: Text(text, style: UiText.body)),
      ],
    ),
  );

  Widget _table(List<String> head, List<List<String>> rows) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: UiText.bodyStrong,
          dataTextStyle: UiText.small.copyWith(color: AppColors.uiText),
          columns: [for (final h in head) DataColumn(label: Text(h))],
          rows: [
            for (final r in rows)
              DataRow(cells: [for (final c in r) DataCell(Text(c))]),
          ],
        ),
      );

  Widget _consistency(ProgressReport r) => ChartCard(
    title: 'Weekly learning consistency',
    subtitle: 'Learning days in each of the last 8 weeks',
    summary:
        'Learning days per week, last 8 weeks: ${[for (final w in r.consistency) w.learningDays].join(', ')}.',
    columns: const ['Week starting', 'Learning days'],
    rows: [
      for (final w in r.consistency)
        [
          '${w.weekStart.day} ${_months[w.weekStart.month - 1]}',
          '${w.learningDays} of 7',
        ],
    ],
    child: ColumnChart(
      values: [for (final w in r.consistency) w.learningDays.toDouble()],
      labels: [
        for (final w in r.consistency)
          '${w.weekStart.day}/${w.weekStart.month}',
      ],
      max: 7,
      color: AppColors.uiChart2,
      height: Sizes.kidsNode,
    ),
  );

  List<Widget> _skills(ProgressReport r) => [
    ChartCard(
      title: 'Skill mastery',
      subtitle: 'A running estimate from finished activities (all time). Bands: getting started, practising, confident.',
      summary: r.skills.isEmpty
          ? 'No skills practised yet.'
          : 'Skill mastery: ${[for (final k in r.skills) '${k.name} ${k.band.label.toLowerCase()}'].join(', ')}.',
      columns: const ['Skill', 'Band', 'Activities'],
      rows: [
        for (final k in r.skills) [k.name, k.band.label, '${k.evidence}'],
      ],
      child: r.skills.isEmpty
          ? Text(
              'Skills appear after a few finished activities.',
              style: UiText.small,
            )
          : BarList(
              color: AppColors.uiChart4,
              rows: [
                for (final k in r.skills)
                  (
                    label:
                        '${k.name}${k.practisedInPeriod ? '' : ' (not this period)'}',
                    fraction: k.mastery,
                    value: k.band.label,
                  ),
              ],
            ),
    ),
  ];
}
