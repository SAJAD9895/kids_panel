import '../../../learning/domain/catalog.dart';
import '../item_spec.dart';
import '../registry.dart';

/// How the options of a choice item look.
enum ChoiceStyle {
  /// Words or short labels.
  text,

  /// Pictures (image-based questions).
  picture,

  /// Big letters or numbers.
  glyph,
}

/// Pick the right option(s). Shared by multiple choice, image, audio, letter and number
/// recognition and fill-the-blank: they differ in content and look, not in rules.
class ChoiceSpec extends ItemSpec {
  const ChoiceSpec({
    required super.id,
    required super.kind,
    required super.prompt,
    required this.options,
    required this.correct,
    super.hintText,
    this.style = ChoiceStyle.text,
    this.audioOnly = false,
    this.countPicture,
    this.count,
    this.sentence,
    this.sourceQuestionId,
    this.answerIds = const {},
    this.equation,
  });

  final List<Choice> options;
  final Set<String> correct;
  final ChoiceStyle style;

  /// Audio questions: the prompt is heard, not read (a big "listen" button instead of text).
  final bool audioOnly;

  /// Number recognition: show [count] of this picture to count.
  final PictureRef? countPicture;
  final int? count;

  /// Fill the blank: the sentence with `___` where the answer goes.
  final LocalizedText? sentence;

  /// Adding and taking away: the sum to show (with pictures to count).
  final Equation? equation;

  /// `questions.id` when the item came from the questions table.
  final String? sourceQuestionId;

  /// Option id → `answers.id`, when the item came from the questions table.
  final Map<String, String> answerIds;

  @override
  String? get questionId => sourceQuestionId;

  bool get multi => correct.length > 1;
}

/// Shared rules for every choice kind.
abstract class _ChoiceKindBase extends ActivityKind<ChoiceSpec> {
  const _ChoiceKindBase();

  @override
  Verdict evaluate(ChoiceSpec spec, ItemAnswer answer) {
    if (answer is! PickAnswer) return const Verdict.wrong();
    final picked = answer.ids;
    if (picked.length == spec.correct.length &&
        picked.containsAll(spec.correct)) {
      return const Verdict.right();
    }
    final hits = picked.where(spec.correct.contains).length;
    return Verdict.wrong(
      partial: spec.correct.isEmpty ? 0 : hits / spec.correct.length,
    );
  }

  /// Level 1: the item's hint (or a gentle default). Level 2: remove half the wrong options.
  @override
  Hint hint(ChoiceSpec spec, int level) {
    final text = spec.hintText.isEmpty
        ? const LocalizedText({'en': 'Listen again and look closely!'})
        : spec.hintText;
    if (level <= 1) return Hint(text: text);
    final wrong = spec.options
        .where((o) => !spec.correct.contains(o.id))
        .map((o) => o.id)
        .toList();
    return Hint(
      text: text,
      eliminate: wrong.take((wrong.length / 2).ceil()).toSet(),
    );
  }

  @override
  ItemAnswer? solution(ChoiceSpec spec) => PickAnswer(spec.correct);

  /// Keeps every correct option and as many wrong ones as the policy allows, shuffled with the
  /// item's seed (younger children see fewer options).
  static List<Choice> trimAndShuffle(
    List<Choice> options,
    Set<String> correct,
    ParseContext ctx, {
    bool shuffle = true,
  }) {
    final right = options.where((o) => correct.contains(o.id)).toList();
    final wrong = options.where((o) => !correct.contains(o.id)).toList();
    final keep = (ctx.policy.maxOptions - right.length).clamp(1, wrong.length);
    final picked = [...right, ...ctx.random.shuffled(wrong).take(keep)];
    return shuffle ? SeededRandom(ctx.seed + 1).shuffled(picked) : picked;
  }

  static Set<String> correctIds(Object? v) => switch (v) {
    List l => l.map((e) => '$e').toSet(),
    null => const {},
    _ => {'$v'},
  };

  static List<Choice> choices(Object? v) {
    final list = v is List ? v : const [];
    return [
      for (var i = 0; i < list.length; i++) Choice.fromJson(list[i], 'o$i'),
    ];
  }
}

