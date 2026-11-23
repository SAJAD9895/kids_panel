import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/routes.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/grown_up.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../child_profiles/presentation/child_providers.dart';
import '../../../learning/presentation/learning_providers.dart';
import '../../../rewards/domain/rewards.dart';
import '../../../rewards/presentation/rewards_providers.dart';
import '../../../rewards/presentation/screens/rewards_screen.dart'
    show dateLabel;
import '../../../rewards/presentation/widgets/reward_widgets.dart';

/// P18 Rewards and goals, per child: what they've earned (stars, learning days, badges with
/// dates, the star history), the learning goals (saved through `PUT /children/:id/goals`), and
/// how rewards work. Rewards are only ever given by the server; nothing here awards stars.
class ChildRewardsScreen extends ConsumerWidget {
  const ChildRewardsScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref
        .watch(childrenProvider)
        .value
        ?.where((c) => c.id == childId)
        .firstOrNull;
    final rewards = ref.watch(rewardsProvider(childId));
    final name = child?.nickname ?? 'your child';
    return OrientationScope(
      policy: OrientationPolicy.grownUps,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${child?.nickname ?? 'Child'}: rewards and goals'),
          leading: BackButton(
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(Routes.child(childId)),
          ),
        ),
        body: switch (rewards) {
          AsyncValue(:final value?, isLoading: false) => _Body(
            childId: childId,
            name: name,
            summary: value,
          ),
          AsyncValue(hasError: true, isLoading: false) => GrownUpErrorView(
            error: rewards.error ?? const ServerFailure(),
            onRetry: () => ref.invalidate(rewardsProvider(childId)),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.childId,
    required this.name,
    required this.summary,
  });

  final String childId;
  final String name;
  final RewardsSummary summary;

  @override
  Widget build(BuildContext context) {
    final r = summary;
    final earned = r.earnedBadges;
    final notYet = r.badges.where((b) => !b.earned).toList();
    return GrownUpPage(
      children: [
        _Overview(summary: r),
        const SizedBox(height: Space.s8),
        Text('Learning goals', style: UiText.h3),
        const SizedBox(height: Space.s2),
        Text(
          'Small, optional targets. Reaching one gives a bonus star and a short celebration; missing one costs nothing.',
          style: UiText.small,
        ),
        _GoalsForm(
          key: ValueKey(r.goals),
          childId: childId,
          name: name,
          goals: r.goals,
        ),
        const SizedBox(height: Space.s8),
        Text(
          'Badges earned (${earned.length} of ${r.badges.length})',
          style: UiText.h3,
        ),
        const SizedBox(height: Space.s3),
        if (earned.isEmpty)
          Text('No badges yet.', style: UiText.small)
        else
          for (final b in earned) _BadgeRow(badge: b),
        if (notYet.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Still to earn (${notYet.length})',
              style: UiText.bodyStrong,
            ),
            children: [for (final b in notYet) _BadgeRow(badge: b)],
          ),
        const SizedBox(height: Space.s8),
        Text('Star history', style: UiText.h3),
        const SizedBox(height: Space.s2),
        Text(
          'The latest ${r.transactions.length} stars and what they were for.',
          style: UiText.small,
        ),
        const SizedBox(height: Space.s3),
        if (r.transactions.isEmpty)
          Text('No stars yet.', style: UiText.small)
        else
          for (final t in r.transactions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                t.reason == StarReason.badge && t.badgeTitle != null
                    ? 'Badge: ${t.badgeTitle}'
                    : t.reason.kidLabel,
              ),
              subtitle: Text(dateLabel(t.day)),
              trailing: Text(
                '+${t.amount} ${t.amount == 1 ? 'star' : 'stars'}',
                style: UiText.bodyStrong,
              ),
            ),
        const SizedBox(height: Space.s8),
        _HowItWorks(rules: r.rules, name: name),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.summary});
  final RewardsSummary summary;

  @override
  Widget build(BuildContext context) {
    final r = summary;
    final tiles = [
      ('Stars', '${r.balance}', Icons.star_rounded),
      (
        'Learning days in a row',
        '${r.streak.current} (best ${r.streak.longest})',
        Icons.wb_sunny_rounded,
      ),
      (
        'Badges',
        '${r.badges.where((b) => b.earned).length} of ${r.badges.length}',
        Icons.workspace_premium_rounded,
      ),
      if (r.goals.enabled) ...[
        (
          "Today's goal",
          '${r.day.progress.clamp(0, r.day.target)} of ${r.day.target} activities',
          Icons.flag_rounded,
        ),
        (
          "This week's goal",
          '${r.week.progress.clamp(0, r.week.target)} of ${r.week.target} days',
          Icons.event_available_rounded,
        ),
      ],
    ];
    final wide = WindowClass.of(context).isAtLeastMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.s4,
          runSpacing: Space.s4,
          children: [
            for (final (label, value, icon) in tiles)
              Container(
                width: wide ? Sizes.kidsCardW : double.infinity,
                padding: const EdgeInsets.all(Space.s5),
                decoration: BoxDecoration(
                  color: AppColors.uiSurface,
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.uiPrimary),
                    const SizedBox(width: Space.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: UiText.small),
                          Text(value, style: UiText.bodyStrong),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.s6),
        Text('Learning days (last 6 weeks)', style: UiText.bodyStrong),
        const SizedBox(height: Space.s3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.uiFormW),
          child: StreakCalendar(today: r.today, learningDays: r.learningDays),
        ),
      ],
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badge});
  final BadgeInfo badge;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: BadgeArt(art: badge.art, size: Sizes.tapUi, earned: badge.earned),
    title: Text(badge.title),
    subtitle: Text(
      badge.earned
          ? 'Earned ${dateLabel(badge.earnedAt!)}. ${badge.description}'
          : badge.howToEarn,
    ),
    trailing: badge.bonusStars > 0
        ? Text('+${badge.bonusStars}', style: UiText.small)
        : null,
  );
}

