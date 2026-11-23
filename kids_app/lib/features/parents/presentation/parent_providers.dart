import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/account.dart';
import '../domain/parent_reports.dart';

final familyOverviewProvider = FutureProvider.autoDispose<FamilyOverview>(
  (ref) => ref.watch(parentReportsRepositoryProvider).overview(),
);

typedef ReportArgs = ({String childId, ReportPeriod period, DateTime? date});

final reportProvider = FutureProvider.autoDispose
    .family<ProgressReport, ReportArgs>(
      (ref, a) => ref
          .watch(parentReportsRepositoryProvider)
          .report(a.childId, period: a.period, date: a.date),
    );

final notificationsProvider =
    FutureProvider.autoDispose<List<ParentNotification>>(
      (ref) => ref.watch(accountRepositoryProvider).notifications(),
    );

final noticePreferencesProvider = FutureProvider.autoDispose<NoticePreferences>(
  (ref) => ref.watch(accountRepositoryProvider).preferences(),
);

final consentsProvider = FutureProvider.autoDispose<List<ConsentRecord>>(
  (ref) => ref.watch(accountRepositoryProvider).consents(),
);

final subscriptionProvider = FutureProvider.autoDispose<SubscriptionInfo>(
  (ref) => ref.watch(accountRepositoryProvider).subscription(),
);

final plansProvider = FutureProvider.autoDispose<List<PlanOption>>(
  (ref) => ref.watch(accountRepositoryProvider).plans(),
);

final exportsProvider = FutureProvider.autoDispose<List<ExportRequest>>(
  (ref) => ref.watch(accountRepositoryProvider).exports(),
);

final deletionRequestsProvider =
    FutureProvider.autoDispose<List<DeletionRequest>>(
      (ref) => ref.watch(accountRepositoryProvider).deletionRequests(),
    );
