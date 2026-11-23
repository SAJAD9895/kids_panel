import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../child_profiles/presentation/child_providers.dart';
import '../../../kids_home/presentation/widgets/kids_shell.dart';
import '../../../learning/presentation/widgets/kid_widgets.dart';
import '../../../learning/presentation/widgets/kids_content.dart';
import '../../domain/rewards.dart';
import '../rewards_providers.dart';
import '../widgets/reward_widgets.dart';

/// K16 My rewards: star balance, today's and this week's goal, learning days, what's new,
/// achievements and every badge (earned ones with their date, the rest with how to earn them).
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    return KidsContent(
      header: const KidsTopBar(title: 'My rewards'),
      builder: (context, d) {
        if (child == null) return const [];
        final rewards = ref.watch(rewardsProvider(child.id));
        return switch (rewards) {
          AsyncValue(:final value?, isLoading: false) => _filled(
            context,
            value,
          ),
          AsyncValue(hasError: true, isLoading: false) => [
            const SizedBox(height: Space.s9),
            KidsErrorView(
              onRetry: () => ref.invalidate(rewardsProvider(child.id)),
            ),
          ],
          _ => _loading,
        };
      },
    );
  }

  static final _loading = <Widget>[
    const SizedBox(height: Space.s7),
    const LoadingRegion(
      label: 'Loading your rewards',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(height: Sizes.kidsNode, radius: Radii.x2xl),
          SizedBox(height: Space.s6),
          Skeleton(height: Sizes.kidsHeroH, radius: Radii.x2xl),
        ],
      ),
    ),
  ];

  List<Widget> _filled(BuildContext context, RewardsSummary r) {
    final wide = WindowClass.of(context).isAtLeastExpanded;
    final top = [
      _StarJar(balance: r.balance, rules: r.rules),
      if (r.goals.enabled) _Goals(summary: r),
    ];
    return [
      const SizedBox(height: Space.s7),
      if (wide)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, w) in top.indexed) ...[
                if (i > 0) const SizedBox(width: Space.s6),
                Expanded(child: w),
              ],
            ],
          ),
        )
      else
        for (final (i, w) in top.indexed) ...[
          if (i > 0) const SizedBox(height: Space.s6),
          w,
        ],
      const ShelfTitle('My learning days'),
      _StreakCard(summary: r),
      if (r.transactions.isNotEmpty) ...[
        const ShelfTitle('New for me'),
        _Recent(transactions: r.transactions.take(5).toList()),
      ],
      const ShelfTitle('What I did'),
      _Achievements(counts: r.counts, streak: r.streak),
      ShelfTitle(
        'My badges (${r.badges.where((b) => b.earned).length} of ${r.badges.length})',
      ),
      _BadgeGrid(badges: r.badges),
    ];
  }
}

String dateLabel(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final l = d.toLocal();
  return '${l.day} ${months[l.month - 1]} ${l.year}';
}

class _Card extends StatelessWidget {
  const _Card({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Space.s7),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(Radii.x2xl),
    ),
    child: child,
  );
}

class _StarJar extends StatelessWidget {
  const _StarJar({required this.balance, required this.rules});
  final int balance;
  final List<RewardRule> rules;

  @override
  Widget build(BuildContext context) => _Card(
    color: AppColors.kidsListenSoft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          container: true,
          label: 'I have $balance ${balance == 1 ? 'star' : 'stars'}',
          child: ExcludeSemantics(
            child: Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: AppColors.kidsStar,
                  size: Sizes.tapKidsXl,
                ),
                const SizedBox(width: Space.s4),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$balance', style: KidsText.display),
                      Text(
                        balance == 1 ? 'star' : 'stars',
                        style: KidsText.label,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.s5),
        Text(
          'Stars stay yours forever.',
          style: KidsText.caption.copyWith(color: AppColors.kidsListenInk),
        ),
        const SizedBox(height: Space.s5),
        KidsButton.soft(
          label: 'How do I get stars?',
          icon: Icons.help_outline_rounded,
          onPressed: () => _howStars(context, rules),
        ),
      ],
    ),
  );

  static void _howStars(
    BuildContext context,
    List<RewardRule> rules,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.kidsSurface,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Space.s7, 0, Space.s7, Space.s8),
        children: [
          Text('How I get stars', style: KidsText.title),
          const SizedBox(height: Space.s5),
          for (final r in rules.where((r) => r.stars > 0))
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.kidsStar),
                  const SizedBox(width: Space.s3),
                  Expanded(child: Text(r.description, style: KidsText.body)),
                ],
              ),
            ),
          Text('New badges can give bonus stars too.', style: KidsText.body),
        ],
      ),
    ),
  );
}

