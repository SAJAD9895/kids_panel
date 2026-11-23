import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../learning/domain/progress.dart';
import '../domain/media.dart';
import '../domain/media_repositories.dart';

/// `POST /play/launch`, `POST /play/heartbeat` and `PUT /children/:id/screen-time`. The user
/// comes from the JWT; the Edge Function checks the child belongs to this parent.
class SupabaseMediaRepository
    implements MediaRepository, MediaControlsRepository {
  SupabaseMediaRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<MediaLaunch> launch({
    required String childId,
    required String activityId,
  }) async {
    try {
      final res = await _db.functions.invoke(
        'play/launch',
        body: {'childId': childId, 'activityId': activityId},
      );
      return MediaLaunch.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<HeartbeatResult> heartbeat({
    required String childId,
    required String section,
    required int seconds,
  }) async {
    try {
      final res = await _db.functions.invoke(
        'play/heartbeat',
        body: {
          'childId': childId,
          'section': section,
          'seconds': seconds.clamp(1, 120),
        },
      );
      final m = (res.data as Map).cast<String, dynamic>();
      return HeartbeatResult(
        remainingSeconds: (m['remainingSeconds'] as num?)?.toInt(),
        locked: m['locked'] as bool? ?? false,
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> saveControls(
    String childId, {
    required SectionSwitches sections,
    required MediaControls controls,
  }) async {
    try {
      await _db.functions.invoke(
        'children/$childId/screen-time',
        method: HttpMethod.put,
        body: controlsBody(sections, controls),
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  /// The request body (public for tests).
  static Map<String, Object?> controlsBody(
    SectionSwitches sections,
    MediaControls controls,
  ) => {
    'learnEnabled': sections.learn,
    'watchEnabled': sections.watch,
    'listenEnabled': sections.listen,
    'togetherEnabled': sections.together,
    'dailyLimitMinutes': controls.dailyLimitMinutes,
    'limitedSections': controls.limitedSections.toList()..sort(),
    'blockedCategoryIds': controls.blockedCategoryIds.toList()..sort(),
  };
}

/// Positions on the device (shared preferences; browser storage on the web). One small JSON
/// map per child, newest 50 kept.
class PrefsMediaPositionStore implements MediaPositionStore {
  PrefsMediaPositionStore(this._prefs);

  final SharedPreferences _prefs;
  static String _key(String child) => 'kl.media.pos.$child';

  Map<String, dynamic> _read(String child) {
    try {
      return (jsonDecode(_prefs.getString(_key(child)) ?? '{}') as Map)
          .cast<String, dynamic>();
    } catch (_) {
      return {}; // unreadable: forget it rather than crash
    }
  }

  @override
  Future<Map<String, ResumePoint>> positions(String childId) async => {
    for (final e in _read(childId).entries)
      e.key: ?ResumePoint.fromJson(e.value as Map?),
  };

  @override
  Future<void> save(String childId, String activityId, ResumePoint p) async {
    final m = _read(childId)
      ..remove(activityId)
      ..[activityId] = p.toJson();
    while (m.length > 50) {
      m.remove(m.keys.first);
    }
    await _prefs.setString(_key(childId), jsonEncode(m));
  }

  @override
  Future<void> clear(String childId, String activityId) async {
    final m = _read(childId)..remove(activityId);
    await _prefs.setString(_key(childId), jsonEncode(m));
  }
}

class MemoryMediaPositionStore implements MediaPositionStore {
  final saved = <String, Map<String, ResumePoint>>{};

  @override
  Future<Map<String, ResumePoint>> positions(String childId) async => {
    ...?saved[childId],
  };

  @override
  Future<void> save(String childId, String activityId, ResumePoint p) async =>
      (saved[childId] ??= {})[activityId] = p;

  @override
  Future<void> clear(String childId, String activityId) async =>
      saved[childId]?.remove(activityId);
}