/// `{"kind":"multiple_choice","prompt":"Which one is round?","options":[…],"correct":["b"]}`
class MultipleChoiceKind extends _ChoiceKindBase {
  const MultipleChoiceKind();
  @override
  String get key => 'multiple_choice';

  @override
  ChoiceSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final correct = _ChoiceKindBase.correctIds(json['correct']);
    final options = _ChoiceKindBase.choices(json['options']);
    if (options.length < 2 ||
        correct.isEmpty ||
        !correct.every((c) => options.any((o) => o.id == c))) {
      throw const ContentException(
        'multiple_choice needs 2+ options and a correct one',
      );
    }
    final hasPictures = options.every((o) => o.picture != null);
    return ChoiceSpec(
      id: ctx.itemId,
      kind: key,
      prompt: Prompt.fromJson(json['prompt']),
      hintText: LocalizedText.fromJson(json['hint']),
      options: _ChoiceKindBase.trimAndShuffle(
        options,
        correct,
        ctx,
        shuffle: json['shuffle'] != false,
      ),
      correct: correct,
      style: hasPictures ? ChoiceStyle.picture : ChoiceStyle.text,
      sourceQuestionId: json['questionId'] as String?,
      answerIds:
          (json['answerIds'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
          const {},
    );
  }
}

/// Image-based: pictures as options, and usually a picture in the prompt.
class ImageChoiceKind extends _ChoiceKindBase {
  const ImageChoiceKind();
  @override
  String get key => 'image_choice';

  @override
  ChoiceSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final base = const MultipleChoiceKind().parse(json, ctx);
    if (base.options.any((o) => o.picture == null)) {
      throw const ContentException('image_choice options need pictures');
    }
    return ChoiceSpec(
      id: base.id,
      kind: key,
      prompt: base.prompt,
      hintText: base.hintText,
      options: base.options,
      correct: base.correct,
      style: ChoiceStyle.picture,
    );
  }
}

/// Audio-based: the question is heard (a big "listen" button), options are pictures or words.
class AudioChoiceKind extends _ChoiceKindBase {
  const AudioChoiceKind();
  @override
  String get key => 'audio_choice';

  @override
  ChoiceSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final base = const MultipleChoiceKind().parse(json, ctx);
    if (base.prompt.spoken().isEmpty) {
      throw const ContentException('audio_choice needs something to say');
    }
    return ChoiceSpec(
      id: base.id,
      kind: key,
      prompt: base.prompt,
      hintText: base.hintText,
      options: base.options,
      correct: base.correct,
      style: base.style,
      audioOnly: true,
      sourceQuestionId: base.sourceQuestionId,
      answerIds: base.answerIds,
    );
  }
}

/// `{"kind":"letter_recognition","target":"b","distractors":["d","p","q"]}`: find the letter.
/// Without distractors, look-alike letters are used.
class LetterRecognitionKind extends _ChoiceKindBase {
  const LetterRecognitionKind();
  @override
  String get key => 'letter_recognition';

  static const _lookAlikes = {
    'b': ['d', 'p', 'q'],
    'd': ['b', 'p', 'q'],
    'p': ['q', 'b', 'd'],
    'q': ['p', 'g', 'd'],
    'm': ['n', 'w', 'u'],
    'n': ['m', 'u', 'h'],
    'u': ['n', 'v', 'w'],
    'a': ['o', 'e', 'c'],
    'e': ['c', 'o', 'a'],
    'c': ['o', 'e', 'a'],
    'g': ['q', 'y', 'p'],
    'h': ['n', 'k', 'b'],
    'f': ['t', 'l', 'k'],
  };

