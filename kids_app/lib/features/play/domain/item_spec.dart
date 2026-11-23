/// The building blocks every activity type shares: what is asked, what can be answered, how an
/// answer is judged, and what a hint does. Pure Dart, no Flutter.
library;

import 'dart:math' as math;

import '../../learning/domain/catalog.dart';

/// A picture by reference, resolved by the app: `shape:circle`, `icon:cat`, `char:pip`,
/// `glyph:b` (a big letter / number), `half:heart:left` (one side of a shape),
/// `gap:heart:right` (a shape with one side missing), later `asset:<media id>` for real artwork.
///
/// Optional modifiers after `?` (for sorting by colour and size):
/// `shape:circle?color=red&size=small`. Colours: red, blue, yellow, green, purple, orange.
/// Sizes: small, medium, big.
class PictureRef {
  const PictureRef(this.value);

  static PictureRef? parse(Object? v) =>
      v is String && v.contains(':') ? PictureRef(v) : null;

  static const colors = {'red', 'blue', 'yellow', 'green', 'purple', 'orange'};
  static const sizes = {'small', 'medium', 'big'};

  final String value;

  String get _base =>
      value.contains('?') ? value.substring(0, value.indexOf('?')) : value;
  String get scheme => _base.substring(0, _base.indexOf(':'));
  String get name => _base.substring(_base.indexOf(':') + 1);

  Map<String, String> get params => value.contains('?')
      ? Uri.splitQueryString(value.substring(value.indexOf('?') + 1))
      : const {};

  /// One of [colors], or null for the picture's own colour.
  String? get color =>
      colors.contains(params['color']) ? params['color'] : null;

  /// One of [sizes], or null (full size).
  String? get size => sizes.contains(params['size']) ? params['size'] : null;

  /// Words for screen readers and the voice: "big red circle".
  String describe() {
    final parts = name.split(':');
    final what = switch (scheme) {
      'count' => parts.join(' '),
      'half' when parts.length > 1 => '${parts[0]}, ${parts[1]} side',
      'gap' when parts.length > 1 =>
        '${parts[0]} with the ${parts[1]} side missing',
      'glyph' when name.length == 1 && name != name.toLowerCase() =>
        'big $name',
      'glyph' when name.length == 1 && name != name.toUpperCase() =>
        'small $name',
      _ => name.replaceAll('-', ' '),
    };
    return [?size, ?color, what].join(' ');
  }

  @override
  bool operator ==(Object other) => other is PictureRef && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// What the child sees and hears for one item. Text is short (most players can't read yet);
/// [speak] is what the voice says, defaulting to the text.
class Prompt {
  const Prompt({
    this.text = const LocalizedText({}),
    this.speak = const LocalizedText({}),
    this.picture,
  });

  factory Prompt.fromJson(Object? json) {
    if (json is String) return Prompt(text: LocalizedText.fromJson(json));
    final m = json is Map ? json : const {};
    return Prompt(
      text: LocalizedText.fromJson(m['text']),
      speak: LocalizedText.fromJson(m['speak']),
      picture: PictureRef.parse(m['picture']),
    );
  }

  final LocalizedText text;
  final LocalizedText speak;
  final PictureRef? picture;

  /// What the voice reads.
  String spoken([String locale = 'en']) =>
      speak.isEmpty ? text.of(locale) : speak.of(locale);
}

/// Something tappable or draggable: an option, a card, a token, a tile.
class Choice {
  const Choice({
    required this.id,
    this.label = const LocalizedText({}),
    this.picture,
    this.speak = const LocalizedText({}),
  });

  factory Choice.fromJson(Object? json, [String? fallbackId]) {
    if (json is String) {
      return Choice(id: json, label: LocalizedText.fromJson(json));
    }
    final m = json is Map ? json : const {};
    return Choice(
      id: '${m['id'] ?? fallbackId ?? m['label'] ?? m['picture']}',
      label: LocalizedText.fromJson(m['label']),
      picture: PictureRef.parse(m['picture']),
      speak: LocalizedText.fromJson(m['speak']),
    );
  }

  final String id;
  final LocalizedText label;
  final PictureRef? picture;
  final LocalizedText speak;

  /// The name read out for this choice (screen readers and the voice).
  String spoken([String locale = 'en']) => !speak.isEmpty
      ? speak.of(locale)
      : (!label.isEmpty ? label.of(locale) : picture?.describe() ?? id);
}

/// One item (question, round) of an activity. Each activity type subclasses it.
abstract class ItemSpec {
  const ItemSpec({
    required this.id,
    required this.kind,
    required this.prompt,
    this.hintText = const LocalizedText({}),
  });

  final String id;

  /// The registered type key, e.g. `multiple_choice`.
  final String kind;
  final Prompt prompt;
  final LocalizedText hintText;

  /// Set when the item came from the `questions` table, so answers are stored per question.
  String? get questionId => null;
}

/// A child's answer. Each activity type has its own shape.
sealed class ItemAnswer {
  const ItemAnswer();

