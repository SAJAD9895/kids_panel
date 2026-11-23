import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_info.dart';
import '../../../app/providers.dart';
import '../../../core/audio/speech.dart';
import '../../../core/clock/clock.dart';
import '../../../core/error/failure.dart';
import '../../child_profiles/presentation/child_providers.dart';
import '../../learning/domain/catalog.dart';
import '../../learning/domain/progress.dart';
import '../../learning/presentation/learning_providers.dart';
import '../../play/domain/session_report.dart';
import '../../play/presentation/play_providers.dart';
import '../domain/media.dart';
import '../domain/media_repositories.dart';
import 'players.dart';

// =============================================================================================
// Shared: positions, visibility, the session tracker
// =============================================================================================

/// Where the child stopped in each item: the server's (any device) and this device's (instant,
/// offline), the newer one winning.
final mediaPositionsProvider =
    FutureProvider.family<Map<String, ResumePoint>, String>((
      ref,
      childId,
    ) async {
      final server = (await ref.watch(childProgressProvider(childId).future))
          .positions;
      final local = await ref
          .read(mediaPositionStoreProvider)
          .positions(childId);
      final out = {...server};
      for (final e in local.entries) {
        final s = out[e.key];
        if (s == null || e.value.at.isAfter(s.at)) out[e.key] = e.value;
      }
      // a finished item on the server (no position) beats an older local one
      return out;
    });

extension MediaVisibility on KidsData {
  /// Right age, section on, category not blocked (videos, songs, stories).
  bool canSee(ActivitySummary a) => MediaRules.visible(
    a,
    ageMonths: ageMonths,
    sections: progress.sections,
    controls: progress.controls,
  );
}

/// Reports one media session to `play/sync` (start, then completed or abandoned with where it
/// stopped), counts active time for the daily limit (`play/heartbeat` every 30 s), and keeps
/// the position on the device. Holds no `ref`: it outlives the screen that created it.
class MediaSessionTracker {
  MediaSessionTracker({
    required this.sync,
    required this.media,
    required this.positions,
    required this.newId,
    required this.now,
    required this.childId,
    required this.activityId,
    required this.section,
    required this.contentVersion,
    this.source = PlaySource.feed,
    this.lessonStepId,
    this.onLocked,
  });

  factory MediaSessionTracker.of(
    Ref ref, {
    required String childId,
    required MediaLaunch launch,
    PlaySource source = PlaySource.feed,
    String? lessonStepId,
    void Function()? onLocked,
  }) => MediaSessionTracker(
    sync: ref.read(syncServiceProvider),
    media: ref.read(mediaRepositoryProvider),
    positions: ref.read(mediaPositionStoreProvider),
    newId: ref.read(sessionIdProvider),
    now: ref.read(clockProvider),
    childId: childId,
    activityId: launch.activityId,
    section: launch.section,
    contentVersion: launch.contentVersion,
    source: source,
    lessonStepId: lessonStepId,
    onLocked: onLocked,
  );

  static const beatEvery = Duration(seconds: 30);

  final SyncService sync;
  final MediaRepository media;
  final MediaPositionStore positions;
  final String Function() newId;
  final DateTime Function() now;
  final String childId;
  final String activityId;
  final String section;
  final int contentVersion;
  final PlaySource source;
  final String? lessonStepId;
  void Function()? onLocked;

  String? _sessionId;
  DateTime? _startedAt;
  int _activeMs = 0;
  int _unreportedMs = 0;
  bool _ended = false;
  bool locked = false;

  bool get started => _sessionId != null;
  bool get ended => _ended;
  int get activeMs => _activeMs;
  String? get sessionId => _sessionId;

  SessionReport _report(
    SessionStatus status, {
    bool completed = false,
    Map<String, Object?> extra = const {},
  }) => SessionReport(
    sessionId: _sessionId!,
    childId: childId,
    activityId: activityId,
    lessonStepId: lessonStepId,
    status: status,
    startedAt: _startedAt!,
    endedAt: status == SessionStatus.started ? null : now(),
    source: source,
    platform: currentPlatform(),
    appVersion: appVersion,
    contentVersion: contentVersion,
    completed: completed,
    score: completed ? 100 : null,
    durationMs: _activeMs,
    extra: extra,
  );

