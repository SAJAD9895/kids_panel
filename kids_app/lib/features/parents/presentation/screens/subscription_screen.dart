import 'package:flutter/foundation.dart';
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

/// P06 Subscription: what the billing service recorded (plan, status, store, renewal or end
/// date, Plus access) and where to manage it. Buying, restoring and the web billing portal need
/// store / Stripe connections this build doesn't have: those entries say so instead of
/// pretending (docs/parent-dashboard/subscriptions.md).
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);
    final plans = ref.watch(plansProvider);
    return OrientationScope(
      policy: OrientationPolicy.grownUps,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Subscription'),
          leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(Routes.parents),
          ),
        ),
        body: switch (sub) {
          AsyncValue(:final value?, isLoading: false) => _Body(
            info: value,
            plans: plans.value ?? const [],
          ),
          AsyncValue(hasError: true, isLoading: false) => GrownUpErrorView(
            error: sub.error ?? const ServerFailure(),
            onRetry: () => ref.invalidate(subscriptionProvider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.info, required this.plans});
  final SubscriptionInfo info;
  final List<PlanOption> plans;

  void _notConnected(BuildContext context, String what) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(what),
      content: const Text(
        'This needs the App Store, Google Play or web checkout connection, which isn’t set up in this '
        'version of the app. Nothing was charged or changed.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plus = info.hasPlus;
    final rows = <(String, String)>[
      ('Plan', info.plan?.label ?? (plus ? 'Plus' : 'Basic (free)')),
      if (info.status != null)
        ('Status', subscriptionStatusLabel(info.status!)),
      if (info.provider != null) ('Bought through', info.providerLabel),
      if (info.startedAt != null) ('Started', _date(info.startedAt!)),
      if (info.periodEnd != null)
        (
          info.autoRenew && info.status == 'active' ? 'Renews on' : 'Ends on',
          _date(info.periodEnd!),
        ),
      if (info.plusUntil != null) ('Plus works until', _date(info.plusUntil!)),
      if (info.plan != null) ('Children', 'up to ${info.plan!.maxChildren}'),
    ];
    final manage = info.manageUrl;
    final mobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    return GrownUpPage(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                plus ? 'You have Plus' : 'You’re on Basic',
                style: UiText.h2,
              ),
            ),
            if (info.environment == 'sandbox')
              const GrownUpTag(
                label: 'Test subscription',
                icon: Icons.science_outlined,
              ),
          ],
        ),
        const SizedBox(height: Space.s4),
        Card(
          child: Column(
            children: [
              for (final (k, v) in rows)
                ListTile(
                  dense: true,
                  title: Text(k, style: UiText.small),
                  trailing: Text(v, style: UiText.bodyStrong),
                ),
            ],
          ),
        ),
        if (info.status == 'billing_retry' ||
            info.status == 'grace_period') ...[
          const SizedBox(height: Space.s4),
          Container(
            padding: const EdgeInsets.all(Space.s4),
            decoration: BoxDecoration(
              color: AppColors.uiWarningSoft,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Text(
              'The store couldn’t take the last payment. Update your payment method in ${info.providerLabel}.',
              style: UiText.small.copyWith(color: AppColors.uiWarningText),
            ),
          ),
        ],
        const SizedBox(height: Space.s7),
        Text(plus ? 'Manage or cancel' : 'Upgrade to Plus', style: UiText.h3),
        const SizedBox(height: Space.s3),
        if (plus) ...[
          if (manage != null) ...[
            Text(
              'Plans bought in ${info.providerLabel} are changed and cancelled there. Cancelling keeps Plus until the end of the paid period.',
              style: UiText.small,
            ),
            const SizedBox(height: Space.s3),
            FilledButton.icon(
              onPressed: () => ref.read(urlOpenerProvider)(manage),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text('Open ${info.providerLabel} subscriptions'),
            ),
          ] else if (info.provider == 'promo')
            Text(
              'Plus came from a code. It ends by itself on ${info.periodEnd == null ? 'its end date' : _date(info.periodEnd!)}; there’s nothing to cancel and you won’t be charged.',
              style: UiText.body,
            )
          else
            OutlinedButton.icon(
              onPressed: () => _notConnected(context, 'Web billing'),
              icon: const Icon(Icons.info_outline_rounded),
              label: const Text('Manage web billing (not connected yet)'),
            ),
        ] else ...[
          Text(
            'Plus adds every activity, video, song and story, and room for more children.',
            style: UiText.small,
          ),
          const SizedBox(height: Space.s3),
          for (final p in plans)
            Card(
              child: ListTile(
                title: Text(p.label),
                subtitle: Text(
                  '${p.trialDays > 0 ? '${p.trialDays}-day free trial · ' : ''}up to ${p.maxChildren} children · price shown by the store',
                  style: UiText.small,
                ),
                trailing: OutlinedButton(
                  onPressed: () => _notConnected(context, 'Buying ${p.label}'),
                  child: const Text('Choose (not connected yet)'),
                ),
              ),
            ),
        ],
        const SizedBox(height: Space.s7),
        Text('Already subscribed?', style: UiText.h3),
        const SizedBox(height: Space.s2),
        Text(
          mobile
              ? 'If you bought Plus on another device with the same store account, restoring finds it.'
              : 'Restoring is done in the iPhone, iPad or Android app.',
          style: UiText.small,
        ),
        const SizedBox(height: Space.s3),
        Wrap(
          spacing: Space.s3,
          runSpacing: Space.s3,
          children: [
            OutlinedButton.icon(
              onPressed: () => _notConnected(context, 'Restore purchases'),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restore purchases (not connected yet)'),
            ),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(subscriptionProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check status again'),
            ),
          ],
        ),
      ],
    );
  }
}
