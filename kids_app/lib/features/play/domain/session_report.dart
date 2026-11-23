import '../../learning/domain/catalog.dart';
import 'engine.dart';
import 'item_spec.dart';
import 'kinds/choice_kinds.dart';
import 'registry.dart';

/// One difficulty level of a game (`games.config.levels[]`): its own items, and optionally its
/// own number of options (or memory pairs) and tries. Levels go from easiest to hardest.
class GameLevel {
  const GameLevel({
    required this.id,
    required this.rawItems,
    this.label = const LocalizedText({}),
    this.minAgeMonths = 0,
    this.maxOptions,
    this.maxAttempts,
  });

  factory GameLevel.fromJson(Map<String, dynamic> j, int index) => GameLevel(
    id: '${j['id'] ?? 'level-${index + 1}'}',
    label: LocalizedText.fromJson(j['label']),
    minAgeMonths: (j['minAgeMonths'] as num?)?.toInt() ?? 0,
    maxOptions: (j['options'] as num?)?.toInt(),
    maxAttempts: (j['attempts'] as num?)?.toInt(),
    rawItems: [
      for (final e in (j['items'] as List?) ?? const [])
        (e as Map).cast<String, dynamic>(),
    ],
  );

  final String id;
  final LocalizedText label;

  /// The level picked first for a child this old (the hardest one they're old enough for).
  final int minAgeMonths;
  final int? maxOptions;
  final int? maxAttempts;
  final List<Map<String, dynamic>> rawItems;

  DifficultyPolicy apply(DifficultyPolicy p) =>
      p.copyWith(maxOptions: maxOptions, maxAttempts: maxAttempts);
}

/// Activity content as stored: the raw items are parsed per session (the session seed decides
/// option order), so the same content can be played many times.
///
/// A game either has one list of items (`config.items`) or several [levels]
/// (`config.levels`); with levels, [forLevel] picks the one being played.
class ActivitySource {
  const ActivitySource({
    required this.activity,
    required this.rawItems,
    this.intro = const Prompt(),
    this.contentVersion = 1,
    this.difficulty = 1,
    this.levels = const [],
    this.levelId,
  });

  /// Reads `games.config` (`{intro, items}` or `{intro, levels:[{id, label, items, …}]}`) plus
  /// items from the questions table. The same code for Supabase and the demo backend.
  factory ActivitySource.fromConfig({
    required ActivitySummary activity,
    required Map<String, dynamic> config,
    List<Map<String, dynamic>> extraItems = const [],
    int contentVersion = 1,
    int difficulty = 1,
  }) {
    final levels = [
      for (final (i, l) in ((config['levels'] as List?) ?? const []).indexed)
        GameLevel.fromJson((l as Map).cast<String, dynamic>(), i),
    ].where((l) => l.rawItems.isNotEmpty).toList();
    return ActivitySource(
      activity: activity,
      rawItems: [
        for (final e in (config['items'] as List?) ?? const [])
          (e as Map).cast<String, dynamic>(),
        ...extraItems,
      ],
      intro: Prompt.fromJson(config['intro']),
      contentVersion: contentVersion,
      difficulty: difficulty,
      levels: levels,
    );
  }

  final ActivitySummary activity;
  final Prompt intro;
  final List<Map<String, dynamic>> rawItems;
  final int contentVersion;
  final int difficulty;
  final List<GameLevel> levels;

  /// The level these [rawItems] belong to (null for a game without levels).
  final String? levelId;

  /// True when the engine can play it (it has items).
  bool get playable => rawItems.isNotEmpty || levels.isNotEmpty;

  GameLevel? get level => levels.where((l) => l.id == levelId).firstOrNull;

  /// The harder level after the one being played, if any.
  GameLevel? get nextLevel {
    final i = levels.indexWhere((l) => l.id == levelId);
    return i >= 0 && i < levels.length - 1 ? levels[i + 1] : null;
  }

  /// The hardest level a child of [ageMonths] is old enough for.
  GameLevel? defaultLevel(int ageMonths) => levels.isEmpty
      ? null
      : levels.lastWhere(
          (l) => l.minAgeMonths <= ageMonths,
          orElse: () => levels.first,
        );

  /// This content with the items of level [id] (unknown id or no levels: unchanged).
  ActivitySource forLevel(String? id) {
    final l = levels.where((x) => x.id == id).firstOrNull;
    if (l == null) return this;
    return ActivitySource(
      activity: activity,
      rawItems: l.rawItems,
      intro: intro,
      contentVersion: contentVersion,
      difficulty: difficulty,
      levels: levels,
      levelId: l.id,
    );
  }