  /// The first play: the session exists from now (even if the app is closed later).
  void start() {
    if (started) return;
    _sessionId = newId();
    _startedAt = now();
    unawaited(_send(_report(SessionStatus.started)));
  }

  /// Queues and sends a report. The outbox keeps it if sending fails; if the app is shutting
  /// down (the provider container is gone) there is nothing left to do.
  Future<void> _send(SessionReport r) async {
    try {
      await sync.submit(r);
    } catch (_) {}
  }

  /// Called every second while playing (or reading).
  void tick([Duration d = const Duration(seconds: 1)]) {
    if (!started || _ended) return;
    _activeMs += d.inMilliseconds;
    _unreportedMs += d.inMilliseconds;
    if (_unreportedMs >= beatEvery.inMilliseconds) unawaited(beat());
  }

  /// Sends the time not reported yet (at most 120 s per call, the server's cap).
  Future<void> beat() async {
    final secs = (_unreportedMs / 1000).floor().clamp(0, 120);
    if (secs < 1) return;
    _unreportedMs -= secs * 1000;
    try {
      final r = await media.heartbeat(
        childId: childId,
        section: section,
        seconds: secs,
      );
      if (r.locked && !locked) {
        locked = true;
        onLocked?.call();
      }
    } catch (_) {
      // offline: the time is still on the device (a later beat), and launch checks again
      _unreportedMs += secs * 1000;
    }
  }

  /// Keeps where the child is on the device (every few seconds and on pause), for an instant
  /// resume and for interruptions (the app killed mid-video).
  Future<void> remember(ResumePoint p) =>
      positions.save(childId, activityId, p);

  /// Ends the session: completed (star, cleared position) or abandoned with where it stopped.
  Future<void> end({
    required bool completed,
    Map<String, Object?> extra = const {},
  }) async {
    if (!started || _ended) return;
    _ended = true;
    await beat();
    if (completed) {
      await positions.clear(childId, activityId);
    } else {
      final p = ResumePoint.fromMetrics(extra, now());
      if (p != null) await positions.save(childId, activityId, p);
    }
    await _send(
      _report(
        completed ? SessionStatus.completed : SessionStatus.abandoned,
        completed: completed,
        extra: extra,
      ),
    );
  }
}

/// How a load can end before playing.
enum MediaStage { loading, ready, offline, error, locked, unavailable, timeUp }

MediaStage _stageFor(Object e) => switch (e) {
  NetworkFailure() => MediaStage.offline,
  ContentLockedFailure(reason: LockReason.screenTimeOver) => MediaStage.timeUp,
  ContentLockedFailure() => MediaStage.locked,
  NotFoundFailure() => MediaStage.unavailable,
  _ => MediaStage.error,
};

LockReason? _lockFor(Object e) => e is ContentLockedFailure ? e.reason : null;

/// Newest of the server's and this device's resume points.
ResumePoint? _newest(ResumePoint? a, ResumePoint? b) {
  if (a == null) return b;
  if (b == null) return a;
  return b.at.isAfter(a.at) ? b : a;
}

/// Which item, and the lesson step it was opened from (a course island), if any: finishing it
/// then completes that step on the server.
typedef MediaArgs = ({String activityId, String? stepId});

// =============================================================================================
// Video
// =============================================================================================

class VideoView {
  const VideoView({
    this.stage = MediaStage.loading,
    this.launch,
    this.lock,
    this.snapshot = const PlaybackSnapshot(),
    this.captionsOn = true,
    this.fullscreen = false,
    this.finished = false,
    this.resumedFrom,
    this.slow = false,
  });

  final MediaStage stage;
  final MediaLaunch? launch;
  final LockReason? lock;
  final PlaybackSnapshot snapshot;
  final bool captionsOn;
  final bool fullscreen;

