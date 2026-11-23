import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/demo/demo_activity_content.dart';
import 'package:kids_app/features/play/domain/item_spec.dart';
import 'package:kids_app/features/play/domain/kinds/arrange_kinds.dart';
import 'package:kids_app/features/play/domain/kinds/choice_kinds.dart';
import 'package:kids_app/features/play/domain/kinds/memory_trace_kinds.dart';
import 'package:kids_app/features/play/domain/registry.dart';

/// Every activity type: parsing, judging answers, hints, the shown solution.
void main() {
  final registry = KindRegistry.standard();
  const roomy = DifficultyPolicy(maxOptions: 6);
  ItemSpec parse(
    Map<String, dynamic> json, {
    DifficultyPolicy policy = roomy,
    int seed = 7,
  }) => registry.parseItem(
    json,
    ParseContext(itemId: 'i0', seed: seed, policy: policy),
  );
  Verdict judge(ItemSpec s, ItemAnswer a) => registry.evaluate(s, a);

  final sampler = [
    for (final m in (demoActivityContent['engine-sampler']!['items'] as List))
      (m as Map).cast<String, dynamic>(),
  ];
  Map<String, dynamic> sample(String kind) =>
      sampler.firstWhere((m) => m['kind'] == kind);

  test(
    'the standard registry has all 16 types, and the sampler uses each once',
    () {
      expect(registry.keys.toSet(), {
        'multiple_choice',
        'image_choice',
        'audio_choice',
        'letter_recognition',
        'number_recognition',
        'fill_blank',
        'drag_to_target',
        'sort',
        'match_pairs',
        'word_build',
        'puzzle',
        'memory',
        'trace',
        'arithmetic',
        'shape_complete',
        'jigsaw',
      });
      expect(sampler.map((m) => m['kind']).toSet(), registry.keys.toSet());
    },
  );

  test('unknown types and broken content are refused, not crashed on', () {
    expect(() => parse({'kind': 'teleport'}), throwsA(isA<ContentException>()));
    expect(
      () => parse({
        'kind': 'multiple_choice',
        'options': ['a'],
      }),
      throwsA(isA<ContentException>()),
    );
    expect(
      () => parse({'kind': 'trace', 'glyph': '€'}),
      throwsA(isA<ContentException>()),
    );
    expect(
      () => parse({
        'kind': 'sort',
        'bins': [
          {'id': 'x'},
        ],
        'items': [],
      }),
      throwsA(isA<ContentException>()),
    );
    expect(
      () => parse({
        'kind': 'fill_blank',
        'sentence': 'no blank',
        'options': ['a'],
        'correct': 'a',
      }),
      throwsA(isA<ContentException>()),
    );
  });

  group('choice types', () {
    test('multiple choice: right, wrong, partial for multi-answer', () {
      final s = parse(sample('multiple_choice')) as ChoiceSpec;
      expect(judge(s, const PickAnswer({'banana'})).correct, isTrue);
      expect(judge(s, const PickAnswer({'car'})).correct, isFalse);
      final multi = parse({
        'kind': 'multiple_choice',
        'prompt': 'Pick the animals',
        'options': ['cat', 'dog', 'car'],
        'correct': ['cat', 'dog'],
      }) as ChoiceSpec;
      expect(multi.multi, isTrue);
      expect(judge(multi, const PickAnswer({'cat'})).partial, 0.5);
      expect(judge(multi, const PickAnswer({'cat', 'dog'})).correct, isTrue);
    });

    test('younger children see fewer options, the right one always stays', () {
      for (var seed = 0; seed < 20; seed++) {
        final s = parse(
          {
            'kind': 'letter_recognition',
            'target': 'b',
            'distractors': ['d', 'p', 'q', 'h', 'k'],
          },
          policy: const DifficultyPolicy(maxOptions: 3),
          seed: seed,
        ) as ChoiceSpec;
        expect(s.options, hasLength(3));
        expect(s.options.map((o) => o.id), contains('b'));
      }
    });

    test(
      'the same seed gives the same order (resume shows the same screen)',
      () {
        List<String> order(int seed) =>
            (parse(sample('image_choice'), seed: seed) as ChoiceSpec).options
                .map((o) => o.id)
                .toList();
        expect(order(42), order(42));
      },
    );

    test(
      'image, audio, letter, number, fill-the-blank parse to the right shape',
      () {
        expect(
          (parse(sample('image_choice')) as ChoiceSpec).style,
          ChoiceStyle.picture,
        );
        final audio = parse(sample('audio_choice')) as ChoiceSpec;
        expect(audio.audioOnly, isTrue);
        expect(audio.prompt.spoken(), 'Find the cat.');
        final letter = parse(sample('letter_recognition')) as ChoiceSpec;
        expect(letter.style, ChoiceStyle.glyph);
        expect(letter.correct, {'m'});
        expect(letter.prompt.spoken(), contains('letter m'));
        final count = parse({
          'kind': 'number_recognition',
          'count': 4,
          'picture': 'icon:apple',
        }) as ChoiceSpec;
        expect(count.count, 4);
        expect(count.correct, {'4'});
        expect(judge(count, const PickAnswer({'4'})).correct, isTrue);
        final blank = parse(sample('fill_blank')) as ChoiceSpec;
        expect(blank.sentence!.of(), 'The cow says ___');
        expect(judge(blank, const PickAnswer({'moo'})).correct, isTrue);
      },
    );

    test('hints: words first, then wrong options greyed out; the solution is the right pick', () {
      final s = parse(sample('multiple_choice')) as ChoiceSpec;
      expect(registry.hint(s, 1).text.of(), 'You can eat it!');
      final h2 = registry.hint(s, 2);
      expect(h2.eliminate, isNotEmpty);
      expect(h2.eliminate, isNot(contains('banana')));
      expect((registry.solution(s)! as PickAnswer).ids, {'banana'});
    });

    test('wrong answer type is simply wrong', () {
      final s = parse(sample('multiple_choice'));
      expect(judge(s, const OrderAnswer(['banana'])).correct, isFalse);
    });
  });

  group('placing types', () {
    test('drag to target', () {
      final s = parse(sample('drag_to_target')) as PlaceSpec;
      expect(s.fits('fish', 'water'), isTrue);
      expect(s.fits('fish', 'tree'), isFalse);
      expect(
        judge(s, const PlaceAnswer({'fish': 'water', 'bird': 'tree'})).correct,
        isTrue,
      );
      expect(
        judge(
          s,
          const PlaceAnswer({'fish': 'water', 'bird': 'tree'}, mistakes: 2),
        ).mistakes,
        2,
      );
      expect(
        judge(s, const PlaceAnswer({'fish': 'tree', 'bird': 'water'})).correct,
        isFalse,
      );
      expect(
        judge(s, const PlaceAnswer({'fish': 'water'})).correct,
        isFalse,
        reason: 'not finished',
      );
      expect(registry.hint(s, 2).reveal, hasLength(2));
    });

    test('sorting', () {
      final s = parse(sample('sort')) as PlaceSpec;
      expect(s.targets.map((b) => b.id), ['animals', 'food']);
      expect(
        judge(
          s,
          const PlaceAnswer({
            'cow': 'animals',
            'apple': 'food',
            'duck': 'animals',
          }),
        ).correct,
        isTrue,
      );
      expect(
        judge(
          s,
          const PlaceAnswer({
            'cow': 'food',
            'apple': 'food',
            'duck': 'animals',
          }),
        ).partial,
        closeTo(2 / 3, 1e-9),
      );
    });

    test('matching pairs', () {
      final s = parse(sample('match_pairs')) as PlaceSpec;
      expect(s.tokens, hasLength(3));
      final right = {for (final e in s.solution.entries) e.key: e.value};
      expect(judge(s, PlaceAnswer(right)).correct, isTrue);
      final swapped = {...right, 'l0': right['l1']!, 'l1': right['l0']!};
      expect(judge(s, PlaceAnswer(swapped)).correct, isFalse);
    });
  });

  group('ordering types', () {
    test(
      'word building: letters in order, look-alike pieces are interchangeable',
      () {
        final s = parse({
          'kind': 'word_build',
          'word': 'moon',
          'extra': 'x',
        }) as OrderSpec;
        expect(s.pieces, hasLength(5));
        expect(
          s.start.take(4).join(),
          isNot(s.order.join()),
          reason: 'never starts solved',
        );
        expect(
          judge(s, const OrderAnswer(['w0', 'w1', 'w2', 'w3'])).correct,
          isTrue,
        );
        expect(
          judge(s, const OrderAnswer(['w0', 'w2', 'w1', 'w3'])).correct,
          isTrue,
          reason: 'the two o letters swap freely',
        );
        expect(
          judge(s, const OrderAnswer(['w0', 'w1', 'w3', 'w2'])).correct,
          isFalse,
        );
        expect(registry.hint(s, 1).text.of(), 'm … o … o … n');
      },
    );

    test('puzzle: a picture grid, or labelled pieces in order', () {
      final s = parse(sample('puzzle')) as OrderSpec;
      expect((s.columns, s.pieces.length), (2, 4));
      expect(s.start.join(), isNot(s.order.join()));
      expect(judge(s, OrderAnswer(s.order)).correct, isTrue);
      expect(judge(s, OrderAnswer(s.start)).correct, isFalse);
      final story = parse({
        'kind': 'puzzle',
        'pieces': ['plant', 'water', 'grow'],
      }) as OrderSpec;
      expect(story.columns, 0);
      expect(
        judge(story, const OrderAnswer(['plant', 'nonsense', 'grow'])).correct,
        isFalse,
        reason: 'unknown ids are wrong, not a crash',
      );
      expect(
        judge(story, const OrderAnswer(['plant', 'water', 'grow'])).correct,
        isTrue,
      );
    });
  });

  group('memory', () {
    test('pairs, extra flips as mistakes, hint shows one pair', () {
      final s = parse(sample('memory')) as MemorySpec;
      expect(s.cards, hasLength(6));
      expect(s.pairs, 3);
      expect(judge(s, const MemoryAnswer(flips: 3, pairsFound: 3)).mistakes, 0);
      expect(judge(s, const MemoryAnswer(flips: 9, pairsFound: 3)).mistakes, 3);
      expect(
        judge(s, const MemoryAnswer(flips: 9, pairsFound: 2)).correct,
        isFalse,
      );
      final reveal = registry.hint(s, 2).reveal.toList();
      expect(MemorySpec.pairOf(reveal[0]), MemorySpec.pairOf(reveal[1]));
    });

    test('younger children get fewer pairs', () {
      final s = parse({
        'kind': 'memory',
        'cards': ['a', 'b', 'c', 'd', 'e'],
      }, policy: const DifficultyPolicy(maxOptions: 3)) as MemorySpec;
      expect(s.pairs, 3);
    });
  });

  group('tracing', () {
    TraceAnswer follow(
      TraceSpec s, {
      double dx = 0,
      double dy = 0,
      double keep = 1,
    }) => TraceAnswer([
      for (final stroke in s.strokes)
        [
          for (final p in TraceSpec.resample(
            stroke,
            0.02,
          ).take((TraceSpec.resample(stroke, 0.02).length * keep).ceil()))
            Pt(p.x + dx, p.y + dy),
        ],
    ]);

    test('following the path passes for every built-in glyph', () {
      for (final g in Glyphs.known.split('')) {
        final s = parse({'kind': 'trace', 'glyph': g}) as TraceSpec;
        expect(judge(s, follow(s)).correct, isTrue, reason: 'glyph $g');
        expect(
          judge(s, follow(s, dx: 0.03, dy: -0.03)).correct,
          isTrue,
          reason: 'a little wobble is fine ($g)',
        );
      }
    });

    test('scribbles, half a letter and a shifted letter fail', () {
      final s = parse({'kind': 'trace', 'glyph': 'b'}) as TraceSpec;
      expect(
        judge(s, follow(s, keep: 0.4)).correct,
        isFalse,
        reason: 'half done',
      );
      expect(
        judge(s, follow(s, dx: 0.3)).correct,
        isFalse,
        reason: 'next to the letter',
      );
      final scribble = TraceAnswer([
        [for (var i = 0; i < 40; i++) Pt((i % 7) / 7, (i % 5) / 5)],
      ]);
      expect(judge(s, scribble).correct, isFalse);
      expect(
        judge(
          s,
          const TraceAnswer([
            [Pt(0.5, 0.5)],
          ]),
        ).correct,
        isFalse,
        reason: 'a dot',
      );
    });

    test('custom strokes in content', () {
      final s = parse({
        'kind': 'trace',
        'strokes': [
          [
            [0.2, 0.5],
            [0.8, 0.5],
          ],
        ],
      }) as TraceSpec;
      expect(judge(s, follow(s)).correct, isTrue);
    });

    test('younger children get a wider tolerance', () {
      final young = DifficultyPolicy.forChild(ageMonths: 40).traceTolerance;
      final older = DifficultyPolicy.forChild(ageMonths: 90).traceTolerance;
      expect(young, greaterThan(older));
    });
  });

  test('difficulty policy by age', () {
    final toddler = DifficultyPolicy.forChild(ageMonths: 36);
    final reader = DifficultyPolicy.forChild(ageMonths: 90, difficulty: 3);
    expect(
      (toddler.maxOptions, toddler.maxAttempts, toddler.autoSpeak),
      (3, 3, true),
    );
    expect(
      (reader.maxOptions, reader.maxAttempts, reader.autoSpeak),
      (6, 2, false),
    );
  });
}
