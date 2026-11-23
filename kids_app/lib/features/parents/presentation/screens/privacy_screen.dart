import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/routes.dart';
import '../../../../core/clock/clock.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/grown_up.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/widgets/reauth_dialog.dart';
import '../../../child_profiles/presentation/child_providers.dart';
import '../../domain/account.dart';
import '../parent_providers.dart';

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

/// P12 Privacy and data: the consents given (with dates), a copy of the data (one child or
/// the whole account; needs a fresh sign-in), deleting a child (on the child's page) and
/// deleting the account (7 days to change your mind).
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  String? _busy; // which action is running
  String? _error;
  ExportLink? _last;

  /// Runs [op]; if the server wants a fresh sign-in, asks for the email code and tries again.
  Future<T?> _withReauth<T>(String key, Future<T> Function() op) async {
    setState(() {
      _busy = key;
      _error = null;
    });
    try {
      try {
        return await op();
      } on ReauthRequiredFailure {
        setState(() => _busy = null);
        if (!mounted || !await confirmWithEmailCode(context)) return null;
        setState(() => _busy = key);
        return await op();
      }
    } on Failure catch (f) {
      if (mounted) setState(() => _error = f.message);
      return null;
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _export(String? childId) async {
    final link = await _withReauth(
      'export:${childId ?? 'all'}',
      () => ref.read(accountRepositoryProvider).requestExport(childId: childId),
    );
    if (link == null || !mounted) return;
    setState(() => _last = link);
    ref
      ..invalidate(exportsProvider)
      ..invalidate(notificationsProvider);
    if (link.url != null) await ref.read(urlOpenerProvider)(link.url!);
  }

  Future<void> _download(ExportRequest e) async {
    try {
      final link = await ref.read(accountRepositoryProvider).exportLink(e.id);
      if (!mounted) return;
      setState(() => _last = link);
      if (link.url != null) await ref.read(urlOpenerProvider)(link.url!);
    } on Failure catch (f) {
      if (mounted) setState(() => _error = f.message);
    }
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete the whole account?'),
        content: const Text(
          'In 7 days we delete the account, every child profile and all their progress, on every device. '
          'Until then you can cancel here. A subscription bought in a store must be cancelled in that store.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.uiDanger,
              foregroundColor: AppColors.uiOnDanger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete in 7 days'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final d = await _withReauth(
      'delete',
      () => ref.read(accountRepositoryProvider).scheduleAccountDeletion(),
    );
    if (d != null) ref.invalidate(deletionRequestsProvider);
  }

  Future<void> _cancel(DeletionRequest d) async {
    await _withReauth(
      'cancel',
      () => ref.read(accountRepositoryProvider).cancelAccountDeletion(d.id),
    );
    ref.invalidate(deletionRequestsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final consents = ref.watch(consentsProvider);
    final exports = ref.watch(exportsProvider);
    final deletions = ref.watch(deletionRequestsProvider);
    final kids = ref.watch(childrenProvider).value ?? const [];
    final now = ref.watch(clockProvider)();
    String who(String? id) => id == null
        ? 'Whole account'
        : kids.where((c) => c.id == id).firstOrNull?.nickname ?? 'A child';
    final pending = deletions.value?.where((d) => d.pendingAccount).firstOrNull;
    return OrientationScope(
      policy: OrientationPolicy.grownUps,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Privacy and data'),
          leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(Routes.parents),
          ),
        ),
        body: GrownUpPage(
          children: [
            Text('Consents you gave', style: UiText.h3),
            const SizedBox(height: Space.s3),
            switch (consents) {
              AsyncValue(:final value?, isLoading: false) =>
                value.isEmpty
                    ? Text('No consents recorded.', style: UiText.small)
                    : Card(
                        child: Column(
                          children: [
                            for (final c in value)
                              ListTile(
                                title: Text(c.label),
                                subtitle: Text(
                                  c.revokedAt == null
                                      ? 'Given ${_date(c.grantedAt)} · version ${c.version}'
                                      : 'Given ${_date(c.grantedAt)}, withdrawn ${_date(c.revokedAt!)}',
                                  style: UiText.small,
                                ),
                                trailing: Icon(
                                  c.revokedAt == null
                                      ? Icons.check_circle_outline
                                      : Icons.remove_circle_outline,
                                  color: c.revokedAt == null
                                      ? AppColors.uiSuccess
                                      : AppColors.uiTextMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
              AsyncValue(hasError: true, isLoading: false) => GrownUpErrorView(
                error: consents.error!,
                onRetry: () => ref.invalidate(consentsProvider),
              ),
              _ => const LoadingRegion(
                child: Skeleton(
                  height: Sizes.kidsNode,
                  color: AppColors.uiBorder,
                ),
              ),
            },
            const SizedBox(height: Space.s8),
            Text('Download a copy of your data', style: UiText.h3),
            const SizedBox(height: Space.s2),
            Text(
              'A file (JSON) with everything we store: profiles, activities played, scores, stars, badges, '
              'goals and settings. One child’s data, or the whole account. You’ll confirm it’s you first. '
              'The file is kept for 7 days.',
              style: UiText.small,
            ),
            const SizedBox(height: Space.s4),
            Wrap(
              spacing: Space.s3,
              runSpacing: Space.s3,
              children: [
                for (final c in kids)
                  OutlinedButton.icon(
                    onPressed: _busy != null ? null : () => _export(c.id),
                    icon: _busy == 'export:${c.id}'
                        ? const SizedBox.square(
                            dimension: Sizes.iconMd,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text('${c.nickname}’s data'),
                  ),
                FilledButton.icon(
                  onPressed: _busy != null ? null : () => _export(null),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('The whole account'),
                ),
              ],
            ),
            if (_last != null) ...[
              const SizedBox(height: Space.s4),
              Container(
                padding: const EdgeInsets.all(Space.s4),
                decoration: BoxDecoration(
                  color: AppColors.uiSuccessSoft,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Text(
                  _last!.url != null
                      ? 'Your export is ready. The download opened in your browser; the link works for 1 hour.'
                      : 'Your export is ready (demo mode: no file is stored, so there is nothing to download).',
                  style: UiText.small.copyWith(color: AppColors.uiSuccess),
                ),
              ),
            ],
            const SizedBox(height: Space.s4),
            switch (exports) {
              AsyncValue(:final value?) when value.isNotEmpty => Card(
                child: Column(
                  children: [
                    for (final e in value.take(5))
                      ListTile(
                        title: Text(who(e.childId)),
                        subtitle: Text(
                          '${_date(e.createdAt)} · ${e.available(now) ? 'ready until ${_date(e.expiresAt!)}' : switch (e.status) {
                                  'failed' => 'failed',
                                  'processing' || 'requested' => 'being prepared',
                                  _ => 'expired',
                                }}',
                          style: UiText.small,
                        ),
                        trailing: e.available(now)
                            ? TextButton(
                                onPressed: () => _download(e),
                                child: const Text('Download'),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
              _ => const SizedBox.shrink(),
            },
            const SizedBox(height: Space.s8),
            Text('Delete data', style: UiText.h3),
            const SizedBox(height: Space.s2),
            Text(
              'To delete one child, open their profile (Manage children) and choose Delete. It happens straight away.',
              style: UiText.small,
            ),
            const SizedBox(height: Space.s3),
            OutlinedButton.icon(
              onPressed: () => context.go(Routes.children),
              icon: const Icon(Icons.person_remove_outlined),
              label: const Text('Manage children'),
            ),
            const SizedBox(height: Space.s6),
            if (pending != null)
              Container(
                padding: const EdgeInsets.all(Space.s5),
                decoration: BoxDecoration(
                  color: AppColors.uiDangerSoft,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This account will be deleted on ${_date(pending.scheduledFor)}.',
                      style: UiText.bodyStrong.copyWith(
                        color: AppColors.uiDanger,
                      ),
                    ),
                    const SizedBox(height: Space.s3),
                    OutlinedButton(
                      onPressed: _busy != null ? null : () => _cancel(pending),
                      child: const Text('Keep my account'),
                    ),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.uiDanger,
                  ),
                  onPressed: _busy != null || deletions.isLoading
                      ? null
                      : _deleteAccount,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete the whole account'),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: Space.s5),
              FormErrorText(_error!),
            ],
          ],
        ),
      ),
    );
  }
}