  /// Watched to the end (completed session reported).
  final bool finished;

  /// Started from here instead of the beginning ("Continuing from 0:12").
  final Duration? resumedFrom;

  /// Buffering for more than 8 s: show "slow connection".
  final bool slow;

  bool get hasCaptions => launch?.captions() != null;

  VideoView copyWith({
    MediaStage? stage,
    MediaLaunch? launch,
    LockReason? lock,
    PlaybackSnapshot? snapshot,
    bool? captionsOn,
    bool? fullscreen,
    bool? finished,
    Duration? resumedFrom,
    bool clearResumed = false,
    bool? slow,
  }) => VideoView(
    stage: stage ?? this.stage,
    launch: launch ?? this.launch,
    lock: lock ?? this.lock,
    snapshot: snapshot ?? this.snapshot,
    captionsOn: captionsOn ?? this.captionsOn,
    fullscreen: fullscreen ?? this.fullscreen,
    finished: finished ?? this.finished,
    resumedFrom: clearResumed ? null : (resumedFrom ?? this.resumedFrom),
    slow: slow ?? this.slow,
  );
}

final videoProvider = NotifierProvider.autoDispose
    .family<VideoController, VideoView, MediaArgs>(VideoController.new);

/// Plays one video for the selected child: launch (gate + signed URL), resume, play, captions,
/// speed, full screen, time limit, and the session report when the child finishes or leaves.
class VideoController extends Notifier<VideoView> {
  VideoController(this.args);

  final MediaArgs args;
  String get activityId => args.activityId;
  VideoBackend? _backend;
  MediaSessionTracker? _tracker;
  Timer? _ticker;
  int _bufferingSecs = 0;
  int _sinceSave = 0;

  VideoBackend? get backend => _backend;

  @override
  VideoView build() {
    ref.onDispose(_dispose);
    Future.microtask(load);
    return const VideoView();
  }

  String get _childId =>
      ref.read(selectedChildIdProvider) ?? (throw const UnauthorizedFailure());

  Future<void> load() async {
    state = VideoView(captionsOn: state.captionsOn);
    try {
      final childId = _childId;
      final launch = await ref
          .read(mediaRepositoryProvider)
          .launch(childId: childId, activityId: activityId);
      if (!ref.mounted) return;
      final video = launch.video;
      if (video == null) {
        state = state.copyWith(stage: MediaStage.unavailable, launch: launch);
        return;
      }
      final local = (await ref
          .read(mediaPositionStoreProvider)
          .positions(childId))[activityId];
      final start = MediaRules.resumeAt(
        _newest(launch.resume, local),
        duration: video.durationMs == null
            ? null
            : Duration(milliseconds: video.durationMs!),
      );
      final b = _backend = ref.read(videoBackendFactoryProvider)();
      _tracker = MediaSessionTracker.of(
        ref,
        childId: childId,
        launch: launch,
        onLocked: _timeUp,
        source: args.stepId == null ? PlaySource.feed : PlaySource.course,
        lessonStepId: args.stepId,
      );
      b.state.addListener(_onSnapshot);
      state = state.copyWith(
        stage: MediaStage.ready,
        launch: launch,
        resumedFrom: start,
      );
      await b.open(
        video,
        start: start ?? Duration.zero,
        captions: launch.captions(),
      );
      if (!ref.mounted) return;
      if (b.state.value.error == null) await b.play();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(stage: _stageFor(e), lock: _lockFor(e));
    }
  }

  void _onSnapshot() {
    final b = _backend;
    if (b == null || !ref.mounted) return;
    final s = b.state.value;
    state = state.copyWith(snapshot: s, slow: s.buffering ? null : false);
    if (s.playing) _tracker?.start();
    if (!state.finished &&
        s.ready &&
        (s.completed ||
            (!s.playing && MediaRules.finished(s.position, s.duration)))) {
      state = state.copyWith(finished: true);
      unawaited(
        _tracker?.end(
          completed: true,
          extra: {
            'positionMs': s.duration.inMilliseconds,
            'durationMs': s.duration.inMilliseconds,
          },
        ),
      );
    }
  }