  /// The sound each letter makes, and a word that starts with it (for "letter sounds").
  static const phonics = {
    'a': ('a', 'apple'),
    'b': ('buh', 'ball'),
    'c': ('kuh', 'cat'),
    'd': ('duh', 'dog'),
    'e': ('eh', 'egg'),
    'f': ('fff', 'fish'),
    'g': ('guh', 'goat'),
    'h': ('hhh', 'hat'),
    'i': ('ih', 'insect'),
    'j': ('juh', 'jam'),
    'k': ('kuh', 'kite'),
    'l': ('lll', 'lion'),
    'm': ('mmm', 'moon'),
    'n': ('nnn', 'nest'),
    'o': ('o', 'octopus'),
    'p': ('puh', 'pig'),
    'q': ('kwuh', 'queen'),
    'r': ('rrr', 'rabbit'),
    's': ('sss', 'sun'),
    't': ('tuh', 'tiger'),
    'u': ('uh', 'umbrella'),
    'v': ('vvv', 'van'),
    'w': ('wuh', 'web'),
    'x': ('ks', 'fox'),
    'y': ('yuh', 'yo-yo'),
    'z': ('zzz', 'zebra'),
  };

  /// Modes: `name` (default: "find the letter b"), `sound` (hear "buh, like ball", find b),
  /// `case` (see a capital B, find the small b; or the other way round).
  @override
  ChoiceSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final target = '${json['target'] ?? ''}';
    if (target.length != 1) {
      throw const ContentException(
        'letter_recognition needs a one-letter target',
      );
    }
    final mode = '${json['mode'] ?? 'name'}';
    final lower = target.toLowerCase();
    final upper = target != lower;
    final sound = phonics[lower];
    if (mode == 'sound' && sound == null) {
      throw ContentException('no letter sound for "$target"');
    }
    // Look-alikes in the same case as the target.
    final others =
        ((json['distractors'] as List?)?.map((e) => '$e') ??
                (_lookAlikes[lower] ?? const ['o', 'x', 's']).map(
                  (l) => upper ? l.toUpperCase() : l,
                ))
            .where((l) => l != target)
            .toList();
    final options = [
      target,
      ...others,
    ].map((l) => Choice(id: l, label: LocalizedText({'en': l}))).toList();
    final other = upper ? lower : target.toUpperCase();
    final Prompt prompt = json['prompt'] != null
        ? Prompt.fromJson(json['prompt'])
        : switch (mode) {
            'sound' => Prompt(
              text: const LocalizedText({
                'en': 'Which letter makes this sound?',
              }),
              speak: LocalizedText({
                'en':
                    'Which letter says ${sound!.$1}? ${sound.$1}, like ${sound.$2}.',
              }),
            ),
            'case' => Prompt(
              text: LocalizedText({
                'en': upper ? 'Find the big $other' : 'Find the small $other',
              }),
              speak: LocalizedText({
                'en': upper
                    ? 'Here is a small $other. Can you find the big one?'
                    : 'Here is a big $other. Can you find the small one?',
              }),
              picture: PictureRef('glyph:$other'),
            ),
            _ => Prompt(
              text: LocalizedText({'en': 'Find $target'}),
              speak: LocalizedText({'en': 'Can you find the letter $target?'}),
            ),
          };
    return ChoiceSpec(
      id: ctx.itemId,
      kind: key,
      prompt: prompt,
      hintText: json['hint'] != null
          ? LocalizedText.fromJson(json['hint'])
          : mode == 'sound'
          ? LocalizedText({'en': '${sound!.$2} starts with ${sound.$1}'})
          : LocalizedText({'en': '$target looks like this: $target'}),
      options: _ChoiceKindBase.trimAndShuffle(options, {target}, ctx),
      correct: {target},
      style: ChoiceStyle.glyph,
      audioOnly: mode == 'sound',
    );
  }
}

/// `{"kind":"number_recognition","count":4,"picture":"icon:apple"}`: count the things, pick the
/// number. Or `{"target":7}` alone: find the number you hear.
class NumberRecognitionKind extends _ChoiceKindBase {
  const NumberRecognitionKind();
  @override
  String get key => 'number_recognition';

