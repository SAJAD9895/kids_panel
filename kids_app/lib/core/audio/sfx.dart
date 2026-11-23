import 'package:audioplayers/audioplayers.dart';

/// The game sound effects (assets/sfx, made by tool/gen_sfx.py).
enum Sfx { tap, flip, snap, match, correct, tryAgain, complete }

/// Short sounds for taps, flips, drops and feedback. Separate from the voice so a parent can
/// turn sounds off and keep the spoken instructions (or the other way round).
abstract interface class SoundEffects {
  Future<void> play(Sfx sound);
  Future<void> dispose();
}

String sfxAsset(Sfx s) => switch (s) {
  Sfx.tryAgain => 'sfx/try_again.wav',
  _ => 'sfx/${s.name}.wav',
};

/// One reusable player per sound, created on first use. Failures (no audio device, a browser
/// that blocks sound before the first tap) are swallowed: the game works without sound.
class AudioSoundEffects implements SoundEffects {
  final _players = <Sfx, AudioPlayer>{};

  @override
  Future<void> play(Sfx sound) async {
    try {
      final p = _players[sound] ??= AudioPlayer()
        ..setReleaseMode(ReleaseMode.stop);
      await p.stop();
      await p.play(AssetSource(sfxAsset(sound)), volume: 0.7);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    for (final p in _players.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}

/// Silent sounds that remember what would have played (tests, and the default).
class RecordingSoundEffects implements SoundEffects {
  final played = <Sfx>[];

  @override
  Future<void> play(Sfx sound) async => played.add(sound);

  @override
  Future<void> dispose() async {}
}
