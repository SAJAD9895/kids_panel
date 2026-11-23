import '../../../learning/domain/catalog.dart';
import '../item_spec.dart';
import '../registry.dart';

List<Choice> _choices(Object? v, String prefix) {
  final list = v is List ? v : const [];
  return [
    for (var i = 0; i < list.length; i++) Choice.fromJson(list[i], '$prefix$i'),
  ];
}

/// Put tokens where they belong: each token has one right target (drag and drop), or one right
/// bin among a few (sorting and classification).
class PlaceSpec extends ItemSpec {
  const PlaceSpec({
    required super.id,
    required super.kind,
    required super.prompt,
    required this.tokens,
    required this.targets,
    required this.solution,
    super.hintText,
  });

  final List<Choice> tokens;
  final List<Choice> targets;

  /// token id → target id
  final Map<String, String> solution;

  bool fits(String tokenId, String targetId) => solution[tokenId] == targetId;
}

abstract class _PlaceKindBase extends ActivityKind<PlaceSpec> {
  const _PlaceKindBase();

  @override
  Verdict evaluate(PlaceSpec spec, ItemAnswer answer) {
    if (answer is! PlaceAnswer) return const Verdict.wrong();
    final right = spec.solution.entries
        .where((e) => answer.placements[e.key] == e.value)
        .length;
    if (right == spec.solution.length &&
        answer.placements.length == spec.solution.length) {
      return Verdict.right(mistakes: answer.mistakes);
    }
    return Verdict.wrong(partial: right / spec.solution.length);
  }

  /// Level 1: words. Level 2: show where the first token goes.
  @override
  Hint hint(PlaceSpec spec, int level) {
    final text = spec.hintText.isEmpty
        ? const LocalizedText({'en': 'Look at the shapes and colours.'})
        : spec.hintText;
    if (level <= 1) return Hint(text: text);
    final first = spec.solution.entries.first;
    return Hint(text: text, reveal: {first.key, first.value});
  }

  @override
  ItemAnswer? solution(PlaceSpec spec) => PlaceAnswer(spec.solution);
}

/// `{"kind":"drag_to_target","tokens":[{"id":"t","picture":"shape:triangle"}],
///   "targets":[{"id":"tt","picture":"shape:triangle"}],"solution":{"t":"tt"}}`
class DragToTargetKind extends _PlaceKindBase {
  const DragToTargetKind();
  @override
  String get key => 'drag_to_target';

  @override
  PlaceSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final tokens = _choices(json['tokens'], 't');
    final targets = _choices(json['targets'], 'g');
    final solution = (json['solution'] as Map? ?? const {}).map(
      (k, v) => MapEntry('$k', '$v'),
    );
    if (tokens.isEmpty ||
        tokens.any((t) => !solution.containsKey(t.id)) ||
        solution.values.any((g) => !targets.any((t) => t.id == g))) {
      throw const ContentException(
        'drag_to_target: every token needs a target',
      );
    }
    return PlaceSpec(
      id: ctx.itemId,
      kind: key,
      prompt: Prompt.fromJson(
        json['prompt'] ?? const {'text': 'Put each one in its place'},
      ),
      hintText: LocalizedText.fromJson(json['hint']),
      tokens: ctx.random.shuffled(tokens),
      targets: targets,
      solution: solution,
    );
  }
}

/// `{"kind":"sort","bins":[{"id":"fruit","label":"Fruit"}],
///   "items":[{"id":"apple","picture":"icon:apple","bin":"fruit"}]}`
class SortKind extends _PlaceKindBase {
  const SortKind();
  @override
  String get key => 'sort';

  @override
  PlaceSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final bins = _choices(json['bins'], 'b');
    final raw = json['items'] is List ? json['items'] as List : const [];
    final items = [
      for (var i = 0; i < raw.length; i++) Choice.fromJson(raw[i], 'i$i'),
    ];
    final solution = {
      for (var i = 0; i < raw.length; i++)
        items[i].id: '${(raw[i] as Map)['bin']}',
    };
    if (bins.length < 2 ||
        items.isEmpty ||
        solution.values.any((b) => !bins.any((x) => x.id == b))) {
      throw const ContentException(
        'sort needs 2+ bins and items that each name a bin',
      );
    }
    return PlaceSpec(
      id: ctx.itemId,
      kind: key,
      prompt: Prompt.fromJson(json['prompt'] ?? const {'text': 'Sort them!'}),
      hintText: LocalizedText.fromJson(json['hint']),
      tokens: ctx.random.shuffled(items),
      targets: bins,
      solution: solution,
    );
  }
}

/// `{"kind":"match_pairs","pairs":[{"left":{"picture":"icon:cow"},"right":{"label":"cow"}}]}`
/// Tap (or drag) one on the left, then its partner on the right.
class MatchPairsKind extends _PlaceKindBase {
  const MatchPairsKind();
  @override
  String get key => 'match_pairs';

