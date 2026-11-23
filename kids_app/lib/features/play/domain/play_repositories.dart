import 'session_report.dart';

/// Reads what an activity contains: `games.config.items` for games, the `questions` and
/// `answers` rows for quizzes. Throws [Failure] on network errors.
abstract interface class ActivityContentRepository {
  Future<ActivitySource> load(String activityId);
}

/// Uploads sessions (`POST /play/sync`). Throws [Failure] when the upload itself fails (offline):
/// the caller keeps the reports in the outbox and tries again later.
abstract interface class PlayRepository {
  Future<List<SyncOutcome>> sync(List<SessionReport> reports);
}

/// What stays on the device: the snapshot of an unfinished run (so it can continue after the
/// app was closed or crashed), and the outbox of reports not yet delivered.
abstract interface class SessionStore {
  Future<Map<String, dynamic>?> loadSnapshot(String childId, String activityId);
  Future<void> saveSnapshot(
    String childId,
    String activityId,
    Map<String, Object?> snapshot,
  );
  Future<void> clearSnapshot(String childId, String activityId);

  /// Adds or replaces (same session id and status) a report waiting to be sent.
  Future<void> enqueue(SessionReport report);
  Future<List<SessionReport>> pending();
  Future<void> remove(Iterable<String> keys);
}

/// Outbox key: a session can wait twice (its start and its end).
String outboxKey(SessionReport r) => '${r.sessionId}:${r.status.name}';
