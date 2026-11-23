import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_info.dart';
import '../../../app/providers.dart';
import '../../../core/clock/clock.dart';
import '../../../core/error/failure.dart';
import '../../../core/util/ids.dart';
import '../../child_profiles/presentation/child_providers.dart';
import '../../learning/presentation/learning_providers.dart';
import '../../rewards/domain/rewards.dart';
import '../../rewards/presentation/rewards_providers.dart';
import '../domain/engine.dart';
import '../domain/item_spec.dart';
import '../domain/play_repositories.dart';
import '../domain/registry.dart';
import '../domain/session_report.dart';

/// The activity types the app knows. Override in tests to add or remove types.
final kindRegistryProvider = Provider<KindRegistry>(
  (ref) => KindRegistry.standard(),
);

/// New session ids (overridable so tests get predictable ids).
final sessionIdProvider = Provider<String Function()>((ref) => uuidV4);

final activitySourceProvider = FutureProvider.family<ActivitySource, String>(
  (ref, activityId) =>
      ref.read(activityContentRepositoryProvider).load(activityId),
);

/// `ios`, `android` or `web` (activity_sessions.platform allows only these).
String currentPlatform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => 'web',
  };
}

/// Sends session reports through the outbox: a report is stored first, then sent; if the send
/// fails (offline) it stays and goes with the next flush (next game, next app start).
final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref));

class SyncService {
  SyncService(this._ref);

  final Ref _ref;
  Future<List<SyncOutcome>>? _inFlight;

  SessionStore get _store => _ref.read(sessionStoreProvider);

  /// Stores [report], then tries to send everything waiting. Returns the server's answer for
  /// [report], or null when it couldn't be sent now (it stays in the outbox).
  Future<SyncOutcome?> submit(SessionReport report) async {
    await _store.enqueue(report);
    final outcomes = await flush();
    for (final o in outcomes) {
      if (o.sessionId == report.sessionId) {
        if (report.status != SessionStatus.started) return o;
      }
    }
    return null;
  }

  /// Sends every waiting report (oldest first: a start before its end). Never throws.
  Future<List<SyncOutcome>> flush() {
    final running = _inFlight;
    if (running != null) return running.then((_) => flush());
    final f = _flush();
    _inFlight = f;
    return f.whenComplete(() => _inFlight = null);
  }

  Future<List<SyncOutcome>> _flush() async {
    final pending = await _store.pending();
    if (pending.isEmpty) return const [];
    pending.sort((a, b) {
      final t = a.startedAt.compareTo(b.startedAt);
      return t != 0 ? t : a.status.index.compareTo(b.status.index);
    });
    try {
      final outcomes = <SyncOutcome>[];
      for (var i = 0; i < pending.length; i += 100) {
        final batch = pending.sublist(i, (i + 100).clamp(0, pending.length));
        final got = await _ref.read(playRepositoryProvider).sync(batch);
        outcomes.addAll(got);
        // What the server says each session newly earned: celebrated once, for its child.
        final childOf = {for (final r in batch) r.sessionId: r.childId};
        for (final o in got) {
          final child = childOf[o.sessionId];
          if (child == null || o.status != 'accepted') continue;
          final e = RewardEvents.fromJson(child, o.rewards);
          if (e != null) _ref.read(celebrationQueueProvider.notifier).push(e);
        }
        final settled = {
          for (final o in got)
            if (o.settled) o.sessionId,
        };
        await _store.remove([
          for (final r in batch)
            if (settled.contains(r.sessionId)) outboxKey(r),
        ]);
      }
      // Progress changed on the server: home, islands and stars refresh.
      for (final childId in {for (final r in pending) r.childId}) {
        _ref.invalidate(childProgressProvider(childId));
        _ref.invalidate(rewardsProvider(childId));
      }
      return outcomes;
    } on Failure {
      return const []; // offline or server trouble: everything stays queued
    }
  }
}

/// Which activity, from where.
typedef PlayArgs = ({
  String activityId,
  String? courseId,
  String? stepId,
  PlaySource source,
});

enum PlayerStage { loading, error, unsupported, resumeOffer, playing }

class PlayerView {
  const PlayerView({
    this.stage = PlayerStage.loading,
    this.source,
    this.run,
    this.hint = Hint.none,
    this.outcome,
    this.syncing = false,
    this.savedOffline = false,
    this.error,
    this.policy = const DifficultyPolicy(),
  });

  final PlayerStage stage;
  final ActivitySource? source;
  final RunState? run;

  /// The hint showing now for the current item.
  final Hint hint;

  /// The server's answer for the finished session (star, unlocked step).
  final SyncOutcome? outcome;
  final bool syncing;

  /// Finished, but couldn't be sent yet: it's in the outbox.
  final bool savedOffline;
  final Object? error;
  final DifficultyPolicy policy;

