/// Parent account: notifications, preferences, consents, subscription, privacy requests.
/// Pure Dart. Reads come from RLS-protected tables; every write goes through an Edge Function.
library;

import 'parent_reports.dart' show formatDuration;

/// The notice types a parent can switch (in-app). Labels are what P11 shows.
enum NoticeType {
  weeklyProgress(
    'weekly_progress',
    'Weekly learning summary',
    'Every Monday: last week for each child',
  ),
  goalReached(
    'goal_reached',
    'Goals reached',
    'When a child reaches a daily or weekly goal',
  ),
  accountSecurity(
    'account_security',
    'Account activity',
    'Important changes, like a deleted profile',
  ),
  deletionScheduled(
    'deletion_scheduled',
    'Account deletion',
    'When the account is set to be deleted',
  ),
  exportReady('export_ready', 'Data exports', 'When a data export is ready'),
  subscriptionChanged(
    'subscription_changed',
    'Subscription changes',
    'Started, renewed, cancelled or ended',
  ),
  billingIssue(
    'billing_issue',
    'Payment problems',
    'When a store can’t take a payment',
  ),
  trialEnding(
    'trial_ending',
    'Trial ending',
    'Two days before a free trial ends',
  );

  const NoticeType(this.key, this.label, this.help);
  final String key;
  final String label;
  final String help;

  static NoticeType? of(String key) =>
      values.where((t) => t.key == key).firstOrNull;
}

