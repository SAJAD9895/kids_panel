import 'dart:math' as math;

import 'item_spec.dart';
import 'registry.dart';

/// The player's stages.
enum PlayPhase {
  /// Character, title, "Play" and "Listen".
  intro,

  /// An item waits for an answer.
  question,

  /// Feedback after an answer (right, try again, or here's the answer).
  feedback,

  /// All items done: the completion screen.
  completed,
}

enum FeedbackKind { correct, tryAgain, revealed }

/// What happened to one item.
class ItemProgress {
  const ItemProgress({
    this.wrongAttempts = 0,
    this.mistakes = 0,
    this.hintLevel = 0,
    this.correct = false,
    this.revealed = false,
    this.answers = const [],
    this.spentMs = 0,
  });

  /// Wrong answers submitted (each try after the first is a retry).
  final int wrongAttempts;

  /// Wrong sub-moves inside the final answer (bounced drops, extra memory flips).
  final int mistakes;
  final int hintLevel;
  final bool correct;

  /// Shown the answer after the last try.
  final bool revealed;

  /// Every answer given, compact, in order (for the progress log).
  final List<Object?> answers;
  final int spentMs;

  bool get done => correct || revealed;
  int get attempts => wrongAttempts + (correct ? 1 : 0);

  ItemProgress copyWith({
    int? wrongAttempts,
    int? mistakes,
    int? hintLevel,
    bool? correct,
    bool? revealed,
    List<Object?>? answers,
    int? spentMs,
  }) => ItemProgress(
    wrongAttempts: wrongAttempts ?? this.wrongAttempts,
    mistakes: mistakes ?? this.mistakes,
    hintLevel: hintLevel ?? this.hintLevel,
    correct: correct ?? this.correct,
    revealed: revealed ?? this.revealed,
    answers: answers ?? this.answers,
    spentMs: spentMs ?? this.spentMs,
  );

  /// 0..1: full marks first time; less for retries, mistakes and hints; 0 when revealed.
  double get points {
    if (!correct) return 0;
    final p = 1 - 0.25 * wrongAttempts - 0.1 * mistakes - 0.1 * hintLevel;
    return p.clamp(0.25, 1.0);
  }

  Map<String, Object?> toJson() => {
    'w': wrongAttempts,
    'm': mistakes,
    'h': hintLevel,
    'c': correct,
    'r': revealed,
    'a': answers,
    't': spentMs,
  };

  factory ItemProgress.fromJson(Map<String, dynamic> j) => ItemProgress(
    wrongAttempts: (j['w'] as num?)?.toInt() ?? 0,
    mistakes: (j['m'] as num?)?.toInt() ?? 0,
    hintLevel: (j['h'] as num?)?.toInt() ?? 0,
    correct: j['c'] as bool? ?? false,
    revealed: j['r'] as bool? ?? false,
    answers: (j['a'] as List?) ?? const [],
    spentMs: (j['t'] as num?)?.toInt() ?? 0,
  );
}

/// One run of one activity by one child. Immutable; [SessionEngine] makes the next one.
class RunState {
  const RunState({
    required this.sessionId,
    required this.childId,
    required this.activityId,
    required this.items,
    required this.progress,
    required this.startedAt,
    this.lessonStepId,
    this.phase = PlayPhase.intro,
    this.index = 0,
    this.feedback,
    this.activeMs = 0,
    this.resumedAt,
    this.itemShownAt,
    this.endedAt,
    this.run = 1,
    this.level,
  });

  final String sessionId;
  final String childId;
  final String activityId;
  final String? lessonStepId;
  final List<ItemSpec> items;
  final List<ItemProgress> progress;
  final PlayPhase phase;
  final int index;
  final FeedbackKind? feedback;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// Time actually playing (pauses and the intro don't count), up to [resumedAt].
  final int activeMs;

  /// When the current playing stretch began (null while paused or not started).
  final DateTime? resumedAt;

  /// When the current item appeared (for per-item time).
  final DateTime? itemShownAt;

  /// 1 for the first play of this activity in a row, 2 after "Play again", …
  final int run;

  /// The game level being played (null for games without levels).
  final String? level;

  ItemSpec get item => items[index];
  ItemProgress get current => progress[index];
  bool get isLast => index == items.length - 1;

  int get correctCount => progress.where((p) => p.correct).length;

  /// Wrong answers plus wrong sub-moves, over every item.
  int get incorrectCount =>
      progress.fold(0, (n, p) => n + p.wrongAttempts + p.mistakes);
  int get hintsUsed => progress.fold(0, (n, p) => n + p.hintLevel);

  /// 0..100.
  int get score => items.isEmpty
      ? 0
      : (100 * progress.fold<double>(0, (n, p) => n + p.points) / items.length)
            .round();