  PlayerView copyWith({
    PlayerStage? stage,
    ActivitySource? source,
    RunState? run,
    Hint? hint,
    SyncOutcome? outcome,
    bool? syncing,
    bool? savedOffline,
    Object? error,
    DifficultyPolicy? policy,
  }) => PlayerView(
    stage: stage ?? this.stage,
    source: source ?? this.source,
    run: run ?? this.run,
    hint: hint ?? this.hint,
    outcome: outcome ?? this.outcome,
    syncing: syncing ?? this.syncing,
    savedOffline: savedOffline ?? this.savedOffline,
    error: error,
    policy: policy ?? this.policy,
  );
}

/// How long an interrupted run can be continued; after that it is closed as abandoned.
const resumeWindow = Duration(hours: 24);

final playerProvider = NotifierProvider.autoDispose
    .family<PlayerController, PlayerView, PlayArgs>(PlayerController.new);

/// Runs one activity for the selected child: loads content, offers to continue an interrupted
/// run, drives the [SessionEngine], saves a snapshot after every step, and reports the start
/// and the end of the session through the [SyncService].
class PlayerController extends Notifier<PlayerView> {
  PlayerController(this.args);

  final PlayArgs args;
  late SessionEngine _engine;
  Map<String, dynamic>? _savedSnapshot;

  /// The content as loaded (all levels); `state.source` is the level being played.
  ActivitySource? _base;

  DateTime get _now => ref.read(clockProvider)();
  String get _childId =>
      ref.read(selectedChildIdProvider) ?? (throw const UnauthorizedFailure());
  SessionStore get _store => ref.read(sessionStoreProvider);

  @override
  PlayerView build() {
    Future.microtask(_load);
    return const PlayerView();
  }

  int get _ageMonths => ref.read(childAgeMonthsProvider) ?? 48;

  /// The child's settings, adjusted by the level being played.
  DifficultyPolicy _policyFor(ActivitySource src) {
    final p = DifficultyPolicy.forChild(
      ageMonths: _ageMonths,
      difficulty: src.difficulty,
    );
    return src.level?.apply(p) ?? p;
  }

  void _use(ActivitySource src) {
    _engine = SessionEngine(ref.read(kindRegistryProvider), _policyFor(src));
  }

  Future<void> _load() async {
    state = const PlayerView();
    try {
      final base = await ref.read(
        activitySourceProvider(args.activityId).future,
      );
      if (!ref.mounted) return;
      _base = base;
      var src = base.forLevel(base.defaultLevel(_ageMonths)?.id);
      var policy = _policyFor(src);
      _use(src);
      if (!src.playable) {
        state = PlayerView(
          stage: PlayerStage.unsupported,
          source: src,
          policy: policy,
        );
        return;
      }
      final snap = await _store.loadSnapshot(_childId, args.activityId);
      if (!ref.mounted) return;
      if (snap != null) {
        final savedAt = DateTime.tryParse('${snap['savedAt']}');
        if (savedAt != null &&
            _now.difference(savedAt) < resumeWindow &&
            snap['phase'] != 'completed') {
          _savedSnapshot = snap;
          src = base.forLevel(snap['level'] as String? ?? src.levelId);
          policy = _policyFor(src);
          _use(src);
          state = PlayerView(
            stage: PlayerStage.resumeOffer,
            source: src,
            policy: policy,
          );
          return;
        }
        await _abandonSnapshot(
          snap,
          base,
        ); // too old: close it honestly, start fresh
      }
      _fresh(src, policy);
    } on ContentException catch (e) {
      if (ref.mounted) {
        state = PlayerView(stage: PlayerStage.unsupported, error: e);
      }
    } catch (e) {
      if (ref.mounted) state = PlayerView(stage: PlayerStage.error, error: e);
    }
  }

  void _fresh(ActivitySource src, DifficultyPolicy policy) {
    final id = ref.read(sessionIdProvider)();
    final run = _engine.create(
      sessionId: id,
      childId: _childId,
      activityId: args.activityId,
      lessonStepId: args.stepId,
      items: src.build(ref.read(kindRegistryProvider), policy, id),
      now: _now,
      level: src.levelId,
    );
    state = PlayerView(
      stage: PlayerStage.playing,
      source: src,
      run: run,
      policy: policy,
    );
  }

  void retryLoad() {
    ref.invalidate(activitySourceProvider(args.activityId));
    _load();
  }

  /// "Keep going" on the resume offer.
  Future<void> continueSaved() async {
    final src = state.source!, snap = _savedSnapshot!;
    final items = src.build(
      ref.read(kindRegistryProvider),
      state.policy,
      snap['sessionId'] as String,
    );
    final restored = _engine.restore(snap, items);
    if (restored == null) {
      await _abandonSnapshot(
        snap,
        _base ?? src,
      ); // content changed since: start over
      _fresh(src, state.policy);
      return;
    }
    state = state.copyWith(
      stage: PlayerStage.playing,
      run: _engine.begin(restored, _now),
    );
    if (restored.phase == PlayPhase.completed) await _finish();
  }

  /// "Start over" on the resume offer: the old run is reported as abandoned.
  Future<void> startOver() async {
    final snap = _savedSnapshot;
    if (snap != null) await _abandonSnapshot(snap, _base ?? state.source!);
    _fresh(state.source!, state.policy);
  }

