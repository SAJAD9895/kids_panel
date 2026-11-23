import 'dart:math' as math;

import '../../../learning/domain/catalog.dart';
import '../item_spec.dart';
import '../registry.dart';

/// Memory: cards face down, find the pairs.
class MemorySpec extends ItemSpec {
  const MemorySpec({
    required super.id,
    required super.kind,
    required super.prompt,
    required this.cards,
    super.hintText,
    this.timer = false,
  });

  /// Show a clock (Memory Match). The move counter always shows.
  final bool timer;

  /// The deck, already shuffled. Two cards with the same [Choice.id] prefix make a pair:
  /// ids are `<pair>#1` and `<pair>#2`.
  final List<Choice> cards;

  int get pairs => cards.length ~/ 2;

  static String pairOf(String cardId) => cardId.split('#').first;
}

/// `{"kind":"memory","cards":[{"id":"cat","picture":"icon:cat"},{"id":"dog","picture":"icon:dog"}]}`
class MemoryKind extends ActivityKind<MemorySpec> {
  const MemoryKind();
  @override
  String get key => 'memory';

  @override
  MemorySpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final raw = json['cards'] is List ? json['cards'] as List : const [];
    final faces = [
      for (var i = 0; i < raw.length; i++) Choice.fromJson(raw[i], 'c$i'),
    ];
    if (faces.length < 2 || faces.length > 8) {
      throw const ContentException('memory needs 2..8 different cards');
    }
    // Younger children get fewer pairs.
    final keep = faces.take(math.max(2, ctx.policy.maxOptions)).toList();
    final deck = [
      for (final f in keep) ...[
        Choice(
          id: '${f.id}#1',
          label: f.label,
          picture: f.picture,
          speak: f.speak,
        ),
        Choice(
          id: '${f.id}#2',
          label: f.label,
          picture: f.picture,
          speak: f.speak,
        ),
      ],
    ];
    return MemorySpec(
      id: ctx.itemId,
      kind: key,
      prompt: Prompt.fromJson(
        json['prompt'] ??
            const {
              'text': 'Find the pairs',
              'speak': 'Turn two cards. Can you find the pairs?',
            },
      ),
      hintText: LocalizedText.fromJson(json['hint']),
      cards: ctx.random.shuffled(deck),
      timer: json['timer'] == true,
    );
  }

  /// Always right once every pair is found; extra flips beyond a careful player's count as
  /// mistakes (a perfect game turns each pair once; a little guessing is expected).
  @override
  Verdict evaluate(MemorySpec spec, ItemAnswer answer) {
    if (answer is! MemoryAnswer || answer.pairsFound < spec.pairs) {
      return const Verdict.wrong();
    }
    final allowance = spec.pairs * 2;
    return Verdict.right(mistakes: math.max(0, answer.flips - allowance));
  }

  /// Level 2: show where one pair is.
  @override
  Hint hint(MemorySpec spec, int level) {
    const text = LocalizedText({
      'en': 'Try to remember where you saw each picture.',
    });
    if (level <= 1) return const Hint(text: text);
    final first = spec.cards.first.id;
    final partner = spec.cards
        .firstWhere(
          (c) =>
              c.id != first &&
              MemorySpec.pairOf(c.id) == MemorySpec.pairOf(first),
        )
        .id;
    return Hint(text: text, reveal: {first, partner});
  }
}

/// Tracing: follow a letter or number with a finger.
class TraceSpec extends ItemSpec {
  const TraceSpec({
    required super.id,
    required super.kind,
    required super.prompt,
    required this.strokes,
    required this.tolerance,
    super.hintText,
    this.glyph,
  });

  /// The path to follow, as strokes in the unit square, in writing order.
  final List<List<Pt>> strokes;
  final double tolerance;
  final String? glyph;

  /// Points along the path every [step], used to check coverage.
  List<Pt> checkpoints([double step = 0.04]) => [
    for (final s in strokes) ...resample(s, step),
  ];

