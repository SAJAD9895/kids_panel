import 'account.dart';
import 'parent_reports.dart';

/// GET /progress/overview and GET /progress/report.
abstract interface class ParentReportsRepository {
  Future<FamilyOverview> overview();
  Future<ProgressReport> report(
    String childId, {
    required ReportPeriod period,
    DateTime? date,
  });
}

/// Notifications, preferences, consents, subscription and privacy requests.
abstract interface class AccountRepository {
  Future<List<ParentNotification>> notifications();

  /// Marks [ids] read (all when null).
  Future<void> markRead([List<String>? ids]);
  Future<NoticePreferences> preferences();
  Future<void> savePreferences(NoticePreferences prefs);

  Future<List<ConsentRecord>> consents();
  Future<SubscriptionInfo> subscription();
  Future<List<PlanOption>> plans();

  Future<List<ExportRequest>> exports();

  /// Builds an export of one child ([childId]) or the whole account (null). Needs a recent
  /// sign-in: throws `ReauthRequiredFailure` otherwise.
  Future<ExportLink> requestExport({String? childId});
  Future<ExportLink> exportLink(String requestId);

  Future<List<DeletionRequest>> deletionRequests();

  /// Schedules the account's deletion (7 days). Needs a recent sign-in.
  Future<DeletionRequest> scheduleAccountDeletion();
  Future<void> cancelAccountDeletion(String requestId);
}