  void _tick() {
    final s = state.snapshot;
    final t = _tracker;
    if (t == null) return;
    if (s.playing && !s.buffering) {
      t.tick();
      if (++_sinceSave >= 5) {
        _sinceSave = 0;
        unawaited(t.remember(_point(s)));
      }
    }
    _bufferingSecs = s.buffering ? _bufferingSecs + 1 : 0;
    if (_bufferingSecs == 8 && ref.mounted) state = state.copyWith(slow: true);
  }

  ResumePoint _point(PlaybackSnapshot s) => ResumePoint(
    positionMs: s.position.inMilliseconds,
    durationMs: s.duration.inMilliseconds,
    at: ref.read(clockProvider)(),
  );

  void _timeUp() {
    unawaited(_backend?.pause());
    if (ref.mounted) state = state.copyWith(stage: MediaStage.timeUp);
  }

  Future<void> toggle() async {
    final b = _backend;
    if (b == null) return;
    final s = b.state.value;
    if (s.playing) {
      await b.pause();
      unawaited(_tracker?.remember(_point(s)));
    } else {
      if (state.finished || s.completed) {
        await b.seek(Duration.zero);
        state = state.copyWith(finished: false);
        _tracker = _tracker == null
            ? null
            : MediaSessionTracker.of(
                ref,
                childId: _childId,
                launch: state.launch!,
                onLocked: _timeUp,
              );
      }
      await b.play();
    }
  }

  Future<void> pause() async => _backend?.pause();

  Future<void> seek(Duration to) async {
    final d = state.snapshot.duration;
    await _backend?.seek(
      Duration(milliseconds: to.inMilliseconds.clamp(0, d.inMilliseconds)),
    );
  }

  Future<void> skip(Duration by) => seek(state.snapshot.position + by);

  Future<void> setSpeed(double speed) async => _backend?.setSpeed(speed);

  void toggleCaptions() =>
      state = state.copyWith(captionsOn: !state.captionsOn);

  void setFullscreen(bool on) => state = state.copyWith(fullscreen: on);

  /// "Start again": from the beginning, even after a resume.
  Future<void> restart() async {
    await seek(Duration.zero);
    state = state.copyWith(clearResumed: true);
    await _backend?.play();
  }

  /// After a network error: reopen where it stopped.
  Future<void> retry() async {
    final b = _backend, launch = state.launch;
    if (b == null || launch?.video == null) return load();
    final at = state.snapshot.position;
    state = state.copyWith(
      snapshot: const PlaybackSnapshot(buffering: true),
      slow: false,
    );
    await b.open(launch!.video!, start: at, captions: launch.captions());
    if (b.state.value.error == null) await b.play();
  }

  /// Leaving: save where the child stopped and close the session.
  Future<void> leave() async {
    final s = _backend?.state.value;
    final t = _tracker;
    if (s == null || t == null || state.finished) return;
    await _backend?.pause();
    await t.end(
      completed: MediaRules.finished(s.position, s.duration),
      extra: {
        'positionMs': s.position.inMilliseconds,
        'durationMs': s.duration.inMilliseconds,
      },
    );
  }

  void _dispose() {
    _ticker?.cancel();
    final b = _backend;
    _backend = null;
    final s = b?.state.value;
    final t = _tracker;
    if (t != null && s != null && !t.ended) {
      unawaited(
        t.end(
          completed: MediaRules.finished(s.position, s.duration),
          extra: {
            'positionMs': s.position.inMilliseconds,
            'durationMs': s.duration.inMilliseconds,
          },
        ),
      );
    }
    b?.state.removeListener(_onSnapshot);
    unawaited(b?.dispose());
  }
}

// =============================================================================================
// Songs (one player for the whole app: keeps playing while the child browses, and in the
// background where the platform allows)
// =============================================================================================

class AudioView {
  const AudioView({
    this.stage = MediaStage.loading,
    this.queue,
    this.titles = const {},
    this.launch,
    this.lock,
    this.snapshot = const PlaybackSnapshot(),
    this.active = false,
  });