  static List<Pt> resample(List<Pt> stroke, double step) {
    if (stroke.length < 2) return stroke;
    final out = <Pt>[stroke.first];
    var carry = 0.0;
    for (var i = 1; i < stroke.length; i++) {
      final a = stroke[i - 1], b = stroke[i];
      final len = a.dist(b);
      var d = step - carry;
      while (d <= len) {
        final t = d / len;
        out.add(Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t));
        d += step;
      }
      carry = len - (d - step);
    }
    if (out.last.dist(stroke.last) > step / 2) out.add(stroke.last);
    return out;
  }
}

/// `{"kind":"trace","glyph":"a"}` (built-in shapes for a–h, o, l and 0–9) or
/// `{"kind":"trace","strokes":[[[0.5,0.1],[0.5,0.9]]]}`.
class TraceKind extends ActivityKind<TraceSpec> {
  const TraceKind();
  @override
  String get key => 'trace';

  /// Share of the path the finger must pass near, and the share of finger points allowed to
  /// wander off it.
  static const minCoverage = 0.75;
  static const maxStray = 0.3;

  @override
  TraceSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final glyph = json['glyph'] as String?;
    final raw = json['strokes'];
    final strokes = raw is List
        ? [
            for (final s in raw)
              [
                for (final p in s as List)
                  Pt(
                    ((p as List)[0] as num).toDouble(),
                    (p[1] as num).toDouble(),
                  ),
              ],
          ]
        : (glyph == null ? null : Glyphs.strokes(glyph));
    if (strokes == null ||
        strokes.isEmpty ||
        strokes.any((s) => s.length < 2)) {
      throw ContentException(
        'trace needs strokes or a known glyph (got ${glyph ?? 'none'})',
      );
    }
    return TraceSpec(
      id: ctx.itemId,
      kind: key,
      prompt: json['prompt'] == null
          ? Prompt(
              text: LocalizedText({'en': glyph ?? ''}),
              speak: LocalizedText({
                'en': glyph == null ? 'Follow the dots' : 'Trace the $glyph',
              }),
            )
          : Prompt.fromJson(json['prompt']),
      hintText: LocalizedText.fromJson(json['hint']),
      strokes: strokes,
      tolerance: ctx.policy.traceTolerance,
      glyph: glyph,
    );
  }

  /// Ink may be at most this many times the letter's length (stops scribbling over everything).
  static const maxInkRatio = 2.2;

  @override
  Verdict evaluate(TraceSpec spec, ItemAnswer answer) {
    if (answer is! TraceAnswer) return const Verdict.wrong();
    final drawn = [
      for (final s in answer.strokes) ...TraceSpec.resample(s, 0.02),
    ];
    if (drawn.length < 3) return const Verdict.wrong();
    final checks = spec.checkpoints();
    final covered =
        checks
            .where((c) => drawn.any((d) => d.dist(c) <= spec.tolerance))
            .length /
        checks.length;
    final path = spec.checkpoints(0.02);
    final stray =
        drawn
            .where((d) => !path.any((c) => c.dist(d) <= spec.tolerance * 1.5))
            .length /
        drawn.length;
    double length(List<Pt> s) =>
        [for (var i = 1; i < s.length; i++) s[i - 1].dist(s[i])]
            .fold(0.0, (a, b) => a + b);
    final ink = answer.strokes.fold<double>(0, (n, s) => n + length(s));
    final want = spec.strokes.fold<double>(0, (n, s) => n + length(s));
    if (covered >= minCoverage &&
        stray <= maxStray &&
        ink <= want * maxInkRatio) {
      return const Verdict.right();
    }
    return Verdict.wrong(partial: covered);
  }

  /// Level 1: words. Level 2: show where to start (the start dot pulses).
  @override
  Hint hint(TraceSpec spec, int level) {
    const text = LocalizedText({
      'en': 'Start at the green dot and follow the path.',
    });
    return level <= 1
        ? const Hint(text: text)
        : const Hint(text: text, reveal: {'start'});
  }
}

/// Built-in stroke paths for tracing, in the unit square, in the order a child writes them.
/// Simple, school-print shapes; real lettering can replace them through `strokes` in content.
abstract final class Glyphs {
  static List<Pt> _line(double x1, double y1, double x2, double y2) => [
    Pt(x1, y1),
    Pt(x2, y2),
  ];