  /// Parses every item with a seed from the session id. Throws [ContentException] when an item
  /// can't be read: the player then shows "Almost ready!" instead of a broken game.
  List<ItemSpec> build(
    KindRegistry registry,
    DifficultyPolicy policy,
    String sessionId,
  ) {
    final p = level?.apply(policy) ?? policy;
    final prefix = levelId == null ? '' : '$levelId/';
    return [
      for (var i = 0; i < rawItems.length; i++)
        registry.parseItem(
          rawItems[i],
          ParseContext(
            itemId: '$prefix${rawItems[i]['questionId'] ?? 'i$i'}',
            seed: stableHash('$sessionId/$prefix$i'),
            policy: p,
          ),
        ),
    ];
  }
}

enum SessionStatus { started, completed, abandoned }

/// Where the child opened the activity from (activity_sessions.source).
enum PlaySource {
  feed,
  search,
  collection,
  course,
  favorite,
  shuffle,
  together,
  learningPath,
  offline,
}

/// What the app uploads for one session (`POST /play/sync` item). Built from a [RunState].
/// It names the child and activity; the server checks both against the signed-in parent.
class SessionReport {
  const SessionReport({
    required this.sessionId,
    required this.childId,
    required this.activityId,
    required this.status,
    required this.startedAt,
    required this.source,
    required this.platform,
    required this.appVersion,
    this.lessonStepId,
    this.endedAt,
    this.contentVersion = 1,
    this.completed = false,
    this.score,
    this.correctCount,
    this.totalCount,
    this.incorrectCount = 0,
    this.hintsUsed = 0,
    this.durationMs = 0,
    this.items = const [],
    this.responses = const [],
    this.run = 1,
    this.level,
    this.extra = const {},
  });

  final String sessionId;
  final String childId;
  final String activityId;
  final String? lessonStepId;
  final SessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final PlaySource source;
  final String platform;
  final String appVersion;
  final int contentVersion;
  final bool completed;
  final int? score;
  final int? correctCount;
  final int? totalCount;
  final int incorrectCount;
  final int hintsUsed;
  final int durationMs;
  final int run;

  /// The game level played (null for games without levels).
  final String? level;

  /// More metrics: media sessions save where they stopped (`positionMs`, `durationMs`, or
  /// `page`, `pages` for stories) so the child can continue there, on any device.
  final Map<String, Object?> extra;

  /// Per item: kind, right, wrong tries, mistakes, hints, revealed, time.
  final List<Map<String, Object?>> items;

  /// Per question and attempt, for items from the questions table.
  final List<Map<String, Object?>> responses;

  static String _source(PlaySource s) =>
      s == PlaySource.learningPath ? 'learning_path' : s.name;

  /// Start report: sent when play begins, so a session that never finishes still exists.
  factory SessionReport.started(
    RunState s, {
    required PlaySource source,
    required String platform,
    required String appVersion,
    int contentVersion = 1,
  }) => SessionReport(
    sessionId: s.sessionId,
    childId: s.childId,
    activityId: s.activityId,
    lessonStepId: s.lessonStepId,
    status: SessionStatus.started,
    startedAt: s.startedAt,
    source: source,
    platform: platform,
    appVersion: appVersion,
    contentVersion: contentVersion,
    run: s.run,
    level: s.level,
  );

  /// End report: completed (every item done) or abandoned (left before the end).
  factory SessionReport.ended(
    RunState s, {
    required DateTime now,
    required PlaySource source,
    required String platform,
    required String appVersion,
    int contentVersion = 1,
  }) {
    final completed = s.phase == PlayPhase.completed;
    final done = s.progress.where((p) => p.done).length;
    return SessionReport(
      sessionId: s.sessionId,
      childId: s.childId,
      activityId: s.activityId,
      lessonStepId: s.lessonStepId,
      status: completed ? SessionStatus.completed : SessionStatus.abandoned,
      startedAt: s.startedAt,
      endedAt: s.endedAt ?? now,
      source: source,
      platform: platform,
      appVersion: appVersion,
      contentVersion: contentVersion,
      completed: completed,
      score: completed ? s.score : null,
      correctCount: s.correctCount,
      totalCount: completed ? s.items.length : done,
      incorrectCount: s.incorrectCount,
      hintsUsed: s.hintsUsed,
      durationMs: s.activeMsAt(now),
      run: s.run,
      level: s.level,
      items: [
        for (var i = 0; i < s.items.length && i < 60; i++)
          {
            'k': s.items[i].kind,
            'ok': s.progress[i].correct,
            'w': s.progress[i].wrongAttempts,
            'm': s.progress[i].mistakes,
            'h': s.progress[i].hintLevel,
            'r': s.progress[i].revealed,
            't': s.progress[i].spentMs,
          },
      ],
      responses: [
        for (var i = 0; i < s.items.length; i++)
          if (s.items[i].questionId != null)
            for (var a = 0; a < s.progress[i].answers.length && a < 20; a++)
              {
                'questionId': s.items[i].questionId,
                'attempt': a + 1,
                'isCorrect':
                    s.progress[i].correct &&
                    a == s.progress[i].answers.length - 1,
                'answerId': _answerId(s.items[i], s.progress[i].answers[a]),
                'responseMs': a == s.progress[i].answers.length - 1
                    ? s.progress[i].spentMs
                    : null,
              },
      ],
    );
  }