  /// 1–3 celebration stars on the completion screen (the daily star comes from the server).
  int get celebrationStars => score >= 85 ? 3 : (score >= 60 ? 2 : 1);

  int activeMsAt(DateTime now) =>
      activeMs +
      (resumedAt == null
          ? 0
          : math.max<int>(0, now.difference(resumedAt!).inMilliseconds));

  RunState copyWith({
    List<ItemProgress>? progress,
    PlayPhase? phase,
    int? index,
    FeedbackKind? feedback,
    bool clearFeedback = false,
    int? activeMs,
    DateTime? resumedAt,
    bool clearResumedAt = false,
    DateTime? itemShownAt,
    DateTime? endedAt,
  }) => RunState(
    sessionId: sessionId,
    childId: childId,
    activityId: activityId,
    lessonStepId: lessonStepId,
    items: items,
    progress: progress ?? this.progress,
    startedAt: startedAt,
    phase: phase ?? this.phase,
    index: index ?? this.index,
    feedback: clearFeedback ? null : (feedback ?? this.feedback),
    activeMs: activeMs ?? this.activeMs,
    resumedAt: clearResumedAt ? null : (resumedAt ?? this.resumedAt),
    itemShownAt: itemShownAt ?? this.itemShownAt,
    endedAt: endedAt ?? this.endedAt,
    run: run,
    level: level,
  );

  /// What's saved on the device so an interrupted session can continue. Item content isn't
  /// saved: it is re-read and must parse to the same ids (seeded by the session id).
  Map<String, Object?> toSnapshot(DateTime now) => {
    'v': 1,
    'sessionId': sessionId,
    'childId': childId,
    'activityId': activityId,
    'lessonStepId': lessonStepId,
    'itemIds': [for (final i in items) i.id],
    'index': index,
    'phase': phase == PlayPhase.completed ? 'completed' : 'question',
    'progress': [for (final p in progress) p.toJson()],
    'startedAt': startedAt.toUtc().toIso8601String(),
    'activeMs': activeMsAt(now),
    'run': run,
    'level': ?level,
    'savedAt': now.toUtc().toIso8601String(),
  };
}

/// The rules of a run. Pure: every method takes a state and returns the next one, so the player
/// UI, the tests and resuming all share one implementation.
class SessionEngine {
  const SessionEngine(this.registry, this.policy);

  final KindRegistry registry;
  final DifficultyPolicy policy;

  RunState create({
    required String sessionId,
    required String childId,
    required String activityId,
    required List<ItemSpec> items,
    required DateTime now,
    String? lessonStepId,
    int run = 1,
    String? level,
  }) {
    if (items.isEmpty) {
      throw const ContentException('an activity needs at least one item');
    }
    return RunState(
      sessionId: sessionId,
      childId: childId,
      activityId: activityId,
      lessonStepId: lessonStepId,
      items: items,
      progress: List.filled(items.length, const ItemProgress()),
      startedAt: now,
      run: run,
      level: level,
    );
  }

