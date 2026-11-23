import '../../learning/domain/progress.dart';
import 'media.dart';

/// `POST /play/launch` and `POST /play/heartbeat`. Throws [Failure]: [ContentLockedFailure]
/// when the server refuses (Plus, age, a parent's switch, the daily limit), [NetworkFailure]
/// when offline.
abstract interface class MediaRepository {
  Future<MediaLaunch> launch({
    required String childId,
    required String activityId,
  });

  /// Adds [seconds] (1..120) of watching / listening to today's total.
  Future<HeartbeatResult> heartbeat({
    required String childId,
    required String section,
    required int seconds,
  });
}

class HeartbeatResult {
  const HeartbeatResult({this.remainingSeconds, this.locked = false});

  /// Null when there is no limit for this section.
  final int? remainingSeconds;
  final bool locked;
}

/// The parent's media controls (`PUT /children/:id/screen-time`). Reading comes with the
/// child's progress (screen_time_rules under RLS).
abstract interface class MediaControlsRepository {
  Future<void> saveControls(
    String childId, {
    required SectionSwitches sections,
    required MediaControls controls,
  });
}

/// Where the child stopped, kept on the device too: resuming is instant and works before the
/// server has the session (offline, or a report still in the outbox).
abstract interface class MediaPositionStore {
  Future<Map<String, ResumePoint>> positions(String childId);
  Future<void> save(String childId, String activityId, ResumePoint p);
  Future<void> clear(String childId, String activityId);
}