  @override
  PlaceSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final raw = json['pairs'] is List ? json['pairs'] as List : const [];
    if (raw.length < 2) {
      throw const ContentException('match_pairs needs 2+ pairs');
    }
    final lefts = <Choice>[],
        rights = <Choice>[],
        solution = <String, String>{};
    for (var i = 0; i < raw.length; i++) {
      final m = raw[i] as Map;
      final l = Choice.fromJson(m['left'], 'l$i'),
          r = Choice.fromJson(m['right'], 'r$i');
      final left = Choice(
        id: 'l$i',
        label: l.label,
        picture: l.picture,
        speak: l.speak,
      );
      final right = Choice(
        id: 'r$i',
        label: r.label,
        picture: r.picture,
        speak: r.speak,
      );
      lefts.add(left);
      rights.add(right);
      solution[left.id] = right.id;
    }
    return PlaceSpec(
      id: ctx.itemId,
      kind: key,
      prompt: Prompt.fromJson(
        json['prompt'] ?? const {'text': 'Find the pairs'},
      ),
      hintText: LocalizedText.fromJson(json['hint']),
      tokens: lefts,
      targets: ctx.random.shuffled(rights),
      solution: solution,
    );
  }
}

/// Put pieces in the right order: letters of a word, or parts of a picture.
class OrderSpec extends ItemSpec {
  const OrderSpec({
    required super.id,
    required super.kind,
    required super.prompt,
    required this.pieces,
    required this.order,
    required this.start,
    super.hintText,
    this.picture,
    this.columns = 0,
  });

  /// Every piece (word building may include extra letters that aren't used).
  final List<Choice> pieces;

  /// The right order of piece ids.
  final List<String> order;

  /// How the pieces are laid out at first (shuffled).
  final List<String> start;

  /// Word building: the picture of the word. Puzzle: the picture that is cut up.
  final PictureRef? picture;

  /// Puzzle grid width (0 for words).
  final int columns;

  Choice piece(String id) => pieces.firstWhere((p) => p.id == id);
}

abstract class _OrderKindBase extends ActivityKind<OrderSpec> {
  const _OrderKindBase();

  @override
  Verdict evaluate(OrderSpec spec, ItemAnswer answer) {
    if (answer is! OrderAnswer) return const Verdict.wrong();
    // Pieces with the same face (two "o"s in "moon") are interchangeable.
    // An id that isn't a piece (tampered or stale answer) is simply wrong.
    final known = {for (final p in spec.pieces) p.id};
    if (!answer.ids.every(known.contains)) return const Verdict.wrong();
    String face(String id) => spec.piece(id).label.of();
    final got = answer.ids.map(face).toList(),
        want = spec.order.map(face).toList();
    var same = 0;
    for (var i = 0; i < want.length && i < got.length; i++) {
      if (got[i] == want[i]) same++;
    }
    if (got.length == want.length && same == want.length) {
      return Verdict.right(mistakes: answer.mistakes);
    }
    return Verdict.wrong(partial: want.isEmpty ? 0 : same / want.length);
  }

  @override
  ItemAnswer? solution(OrderSpec spec) => OrderAnswer(spec.order);
}

/// `{"kind":"word_build","word":"cat","picture":"icon:cat","extra":"o"}`: tap the letters in
/// order to spell the word.
class WordBuildKind extends _OrderKindBase {
  const WordBuildKind();
  @override
  String get key => 'word_build';

  @override
  OrderSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final word = '${json['word'] ?? ''}'.trim();
    if (word.isEmpty || word.length > 8) {
      throw const ContentException('word_build needs a word of 1..8 letters');
    }
    final letters = word.split('');
    final extra = '${json['extra'] ?? ''}'
        .split('')
        .where((c) => c.trim().isNotEmpty)
        .toList();
    final pieces = [
      for (var i = 0; i < letters.length; i++)
        Choice(id: 'w$i', label: LocalizedText({'en': letters[i]})),
      for (var i = 0; i < extra.length; i++)
        Choice(id: 'x$i', label: LocalizedText({'en': extra[i]})),
    ];
    final order = [for (var i = 0; i < letters.length; i++) 'w$i'];
    var start = ctx.random.shuffled(pieces.map((p) => p.id).toList());
    if (start.take(order.length).join() == order.join() && start.length > 1) {
      start = [...start.skip(1), start.first];
    }
    return OrderSpec(
      id: ctx.itemId,
      kind: key,
      prompt: json['prompt'] == null
          ? Prompt(
              speak: LocalizedText({'en': 'Spell $word'}),
              picture: PictureRef.parse(json['picture']),
            )
          : Prompt.fromJson(json['prompt']),
      hintText: LocalizedText.fromJson(json['hint']),
      pieces: pieces,
      order: order,
      start: start,
      picture: PictureRef.parse(json['picture']),
    );
  }

  /// Level 1: say the word slowly. Level 2: light up the next letter.
  @override
  Hint hint(OrderSpec spec, int level) {
    final word = spec.order.map((id) => spec.piece(id).label.of()).join();
    final text = LocalizedText({'en': word.split('').join(' … ')});
    return level <= 1
        ? Hint(text: text)
        : Hint(text: text, reveal: {spec.order.first});
  }
}