  /// Rebuilds a saved run. Returns null when the content changed since (different items), so
  /// the caller starts fresh instead of mixing two versions.
  RunState? restore(Map<String, dynamic> snap, List<ItemSpec> items) {
    final ids = (snap['itemIds'] as List?)?.cast<String>();
    if (snap['v'] != 1 || ids == null || ids.length != items.length) {
      return null;
    }
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] != items[i].id) return null;
    }
    final progress = [
      for (final p in snap['progress'] as List)
        ItemProgress.fromJson((p as Map).cast<String, dynamic>()),
    ];
    if (progress.length != items.length) return null;
    var index = ((snap['index'] as num?)?.toInt() ?? 0).clamp(
      0,
      items.length - 1,
    );
    // An item finished just before the interruption: continue with the next one.
    while (progress[index].done && index < items.length - 1) {
      index++;
    }
    return RunState(
      sessionId: snap['sessionId'] as String,
      childId: snap['childId'] as String,
      activityId: snap['activityId'] as String,
      lessonStepId: snap['lessonStepId'] as String?,
      items: items,
      progress: progress,
      startedAt: DateTime.parse(snap['startedAt'] as String),
      phase: progress.every((p) => p.done)
          ? PlayPhase.completed
          : PlayPhase.question,
      index: index,
      activeMs: (snap['activeMs'] as num?)?.toInt() ?? 0,
      run: (snap['run'] as num?)?.toInt() ?? 1,
      level: snap['level'] as String?,
    );
  }

  /// Intro → first item, or back into play after a resume.
  RunState begin(RunState s, DateTime now) {
    if (s.phase == PlayPhase.completed) return s;
    return s.copyWith(
      phase: s.phase == PlayPhase.intro ? PlayPhase.question : s.phase,
      resumedAt: s.resumedAt ?? now,
      itemShownAt: now,
    );
  }

  /// Stops the clock (pause sheet, app in the background).
  RunState pause(RunState s, DateTime now) => s.resumedAt == null
      ? s
      : s.copyWith(activeMs: s.activeMsAt(now), clearResumedAt: true);

  RunState resume(RunState s, DateTime now) =>
      s.resumedAt != null ||
          s.phase == PlayPhase.completed ||
          s.phase == PlayPhase.intro
      ? s
      : s.copyWith(resumedAt: now);

  /// Judges an answer. Right → "correct". Wrong with tries left → "try again". Wrong on the
  /// last try → "revealed" (the answer is shown, no more tries).
  (RunState, Verdict) answer(RunState s, ItemAnswer a, DateTime now) {
    if (s.phase != PlayPhase.question || s.current.done) {
      return (s, const Verdict.wrong());
    }
    final e = registry.evaluate(s.item, a);
    final p = s.current;
    final spent =
        p.spentMs +
        (s.itemShownAt == null
            ? 0
            : math.max<int>(0, now.difference(s.itemShownAt!).inMilliseconds));
    final log = [...p.answers, a.toJson()];
    final ItemProgress next;
    final FeedbackKind fb;
    if (e.correct) {
      next = p.copyWith(
        correct: true,
        mistakes: e.mistakes,
        answers: log,
        spentMs: spent,
      );
      fb = FeedbackKind.correct;
    } else if (p.wrongAttempts + 1 >= policy.maxAttempts) {
      next = p.copyWith(
        wrongAttempts: p.wrongAttempts + 1,
        revealed: true,
        answers: log,
        spentMs: spent,
      );
      fb = FeedbackKind.revealed;
    } else {
      next = p.copyWith(
        wrongAttempts: p.wrongAttempts + 1,
        answers: log,
        spentMs: spent,
      );
      fb = FeedbackKind.tryAgain;
    }
    final progress = [...s.progress]..[s.index] = next;
    return (
      s.copyWith(
        progress: progress,
        phase: PlayPhase.feedback,
        feedback: fb,
        itemShownAt: now,
      ),
      e,
    );
  }

  /// "Try again" after a wrong answer: back to the same item.
  RunState retry(RunState s, DateTime now) {
    if (s.phase != PlayPhase.feedback || s.feedback != FeedbackKind.tryAgain) {
      return s;
    }
    return s.copyWith(
      phase: PlayPhase.question,
      clearFeedback: true,
      itemShownAt: now,
    );
  }

  /// The next hint for the current item. When the type has nothing more, the last hint repeats
  /// and the level doesn't rise (so the score isn't lowered for nothing).
  (RunState, Hint) hint(RunState s) {
    if (s.phase != PlayPhase.question) return (s, Hint.none);
    final level = s.current.hintLevel + 1;
    final h = registry.hint(s.item, level);
    final empty = h.text.isEmpty && h.eliminate.isEmpty && h.reveal.isEmpty;
    final previous = registry.hint(s.item, s.current.hintLevel);
    final same =
        h.eliminate.length == previous.eliminate.length &&
        h.reveal.length == previous.reveal.length &&
        h.text.of() == previous.text.of() &&
        s.current.hintLevel > 0;
    if (empty || same) return (s, previous);
    final progress = [...s.progress]
      ..[s.index] = s.current.copyWith(hintLevel: level);
    return (s.copyWith(progress: progress), h);
  }

  /// After "correct" or "revealed": the next item, or the end.
  RunState next(RunState s, DateTime now) {
    if (s.phase != PlayPhase.feedback || s.feedback == FeedbackKind.tryAgain) {
      return s;
    }
    if (s.isLast) {
      return s.copyWith(
        phase: PlayPhase.completed,
        clearFeedback: true,
        activeMs: s.activeMsAt(now),
        clearResumedAt: true,
        endedAt: now,
      );
    }
    return s.copyWith(
      index: s.index + 1,
      phase: PlayPhase.question,
      clearFeedback: true,
      itemShownAt: now,
    );
  }

  /// "Play again": a new session over the same items, everything reset.
  RunState again(
    RunState s, {
    required String sessionId,
    required DateTime now,
  }) => RunState(
    sessionId: sessionId,
    childId: s.childId,
    activityId: s.activityId,
    lessonStepId: s.lessonStepId,
    items: s.items,
    progress: List.filled(s.items.length, const ItemProgress()),
    startedAt: now,
    phase: PlayPhase.question,
    resumedAt: now,
    itemShownAt: now,
    run: s.run + 1,
  );
}
