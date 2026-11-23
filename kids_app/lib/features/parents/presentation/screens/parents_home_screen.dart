import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/session.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/clock/clock.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/gate/gate_controller.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/grown_up.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../child_profiles/domain/child_profile.dart';
import '../../../child_profiles/presentation/child_providers.dart';
import '../../domain/parent_reports.dart';
import '../parent_providers.dart';
import '../widgets/charts.dart';

/// P01 Parent dashboard: every child at a glance (time, lessons, games, streak, stars and
/// badges, today's and this week's goals, recent activities), the family's week, and the way
/// to reports, controls, notifications, subscription and privacy. Data: GET /progress/overview.
class ParentsHomeScreen extends ConsumerWidget {
  const ParentsHomeScreen({super.key});

  void _backToKids(BuildContext context, WidgetRef ref) {
    ref.read(gateProvider.notifier).lock();
    context.go(
      ref.read(selectedChildIdProvider) == null
          ? Routes.whoIsPlaying
          : Routes.kids,
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out on this device?'),
        content: const Text(
          'Your children’s progress stays saved in your account. You’ll need an email code to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(sessionProvider).signOut();
    } on Failure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(f.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final children = ref.watch(childrenProvider);
    final overview = ref.watch(familyOverviewProvider);
    ref.watch(avatarsProvider);
    final demo = ref.watch(appConfigProvider).isDemo;
    final unread = overview.value?.unread ?? 0;

    return OrientationScope(
      policy: OrientationPolicy.grownUps,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grown-ups'),
          leading: IconButton(
            tooltip: 'Back to the kids area',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _backToKids(context, ref),
          ),
          actions: [
            IconButton(
              tooltip: unread == 0
                  ? 'Notifications'
                  : 'Notifications, $unread unread',
              onPressed: () => context.push(Routes.parentNotifications),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                backgroundColor: AppColors.uiNoticeDot,
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(familyOverviewProvider);
            await ref.read(childrenProvider.notifier).reload();
          },
          child: GrownUpPage(
            children: [
              if (demo) ...[
                Container(
                  padding: const EdgeInsets.all(Space.s4),
                  decoration: BoxDecoration(
                    color: AppColors.uiWarningSoft,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Text(
                    'Demo mode: no backend is configured, so nothing is saved after the app closes.',
                    style: UiText.small.copyWith(
                      color: AppColors.uiWarningText,
                    ),
                  ),
                ),
                const SizedBox(height: Space.s6),
              ],
              ..._children(context, ref, children, overview),
              const SizedBox(height: Space.s8),
              Text('Family settings', style: UiText.h2),
              const SizedBox(height: Space.s4),
              Card(
                child: Column(
                  children: [
                    _Link(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Subscription',
                      subtitle: switch (overview.value?.plusUntil) {
                        final d? => 'Plus until ${_date(d)}',
                        null when overview.hasValue => 'Basic',
                        _ => null,
                      },
                      onTap: () => context.push(Routes.subscription),
                    ),
                    const Divider(height: 1),
                    _Link(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'What we tell you, and the inbox',
                      onTap: () => context.push(Routes.parentNotifications),
                    ),
                    const Divider(height: 1),
                    _Link(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy and data',
                      subtitle: 'Consents, download data, delete the account',
                      onTap: () => context.push(Routes.privacy),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.s8),
              Text('Account', style: UiText.h2),
              const SizedBox(height: Space.s4),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.mail_outline_rounded),
                      title: const Text('Signed in as'),
                      subtitle: Text(user?.email ?? '—', style: UiText.small),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.uiDanger,
                      ),
                      title: Text(
                        'Sign out',
                        style: UiText.bodyStrong.copyWith(
                          color: AppColors.uiDanger,
                        ),
                      ),
                      onTap: () => _signOut(context, ref),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _children(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ChildProfile>> children,
    AsyncValue<FamilyOverview> overview,
  ) {
    final header = Wrap(
      spacing: Space.s3,
      runSpacing: Space.s3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Your children', style: UiText.h2),
        OutlinedButton.icon(
          onPressed: () => context.go(Routes.children),
          icon: const Icon(Icons.manage_accounts_outlined),
          label: const Text('Manage children'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push(Routes.newChild),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add a child'),
        ),
      ],
    );
    if (children.hasError || overview.hasError) {
      return [
        header,
        const SizedBox(height: Space.s4),
        GrownUpErrorView(
          error: children.error ?? overview.error!,
          onRetry: () {
            ref.invalidate(familyOverviewProvider);
            ref.read(childrenProvider.notifier).reload();
          },
        ),
      ];
    }
    final list = children.value;
    final o = overview.value;
    if (list == null || o == null) {
      return [
        header,
        const SizedBox(height: Space.s4),
        const LoadingRegion(
          label: 'Loading your children’s progress',
          child: Skeleton(height: Sizes.kidsHeroH, color: AppColors.uiBorder),
        ),
      ];
    }
    if (list.isEmpty) {
      return [
        header,
        const SizedBox(height: Space.s4),
        EmptyStateView(
          title: 'No child profiles yet',
          message: 'Add a child to see their learning here.',
          action: FilledButton(
            onPressed: () => context.push(Routes.newChild),
            child: const Text('Add a child'),
          ),
        ),
      ];
    }
    final wide = WindowClass.of(context).isAtLeastExpanded;
    return [
      header,
      const SizedBox(height: Space.s5),
      Text('This week', style: UiText.h3),
      const SizedBox(height: Space.s4),
      Wrap(
        spacing: Space.s4,
        runSpacing: Space.s4,
        children: [
          StatTile(
            icon: Icons.schedule_rounded,
            label: 'Learning time, all children',
            value: formatDuration(o.secondsWeek),
            width: wide ? Sizes.kidsCardW : null,
          ),
          StatTile(
            icon: Icons.star_rounded,
            label: 'Stars, all children',
            value: '${o.starsTotal}',
            width: wide ? Sizes.kidsCardW : null,
          ),
        ],
      ),
      const SizedBox(height: Space.s6),
      for (final c in list) ...[
        _ChildCard(child: c, overview: o.child(c.id)),
        const SizedBox(height: Space.s5),
      ],
    ];
  }
}

String _date(DateTime d) {
  const m = [
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
  final l = d.toLocal();
  return '${l.day} ${m[l.month - 1]} ${l.year}';
}

String _when(DateTime at, DateTime now) {
  final l = at.toLocal();
  final hm =
      '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  if (dayOfLocal(l) == dayOfLocal(now)) return 'Today $hm';
  if (dayOfLocal(l) == dayOfLocal(now.subtract(const Duration(days: 1)))) {
    return 'Yesterday $hm';
  }
  const m = [
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
  return '${l.day} ${m[l.month - 1]} $hm';
}

DateTime dayOfLocal(DateTime d) => DateTime(d.year, d.month, d.day);

String typeLabel(String t) => switch (t) {
  'game' => 'Game',
  'video' => 'Video',
  'song' => 'Song',
  'story' => 'Story',
  'quiz' => 'Quiz',
  'audiobook' => 'Audiobook',
  _ => t,
};

String statusLabel(String s) => switch (s) {
  'completed' => 'finished',
  'abandoned' => 'stopped early',
  _ => 'started',
};

class _Link extends StatelessWidget {
  const _Link({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!, style: UiText.small),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _ChildCard extends ConsumerWidget {
  const _ChildCard({required this.child, required this.overview});

  final ChildProfile child;
  final ChildOverview? overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final o = overview;
    final age = child.birthYearMonth.ageInYears(now);
    final head = Row(
      children: [
        CircleAvatar(
          radius: Sizes.tapKids / 2,
          backgroundColor: AppColors.kidsMeSoft,
          child: ExcludeSemantics(
            child: BuddyArt(
              ref.watch(buddyArtIndexProvider(child.avatarId)),
              size: Sizes.tapKids - Space.s3,
            ),
          ),
        ),
        const SizedBox(width: Space.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                child.nickname,
                style: UiText.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text('$age years old', style: UiText.small),
            ],
          ),
        ),
      ],
    );
    if (o == null) {
      return Card(
        child: Padding(padding: const EdgeInsets.all(Space.s5), child: head),
      );
    }
    final r = o.rewards;
    final stats = <(IconData, String, String)>[
      (Icons.schedule_rounded, 'Today', formatDuration(o.secondsToday)),
      (Icons.date_range_rounded, 'This week', formatDuration(o.secondsWeek)),
      (Icons.timer_outlined, 'All time', formatDuration(o.secondsTotal)),
      (Icons.landscape_outlined, 'Lessons completed', '${o.lessonsCompleted}'),
      (Icons.sports_esports_outlined, 'Games completed', '${o.gamesCompleted}'),
      (
        Icons.wb_sunny_outlined,
        'Learning days in a row',
        '${r.streak.current} (best ${r.streak.longest})',
      ),
      (Icons.star_outline_rounded, 'Stars', '${r.balance}'),
      (Icons.workspace_premium_outlined, 'Badges', '${o.badgesEarned}'),
    ];
    Widget goal(String label, int progress, int target, bool done) => Semantics(
      container: true,
      label: done ? '$label: reached' : '$label: $progress of $target',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              done
                  ? '$label: reached'
                  : '$label: ${progress.clamp(0, target)} of $target',
              style: UiText.small.copyWith(color: AppColors.uiText),
            ),
            const SizedBox(height: Space.s2),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: LinearProgressIndicator(
                value: done
                    ? 1.0
                    : (target == 0 ? 0.0 : progress / target).clamp(0.0, 1.0),
                minHeight: Space.s3,
                color: done ? AppColors.uiSuccess : AppColors.uiChart1,
                backgroundColor: AppColors.uiBorder,
              ),
            ),
          ],
        ),
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            const SizedBox(height: Space.s5),
            LayoutBuilder(
              builder: (context, box) {
                // two tiles a row on phones, three or four on wider cards
                final cols = box.maxWidth < 520
                    ? 2
                    : (box.maxWidth < 760 ? 3 : 4);
                final w = (box.maxWidth - Space.s3 * (cols - 1)) / cols;
                return Wrap(
                  spacing: Space.s3,
                  runSpacing: Space.s3,
                  children: [
                    for (final (icon, label, value) in stats)
                      StatTile(
                        icon: icon,
                        label: label,
                        value: value,
                        width: w,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: Space.s5),
            if (r.goals.enabled) ...[
              goal(
                'Today’s goal (activities)',
                r.day.progress,
                r.day.target,
                r.day.done,
              ),
              const SizedBox(height: Space.s4),
              goal(
                'This week’s goal (learning days)',
                r.week.progress,
                r.week.target,
                r.week.done,
              ),
            ] else
              Text(
                'Learning goals are off for ${child.nickname}.',
                style: UiText.small,
              ),
            const SizedBox(height: Space.s5),
            Text('Recent activities', style: UiText.bodyStrong),
            const SizedBox(height: Space.s2),
            if (o.recent.isEmpty)
              Text('Nothing played yet.', style: UiText.small)
            else
              for (final a in o.recent.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.s1),
                  child: Text(
                    '${a.title} · ${typeLabel(a.type)}, ${statusLabel(a.status)} · ${_when(a.startedAt, now)}',
                    style: UiText.small.copyWith(color: AppColors.uiText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            const SizedBox(height: Space.s5),
            Wrap(
              spacing: Space.s3,
              runSpacing: Space.s3,
              children: [
                FilledButton.icon(
                  onPressed: () => context.push(Routes.childReport(child.id)),
                  icon: const Icon(Icons.insights_rounded),
                  label: Text('${child.nickname}’s report'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push(Routes.child(child.id)),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Settings and controls'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push(Routes.childRewards(child.id)),
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Rewards and goals'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
