/// One child's learning progress, as the server recorded it. Pure Dart.
library;

import '../../rewards/domain/rewards.dart';

export '../../rewards/domain/rewards.dart' show GoalSettings;

class Enrollment {
  const Enrollment({
    required this.courseId,
    required this.status,
    this.currentStepId,
  });

  final String courseId;

  /// `in_progress`, `completed` or `paused`.
  final String status;
  final String? currentStepId;

  bool get completed => status == 'completed';
}

class PlayedActivity {
  const PlayedActivity({required this.activityId, required this.at});

  final String activityId;
  final DateTime at;
}

class EarnedReward {
  const EarnedReward({
    required this.key,
    required this.type,
    required this.title,
    this.quantity = 1,
  });

  final String key;

  /// `sticker`, `scene`, `badge`, `avatar_item`.
  final String type;
  final String title;
  final int quantity;
}

/// Which sections the parent left on (screen_time_rules). Games are always on.
class SectionSwitches {
  const SectionSwitches({
    this.learn = true,
    this.watch = true,
    this.listen = true,
    this.together = true,
  });

  final bool learn;
  final bool watch;
  final bool listen;
  final bool together;
}

/// Where a child stopped in a video, song or story (from the last unfinished session).
class ResumePoint {
  const ResumePoint({
    this.positionMs,
    this.durationMs,
    this.page,
    this.pages,
    required this.at,
  });

  /// From a session's metrics (`{positionMs, durationMs}` or `{page, pages}`); null if none.
  static ResumePoint? fromMetrics(Map? m, DateTime at) {
    if (m == null) return null;
    int? n(Object? v) => (v as num?)?.toInt();
    final p = ResumePoint(
      positionMs: n(m['positionMs']),
      durationMs: n(m['durationMs']),
      page: n(m['page']),
      pages: n(m['pages']),
      at: at,
    );
    return p.positionMs == null && p.page == null ? null : p;
  }

  final int? positionMs;
  final int? durationMs;

  /// Stories: the page (0-based) and how many there are.
  final int? page;
  final int? pages;
  final DateTime at;

  /// 0..1, for progress bars.
  double get fraction {
    if (page != null && (pages ?? 0) > 0) return (page! + 1) / pages!;
    if (positionMs != null && (durationMs ?? 0) > 0) {
      return (positionMs! / durationMs!).clamp(0.0, 1.0);
    }
    return 0;
  }

  Map<String, Object?> toJson() => {
    'positionMs': ?positionMs,
    'durationMs': ?durationMs,
    'page': ?page,
    'pages': ?pages,
    'at': at.toUtc().toIso8601String(),
  };

  static ResumePoint? fromJson(Map? j) => j == null
      ? null
      : fromMetrics(j, DateTime.tryParse('${j['at']}') ?? DateTime.utc(2000));
}

/// The parent's media controls for this child (screen_time_rules): sections, categories, limit.
class MediaControls {
  const MediaControls({
    this.blockedCategoryIds = const {},
    this.dailyLimitMinutes,
    this.limitedSections = const {'learn', 'watch', 'listen', 'together'},
  });

  final Set<String> blockedCategoryIds;

  /// Null = no daily limit.
  final int? dailyLimitMinutes;
  final Set<String> limitedSections;
}

class ChildProgress {
  const ChildProgress({
    this.completedStepIds = const {},
    this.enrollments = const [],
    this.recent = const [],
    this.starsToday = 0,
    this.starsTotal = 0,
    this.rewards = const [],
    this.favoriteIds = const {},
    this.sections = const SectionSwitches(),
    this.controls = const MediaControls(),
    this.positions = const {},
    this.goals = const GoalSettings(),
  });

  static const empty = ChildProgress();

  final Set<String> completedStepIds;
  final List<Enrollment> enrollments;

  /// Newest first, one entry per activity.
  final List<PlayedActivity> recent;

  /// Activity stars today: the daily goal counts these (one per different activity).
  final int starsToday;

  /// The star balance: every star in the ledger, bonuses included (never goes down).
  final int starsTotal;
  final List<EarnedReward> rewards;
  final Set<String> favoriteIds;
  final SectionSwitches sections;
  final MediaControls controls;

  /// Activity id → where the child stopped (unfinished videos, songs, stories).
  final Map<String, ResumePoint> positions;

  /// The parent's learning goals (`learning_goals`, or the defaults).
  final GoalSettings goals;

  ChildProgress copyWith({
    Set<String>? completedStepIds,
    List<Enrollment>? enrollments,
    List<PlayedActivity>? recent,
    int? starsToday,
    int? starsTotal,
    List<EarnedReward>? rewards,
    Set<String>? favoriteIds,
    SectionSwitches? sections,
    MediaControls? controls,
    Map<String, ResumePoint>? positions,
    GoalSettings? goals,
  }) => ChildProgress(
    completedStepIds: completedStepIds ?? this.completedStepIds,
    enrollments: enrollments ?? this.enrollments,
    recent: recent ?? this.recent,
    starsToday: starsToday ?? this.starsToday,
    starsTotal: starsTotal ?? this.starsTotal,
    rewards: rewards ?? this.rewards,
    favoriteIds: favoriteIds ?? this.favoriteIds,
    sections: sections ?? this.sections,
    controls: controls ?? this.controls,
    positions: positions ?? this.positions,
    goals: goals ?? this.goals,
  );

  int get stickers => rewards
      .where((r) => r.type == 'sticker')
      .fold(0, (n, r) => n + r.quantity);
  List<EarnedReward> get badges =>
      rewards.where((r) => r.type == 'badge').toList();

  Enrollment? enrollment(String courseId) {
    for (final e in enrollments) {
      if (e.courseId == courseId) return e;
    }
    return null;
  }
}