  @override
  ChoiceSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final count = (json['count'] as num?)?.toInt();
    final target = (json['target'] as num?)?.toInt() ?? count;
    if (target == null || target < 0 || target > 20) {
      throw const ContentException('number_recognition needs 0..20');
    }
    final distractors =
        (json['distractors'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [
          target - 1,
          target + 1,
          target + 2,
        ].where((n) => n >= 0 && n <= 20).toList();
    final options = {
      target,
      ...distractors,
    }.map((n) => Choice(id: '$n', label: LocalizedText({'en': '$n'}))).toList();
    final picture = PictureRef.parse(json['picture']);
    if (count != null && (picture == null || count > 10)) {
      throw const ContentException('counting needs a picture and ≤ 10');
    }
    return ChoiceSpec(
      id: ctx.itemId,
      kind: key,
      prompt: json['prompt'] != null
          ? Prompt.fromJson(json['prompt'])
          : count != null
          ? const Prompt(
              text: LocalizedText({'en': 'How many?'}),
              speak: LocalizedText({'en': 'How many can you count?'}),
            )
          : Prompt(
              text: LocalizedText({'en': 'Find $target'}),
              speak: LocalizedText({'en': 'Can you find the number $target?'}),
            ),
      hintText: count != null
          ? const LocalizedText({'en': 'Touch each one as you count.'})
          : LocalizedText({'en': 'Listen: $target.'}),
      options: _ChoiceKindBase.trimAndShuffle(options, {'$target'}, ctx),
      correct: {'$target'},
      style: ChoiceStyle.glyph,
      countPicture: count != null ? picture : null,
      count: count,
    );
  }
}

/// `{"kind":"fill_blank","sentence":"The cow says ___","options":["moo","quack"],"correct":"moo"}`
class FillBlankKind extends _ChoiceKindBase {
  const FillBlankKind();
  @override
  String get key => 'fill_blank';

  static const blank = '___';

  @override
  ChoiceSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final sentence = LocalizedText.fromJson(json['sentence']);
    if (!sentence.of().contains(blank)) {
      throw const ContentException('fill_blank sentence needs ___');
    }
    final options = _ChoiceKindBase.choices(json['options']);
    final correct = _ChoiceKindBase.correctIds(json['correct']);
    if (correct.length != 1 || !options.any((o) => o.id == correct.first)) {
      throw const ContentException(
        'fill_blank needs exactly one correct option',
      );
    }
    return ChoiceSpec(
      id: ctx.itemId,
      kind: key,
      prompt: json['prompt'] == null
          ? Prompt(
              speak: LocalizedText({
                'en': sentence.of().replaceAll(blank, 'what?'),
              }),
              picture: PictureRef.parse(json['picture']),
            )
          : Prompt.fromJson(json['prompt']),
      hintText: LocalizedText.fromJson(json['hint']),
      options: _ChoiceKindBase.trimAndShuffle(options, correct, ctx),
      correct: correct,
      sentence: sentence,
    );
  }
}

/// A small sum shown with pictures: `3 + 2 = ?` or `5 − 2 = ?`.
class Equation {
  const Equation(this.a, this.op, this.b, {this.picture});

  final int a;

  /// `+` or `-`.
  final String op;
  final int b;

  /// What to count (e.g. `icon:apple`); numbers only when null.
  final PictureRef? picture;

  int get result => op == '-' ? a - b : a + b;

  static const _words = [
    'zero',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
    'eleven',
    'twelve',
    'thirteen',
    'fourteen',
    'fifteen',
    'sixteen',
    'seventeen',
    'eighteen',
    'nineteen',
    'twenty',
  ];

  static String word(int n) => n >= 0 && n < _words.length ? _words[n] : '$n';

  /// "3 + 2 = ?"
  String get text => '$a ${op == '-' ? '−' : '+'} $b = ?';

  /// What the voice asks.
  String get spoken {
    final what = picture?.describe();
    if (what == null) {
      return 'What is ${word(a)} ${op == '-' ? 'take away' : 'plus'} ${word(b)}?';
    }
    return op == '-'
        ? 'There are ${word(a)} ${what}s. ${word(b)} go away. How many are left?'
        : '${word(a)} ${what}s and ${word(b)} more. How many altogether?';
  }
}

/// `{"kind":"arithmetic","a":3,"op":"+","b":2,"picture":"icon:apple"}`: simple adding and taking
/// away, with pictures to count. Numbers 0..10 each, results 0..20. The options are the answer
/// and its neighbours (the mistakes children really make: off by one or two).
class ArithmeticKind extends _ChoiceKindBase {
  const ArithmeticKind();
  @override
  String get key => 'arithmetic';