  final MediaStage stage;
  final SongQueue? queue;

  /// Song id → title (for the mini player and the list).
  final Map<String, String> titles;
  final MediaLaunch? launch;
  final LockReason? lock;
  final PlaybackSnapshot snapshot;

  /// A song is loaded (the mini player shows).
  final bool active;

  String? get currentId => queue?.current;
  String get title => titles[currentId] ?? '';

  AudioView copyWith({
    MediaStage? stage,
    SongQueue? queue,
    Map<String, String>? titles,
    MediaLaunch? launch,
    LockReason? lock,
    PlaybackSnapshot? snapshot,
    bool? active,
    bool clearLaunch = false,
  }) => AudioView(
    stage: stage ?? this.stage,
    queue: queue ?? this.queue,
    titles: titles ?? this.titles,
    launch: clearLaunch ? null : (launch ?? this.launch),
    lock: lock ?? this.lock,
    snapshot: snapshot ?? this.snapshot,
    active: active ?? this.active,
  );
}

final audioProvider = NotifierProvider<AudioController, AudioView>(
  AudioController.new,
);

class AudioController extends Notifier<AudioView> {
  AudioBackend? _backend;
  MediaSessionTracker? _tracker;
  Timer? _ticker;
  bool _advancing = false;
  int _sinceSave = 0;

  @override
  AudioView build() {
    // A different child (or signing out) stops the music.
    ref.listen(selectedChildIdProvider, (prev, next) {
      if (prev != next) unawaited(stop());
    });
    ref.onDispose(() {
      _ticker?.cancel();
      unawaited(_backend?.dispose());
    });
    return const AudioView(stage: MediaStage.ready);
  }

  /// Plays [ids] (a song list) from [startId].
  /// The lesson step of the song the child opened (only that song completes it).
  String? _step;
  String? _stepSong;

  Future<void> playList(
    List<ActivitySummary> songs, {
    required String startId,
    String? stepId,
  }) async {
    _step = stepId;
    _stepSong = startId;
    final queue = SongQueue([for (final s in songs) s.id], start: startId);
    state = state.copyWith(
      queue: queue,
      titles: {for (final s in songs) s.id: s.title.of()},
      active: true,
    );
    await _loadCurrent(resume: true);
  }

  Future<void> _endTrack({bool? completed}) async {
    final t = _tracker;
    final s = _backend?.state.value;
    _tracker = null;
    if (t == null || s == null) return;
    await t.end(
      completed: completed ?? MediaRules.finished(s.position, s.duration),
      extra: {
        'positionMs': s.position.inMilliseconds,
        'durationMs': s.duration.inMilliseconds,
      },
    );
  }

  Future<void> _loadCurrent({bool resume = false}) async {
    final id = state.currentId;
    final childId = ref.read(selectedChildIdProvider);
    if (id == null || childId == null) return;
    state = state.copyWith(
      stage: MediaStage.loading,
      clearLaunch: true,
      snapshot: const PlaybackSnapshot(buffering: true),
    );
    try {
      final launch = await ref
          .read(mediaRepositoryProvider)
          .launch(childId: childId, activityId: id);
      if (state.currentId != id) return; // the child moved on meanwhile
      final audio = launch.audio;
      if (audio == null) {
        state = state.copyWith(stage: MediaStage.unavailable, launch: launch);
        return;
      }
      final local = (await ref
          .read(mediaPositionStoreProvider)
          .positions(childId))[id];
      final start = resume
          ? MediaRules.resumeAt(_newest(launch.resume, local))
          : null;
      final b = _backend ??= ref.read(audioBackendFactoryProvider)()
        ..state.addListener(_onSnapshot);
      final step = id == _stepSong ? _step : null;
      _tracker = MediaSessionTracker.of(
        ref,
        childId: childId,
        launch: launch,
        onLocked: _timeUp,
        source: step == null ? PlaySource.feed : PlaySource.course,
        lessonStepId: step,
      );
      state = state.copyWith(stage: MediaStage.ready, launch: launch);
      await b.open(
        audio,
        start: start ?? Duration.zero,
        nowPlaying: NowPlaying(id: id, title: state.title),
      );
      if (b.state.value.error == null) await b.play();
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } catch (e) {
      state = state.copyWith(stage: _stageFor(e), lock: _lockFor(e));
    }
  }

