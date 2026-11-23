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
import '../../domain/account.dart';
import '../parent_providers.dart';

String _ago(DateTime at) {
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
  final l = at.toLocal();
  return '${l.day} ${m[l.month - 1]}, ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// P11 Notifications: the in-app inbox (weekly summaries, goals reached, account and
/// subscription events). Nicknames are filled in on this device; notices only carry ids.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsProvider);
    final kids = ref.watch(childrenProvider).value ?? const [];
    String name(String? id) =>
        kids.where((c) => c.id == id).firstOrNull?.nickname ?? 'Your child';
    Future<void> markAll() async {
      try {
        await ref.read(accountRepositoryProvider).markRead();
        ref
          ..invalidate(notificationsProvider)
          ..invalidate(familyOverviewProvider);
      } on Failure catch (f) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(f.message)));
        }
      }
    }

    return OrientationScope(
      policy: OrientationPolicy.grownUps,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(Routes.parents),
          ),
          actions: [
            IconButton(
              tooltip: 'Notification settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(Routes.parentNotificationSettings),
            ),
          ],
        ),
        body: GrownUpPage(
          children: switch (list) {
            AsyncValue(:final value?, isLoading: false) => [
              if (value.any((n) => n.unread))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: markAll,
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Mark all as read'),
                  ),
                ),
              if (value.isEmpty)
                const EmptyStateView(
                  title: 'No notifications yet',
                  message: 'Weekly summaries, goals reached and account news will appear here.',
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final (i, n) in value.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        () {
                          final t = n.text(name);
                          return Semantics(
                            label: n.unread ? 'Unread' : null,
                            child: ListTile(
                              leading: Icon(
                                n.unread ? Icons.circle : Icons.circle_outlined,
                                size: Sizes.iconSm,
                                color: n.unread
                                    ? AppColors.uiNoticeDot
                                    : AppColors.uiBorderInput,
                              ),
                              title: Text(
                                t.title,
                                style: n.unread
                                    ? UiText.bodyStrong
                                    : UiText.body,
                              ),
                              subtitle: Text(
                                '${t.body.isEmpty ? '' : '${t.body}\n'}${_ago(n.createdAt)}',
                                style: UiText.small,
                              ),
                              isThreeLine: t.body.isNotEmpty,
                              onTap: n.unread
                                  ? () async {
                                      await ref
                                          .read(accountRepositoryProvider)
                                          .markRead([n.id]);
                                      ref
                                        ..invalidate(notificationsProvider)
                                        ..invalidate(familyOverviewProvider);
                                    }
                                  : null,
                            ),
                          );
                        }(),
                      ],
                    ],
                  ),
                ),
            ],
            AsyncValue(hasError: true, isLoading: false) => [
              GrownUpErrorView(
                error: list.error ?? const ServerFailure(),
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
            ],
            _ => [
              const LoadingRegion(
                child: Skeleton(
                  height: Sizes.kidsHeroH,
                  color: AppColors.uiBorder,
                ),
              ),
            ],
          },
        ),
      ),
    );
  }
}

/// P11 settings: which notices to receive, per type. In-app notices are delivered; email and
/// push need a sender that isn't connected yet, so they are not offered as switches.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(noticePreferencesProvider);
    return OrientationScope(
      policy: OrientationPolicy.grownUps,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notification settings'),
          leading: BackButton(
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(Routes.parentNotifications),
          ),
        ),
        body: switch (prefs) {
          AsyncValue(:final value?, isLoading: false) => _PrefsForm(
            initial: value,
          ),
          AsyncValue(hasError: true, isLoading: false) => GrownUpErrorView(
            error: prefs.error ?? const ServerFailure(),
            onRetry: () => ref.invalidate(noticePreferencesProvider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _PrefsForm extends ConsumerStatefulWidget {
  const _PrefsForm({required this.initial});
  final NoticePreferences initial;

  @override
  ConsumerState<_PrefsForm> createState() => _PrefsFormState();
}

class _PrefsFormState extends ConsumerState<_PrefsForm> {
  late final NoticePreferences _p = {...widget.initial};
  var _saving = false;
  String? _error;

  bool get _changed => NoticeType.values.any((t) => _p[t] != widget.initial[t]);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountRepositoryProvider).savePreferences(_p);
      ref.invalidate(noticePreferencesProvider);
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
  Widget build(BuildContext context) => GrownUpPage(
    children: [
      Text('In the app', style: UiText.h3),
      const SizedBox(height: Space.s2),
      Text(
        'Notices appear in the Grown-ups area. Children never see them. Email and push delivery '
        'aren’t connected yet in this version.',
        style: UiText.small,
      ),
      const SizedBox(height: Space.s3),
      for (final t in NoticeType.values)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.label),
          subtitle: Text(t.help, style: UiText.small),
          value: _p[t] ?? true,
          onChanged: (v) => setState(() => _p[t] = v),
        ),
      if (_error != null) ...[
        const SizedBox(height: Space.s5),
        FormErrorText(_error!),
      ],
      const SizedBox(height: Space.s6),
      Align(
        alignment: Alignment.centerLeft,
        child: PrimaryButton(
          label: 'Save',
          busy: _saving,
          onPressed: _changed ? _save : null,
        ),
      ),
    ],
  );
}
