import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../rewards/domain/rewards.dart' show dayKey;
import '../domain/account.dart';
import '../domain/parent_reports.dart';
import '../domain/parent_repositories.dart';

Future<T> _guard<T>(Future<T> Function() f) async {
  try {
    return await f();
  } catch (e) {
    throw mapError(e);
  }
}

/// `GET /progress/overview` and `GET /progress/report` (Edge Function `progress`).
class SupabaseParentReportsRepository implements ParentReportsRepository {
  SupabaseParentReportsRepository(this._db);
  final SupabaseClient _db;

  @override
  Future<FamilyOverview> overview() => _guard(() async {
    final res = await _db.functions.invoke(
      'progress/overview',
      method: HttpMethod.get,
    );
    return FamilyOverview.fromJson(res.data as Map);
  });

  @override
  Future<ProgressReport> report(
    String childId, {
    required ReportPeriod period,
    DateTime? date,
  }) => _guard(() async {
    final res = await _db.functions.invoke(
      'progress/report',
      method: HttpMethod.get,
      queryParameters: {
        'childId': childId,
        'period': period.name,
        'date': ?(date == null ? null : dayKey(date)),
      },
    );
    return ProgressReport.fromJson(res.data as Map);
  });
}

/// Reads under RLS (own rows only); writes through the `account` Edge Function.
class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._db);
  final SupabaseClient _db;

  String get _uid => _db.auth.currentUser?.id ?? '';

  @override
  Future<List<ParentNotification>> notifications() => _guard(() async {
    final rows = await _db
        .from('notifications')
        .select('id, type, params, created_at, read_at')
        .eq('channel', 'in_app')
        .order('created_at', ascending: false)
        .limit(100);
    return [for (final r in rows) ParentNotification.fromJson(r)];
  });

  @override
  Future<void> markRead([List<String>? ids]) => _guard(() async {
    await _db.functions.invoke(
      'account/notifications/read',
      body: {'ids': ?ids},
    );
  });

  @override
  Future<NoticePreferences> preferences() => _guard(() async {
    final rows = await _db
        .from('notification_preferences')
        .select('type, channel, enabled')
        .eq('user_id', _uid)
        .eq('channel', 'in_app');
    final stored = {
      for (final r in rows) r['type'] as String: r['enabled'] as bool,
    };
    return {for (final t in NoticeType.values) t: stored[t.key] ?? true};
  });

  @override
  Future<void> savePreferences(NoticePreferences prefs) => _guard(() async {
    await _db.functions.invoke(
      'account/notification-preferences',
      method: HttpMethod.put,
      body: [
        for (final e in prefs.entries)
          {'type': e.key.key, 'channel': 'in_app', 'enabled': e.value},
      ],
    );
  });

  @override
  Future<List<ConsentRecord>> consents() => _guard(() async {
    final rows = await _db
        .from('parental_consents')
        .select('consent_type, policy_version, method, granted_at, revoked_at')
        .order('granted_at');
    return [for (final r in rows) ConsentRecord.fromJson(r)];
  });

  @override
  Future<SubscriptionInfo> subscription() => _guard(() async {
    final subs = await _db
        .from('subscriptions')
        .select(
          'status, provider, environment, current_period_end, auto_renew, started_at, '
          'plan:subscription_plans(key, billing_interval, trial_days, max_children)',
        )
        .order('started_at', ascending: false)
        .limit(1);
    final ent = await _db
        .from('entitlements')
        .select('active_until')
        .eq('entitlement', 'plus');
    final until = ent.isEmpty
        ? null
        : DateTime.tryParse('${ent.first['active_until']}');
    if (subs.isEmpty) return SubscriptionInfo(plusUntil: until);
    final s = subs.first;
    return SubscriptionInfo(
      plan: s['plan'] == null ? null : PlanOption.fromJson(s['plan'] as Map),
      status: s['status'] as String?,
      provider: s['provider'] as String?,
      environment: s['environment'] as String?,
      periodEnd: DateTime.tryParse('${s['current_period_end']}'),
      autoRenew: s['auto_renew'] as bool? ?? false,
      startedAt: DateTime.tryParse('${s['started_at']}'),
      plusUntil: until,
    );
  });

  @override
  Future<List<PlanOption>> plans() => _guard(() async {
    final rows = await _db
        .from('subscription_plans')
        .select('key, billing_interval, trial_days, max_children')
        .eq('active', true)
        .order('billing_interval');
    return [for (final r in rows) PlanOption.fromJson(r)];
  });

  @override
  Future<List<ExportRequest>> exports() => _guard(() async {
    final rows = await _db
        .from('data_export_requests')
        .select('id, status, child_id, created_at, expires_at')
        .order('created_at', ascending: false)
        .limit(20);
    return [for (final r in rows) ExportRequest.fromJson(r)];
  });

  ExportLink _link(Map m, String id) => ExportLink(
    requestId: id,
    url: m['url'] == null ? null : Uri.parse('${m['url']}'),
    expiresAt: DateTime.tryParse('${m['expiresAt']}'),
  );

  @override
  Future<ExportLink> requestExport({String? childId}) => _guard(() async {
    final res = await _db.functions.invoke(
      'account/export',
      body: {'childId': ?childId},
    );
    final m = res.data as Map;
    return _link(m, '${m['requestId']}');
  });

  @override
  Future<ExportLink> exportLink(String requestId) => _guard(() async {
    final res = await _db.functions.invoke(
      'account/exports/$requestId/url',
      method: HttpMethod.get,
    );
    return _link(res.data as Map, requestId);
  });

  @override
  Future<List<DeletionRequest>> deletionRequests() => _guard(() async {
    final rows = await _db
        .from('deletion_requests')
        .select('id, scope, status, scheduled_for')
        .order('created_at', ascending: false)
        .limit(20);
    return [for (final r in rows) DeletionRequest.fromJson(r)];
  });

  @override
  Future<DeletionRequest> scheduleAccountDeletion() => _guard(() async {
    final res = await _db.functions.invoke('account/deletion');
    final m = res.data as Map;
    return DeletionRequest(
      id: '${m['deletionRequestId']}',
      scope: 'account',
      status: 'scheduled',
      scheduledFor: DateTime.tryParse('${m['scheduledFor']}') ?? DateTime.now(),
    );
  });

  @override
  Future<void> cancelAccountDeletion(String requestId) => _guard(() async {
    await _db.functions.invoke(
      'account/deletion/$requestId',
      method: HttpMethod.delete,
    );
  });
}