  /// On the intro: play another level (the run hasn't started, so nothing is reported).
  void chooseLevel(String levelId) {
    final base = _base, run = state.run;
    if (base == null || run == null || run.phase != PlayPhase.intro) return;
    final src = base.forLevel(levelId);
    _use(src);
    _fresh(src, _policyFor(src));
  }

  /// On the completion screen: straight into the next, harder level (a new session).
  Future<void> playNextLevel() async {
    final next = state.source?.nextLevel;
    if (next == null || _base == null) return;
    final src = _base!.forLevel(next.id);
    _use(src);
    state = state.copyWith(source: src, policy: _policyFor(src));
    await playAgain();
  }

  Future<void> _abandonSnapshot(
    Map<String, dynamic> snap,
    ActivitySource base,
  ) async {
    final src = base.forLevel(snap['level'] as String?);
    await _store.clearSnapshot(_childId, args.activityId);
    final items = src.build(
      ref.read(kindRegistryProvider),
      _policyFor(src),
      snap['sessionId'] as String,
    );
    final old = SessionEngine(
      ref.read(kindRegistryProvider),
      _policyFor(src),
    ).restore(snap, items);
    if (old == null) return;
    unawaited(
      ref
          .read(syncServiceProvider)
          .submit(
            SessionReport.ended(
              old,
              now: DateTime.tryParse('${snap['savedAt']}') ?? _now,
              source: args.source,
              platform: currentPlatform(),
              appVersion: appVersion,
              contentVersion: src.contentVersion,
            ),
          ),
    );
  }

  /// Intro → first item. Reports the start (so even an unfinished session exists).
  Future<void> start() async {
    final run = state.run;
    if (run == null) return;
    state = state.copyWith(run: _engine.begin(run, _now));
    await _save();
    unawaited(
      ref
          .read(syncServiceProvider)
          .submit(
            SessionReport.started(
              state.run!,
              source: args.source,
              platform: currentPlatform(),
              appVersion: appVersion,
              contentVersion: state.source!.contentVersion,
            ),
          ),
    );
  }

  Verdict submit(ItemAnswer answer) {
    final run = state.run;
    if (run == null) return const Verdict.wrong();
    final (next, e) = _engine.answer(run, answer, _now);
    state = state.copyWith(run: next, hint: Hint.none);
    _save();
    return e;
  }

  void retry() {
    final run = state.run;
    if (run != null) state = state.copyWith(run: _engine.retry(run, _now));
  }

  Hint useHint() {
    final run = state.run;
    if (run == null) return Hint.none;
    final (next, h) = _engine.hint(run);
    state = state.copyWith(run: next, hint: h);
    _save();
    return h;
  }

  Future<void> next() async {
    final run = state.run;
    if (run == null) return;
    state = state.copyWith(run: _engine.next(run, _now), hint: Hint.none);
    if (state.run!.phase == PlayPhase.completed) {
      await _finish();
    } else {
      await _save();
    }
  }

  void pause() {
    final run = state.run;
    if (run != null) {
      state = state.copyWith(run: _engine.pause(run, _now));
      _save();
    }
  }

  void resume() {
    final run = state.run;
    if (run != null) state = state.copyWith(run: _engine.resume(run, _now));
  }

  /// Leaving mid-way keeps the snapshot (the child can continue later); nothing is reported
  /// as abandoned yet, so finishing later still counts.
  Future<void> leave() async {
    final run = state.run;
    if (run == null ||
        run.phase == PlayPhase.completed ||
        run.phase == PlayPhase.intro) {
      return;
    }
    state = state.copyWith(run: _engine.pause(run, _now));
    await _save();
  }

  /// "Play again": a new session over the same content.
  Future<void> playAgain() async {
    final run = state.run;
    if (run == null) return;
    final id = ref.read(sessionIdProvider)();
    final src = state.source!;
    final fresh = _engine.create(
      sessionId: id,
      childId: run.childId,
      activityId: run.activityId,
      lessonStepId: run.lessonStepId,
      items: src.build(ref.read(kindRegistryProvider), state.policy, id),
      now: _now,
      run: run.run + 1,
      level: src.levelId,
    );
    state = PlayerView(
      stage: PlayerStage.playing,
      source: src,
      run: fresh,
      policy: state.policy,
    );
    await start();
  }

  Future<void> _save() async {
    final run = state.run;
    if (run == null || run.phase == PlayPhase.intro) return;
    await _store.saveSnapshot(
      run.childId,
      run.activityId,
      run.toSnapshot(_now),
    );
  }

  Future<void> _finish() async {
    final run = state.run!;
    await _store.clearSnapshot(run.childId, run.activityId);
    state = state.copyWith(syncing: true);
    final outcome = await ref
        .read(syncServiceProvider)
        .submit(
          SessionReport.ended(
            run,
            now: _now,
            source: args.source,
            platform: currentPlatform(),
            appVersion: appVersion,
            contentVersion: state.source!.contentVersion,
          ),
        );
    if (!ref.mounted) return;
    state = state.copyWith(
      syncing: false,
      outcome: outcome,
      savedOffline: outcome == null,
    );
  }
}
