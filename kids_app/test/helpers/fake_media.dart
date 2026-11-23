import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:kids_app/features/media/domain/media.dart';
import 'package:kids_app/features/media/presentation/players.dart';

/// Fake players for widget tests: no plugins, time moves only when a test says so.
class FakeMedia {
  final videos = <FakeVideoBackend>[];
  final audios = <FakeAudioBackend>[];

  /// The next file opened fails as if the network dropped.
  bool failNextOpen = false;

  FakeVideoBackend get video => videos.last;
  FakeAudioBackend get audio => audios.last;

  VideoBackend newVideo() {
    final b = FakeVideoBackend(this);
    videos.add(b);
    return b;
  }

  AudioBackend newAudio() {
    final b = FakeAudioBackend(this);
    audios.add(b);
    return b;
  }
}

mixin _FakePlayer on MediaBackend {
  FakeMedia get media;
  final _state = ValueNotifier(const PlaybackSnapshot());
  MediaFile? opened;
  MediaFile? captionsFile;
  NowPlaying? nowPlaying;
  Duration openedAt = Duration.zero;
  bool disposed = false;
  final calls = <String>[];

  @override
  ValueListenable<PlaybackSnapshot> get state => _state;
  PlaybackSnapshot get value => _state.value;

  @override
  Future<void> open(
    MediaFile file, {
    Duration start = Duration.zero,
    MediaFile? captions,
    NowPlaying? nowPlaying,
  }) async {
    calls.add('open ${file.url} @${start.inMilliseconds}');
    opened = file;
    captionsFile = captions;
    this.nowPlaying = nowPlaying;
    openedAt = start;
    if (media.failNextOpen) {
      media.failNextOpen = false;
      _state.value = const PlaybackSnapshot(error: 'network');
      return;
    }
    _state.value = PlaybackSnapshot(
      ready: true,
      position: start,
      duration: Duration(milliseconds: file.durationMs ?? 30000),
    );
  }

  @override
  Future<void> play() async {
    calls.add('play');
    if (value.error != null) return;
    _state.value = value.copyWith(playing: true, completed: false);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _state.value = value.copyWith(playing: false);
  }

  @override
  Future<void> seek(Duration to) async {
    calls.add('seek ${to.inMilliseconds}');
    _state.value = value.copyWith(position: to, completed: false);
  }

  @override
  Future<void> setSpeed(double speed) async {
    calls.add('speed $speed');
    _state.value = value.copyWith(speed: speed);
  }

  /// Plays [by] of the file (only while playing); reaching the end completes it.
  void advance(Duration by) {
    if (!value.playing) return;
    final pos = value.position + by;
    _state.value = pos >= value.duration
        ? value.copyWith(
            position: value.duration,
            playing: false,
            completed: true,
          )
        : value.copyWith(position: pos);
  }

  void buffering(bool on) => _state.value = value.copyWith(buffering: on);
  void caption(String text) => _state.value = value.copyWith(caption: text);
  void fail() =>
      _state.value = value.copyWith(error: 'network', playing: false);

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeVideoBackend extends VideoBackend with _FakePlayer {
  FakeVideoBackend(this.media);
  @override
  final FakeMedia media;
  @override
  double get aspectRatio => 16 / 9;
  @override
  Widget view() => const SizedBox.expand(key: ValueKey('fake-video'));
}

class FakeAudioBackend extends AudioBackend with _FakePlayer {
  FakeAudioBackend(this.media);
  @override
  final FakeMedia media;
}