  void _onSnapshot() {
    final s = _backend?.state.value;
    if (s == null) return;
    state = state.copyWith(snapshot: s);
    if (s.playing) _tracker?.start();
    if (s.completed && !_advancing && _tracker != null && _tracker!.started) {
      _advancing = true;
      unawaited(_afterCompletion().whenComplete(() => _advancing = false));
    }
  }

  Future<void> _afterCompletion() async {
    await _endTrack(completed: true);
    final next = state.queue?.afterCompletion();
    if (next == null) {
      state = state.copyWith(snapshot: state.snapshot.copyWith(playing: false));
      return;
    }
    state = state.copyWith(queue: next);
    await _loadCurrent();
  }

  void _tick() {
    final s = state.snapshot;
    final t = _tracker;
    if (t == null || !s.playing) return;
    t.tick();
    if (++_sinceSave >= 5) {
      _sinceSave = 0;
      unawaited(
        t.remember(
          ResumePoint(
            positionMs: s.position.inMilliseconds,
            durationMs: s.duration.inMilliseconds,
            at: ref.read(clockProvider)(),
          ),
        ),
      );
    }
  }

  void _timeUp() {
    unawaited(_backend?.pause());
    state = state.copyWith(stage: MediaStage.timeUp);
  }

  Future<void> toggle() async {
    final b = _backend;
    if (b == null) return;
    if (b.state.value.playing) {
      await b.pause();
    } else {
      if (b.state.value.completed) await b.seek(Duration.zero);
      if (_tracker == null || _tracker!.ended) {
        // the list had ended: start the song again as a new session
        await _loadCurrent();
        return;
      }
      await b.play();
    }
  }

  Future<void> next() async {
    final q = state.queue?.next();
    if (q == null) return;
    await _endTrack();
    state = state.copyWith(queue: q);
    await _loadCurrent();
  }

  Future<void> previous() async {
    final q = state.queue;
    if (q == null) return;
    final (prev, restart) = q.previous(state.snapshot.position);
    if (restart) {
      await _backend?.seek(Duration.zero);
      return;
    }
    await _endTrack();
    state = state.copyWith(queue: prev);
    await _loadCurrent();
  }

  Future<void> select(String id) async {
    final q = state.queue;
    if (q == null || q.current == id) return;
    await _endTrack();
    state = state.copyWith(queue: q.select(id));
    await _loadCurrent();
  }

  Future<void> seek(Duration to) async => _backend?.seek(to);

  void cycleRepeat() {
    final q = state.queue;
    if (q != null) state = state.copyWith(queue: q.cycleRepeat());
  }

  void toggleShuffle() {
    final q = state.queue;
    if (q != null) state = state.copyWith(queue: q.toggleShuffle());
  }

  Future<void> retry() => _loadCurrent(resume: true);

  /// Closes the player (the mini player's ✕, a child switch): saves where it stopped.
  Future<void> stop() async {
    await _backend?.pause();
    await _endTrack();
    _ticker?.cancel();
    _ticker = null;
    final b = _backend;
    _backend = null;
    b?.state.removeListener(_onSnapshot);
    await b?.dispose();
    state = const AudioView(stage: MediaStage.ready);
  }
}

// =============================================================================================
// Stories
// =============================================================================================

class StoryView {
  const StoryView({
    this.stage = MediaStage.loading,
    this.launch,
    this.lock,
    this.page = 0,
    this.sentence = -1,
    this.narrating = false,
    this.readToMe = true,
    this.slowVoice = false,
    this.finished = false,
    this.startedFrom,
  });

  final MediaStage stage;
  final MediaLaunch? launch;
  final LockReason? lock;
  final int page;

