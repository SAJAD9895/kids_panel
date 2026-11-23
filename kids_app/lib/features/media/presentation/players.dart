import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:video_player/video_player.dart';

import '../domain/media.dart';

/// What the screen shows on the lock screen / notification while audio plays in the background.
class NowPlaying {
  const NowPlaying({required this.id, required this.title, this.artUrl});

  final String id;
  final String title;
  final String? artUrl;
}

/// One player, video or audio, behind the same small surface: open a file (at a position),
/// play, pause, seek, speed. The screens and controllers never touch a plugin directly, so the
/// tests drive a fake and a plugin can change without touching the UI.
abstract class MediaBackend {
  ValueListenable<PlaybackSnapshot> get state;

  /// Opens [file], starting at [start]. Errors (network, unsupported file) arrive in
  /// [state] as `error`, never as an exception.
  Future<void> open(
    MediaFile file, {
    Duration start = Duration.zero,
    MediaFile? captions,
    NowPlaying? nowPlaying,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration to);
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}

abstract class VideoBackend extends MediaBackend {
  /// The picture (letterboxed by the caller with [aspectRatio]).
  Widget view();
  double get aspectRatio;
}

abstract class AudioBackend extends MediaBackend {}

/// Reads a small text file (captions) from the app bundle or the network.
Future<String?> loadText(MediaFile f) async {
  try {
    if (f.isAsset) return await rootBundle.loadString(f.assetPath);
    final res = await http
        .get(Uri.parse(f.url))
        .timeout(const Duration(seconds: 15));
    return res.statusCode == 200 ? res.body : null;
  } catch (_) {
    return null; // no captions is better than no video
  }
}

/// `video_player`: progressive MP4 from a signed URL (the plugin streams it in byte ranges; it
/// never downloads the whole file first), or from the app bundle in demo mode.
class VideoPlayerBackend extends VideoBackend {
  final _state = ValueNotifier(const PlaybackSnapshot());
  VideoPlayerController? _c;

  @override
  ValueListenable<PlaybackSnapshot> get state => _state;

  @override
  double get aspectRatio {
    final v = _c?.value;
    return v != null && v.isInitialized && v.aspectRatio > 0
        ? v.aspectRatio
        : 16 / 9;
  }

  @override
  Widget view() => _c == null ? const SizedBox.shrink() : VideoPlayer(_c!);

  @override
  Future<void> open(
    MediaFile file, {
    Duration start = Duration.zero,
    MediaFile? captions,
    NowPlaying? nowPlaying,
  }) async {
    await _release();
    _state.value = const PlaybackSnapshot(buffering: true);
    final vtt = captions == null ? null : loadText(captions);
    final captionFile = vtt?.then<ClosedCaptionFile>(
      (t) => WebVTTCaptionFile(t ?? 'WEBVTT\n'),
    );
    final c = file.isAsset
        ? VideoPlayerController.asset(
            file.assetPath,
            closedCaptionFile: captionFile,
          )
        : VideoPlayerController.networkUrl(
            Uri.parse(file.url),
            closedCaptionFile: captionFile,
          );
    _c = c;
    c.addListener(_sync);
    try {
      await c.initialize().timeout(const Duration(seconds: 25));
      if (start > Duration.zero) await c.seekTo(start);
      _sync();
    } catch (e) {
      _state.value = _state.value.copyWith(buffering: false, error: e);
    }
  }

  void _sync() {
    final c = _c;
    if (c == null) return;
    final v = c.value;
    if (v.hasError) {
      _state.value = _state.value.copyWith(
        error: v.errorDescription ?? 'error',
        buffering: false,
        playing: false,
      );
      return;
    }
    _state.value = PlaybackSnapshot(
      position: v.position,
      duration: v.duration,
      buffered: v.buffered.isEmpty ? Duration.zero : v.buffered.last.end,
      playing: v.isPlaying,
      buffering: v.isBuffering || !v.isInitialized,
      ready: v.isInitialized,
      completed: v.isCompleted,
      speed: v.playbackSpeed,
      caption: v.caption.text,
    );
  }

  @override
  Future<void> play() async => _c?.play();
  @override
  Future<void> pause() async => _c?.pause();
  @override
  Future<void> seek(Duration to) async => _c?.seekTo(to);
  @override
  Future<void> setSpeed(double speed) async => _c?.setPlaybackSpeed(speed);

  Future<void> _release() async {
    final c = _c;
    _c = null;
    if (c == null) return;
    c.removeListener(_sync);
    await c.dispose();
  }

  @override
  Future<void> dispose() async {
    await _release();
    _state.dispose();
  }
}

/// `just_audio`: songs, story narration. With `just_audio_background` initialised (mobile),
/// playback continues with the screen off and shows on the lock screen; `audio_session` pauses
/// it for phone calls and other apps' audio.
class JustAudioBackend extends AudioBackend {
  JustAudioBackend() {
    _subs = [
      _p.playerStateStream.listen((s) => _emit()),
      _p.positionStream.listen((_) => _emit()),
      _p.bufferedPositionStream.listen((_) => _emit()),
      _p.durationStream.listen((_) => _emit()),
      _p.playbackEventStream.listen(
        (_) {},
        onError: (Object e, StackTrace _) =>
            _state.value = _state.value.copyWith(error: e, buffering: false),
      ),
    ];
  }

  final _p = ja.AudioPlayer();
  final _state = ValueNotifier(const PlaybackSnapshot());
  late final List<StreamSubscription<Object?>> _subs;

  /// Whether background playback is available (set by bootstrap after a successful init).
  static bool backgroundReady = false;

  @override
  ValueListenable<PlaybackSnapshot> get state => _state;

  void _emit() {
    final s = _p.playerState;
    final ps = s.processingState;
    _state.value = _state.value.copyWith(
      position: _p.position,
      duration: _p.duration ?? Duration.zero,
      buffered: _p.bufferedPosition,
      playing: s.playing && ps != ja.ProcessingState.completed,
      buffering:
          ps == ja.ProcessingState.loading ||
          ps == ja.ProcessingState.buffering,
      ready:
          ps == ja.ProcessingState.ready || ps == ja.ProcessingState.completed,
      completed: ps == ja.ProcessingState.completed,
      speed: _p.speed,
    );
  }

  @override
  Future<void> open(
    MediaFile file, {
    Duration start = Duration.zero,
    MediaFile? captions,
    NowPlaying? nowPlaying,
  }) async {
    _state.value = const PlaybackSnapshot(buffering: true);
    final tag = backgroundReady && nowPlaying != null
        ? MediaItem(
            id: nowPlaying.id,
            title: nowPlaying.title,
            artUri: nowPlaying.artUrl == null
                ? null
                : Uri.tryParse(nowPlaying.artUrl!),
          )
        : null;
    final source = file.isAsset
        ? ja.AudioSource.asset(file.assetPath, tag: tag)
        : ja.AudioSource.uri(Uri.parse(file.url), tag: tag);
    try {
      await _p
          .setAudioSource(source, initialPosition: start)
          .timeout(const Duration(seconds: 25));
      _emit();
    } catch (e) {
      _state.value = _state.value.copyWith(error: e, buffering: false);
    }
  }

  @override
  Future<void> play() async {
    unawaited(_p.play()); // completes when playback stops, not when it starts
  }

  @override
  Future<void> pause() => _p.pause();
  @override
  Future<void> seek(Duration to) => _p.seek(to);
  @override
  Future<void> setSpeed(double speed) => _p.setSpeed(speed);

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _p.dispose();
    _state.dispose();
  }
}