  /// Arc around (cx, cy), radius rx × ry, from angle a1 to a2 in degrees (0 = right, 90 = down).
  static List<Pt> _arc(
    double cx,
    double cy,
    double rx,
    double ry,
    double a1,
    double a2, {
    int steps = 24,
  }) => [
    for (var i = 0; i <= steps; i++)
      () {
        final a = (a1 + (a2 - a1) * i / steps) * math.pi / 180;
        return Pt(cx + rx * math.cos(a), cy + ry * math.sin(a));
      }(),
  ];

  /// Every letter and number with built-in strokes (capitals are the straight-line ones plus
  /// O, C and U, the easiest to start with).
  static const known = 'abcdefgholx0123456789AEFHIKLMNOTUVWXYZC';

  static List<List<Pt>>? strokes(String glyph) => switch (glyph) {
    'o' || '0' => [_arc(0.5, 0.55, 0.28, 0.35, -90, 270)],
    'O' => [_arc(0.5, 0.5, 0.3, 0.4, -90, 270)],
    'C' => [_arc(0.55, 0.5, 0.3, 0.4, -40, -320)],
    'U' => [
      [
        ..._line(0.3, 0.1, 0.3, 0.6),
        ..._arc(0.5, 0.6, 0.2, 0.3, 180, 0),
        ..._line(0.7, 0.6, 0.7, 0.1),
      ],
    ],
    'A' => [
      _line(0.5, 0.1, 0.25, 0.9),
      _line(0.5, 0.1, 0.75, 0.9),
      _line(0.34, 0.62, 0.66, 0.62),
    ],
    'E' => [
      _line(0.32, 0.1, 0.32, 0.9),
      _line(0.32, 0.1, 0.7, 0.1),
      _line(0.32, 0.5, 0.62, 0.5),
      _line(0.32, 0.9, 0.7, 0.9),
    ],
    'F' => [
      _line(0.32, 0.1, 0.32, 0.9),
      _line(0.32, 0.1, 0.7, 0.1),
      _line(0.32, 0.5, 0.62, 0.5),
    ],
    'H' => [
      _line(0.3, 0.1, 0.3, 0.9),
      _line(0.7, 0.1, 0.7, 0.9),
      _line(0.3, 0.5, 0.7, 0.5),
    ],
    'I' => [
      _line(0.5, 0.1, 0.5, 0.9),
      _line(0.35, 0.1, 0.65, 0.1),
      _line(0.35, 0.9, 0.65, 0.9),
    ],
    'K' => [
      _line(0.32, 0.1, 0.32, 0.9),
      [..._line(0.7, 0.1, 0.32, 0.55), ..._line(0.32, 0.55, 0.72, 0.9)],
    ],
    'L' => [
      [..._line(0.35, 0.1, 0.35, 0.9), ..._line(0.35, 0.9, 0.7, 0.9)],
    ],
    'M' => [
      [
        ..._line(0.22, 0.9, 0.22, 0.1),
        ..._line(0.22, 0.1, 0.5, 0.6),
        ..._line(0.5, 0.6, 0.78, 0.1),
        ..._line(0.78, 0.1, 0.78, 0.9),
      ],
    ],
    'N' => [
      [
        ..._line(0.28, 0.9, 0.28, 0.1),
        ..._line(0.28, 0.1, 0.72, 0.9),
        ..._line(0.72, 0.9, 0.72, 0.1),
      ],
    ],
    'T' => [_line(0.25, 0.1, 0.75, 0.1), _line(0.5, 0.1, 0.5, 0.9)],
    'V' => [
      [..._line(0.25, 0.1, 0.5, 0.9), ..._line(0.5, 0.9, 0.75, 0.1)],
    ],
    'W' => [
      [
        ..._line(0.16, 0.1, 0.33, 0.9),
        ..._line(0.33, 0.9, 0.5, 0.4),
        ..._line(0.5, 0.4, 0.67, 0.9),
        ..._line(0.67, 0.9, 0.84, 0.1),
      ],
    ],
    'X' => [_line(0.27, 0.1, 0.73, 0.9), _line(0.73, 0.1, 0.27, 0.9)],
    'Y' => [
      _line(0.25, 0.1, 0.5, 0.5),
      [..._line(0.75, 0.1, 0.5, 0.5), ..._line(0.5, 0.5, 0.5, 0.9)],
    ],
    'Z' => [
      [
        ..._line(0.28, 0.1, 0.72, 0.1),
        ..._line(0.72, 0.1, 0.28, 0.9),
        ..._line(0.28, 0.9, 0.72, 0.9),
      ],
    ],
    'c' => [_arc(0.52, 0.62, 0.26, 0.26, -40, -320)],
    'a' => [
      _arc(0.48, 0.64, 0.22, 0.24, -20, -380),
      _line(0.7, 0.38, 0.7, 0.9),
    ],
    'b' => [_line(0.32, 0.1, 0.32, 0.9), _arc(0.52, 0.66, 0.2, 0.23, 180, 540)],
    'd' => [_arc(0.48, 0.66, 0.2, 0.23, 0, 360), _line(0.68, 0.1, 0.68, 0.9)],
    'e' => [
      [
        ..._line(0.28, 0.64, 0.74, 0.64),
        ..._arc(0.51, 0.64, 0.23, 0.24, 0, -300),
      ],
    ],
    'f' => [
      _arc(0.62, 0.24, 0.14, 0.14, 0, -180).reversed.toList()
        ..addAll(_line(0.48, 0.24, 0.48, 0.9)),
      _line(0.34, 0.45, 0.66, 0.45),
    ],
    'g' => [
      _arc(0.48, 0.45, 0.2, 0.2, 0, 360),
      [..._line(0.68, 0.28, 0.68, 0.8), ..._arc(0.5, 0.8, 0.18, 0.14, 0, 160)],
    ],
    'h' => [
      _line(0.32, 0.1, 0.32, 0.9),
      [..._arc(0.5, 0.6, 0.18, 0.18, 180, 360), ..._line(0.68, 0.6, 0.68, 0.9)],
    ],
    'l' => [_line(0.5, 0.1, 0.5, 0.9)],
    'x' => [_line(0.3, 0.35, 0.7, 0.9), _line(0.7, 0.35, 0.3, 0.9)],
    '1' => [
      [..._line(0.36, 0.26, 0.54, 0.1), ..._line(0.54, 0.1, 0.54, 0.9)],
    ],
    '2' => [
      [
        ..._arc(0.5, 0.32, 0.2, 0.2, 200, 380),
        ..._line(0.68, 0.42, 0.3, 0.9),
        ..._line(0.3, 0.9, 0.72, 0.9),
      ],
    ],
    '3' => [
      [
        ..._arc(0.48, 0.3, 0.2, 0.18, 200, 450),
        ..._arc(0.48, 0.68, 0.22, 0.2, -90, 160),
      ],
    ],
    '4' => [
      [..._line(0.6, 0.1, 0.26, 0.64), ..._line(0.26, 0.64, 0.76, 0.64)],
      _line(0.6, 0.36, 0.6, 0.9),
    ],
    '5' => [
      [
        ..._line(0.7, 0.1, 0.36, 0.1),
        ..._line(0.36, 0.1, 0.33, 0.46),
        ..._arc(0.5, 0.66, 0.22, 0.22, -120, 160),
      ],
    ],
    '6' => [
      [
        ..._arc(0.52, 0.5, 0.24, 0.38, -60, -180),
        ..._arc(0.5, 0.68, 0.2, 0.2, 180, 540),
      ],
    ],
    '7' => [
      [..._line(0.3, 0.1, 0.72, 0.1), ..._line(0.72, 0.1, 0.42, 0.9)],
    ],
    '8' => [
      [
        ..._arc(0.5, 0.3, 0.17, 0.19, 90, 450),
        ..._arc(0.5, 0.7, 0.21, 0.2, -90, 270),
      ],
    ],
    '9' => [
      [..._arc(0.5, 0.32, 0.2, 0.2, 0, 360), ..._line(0.7, 0.32, 0.62, 0.9)],
    ],
    _ => null,
  };
}