  /// The sentence being read (highlighted), −1 for none.
  final int sentence;
  final bool narrating;

  /// "Read to me" turns the pages by itself after each page is read.
  final bool readToMe;
  final bool slowVoice;

  /// The last page was reached (completed session reported).
  final bool finished;

  /// Opened on this page (continue reading).
  final int? startedFrom;

  List<StoryPage> get pages => launch?.pages ?? const [];

  StoryView copyWith({
    MediaStage? stage,
    MediaLaunch? launch,
    LockReason? lock,
    int? page,
    int? sentence,
    bool? narrating,
    bool? readToMe,
    bool? slowVoice,
    bool? finished,
    int? startedFrom,
  }) => StoryView(
    stage: stage ?? this.stage,
    launch: launch ?? this.launch,
    lock: lock ?? this.lock,
    page: page ?? this.page,
    sentence: sentence ?? this.sentence,
    narrating: narrating ?? this.narrating,
    readToMe: readToMe ?? this.readToMe,
    slowVoice: slowVoice ?? this.slowVoice,
    finished: finished ?? this.finished,
    startedFrom: startedFrom ?? this.startedFrom,
  );
}

final storyProvider = NotifierProvider.autoDispose
    .family<StoryController, StoryView, MediaArgs>(StoryController.new);

/// Reads one story: pages, narration (recorded audio when a page has it, else the device's
/// voice sentence by sentence, with the sentence highlighted), reading progress, continue
/// reading, and the session report.
class StoryController extends Notifier<StoryView> {
  StoryController(this.args);

  final MediaArgs args;
  String get activityId => args.activityId;
  MediaSessionTracker? _tracker;
  Timer? _ticker;
  Timer? _turn;
  AudioBackend? _pageAudio;
  late SpeechService _speech;
  int _run = 0; // bumped to cancel a narration in progress
  bool _paused = false;

  /// The page and page count, kept outside `state` for dispose (which can't read state).
  int _page = 0;
  int _pages = 0;

  @override
  set state(StoryView value) {
    _page = value.page;
    _pages = value.pages.length;
    super.state = value;
  }

  @override
  StoryView build() {
    _speech = ref.read(speechProvider);
    ref.onDispose(_dispose);
    Future.microtask(load);
    return const StoryView();
  }