/// `{"kind":"puzzle","picture":"char:pip","grid":2}`: a picture cut into grid×grid pieces; tap
/// two pieces to swap them until the picture is whole. `pieces` with labels makes an ordering
/// puzzle instead ("put the story in order").
class PuzzleKind extends _OrderKindBase {
  const PuzzleKind();
  @override
  String get key => 'puzzle';

  @override
  OrderSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final picture = PictureRef.parse(json['picture']);
    final labelled = _choices(json['pieces'], 'p');
    final grid = ((json['grid'] as num?)?.toInt() ?? 2).clamp(2, 4);
    final pieces = labelled.isNotEmpty
        ? labelled
        : [
            for (var i = 0; i < grid * grid; i++)
              Choice(id: 'p$i', label: LocalizedText({'en': '${i + 1}'})),
          ];
    if (labelled.isEmpty && picture == null) {
      throw const ContentException('puzzle needs a picture or pieces');
    }
    final order = pieces.map((p) => p.id).toList();
    var start = ctx.random.shuffled(order);
    if (start.join() == order.join()) start = [...start.skip(1), start.first];
    return OrderSpec(
      id: ctx.itemId,
      kind: key,
      prompt: Prompt.fromJson(
        json['prompt'] ?? const {'text': 'Fix the picture'},
      ),
      hintText: LocalizedText.fromJson(json['hint']),
      pieces: pieces,
      order: order,
      start: start,
      picture: picture,
      columns: labelled.isEmpty ? grid : 0,
    );
  }

  /// Level 2: show where the first misplaced piece belongs.
  @override
  Hint hint(OrderSpec spec, int level) {
    const text = LocalizedText({'en': 'Start with the top corner.'});
    return level <= 1
        ? Hint(text: spec.hintText.isEmpty ? text : spec.hintText)
        : Hint(text: text, reveal: {spec.order.first});
  }
}

/// A jigsaw: the picture cut into a grid; pieces wait in a tray and go onto the board. Judged
/// like drag and drop (each piece has one right place; wrong drops bounce back).
class JigsawSpec extends PlaceSpec {
  const JigsawSpec({
    required super.id,
    required super.kind,
    required super.prompt,
    required super.tokens,
    required super.targets,
    required super.solution,
    required this.picture,
    required this.grid,
    super.hintText,
  });

  final PictureRef picture;

  /// Pieces per side (2 = 4 pieces, 3 = 9, 4 = 16).
  final int grid;

  /// Board position (0-based, row by row) of a piece or slot id like `p5` / `s5`.
  static int indexOf(String id) => int.parse(id.substring(1));
}

/// `{"kind":"jigsaw","picture":"char:pip","grid":3}`
class JigsawKind extends _PlaceKindBase {
  const JigsawKind();
  @override
  String get key => 'jigsaw';

  @override
  JigsawSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final picture = PictureRef.parse(json['picture']);
    final grid = (json['grid'] as num?)?.toInt() ?? 2;
    if (picture == null) {
      throw const ContentException('jigsaw needs a picture');
    }
    if (grid < 2 || grid > 4) {
      throw const ContentException('jigsaw grid is 2, 3 or 4');
    }
    final n = grid * grid;
    String where(int i) {
      final row = i ~/ grid, col = i % grid;
      final v = row == 0 ? 'top' : (row == grid - 1 ? 'bottom' : 'middle');
      final h = col == 0 ? 'left' : (col == grid - 1 ? 'right' : 'middle');
      return v == h ? 'middle' : '$v $h';
    }

    final tokens = [
      for (var i = 0; i < n; i++)
        Choice(id: 'p$i', speak: LocalizedText({'en': 'piece ${i + 1}'})),
    ];
    return JigsawSpec(
      id: ctx.itemId,
      kind: key,
      prompt: Prompt.fromJson(
        json['prompt'] ??
            const {
              'text': 'Build the picture',
              'speak': 'Put each piece where it belongs to make the picture.',
            },
      ),
      hintText: json['hint'] == null
          ? const LocalizedText({'en': 'Start with a corner piece.'})
          : LocalizedText.fromJson(json['hint']),
      tokens: ctx.random.shuffled(tokens),
      targets: [
        for (var i = 0; i < n; i++)
          Choice(id: 's$i', speak: LocalizedText({'en': where(i)})),
      ],
      solution: {for (var i = 0; i < n; i++) 'p$i': 's$i'},
      picture: picture,
      grid: grid,
    );
  }
}
