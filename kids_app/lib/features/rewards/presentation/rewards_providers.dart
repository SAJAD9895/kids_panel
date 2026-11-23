import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/rewards.dart';

/// One child's rewards summary (GET /children/:id/rewards). Refreshed after every sync.
final rewardsProvider = FutureProvider.autoDispose
    .family<RewardsSummary, String>(
      (ref, childId) => ref.watch(rewardsRepositoryProvider).rewards(childId),
    );

/// New rewards waiting to be celebrated, oldest first. Filled by the sync service with what
/// the server says a session newly earned, so a reward earned offline is celebrated once, when
/// it is actually confirmed, and a replayed upload (status `duplicate`) never celebrates again.
final celebrationQueueProvider =
    NotifierProvider<CelebrationQueue, List<RewardEvents>>(
      CelebrationQueue.new,
    );

class CelebrationQueue extends Notifier<List<RewardEvents>> {
  @override
  List<RewardEvents> build() => const [];

  void push(RewardEvents e) {
    if (!e.isEmpty) state = [...state, e];
  }

  /// The next celebration for [childId] (others wait for their own child).
  RewardEvents? nextFor(String? childId) =>
      state.where((e) => e.childId == childId).firstOrNull;

  void done(RewardEvents e) => state = [
    for (final x in state)
      if (!identical(x, e)) x,
  ];

  void clear() => state = const [];
}