  Future<void> load() async {
    state = const StoryView();
    try {
      final childId =
          ref.read(selectedChildIdProvider) ??
          (throw const UnauthorizedFailure());
      final launch = await ref
          .read(mediaRepositoryProvider)
          .launch(childId: childId, activityId: activityId);
      if (!ref.mounted) return;
      if (launch.pages.isEmpty) {
        state = state.copyWith(stage: MediaStage.unavailable, launch: launch);
        return;
      }
      final local = (await ref
          .read(mediaPositionStoreProvider)
          .positions(childId))[activityId];
      final start = StoryRules.startPage(
        _newest(launch.resume, local),
        launch.pages.length,
      );
      _tracker = MediaSessionTracker.of(
        ref,
        childId: childId,
        launch: launch,
        onLocked: _timeUp,
        source: args.stepId == null ? PlaySource.feed : PlaySource.course,
        lessonStepId: args.stepId,
      )..start();
      state = state.copyWith(
        stage: MediaStage.ready,
        launch: launch,
        page: start,
        startedFrom: start,
      );
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_paused) _tracker?.tick();
      });
      _checkFinished();
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(stage: _stageFor(e), lock: _lockFor(e));
    }
  }

  void _timeUp() {
    stopNarration();
    if (ref.mounted) state = state.copyWith(stage: MediaStage.timeUp);
  }

  /// The app went to the background (or came back): narration and the reading clock stop.
  void setPaused(bool paused) {
    _paused = paused;
    if (paused) stopNarration();
  }

  void _checkFinished() {
    final n = state.pages.length;
    if (state.finished || !StoryRules.finished(state.page, n)) return;
    state = state.copyWith(finished: true);
    unawaited(
      _tracker?.end(completed: true, extra: {'page': n - 1, 'pages': n}),
    );
  }

  void _savePage() {
    final t = _tracker;
    if (t == null) return;
    unawaited(
      t.remember(
        ResumePoint(
          page: state.page,
          pages: state.pages.length,
          at: ref.read(clockProvider)(),
        ),
      ),
    );
  }

  Future<void> goTo(int page, {bool keepReading = false}) async {
    final n = state.pages.length;
    if (n == 0) return;
    final p = page.clamp(0, n - 1);
    final wasReading = state.narrating;
    await stopNarration();
    state = state.copyWith(page: p, sentence: -1);
    _savePage();
    _checkFinished();
    if (keepReading || (wasReading && state.readToMe)) unawaited(play());
  }

  Future<void> nextPage() => goTo(state.page + 1);
  Future<void> previousPage() => goTo(state.page - 1);

  void setReadToMe(bool on) => state = state.copyWith(readToMe: on);
  void setSlowVoice(bool on) => state = state.copyWith(slowVoice: on);

  /// Reads the page from the sentence it stopped at (or the start).
  Future<void> play() async {
    if (state.narrating || state.pages.isEmpty) return;
    final run = ++_run;
    final page = state.pages[state.page];
    state = state.copyWith(narrating: true);
    final ok = page.narration != null
        ? await _playRecorded(page.narration!, run)
        : await _readAloud(page, run);
    if (run != _run || !ref.mounted) return;
    state = state.copyWith(
      narrating: false,
      sentence: ok ? -1 : state.sentence,
    );
    if (ok && state.readToMe && state.page < state.pages.length - 1) {
      _turn = Timer(const Duration(milliseconds: 1200), () {
        if (run == _run && ref.mounted) goTo(state.page + 1, keepReading: true);
      });
    }
  }

  Future<bool> _readAloud(StoryPage page, int run) async {
    final sentences = page.sentences();
    var i = state.sentence < 0 ? 0 : state.sentence;
    while (i < sentences.length) {
      state = state.copyWith(sentence: i);
      final done = await _speech.narrate(
        sentences[i],
        rate: state.slowVoice ? 0.75 : 1.0,
      );
      if (!done || run != _run || !ref.mounted) return false;
      i++;
    }
    return true;
  }

  Future<bool> _playRecorded(MediaFile audio, int run) async {
    final b = _pageAudio ??= ref.read(audioBackendFactoryProvider)();
    final done = Completer<bool>();
    void listen() {
      final s = b.state.value;
      if (s.completed && !done.isCompleted) done.complete(true);
      if (s.error != null && !done.isCompleted) done.complete(false);
    }

    b.state.addListener(listen);
    if (b.state.value.position == Duration.zero || b.state.value.completed) {
      await b.open(audio);
    }
    await b.setSpeed(state.slowVoice ? 0.85 : 1.0);
    await b.play();
    _stopRecorded = () {
      if (!done.isCompleted) done.complete(false);
    };
    final ok = await done.future;
    b.state.removeListener(listen);
    return ok && run == _run;
  }

  void Function()? _stopRecorded;

  Future<void> stopNarration() async {
    _run++;
    _turn?.cancel();
    await _speech.stop();
    await _pageAudio?.pause();
    _stopRecorded?.call();
    _stopRecorded = null;
    if (ref.mounted && state.narrating) {
      state = state.copyWith(narrating: false);
    }
  }

  /// Leaving: remember the page and close the session (finished stories are already reported).
  Future<void> leave() async {
    await stopNarration();
    final t = _tracker;
    if (t == null || t.ended) return;
    await t.end(
      completed: false,
      extra: {'page': state.page, 'pages': state.pages.length},
    );
  }

  void _dispose() {
    _run++;
    _ticker?.cancel();
    _turn?.cancel();
    unawaited(_speech.stop());
    final t = _tracker;
    if (t != null && !t.ended) {
      unawaited(
        t.end(completed: false, extra: {'page': _page, 'pages': _pages}),
      );
    }
    unawaited(_pageAudio?.dispose());
  }
}
