import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/error/failure.dart';
import '../../learning/data/supabase_learning_repositories.dart';
import '../domain/play_repositories.dart';
import '../domain/session_report.dart';
import 'quiz_mapping.dart';

/// Reads activity content through the Data API (RLS: published activities only).
class SupabaseActivityContentRepository implements ActivityContentRepository {
  SupabaseActivityContentRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<ActivitySource> load(String activityId) async {
    try {
      final r = await _db
          .from('activities')
          .select(
            'id, slug, type, title, description, subject_id, age_min_months, age_max_months, '
            'estimated_seconds, plus_only, players, difficulty, content_version, games(config), '
            'questions(id, position, type, prompt, answers(id, position, content, is_correct, match_key, correct_order))',
          )
          .eq('id', activityId)
          .maybeSingle();
      if (r == null) throw const NotFoundFailure();
      return sourceFromRow(r);
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Public for tests: one activity row (with `games` and `questions` embedded) → source.
  static ActivitySource sourceFromRow(Map<String, dynamic> r) {
    final games = r['games'];
    final config =
        (games is List ? (games.isEmpty ? null : games.first) : games) as Map?;
    final cfg =
        (config?['config'] as Map?)?.cast<String, dynamic>() ?? const {};
    final questions =
        ((r['questions'] as List?) ?? const []).cast<Map<String, dynamic>>()
          ..sort(
            (a, b) => ((a['position'] as num?) ?? 0).compareTo(
              (b['position'] as num?) ?? 0,
            ),
          );
    return ActivitySource.fromConfig(
      activity: activityFromRow(r),
      config: cfg,
      extraItems: questions.map(itemFromQuestion).nonNulls.toList(),
      contentVersion: (r['content_version'] as num?)?.toInt() ?? 1,
      difficulty: (r['difficulty'] as num?)?.toInt() ?? 1,
    );
  }
}

/// `POST /play/sync`.
class SupabasePlayRepository implements PlayRepository {
  SupabasePlayRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<SyncOutcome>> sync(List<SessionReport> reports) async {
    try {
      final res = await _db.functions.invoke(
        'play/sync',
        body: {
          'items': [for (final r in reports) r.toJson()],
        },
      );
      final results = ((res.data as Map)['results'] as List).cast<Map>();
      return [
        for (final x in results)
          SyncOutcome.fromJson(x.cast<String, dynamic>()),
      ];
    } catch (e) {
      throw mapError(e);
    }
  }
}

/// Device storage for snapshots and the outbox (shared preferences: browser storage on the web).
/// Nothing secret is stored: ids, counts and answers of a child's game.
class PrefsSessionStore implements SessionStore {
  PrefsSessionStore(this._prefs);

  final SharedPreferences _prefs;

  static const _outbox = 'kl.play.outbox';
  static String _snap(String child, String activity) =>
      'kl.play.snap.$child.$activity';

  @override
  Future<Map<String, dynamic>?> loadSnapshot(
    String childId,
    String activityId,
  ) async {
    final raw = _prefs.getString(_snap(childId, activityId));
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      await clearSnapshot(
        childId,
        activityId,
      ); // unreadable: start fresh rather than crash
      return null;
    }
  }

  @override
  Future<void> saveSnapshot(
    String childId,
    String activityId,
    Map<String, Object?> snapshot,
  ) => _prefs.setString(_snap(childId, activityId), jsonEncode(snapshot));

  @override
  Future<void> clearSnapshot(String childId, String activityId) =>
      _prefs.remove(_snap(childId, activityId));

  Map<String, dynamic> _read() {
    try {
      return (jsonDecode(_prefs.getString(_outbox) ?? '{}') as Map)
          .cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> enqueue(SessionReport report) async {
    final box = _read()..[outboxKey(report)] = report.toJson();
    // Cap: a device offline for weeks keeps the newest 200 sessions.
    while (box.length > 200) {
      box.remove(box.keys.first);
    }
    await _prefs.setString(_outbox, jsonEncode(box));
  }

  @override
  Future<List<SessionReport>> pending() async {
    final out = <SessionReport>[];
    for (final v in _read().values) {
      try {
        out.add(SessionReport.fromJson((v as Map).cast<String, dynamic>()));
      } catch (_) {
        // a corrupt entry is skipped (and dropped on the next write)
      }
    }
    return out;
  }

  @override
  Future<void> remove(Iterable<String> keys) async {
    final box = _read();
    for (final k in keys) {
      box.remove(k);
    }
    await _prefs.setString(_outbox, jsonEncode(box));
  }
}

/// In-memory store (tests, and the web demo if storage is blocked).
class MemorySessionStore implements SessionStore {
  final snapshots = <String, Map<String, dynamic>>{};
  final outbox = <String, SessionReport>{};

  @override
  Future<Map<String, dynamic>?> loadSnapshot(
    String childId,
    String activityId,
  ) async {
    final s = snapshots['$childId/$activityId'];
    return s == null
        ? null
        : (jsonDecode(jsonEncode(s)) as Map).cast<String, dynamic>();
  }

  @override
  Future<void> saveSnapshot(
    String childId,
    String activityId,
    Map<String, Object?> snapshot,
  ) async => snapshots['$childId/$activityId'] =
      (jsonDecode(jsonEncode(snapshot)) as Map).cast<String, dynamic>();

  @override
  Future<void> clearSnapshot(String childId, String activityId) async =>
      snapshots.remove('$childId/$activityId');

  @override
  Future<void> enqueue(SessionReport report) async =>
      outbox[outboxKey(report)] = report;

  @override
  Future<List<SessionReport>> pending() async => outbox.values.toList();

  @override
  Future<void> remove(Iterable<String> keys) async =>
      keys.forEach(outbox.remove);
}