class _GoalsForm extends ConsumerStatefulWidget {
  const _GoalsForm({
    super.key,
    required this.childId,
    required this.name,
    required this.goals,
  });

  final String childId;
  final String name;
  final GoalSettings goals;

  @override
  ConsumerState<_GoalsForm> createState() => _GoalsFormState();
}

class _GoalsFormState extends ConsumerState<_GoalsForm> {
  late var _g = widget.goals;
  var _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(rewardsRepositoryProvider).saveGoals(widget.childId, _g);
      ref
        ..invalidate(rewardsProvider(widget.childId))
        ..invalidate(childProgressProvider(widget.childId));
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Saved')));
    } on Failure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Use learning goals'),
        subtitle: Text(
          _g.enabled
              ? '${widget.name} sees a daily and a weekly goal.'
              : 'No goals are shown. Stars and badges still work.',
        ),
        value: _g.enabled,
        onChanged: (v) => setState(() => _g = _g.copyWith(enabled: v)),
      ),
      if (_g.enabled) ...[
        const SizedBox(height: Space.s4),
        DropdownButtonFormField<int>(
          initialValue: _g.dailyActivities,
          decoration: const InputDecoration(
            labelText: 'Daily goal',
            helperText: 'Different activities finished in a day',
          ),
          items: [
            for (
              var n = GoalSettings.dailyRange.min;
              n <= GoalSettings.dailyRange.max;
              n++
            )
              DropdownMenuItem(
                value: n,
                child: Text('$n ${n == 1 ? 'activity' : 'activities'}'),
              ),
          ],
          onChanged: (v) =>
              setState(() => _g = _g.copyWith(dailyActivities: v)),
        ),
        const SizedBox(height: Space.s5),
        DropdownButtonFormField<int>(
          initialValue: _g.weeklyDays,
          decoration: const InputDecoration(
            labelText: 'Weekly goal',
            helperText: 'Days with some learning, Monday to Sunday',
          ),
          items: [
            for (
              var n = GoalSettings.weeklyRange.min;
              n <= GoalSettings.weeklyRange.max;
              n++
            )
              DropdownMenuItem(
                value: n,
                child: Text('$n ${n == 1 ? 'day' : 'days'} a week'),
              ),
          ],
          onChanged: (v) => setState(() => _g = _g.copyWith(weeklyDays: v)),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: Space.s5),
        FormErrorText(_error!),
      ],
      const SizedBox(height: Space.s6),
      Align(
        alignment: Alignment.centerLeft,
        child: PrimaryButton(
          label: 'Save goals',
          busy: _saving,
          onPressed: _g == widget.goals ? null : _save,
        ),
      ),
    ],
  );
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.rules, required this.name});
  final List<RewardRule> rules;
  final String name;

  @override
  Widget build(BuildContext context) {
    Widget point(String text) => Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: Space.s1),
            child: Icon(
              Icons.check_rounded,
              size: Sizes.iconMd,
              color: AppColors.uiSuccess,
            ),
          ),
          const SizedBox(width: Space.s3),
          Expanded(child: Text(text, style: UiText.body)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How rewards work', style: UiText.h3),
        const SizedBox(height: Space.s4),
        for (final r in rules.where((r) => r.stars > 0)) point(r.description),
        point(
          'Badges mark milestones (a first game, a finished island, learning days, goals reached). Some give a few bonus stars.',
        ),
        const SizedBox(height: Space.s4),
        Text('What we don’t do', style: UiText.bodyStrong),
        const SizedBox(height: Space.s3),
        point('Stars are never taken away, and they can’t be bought or spent.'),
        point(
          'Replaying the same activity on the same day doesn’t add stars, so there’s no reason to grind.',
        ),
        point(
          'A day off doesn’t break $name’s learning days in a row. Only two days off in a row start a new count, and nothing is lost.',
        ),
        point('No leaderboards or comparisons with other children.'),
        point(
          'No reminders that push $name to come back. Goals are optional and you can switch them off.',
        ),
        point(
          'Rewards are worked out on our server from finished activities, using your household’s time zone, so changing a device’s clock changes nothing.',
        ),
      ],
    );
  }
}