  static String? _answerId(ItemSpec spec, Object? logged) {
    if (spec is! ChoiceSpec || logged is! List || logged.isEmpty) return null;
    return spec.answerIds['${logged.first}'];
  }

  /// The `/play/sync` item.
  Map<String, Object?> toJson() => {
    'session': {
      'id': sessionId,
      'childId': childId,
      'activityId': activityId,
      'lessonStepId': ?lessonStepId,
      'source': _source(source),
      'platform': platform,
      'appVersion': appVersion,
      'contentVersion': contentVersion,
      'status': status.name,
      'startedAt': startedAt.toUtc().toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
    },
    if (status != SessionStatus.started)
      'result': {
        'completed': completed,
        'score': ?score,
        'correctCount': ?correctCount,
        'totalCount': ?totalCount,
        'durationMs': durationMs,
        'metrics': {
          'items': items,
          'incorrect': incorrectCount,
          'hints': hintsUsed,
          'run': run,
          'level': ?level,
          ...extra,
        },
      },
    if (responses.isNotEmpty) 'responses': responses,
  };

  factory SessionReport.fromJson(Map<String, dynamic> j) {
    final s = (j['session'] as Map).cast<String, dynamic>();
    final r = (j['result'] as Map?)?.cast<String, dynamic>();
    final m = (r?['metrics'] as Map?)?.cast<String, dynamic>();
    return SessionReport(
      sessionId: s['id'] as String,
      childId: s['childId'] as String,
      activityId: s['activityId'] as String,
      lessonStepId: s['lessonStepId'] as String?,
      status: SessionStatus.values.byName(s['status'] as String),
      startedAt: DateTime.parse(s['startedAt'] as String),
      endedAt: s['endedAt'] == null
          ? null
          : DateTime.parse(s['endedAt'] as String),
      source: PlaySource.values.firstWhere(
        (p) => _source(p) == s['source'],
        orElse: () => PlaySource.feed,
      ),
      platform: s['platform'] as String,
      appVersion: s['appVersion'] as String,
      contentVersion: (s['contentVersion'] as num?)?.toInt() ?? 1,
      completed: r?['completed'] as bool? ?? false,
      score: (r?['score'] as num?)?.toInt(),
      correctCount: (r?['correctCount'] as num?)?.toInt(),
      totalCount: (r?['totalCount'] as num?)?.toInt(),
      durationMs: (r?['durationMs'] as num?)?.toInt() ?? 0,
      incorrectCount: (m?['incorrect'] as num?)?.toInt() ?? 0,
      hintsUsed: (m?['hints'] as num?)?.toInt() ?? 0,
      run: (m?['run'] as num?)?.toInt() ?? 1,
      level: m?['level'] as String?,
      extra: {
        for (final e in (m ?? const {}).entries)
          if (!const {
            'items',
            'incorrect',
            'hints',
            'run',
            'level',
          }.contains(e.key))
            e.key: e.value,
      },
      items: [
        for (final x in (m?['items'] as List?) ?? const [])
          (x as Map).cast<String, Object?>(),
      ],
      responses: [
        for (final x in (j['responses'] as List?) ?? const [])
          (x as Map).cast<String, Object?>(),
      ],
    );
  }
}

/// The server's answer for one uploaded session.
class SyncOutcome {
  const SyncOutcome({
    required this.sessionId,
    required this.status,
    this.starAwarded = false,
    this.starsToday,
    this.stepCompleted = false,
    this.nextStepId,
    this.courseCompleted = false,
    this.reason,
    this.rewards,
  });

  final String sessionId;

  /// `accepted`, `duplicate` or `rejected`.
  final String status;
  final bool starAwarded;
  final int? starsToday;
  final bool stepCompleted;
  final String? nextStepId;
  final bool courseCompleted;
  final String? reason;

  /// What this session newly earned (private.apply_rewards): stars, badges, goals, streak.
  /// Read with `RewardEvents.fromJson`. Null for replays and unrewarded sessions.
  final Map<String, dynamic>? rewards;

  /// Delivered (or already there): remove it from the outbox. A rejected item won't succeed
  /// on retry either, so it is dropped too (and logged).
  bool get settled =>
      status == 'accepted' || status == 'duplicate' || status == 'rejected';

  factory SyncOutcome.fromJson(Map<String, dynamic> j) => SyncOutcome(
    sessionId: j['sessionId'] as String,
    status: j['status'] as String? ?? 'accepted',
    starAwarded: j['starAwarded'] as bool? ?? false,
    starsToday: (j['starsToday'] as num?)?.toInt(),
    stepCompleted: j['stepCompleted'] as bool? ?? false,
    nextStepId: j['nextStepId'] as String?,
    courseCompleted: j['courseCompleted'] as bool? ?? false,
    reason: j['reason'] as String?,
    rewards: (j['rewards'] as Map?)?.cast<String, dynamic>(),
  );
}