class _Goals extends StatelessWidget {
  const _Goals({required this.summary});
  final RewardsSummary summary;

  @override
  Widget build(BuildContext context) {
    final day = summary.day, week = summary.week;
    Widget goal(String title, GoalStatus g, String unit, String doneText) {
      final done = g.done;
      return Expanded(
        child: Semantics(
          container: true,
          label: done
              ? '$title: done. $doneText'
              : '$title: ${g.progress.clamp(0, g.target)} of ${g.target} $unit',
          child: ExcludeSemantics(
            child: Column(
              children: [
                GoalRing(
                  fraction: done ? 1 : g.fraction,
                  size: Sizes.kidsNode,
                  fill: done ? AppColors.kidsSuccessFill : AppColors.kidsStar,
                  track: AppColors.kidsSurface,
                  child: done
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.kidsSuccess,
                          size: Sizes.iconKids,
                        )
                      : Text(
                          '${g.progress.clamp(0, g.target)}/${g.target}',
                          style: KidsText.heading,
                        ),
                ),
                const SizedBox(height: Space.s3),
                Text(title, style: KidsText.label, textAlign: TextAlign.center),
                Text(
                  done ? doneText : '${g.left} more $unit',
                  style: KidsText.caption.copyWith(
                    color: AppColors.kidsLearnInk,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _Card(
      color: AppColors.kidsLearnSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My goals', style: KidsText.heading),
          const SizedBox(height: Space.s5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              goal('Today', day, 'activities', 'Well done!'),
              const SizedBox(width: Space.s5),
              goal('This week', week, 'days', 'Great week!'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.summary});
  final RewardsSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary.streak;
    final wide = WindowClass.of(context).isAtLeastMedium;
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          label: s.current == 0
              ? 'No learning days in a row right now'
              : '${s.current} learning ${s.current == 1 ? 'day' : 'days'} in a row',
          child: ExcludeSemantics(
            child: Row(
              children: [
                const Icon(
                  Icons.wb_sunny_rounded,
                  color: AppColors.kidsStar,
                  size: Sizes.tapKids,
                ),
                const SizedBox(width: Space.s4),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.current}', style: KidsText.display),
                      Text(
                        s.current == 1 ? 'day in a row' : 'days in a row',
                        style: KidsText.label,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.s4),
        Text(
          'My best: ${s.longest} ${s.longest == 1 ? 'day' : 'days'}',
          style: KidsText.body,
        ),
        const SizedBox(height: Space.s3),
        Text(
          'Resting for a day is fine. It keeps your days in a row.',
          style: KidsText.caption.copyWith(color: AppColors.kidsMeInk),
        ),
      ],
    );
    final calendar = StreakCalendar(
      today: summary.today,
      learningDays: summary.learningDays,
    );
    return _Card(
      color: AppColors.kidsMeSoft,
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: words),
                const SizedBox(width: Space.s8),
                Expanded(child: calendar),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                words,
                const SizedBox(height: Space.s6),
                calendar,
              ],
            ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.transactions});
  final List<StarTransaction> transactions;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final t in transactions)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s3),
          child: Semantics(
            container: true,
            label:
                '${t.reason == StarReason.badge && t.badgeTitle != null ? 'New badge: ${t.badgeTitle}' : t.reason.kidLabel}, plus ${t.amount} ${t.amount == 1 ? 'star' : 'stars'}',
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s6,
                  vertical: Space.s4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.kidsSurface,
                  borderRadius: BorderRadius.circular(Radii.xl),
                ),
                child: Row(
                  children: [
                    Icon(switch (t.reason) {
                      StarReason.badge => Icons.workspace_premium_rounded,
                      StarReason.lesson => Icons.landscape_rounded,
                      StarReason.course => Icons.emoji_events_rounded,
                      StarReason.dailyGoal ||
                      StarReason.weeklyGoal => Icons.flag_rounded,
                      StarReason.activity => Icons.check_circle_rounded,
                    }, color: AppColors.kidsLearnInk),
                    const SizedBox(width: Space.s4),
                    Expanded(
                      child: Text(
                        t.reason == StarReason.badge && t.badgeTitle != null
                            ? 'New badge: ${t.badgeTitle}'
                            : t.reason.kidLabel,
                        style: KidsText.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('+${t.amount}', style: KidsText.label),
                    const Icon(Icons.star_rounded, color: AppColors.kidsStar),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _Achievements extends StatelessWidget {
  const _Achievements({required this.counts, required this.streak});
  final RewardCounts counts;
  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (Icons.calendar_month_rounded, counts.learningDays, 'learning days'),
      (Icons.flag_rounded, counts.dailyGoals, 'daily goals'),
      (Icons.event_available_rounded, counts.weeklyGoals, 'great weeks'),
      (Icons.landscape_rounded, counts.islands, 'islands'),
      (Icons.emoji_events_rounded, counts.courses, 'courses'),
    ];
    return Wrap(
      spacing: Space.s4,
      runSpacing: Space.s4,
      children: [
        for (final (icon, n, label) in tiles)
          Semantics(
            container: true,
            label: '$n $label',
            child: ExcludeSemantics(
              child: Container(
                width: Sizes.kidsNode * 1.3,
                padding: const EdgeInsets.all(Space.s5),
                decoration: BoxDecoration(
                  color: AppColors.kidsSurface,
                  borderRadius: BorderRadius.circular(Radii.xl),
                ),
                child: Column(
                  children: [
                    Icon(icon, color: AppColors.kidsLearnInk),
                    Text('$n', style: KidsText.title),
                    Text(
                      label,
                      style: KidsText.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.badges});
  final List<BadgeInfo> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return Text(
        'Badges are on their way!',
        style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
      );
    }
    final sorted = [
      ...badges.where((b) => b.earned),
      ...badges.where((b) => !b.earned),
    ];
    return Wrap(
      spacing: Space.s4,
      runSpacing: Space.s4,
      children: [for (final b in sorted) _BadgeTile(badge: b)],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});
  final BadgeInfo badge;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: badge.earned
        ? '${badge.title}, earned ${dateLabel(badge.earnedAt!)}'
        : '${badge.title}, not yet. ${badge.howToEarn}',
    child: ExcludeSemantics(
      child: Material(
        color: badge.earned ? AppColors.kidsSurface : AppColors.kidsBgAlt,
        borderRadius: BorderRadius.circular(Radii.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.xl),
          onTap: () => showBadge(context, badge),
          child: SizedBox(
            width: Sizes.kidsNode * 1.3,
            child: Padding(
              padding: const EdgeInsets.all(Space.s4),
              child: Column(
                children: [
                  BadgeArt(
                    art: badge.art,
                    size: Sizes.kidsNode * 0.9,
                    earned: badge.earned,
                  ),
                  const SizedBox(height: Space.s2),
                  Text(
                    badge.title,
                    style: KidsText.caption.copyWith(
                      color: badge.earned
                          ? AppColors.kidsInk
                          : AppColors.kidsInkMuted,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A badge up close: what it is, and when it was earned or how to earn it.
void showBadge(BuildContext context, BadgeInfo b) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  backgroundColor: AppColors.kidsSurface,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.s7, 0, Space.s7, Space.s8),
      child: Column(
        children: [
          BadgeArt(art: b.art, size: Sizes.kidsArtLg * 0.7, earned: b.earned),
          const SizedBox(height: Space.s4),
          Text(b.title, style: KidsText.title, textAlign: TextAlign.center),
          const SizedBox(height: Space.s3),
          Text(
            b.earned ? b.description : 'Not yet. ${b.howToEarn}',
            style: KidsText.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.s3),
          if (b.earned)
            TypeChip(
              icon: Icons.event_rounded,
              label: 'Earned ${dateLabel(b.earnedAt!)}',
              ink: AppColors.kidsMeInk,
              background: AppColors.kidsMeSoft,
            ),
          if (b.bonusStars > 0) ...[
            const SizedBox(height: Space.s3),
            Text(
              b.earned
                  ? 'It gave you ${b.bonusStars} bonus ${b.bonusStars == 1 ? 'star' : 'stars'}.'
                  : 'It gives ${b.bonusStars} bonus ${b.bonusStars == 1 ? 'star' : 'stars'}.',
              style: KidsText.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    ),
  ),
);