  @override
  ChoiceSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final a = (json['a'] as num?)?.toInt(), b = (json['b'] as num?)?.toInt();
    final op = '${json['op'] ?? '+'}';
    if (a == null || b == null || a < 0 || b < 0 || a > 10 || b > 10) {
      throw const ContentException('arithmetic needs a and b between 0 and 10');
    }
    if (op != '+' && op != '-') {
      throw const ContentException('arithmetic op is + or -');
    }
    if (op == '-' && b > a) {
      throw const ContentException('arithmetic: no answers below zero');
    }
    final eq = Equation(a, op, b, picture: PictureRef.parse(json['picture']));
    final answer = eq.result;
    final near = <int>{
      for (final d in [1, -1, 2, -2, 3]) answer + d,
    }.where((n) => n >= 0 && n <= 20).take(4);
    final options = [
      for (final n in [answer, ...near])
        Choice(id: '$n', label: LocalizedText({'en': '$n'})),
    ];
    return ChoiceSpec(
      id: ctx.itemId,
      kind: key,
      prompt: json['prompt'] != null
          ? Prompt.fromJson(json['prompt'])
          : Prompt(
              // With pictures the numbers go above them; without, the sum itself is big.
              text: LocalizedText({
                'en': eq.picture == null ? 'What is the answer?' : eq.text,
              }),
              speak: LocalizedText({'en': eq.spoken}),
            ),
      hintText: json['hint'] != null
          ? LocalizedText.fromJson(json['hint'])
          : LocalizedText({
              'en': eq.picture == null
                  ? (op == '-'
                        ? 'Start at $a and count back $b.'
                        : 'Start at $a and count on $b.')
                  : (op == '-'
                        ? 'Count the ones that are left.'
                        : 'Count all of them together.'),
            }),
      options: _ChoiceKindBase.trimAndShuffle(options, {'$answer'}, ctx),
      correct: {'$answer'},
      style: ChoiceStyle.glyph,
      equation: eq,
    );
  }
}

/// `{"kind":"shape_complete","shape":"heart","missing":"right","distractors":["circle","star"]}`:
/// a shape with one side missing; pick the piece that finishes it.
class ShapeCompleteKind extends _ChoiceKindBase {
  const ShapeCompleteKind();
  @override
  String get key => 'shape_complete';

  static const shapes = {'circle', 'square', 'triangle', 'star', 'heart'};
  static const sides = {'left', 'right', 'top', 'bottom'};

  @override
  ChoiceSpec parse(Map<String, dynamic> json, ParseContext ctx) {
    final shape = '${json['shape'] ?? ''}';
    final side = '${json['missing'] ?? 'right'}';
    if (!shapes.contains(shape) || !sides.contains(side)) {
      throw ContentException(
        'shape_complete needs a shape (${shapes.join(', ')}) and a side',
      );
    }
    final color = json['color'] == null ? '' : '?color=${json['color']}';
    final others = [
      for (final d in (json['distractors'] as List?) ?? shapes.toList())
        if ('$d' != shape && shapes.contains('$d')) '$d',
    ];
    if (others.isEmpty) {
      throw const ContentException('shape_complete needs another shape');
    }
    Choice piece(String sh) => Choice(
      id: sh,
      picture: PictureRef('half:$sh:$side$color'),
      speak: LocalizedText({'en': 'the $side side of a $sh'}),
    );
    return ChoiceSpec(
      id: ctx.itemId,
      kind: key,
      prompt: json['prompt'] != null
          ? Prompt.fromJson(json['prompt'])
          : Prompt(
              text: LocalizedText({'en': 'Finish the $shape'}),
              speak: LocalizedText({'en': 'Which piece finishes the $shape?'}),
              picture: PictureRef('gap:$shape:$side$color'),
            ),
      hintText: json['hint'] != null
          ? LocalizedText.fromJson(json['hint'])
          : LocalizedText({
              'en': 'Look at the edge. Which piece fits the $shape?',
            }),
      options: _ChoiceKindBase.trimAndShuffle(
        [piece(shape), ...others.map(piece)],
        {shape},
        ctx,
      ),
      correct: {shape},
      style: ChoiceStyle.picture,
    );
  }
}
