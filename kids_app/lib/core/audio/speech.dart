import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// The voice of the app: reads instructions, questions and feedback aloud for children who
/// can't read yet. Text-to-speech for now (works offline on phones, the Web Speech API in
/// browsers); recorded voice-over files will play through the same interface (M4).
abstract interface class SpeechService {
  Future<void> speak(String text, {String locale = 'en'});

  /// Reads [text] and completes when it has been read (true) or was stopped (false). Story
  /// narration reads sentence by sentence with this, so pausing stops at once and resuming
  /// starts the sentence again. [rate] 1.0 = the normal (already slow) reading speed.
  Future<bool> narrate(String text, {String locale = 'en', double rate = 1.0});
  Future<void> stop();
}

class TtsSpeechService implements SpeechService {
  TtsSpeechService() : _tts = FlutterTts();

  final FlutterTts _tts;
  String? _language;
  double _rate = 1.0;
  int _generation = 0; // bumped by stop(): a stopped narration reports false

  @override
  Future<void> speak(String text, {String locale = 'en'}) async {
    if (text.trim().isEmpty) return;
    try {
      final lang = locale == 'es' ? 'es-ES' : 'en-GB';
      if (_language != lang) {
        await _tts.setLanguage(lang);
        await _tts.setSpeechRate(0.42); // slower than default: young listeners
        _language = lang;
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // No voice on this device / browser: the text and pictures still carry the game.
    }
  }

  @override
  Future<bool> narrate(
    String text, {
    String locale = 'en',
    double rate = 1.0,
  }) async {
    if (text.trim().isEmpty) return true;
    final mine = ++_generation;
    try {
      final lang = locale == 'es' ? 'es-ES' : 'en-GB';
      if (_language != lang) {
        await _tts.setLanguage(lang);
        _language = lang;
      }
      if (_rate != rate) _rate = rate;
      await _tts.setSpeechRate(0.42 * rate);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(text);
      return mine == _generation;
    } catch (_) {
      return false; // no voice: the reader still shows the words
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Silent voice that remembers what it would have said (tests, and when sound is off).
class RecordingSpeechService implements SpeechService {
  final said = <String>[];

  /// Sentences narrated, in order.
  final narrated = <String>[];

  /// When true, narration waits until [finishNarration] (tests step through a story);
  /// when false, each sentence "finishes" straight away.
  bool holdNarration = false;
  Completer<bool>? _pending;

  bool get narrating => _pending != null;

  @override
  Future<void> speak(String text, {String locale = 'en'}) async =>
      said.add(text);

  @override
  Future<bool> narrate(String text, {String locale = 'en', double rate = 1.0}) {
    narrated.add(text);
    if (!holdNarration) return Future.value(true);
    final c = Completer<bool>();
    _pending = c;
    return c.future;
  }

  /// Ends the sentence being read (as if the voice reached its end).
  void finishNarration() {
    final c = _pending;
    _pending = null;
    c?.complete(true);
  }

  @override
  Future<void> stop() async {
    final c = _pending;
    _pending = null;
    c?.complete(false);
  }
}