  /// Compact, JSON-safe form for the progress log.
  Object? toJson();
}

/// Picked one or more options (choice, letter / number recognition, fill the blank).
final class PickAnswer extends ItemAnswer {
  const PickAnswer(this.ids);
  final Set<String> ids;
  @override
  Object? toJson() => ids.toList()..sort();
}

/// Put things where they belong (drag to target, sorting, matching pairs). [mistakes] counts
/// the wrong drops the view already bounced back.
final class PlaceAnswer extends ItemAnswer {
  const PlaceAnswer(this.placements, {this.mistakes = 0});
  final Map<String, String> placements;
  final int mistakes;
  @override
  Object? toJson() => {'p': placements, 'm': mistakes};
}

/// Put things in order (word building, puzzles).
final class OrderAnswer extends ItemAnswer {
  const OrderAnswer(this.ids, {this.mistakes = 0});
  final List<String> ids;
  final int mistakes;
  @override
  Object? toJson() => {'o': ids, 'm': mistakes};
}

/// Found every pair (memory). [flips] counts turned pairs, including misses.
final class MemoryAnswer extends ItemAnswer {
  const MemoryAnswer({
    required this.flips,
    required this.pairsFound,
    this.timeMs,
  });
  final int flips;
  final int pairsFound;

  /// Time on the board (clock paused while the game is paused), when the clock showed.
  final int? timeMs;
  @override
  Object? toJson() => {'f': flips, 'p': pairsFound, 'ms': ?timeMs};
}

/// A point in the unit square (0..1, origin top-left).
class Pt {
  const Pt(this.x, this.y);
  final double x;
  final double y;
  double dist(Pt o) {
    final dx = x - o.x, dy = y - o.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  String toString() => '(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// Finger strokes, in the unit square (tracing).
final class TraceAnswer extends ItemAnswer {
  const TraceAnswer(this.strokes);
  final List<List<Pt>> strokes;
  @override
  Object? toJson() => {
    's': strokes.length,
    'n': strokes.fold<int>(0, (n, s) => n + s.length),
  };
}

/// The verdict on one answer.
class Verdict {
  const Verdict({required this.correct, this.mistakes = 0, this.partial = 0});

  const Verdict.right({this.mistakes = 0}) : correct = true, partial = 1;
  const Verdict.wrong({this.partial = 0}) : correct = false, mistakes = 0;

  final bool correct;

  /// Wrong sub-moves inside a correct answer (bounced drops, extra memory flips).
  final int mistakes;

  /// 0..1: how close a wrong answer was (e.g. tracing coverage). Informational.
  final double partial;
}

/// What a hint does. Level 1 says something helpful; level 2 also narrows the choice or shows
/// where to start.
class Hint {
  const Hint({
    this.text = const LocalizedText({}),
    this.eliminate = const {},
    this.reveal = const {},
  });

  static const none = Hint();

  final LocalizedText text;

  /// Option ids to grey out (choice types).
  final Set<String> eliminate;

  /// Ids to highlight (the next tile, the first pair, the start of a stroke).
  final Set<String> reveal;
}

/// Settings that depend on the child's age and the activity's difficulty.
class DifficultyPolicy {
  const DifficultyPolicy({
    this.maxAttempts = 3,
    this.maxOptions = 4,
    this.autoSpeak = true,
    this.offerHintAfterWrong = true,
    this.traceTolerance = 0.12,
  });

  /// Ages from the design brief: pre-readers hear everything, see fewer options and get more
  /// tries; older children get more options and a stricter trace.
  factory DifficultyPolicy.forChild({
    required int ageMonths,
    int difficulty = 1,
  }) {
    final young = ageMonths < 48;
    final preReader = ageMonths < 72;
    final hard = difficulty >= 3;
    return DifficultyPolicy(
      maxAttempts: preReader ? 3 : 2,
      maxOptions: young ? 3 : (preReader ? (hard ? 4 : 3) : (hard ? 6 : 4)),
      autoSpeak: preReader,
      offerHintAfterWrong: ageMonths < 60,
      traceTolerance: young ? 0.16 : (preReader ? 0.12 : 0.09),
    );
  }

  /// A game level can set its own number of options (or memory pairs) and tries.
  DifficultyPolicy copyWith({int? maxOptions, int? maxAttempts}) =>
      DifficultyPolicy(
        maxAttempts: maxAttempts ?? this.maxAttempts,
        maxOptions: maxOptions ?? this.maxOptions,
        autoSpeak: autoSpeak,
        offerHintAfterWrong: offerHintAfterWrong,
        traceTolerance: traceTolerance,
      );

  final int maxAttempts;
  final int maxOptions;
  final bool autoSpeak;
  final bool offerHintAfterWrong;

  /// How far (in the unit square) a finger may wander from the letter's path.
  final double traceTolerance;
}

/// Thrown when activity content can't be read. The player shows "Almost ready!" instead.
class ContentException implements Exception {
  const ContentException(this.message);
  final String message;
  @override
  String toString() => 'ContentException: $message';
}

/// Small deterministic random generator, so a resumed session shows the same order.
class SeededRandom {
  SeededRandom(int seed) : _state = (seed & 0x7fffffff) | 1;
  int _state;
  int nextInt(int max) {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state % max;
  }

  List<T> shuffled<T>(List<T> items) {
    final out = [...items];
    for (var i = out.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = out[i];
      out[i] = out[j];
      out[j] = t;
    }
    return out;
  }
}

int stableHash(String s) =>
    s.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x7fffffff);