class ParentNotification {
  const ParentNotification({
    required this.id,
    required this.type,
    required this.params,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;
  final Map<String, Object?> params;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;
  String? get childId => params['childId'] as String?;

  /// Title and text, written here from the type and its parameters. [childName] resolves a
  /// child id to the nickname on this device (nicknames are never put in notices).
  ({String title, String body}) text(
    String Function(String? childId) childName,
  ) {
    switch (type) {
      case 'weekly_progress':
        final kids = [
          for (final c in (params['children'] as List?) ?? const []) c as Map,
        ];
        final parts = [
          for (final c in kids)
            '${childName(c['childId'] as String?)}: ${(c['learningDays'] as num?)?.toInt() ?? 0} learning days, '
                '${(c['activities'] as num?)?.toInt() ?? 0} activities, '
                '${formatDuration((c['seconds'] as num?)?.toInt() ?? 0)}',
        ];
        return (title: 'Last week’s learning', body: parts.join('\n'));
      case 'goal_reached':
        final week = params['period'] == 'week';
        return (
          title:
              '${childName(childId)} reached ${week ? 'this week’s' : 'today’s'} goal',
          body: 'A bonus star was added. You can change goals under Rewards and goals.',
        );
      case 'export_ready':
        return (
          title: 'Your data export is ready',
          body: 'Download it from Privacy and data within 7 days.',
        );
      case 'deletion_scheduled':
        return (
          title: 'Your account is set to be deleted',
          body: 'You can cancel this from Privacy and data until the date shown there.',
        );
      case 'account_security':
        return (
          title: 'A child profile was deleted',
          body: 'If this wasn’t you, sign out on all devices and contact support.',
        );
      case 'subscription_changed':
        return (
          title: 'Your subscription changed',
          body: 'Status: ${subscriptionStatusLabel('${params['status']}')}.',
        );
      case 'billing_issue':
        return (
          title: 'There’s a problem with a payment',
          body: 'Check your payment method in the store you subscribed with.',
        );
      case 'trial_ending':
        return (
          title: 'Your free trial ends soon',
          body: 'Nothing to do if you want to keep Plus.',
        );
      default:
        return (title: 'Notice', body: '');
    }
  }

  factory ParentNotification.fromJson(Map j) => ParentNotification(
    id: '${j['id']}',
    type: '${j['type']}',
    params: ((j['params'] as Map?) ?? const {}).cast<String, Object?>(),
    createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.utc(2000),
    readAt: j['read_at'] == null ? null : DateTime.tryParse('${j['read_at']}'),
  );
}

/// In-app preference per type (stored per type and channel; only in-app is delivered today).
typedef NoticePreferences = Map<NoticeType, bool>;

class ConsentRecord {
  const ConsentRecord({
    required this.type,
    required this.version,
    required this.method,
    required this.grantedAt,
    this.revokedAt,
  });

  final String type;
  final String version;
  final String method;
  final DateTime grantedAt;
  final DateTime? revokedAt;

  String get label => switch (type) {
    'terms' => 'Terms of use',
    'privacy_policy' => 'Privacy policy',
    'child_data_collection' => 'Collecting your child’s learning progress',
    'third_party_disclosure' => 'Sharing with service providers',
    'marketing_email' => 'Marketing emails',
    'push_notifications' => 'Push notifications',
    _ => type,
  };

  factory ConsentRecord.fromJson(Map j) => ConsentRecord(
    type: '${j['consent_type']}',
    version: '${j['policy_version']}',
    method: '${j['method']}',
    grantedAt: DateTime.tryParse('${j['granted_at']}') ?? DateTime.utc(2000),
    revokedAt: j['revoked_at'] == null
        ? null
        : DateTime.tryParse('${j['revoked_at']}'),
  );
}

String subscriptionStatusLabel(String s) => switch (s) {
  'trialing' => 'Free trial',
  'active' => 'Active',
  'grace_period' => 'Payment problem (still active)',
  'billing_retry' => 'Payment problem',
  'paused' => 'Paused',
  'cancelled' => 'Cancelled',
  'expired' => 'Ended',
  'refunded' => 'Refunded',
  'revoked' => 'Revoked',
  _ => s,
};

class PlanOption {
  const PlanOption({
    required this.key,
    required this.interval,
    required this.trialDays,
    required this.maxChildren,
  });

  final String key;

  /// `month`, `year` or `lifetime`.
  final String interval;
  final int trialDays;
  final int maxChildren;

  String get label => switch (interval) {
    'month' => 'Plus, monthly',
    'year' => 'Plus, yearly',
    _ => 'Plus, lifetime',
  };

  factory PlanOption.fromJson(Map j) => PlanOption(
    key: '${j['key']}',
    interval: '${j['billing_interval']}',
    trialDays: (j['trial_days'] as num?)?.toInt() ?? 0,
    maxChildren: (j['max_children'] as num?)?.toInt() ?? 1,
  );
}

/// The household's subscription as the billing service recorded it (null fields = unknown).
class SubscriptionInfo {
  const SubscriptionInfo({
    this.plan,
    this.status,
    this.provider,
    this.environment,
    this.periodEnd,
    this.autoRenew = false,
    this.startedAt,
    this.plusUntil,
  });

  /// No subscription row: the family is on Basic.
  static const basic = SubscriptionInfo();

  final PlanOption? plan;
  final String? status;

  /// `apple`, `google`, `stripe` or `promo`.
  final String? provider;
  final String? environment;
  final DateTime? periodEnd;
  final bool autoRenew;
  final DateTime? startedAt;

  /// From `entitlements`: Plus works until then.
  final DateTime? plusUntil;

  bool get hasPlus => plusUntil != null && plusUntil!.isAfter(DateTime.now());

  String get providerLabel => switch (provider) {
    'apple' => 'App Store',
    'google' => 'Google Play',
    'stripe' => 'Web (card)',
    'promo' => 'Code',
    _ => '—',
  };

  /// Where a subscription is managed or cancelled; null when there's nothing to manage here.
  Uri? get manageUrl => switch (provider) {
    'apple' => Uri.parse('https://apps.apple.com/account/subscriptions'),
    'google' => Uri.parse(
      'https://play.google.com/store/account/subscriptions',
    ),
    _ => null,
  };
}

class ExportRequest {
  const ExportRequest({
    required this.id,
    required this.status,
    required this.createdAt,
    this.childId,
    this.expiresAt,
  });

  final String id;

  /// `requested`, `processing`, `ready`, `expired` or `failed`.
  final String status;
  final String? childId;
  final DateTime createdAt;
  final DateTime? expiresAt;

  bool available(DateTime now) =>
      status == 'ready' && expiresAt != null && expiresAt!.isAfter(now);

  factory ExportRequest.fromJson(Map j) => ExportRequest(
    id: '${j['id']}',
    status: '${j['status']}',
    childId: j['child_id'] as String?,
    createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.utc(2000),
    expiresAt: j['expires_at'] == null
        ? null
        : DateTime.tryParse('${j['expires_at']}'),
  );
}

/// A download link for an export (signed, short-lived). [url] is null in demo mode, where no
/// file is stored.
class ExportLink {
  const ExportLink({
    required this.requestId,
    this.url,
    this.expiresAt,
    this.preview,
  });
  final String requestId;
  final Uri? url;
  final DateTime? expiresAt;

  /// Demo mode: the exported JSON itself (there's no Storage).
  final String? preview;
}

class DeletionRequest {
  const DeletionRequest({
    required this.id,
    required this.scope,
    required this.status,
    required this.scheduledFor,
  });

  final String id;
  final String scope;
  final String status;
  final DateTime scheduledFor;

  bool get pendingAccount => scope == 'account' && status == 'scheduled';

  factory DeletionRequest.fromJson(Map j) => DeletionRequest(
    id: '${j['id']}',
    scope: '${j['scope']}',
    status: '${j['status']}',
    scheduledFor:
        DateTime.tryParse('${j['scheduled_for']}') ?? DateTime.utc(2000),
  );
}
