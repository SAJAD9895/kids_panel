import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/demo/demo_games.dart';
import 'package:kids_app/features/learning/domain/catalog.dart';
import 'package:kids_app/features/play/domain/engine.dart';
import 'package:kids_app/features/play/domain/item_spec.dart';
import 'package:kids_app/features/play/domain/kinds/arrange_kinds.dart';
import 'package:kids_app/features/play/domain/kinds/choice_kinds.dart';
import 'package:kids_app/features/play/domain/kinds/memory_trace_kinds.dart';
import 'package:kids_app/features/play/domain/registry.dart';
import 'package:kids_app/features/play/domain/run_summary.dart';
import 'package:kids_app/features/play/domain/session_report.dart';

/// Phase 10: the game collection's content and the engine pieces it added (levels, sums,
/// shape completion, jigsaws, letter sounds and cases, capitals to trace, colours and sizes).
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

  ActivitySource game(String slug) => ActivitySource.fromConfig(
    activity: ActivitySummary(
      id: slug,
      slug: slug,
      type: ActivityType.game,
      title: LocalizedText({'en': slug}),
    ),
    config: demoGameContent[slug]!.cast<String, dynamic>(),
  );

  group('the collection', () {
    test('eight games, each with Easy, Medium and Hard', () {
      expect(demoGames.map((g) => g.slug), [
        'memory-match',
        'picture-match',
        'word-builder',
        'number-fun',
        'alphabet-adventure',
        'sort-it-out',
        'puzzle-time',
        'quiz-time',
      ]);
      for (final g in demoGames) {
        final src = game(g.slug);
        expect(src.levels.map((l) => l.id), [
          'easy',
          'medium',
          'hard',
        ], reason: g.slug);
        expect(src.playable, isTrue);
      }
    });

    test('every level of every game parses for every age', () {
      for (final g in demoGames) {
        for (final age in [24, 36, 48, 60, 72, 96, 120]) {
          final base = DifficultyPolicy.forChild(ageMonths: age);
          for (final l in game(g.slug).levels) {
            final src = game(g.slug).forLevel(l.id);
            final items = src.build(registry, l.apply(base), 'session-$age');
            expect(items, isNotEmpty, reason: '${g.slug}/${l.id} at $age');
            expect(
              items.every((i) => i.id.startsWith('${l.id}/')),
              isTrue,
              reason: 'level items have level ids (resume safety)',
            );
          }
        }
      }
    });

    test('each game covers the mechanics the brief asks for', () {
      Set<String> kinds(String slug) => {
        for (final l in game(slug).levels)
          for (final i in l.rawItems) '${i['kind']}',
      };
      Set<String> modes(String slug) => {
        for (final l in game(slug).levels)
          for (final i in l.rawItems)
            if (i['kind'] == 'letter_recognition') '${i['mode'] ?? 'name'}',
      };
      expect(kinds('memory-match'), {'memory'});
      expect(
        kinds('picture-match'),
        containsAll(['match_pairs', 'drag_to_target']),
      );
      expect(kinds('word-builder'), {'word_build'});
      expect(
        kinds('number-fun'),
        containsAll(['number_recognition', 'match_pairs', 'arithmetic']),
      );
      expect(
        kinds('alphabet-adventure'),
        containsAll(['letter_recognition', 'match_pairs', 'trace']),
      );
      expect(modes('alphabet-adventure'), {'name', 'case', 'sound'});
      expect(kinds('sort-it-out'), {'sort'});
      expect(kinds('puzzle-time'), containsAll(['jigsaw', 'shape_complete']));
      expect(
        kinds('quiz-time'),
        containsAll(['multiple_choice', 'image_choice', 'audio_choice']),
      );
      // sorting by shape, colour, size and kind
      final pictures = [
        for (final l in game('sort-it-out').levels)
          for (final i in l.rawItems)
            for (final x in i['items'] as List) '${(x as Map)['picture']}',
      ];
      expect(pictures.any((p) => p.contains('color=')), isTrue);
      expect(pictures.any((p) => p.contains('size=')), isTrue);
      expect(pictures.any((p) => p.startsWith('shape:')), isTrue);
      expect(pictures.any((p) => p.startsWith('icon:cow')), isTrue);
      // the memory game shows a clock on every board, and boards grow by level
      final pairs = [
        for (final l in game('memory-match').levels)
          for (final i in l.rawItems) (i['cards'] as List).length,
      ];
      expect(pairs.last, 8);
      expect(
        game('memory-match').levels
            .every((l) => l.rawItems.every((i) => i['timer'] == true)),
        isTrue,
      );
      // jigsaws grow 2×2 → 3×3 → 4×4
      expect(
        [
          for (final l in game('puzzle-time').levels)
            for (final i in l.rawItems)
              if (i['kind'] == 'jigsaw') i['grid'],
        ],
        [2, 3, 4],
      );
    });

    test(
      'the CMS schema knows every registered activity type, and only those',
      () {
        final schema = jsonDecode(
          File('../supabase/schemas/game-config.schema.json')
              .readAsStringSync(),
        ) as Map<String, dynamic>;
        final kinds =
            ((schema[r'$defs']['item']['properties']['kind']['enum']) as List)
                .cast<String>()
                .toSet();
        expect(kinds, registry.keys.toSet());
      },
    );
  });

  group('levels', () {
    final src = game('memory-match');

    test(
      'the starting level suits the child\'s age; Next level goes up one',
      () {
        expect(src.defaultLevel(30)!.id, 'easy');
        expect(src.defaultLevel(60)!.id, 'medium');
        expect(src.defaultLevel(100)!.id, 'hard');
        expect(src.forLevel('easy').nextLevel!.id, 'medium');
        expect(src.forLevel('hard').nextLevel, isNull);
        expect(src.forLevel('nope').levelId, isNull);
      },
    );

    test('a level sets its own board size, whatever the child\'s age', () {
      final young = DifficultyPolicy.forChild(
        ageMonths: 30,
      ); // 3 options by age
      final hard = src.forLevel('hard');
      final memory = hard.build(registry, young, 's').single as MemorySpec;
      expect(memory.pairs, 8);
      expect(memory.timer, isTrue);
      expect(hard.level!.apply(young).maxOptions, 8);
    });

    test(
      'the level travels with the run: snapshot, restore and the report',
      () {
        final hard = src.forLevel('hard');
        final p = hard.level!.apply(const DifficultyPolicy());
        final eng = SessionEngine(registry, p);
        final t0 = DateTime.utc(2026, 11, 19, 9);
        var run = eng.create(
          sessionId: 's1',
          childId: 'c',
          activityId: 'memory-match',
          items: hard.build(registry, p, 's1'),
          now: t0,
          level: 'hard',
        );
        run = eng.begin(run, t0);
        final snap =
            jsonDecode(jsonEncode(run.toSnapshot(t0))) as Map<String, dynamic>;
        expect(snap['level'], 'hard');
        final back = eng.restore(snap, hard.build(registry, p, 's1'))!;
        expect(back.level, 'hard');
        // an Easy board can't be mistaken for the saved Hard one
        expect(
          eng.restore(snap, src.forLevel('easy').build(registry, p, 's1')),
          isNull,
        );
        final (done, v) = eng.answer(
          run,
          const MemoryAnswer(flips: 10, pairsFound: 8, timeMs: 42000),
          t0.add(const Duration(seconds: 50)),
        );
        expect(v.correct, isTrue);
        expect(
          v.mistakes,
          0,
          reason: '10 flips for 8 pairs is within the allowance',
        );
        final report = SessionReport.ended(
          eng.next(done, t0.add(const Duration(seconds: 55))),
          now: t0.add(const Duration(seconds: 55)),
          source: PlaySource.feed,
          platform: 'web',
          appVersion: '1.0.0',
        );
        final json = report.toJson();
        final metrics = (json['result']! as Map)['metrics'] as Map;
        expect(metrics['level'], 'hard');
        expect(
          SessionReport.fromJson(jsonDecode(jsonEncode(json))).level,
          'hard',
        );
      },
    );

    test('a game without levels keeps working as before', () {
      final plain = ActivitySource.fromConfig(
        activity: const ActivitySummary(
          id: 'x',
          slug: 'x',
          type: ActivityType.game,
          title: LocalizedText({'en': 'x'}),
        ),
        config: {
          'items': [
            {'kind': 'letter_recognition', 'target': 'b'},
          ],
        },
      );
      expect(plain.levels, isEmpty);
      expect(plain.defaultLevel(60), isNull);
      expect(plain.forLevel(null).build(registry, roomy, 's').single.id, 'i0');
    });
  });

  group('number games: adding and taking away', () {
    test('right answer, near-miss options, and the words the voice says', () {
      final s = parse({
        'kind': 'arithmetic',
        'a': 3,
        'op': '+',
        'b': 2,
        'picture': 'icon:apple',
      }) as ChoiceSpec;
      expect(s.correct, {'5'});
      expect(s.options.map((o) => o.id), containsAll(['5', '4', '6']));
      expect(s.equation!.spoken, contains('three apples and two more'));
      expect(s.prompt.text.of(), '3 + 2 = ?');
      expect(judge(s, const PickAnswer({'5'})).correct, isTrue);
      expect(judge(s, const PickAnswer({'4'})).correct, isFalse);
    });

    test('taking away, numbers only', () {
      final s = parse({
        'kind': 'arithmetic',
        'a': 9,
        'op': '-',
        'b': 4,
      }) as ChoiceSpec;
      expect(s.correct, {'5'});
      expect(s.equation!.spoken, 'What is nine take away four?');
      expect(s.hintText.of(), 'Start at 9 and count back 4.');
      expect(s.options.every((o) => int.parse(o.id) >= 0), isTrue);
    });

    test('no negative answers, numbers 0..10, + or − only', () {
      for (final bad in [
        {'a': 2, 'op': '-', 'b': 5},
        {'a': 11, 'op': '+', 'b': 1},
        {'a': 1, 'op': '*', 'b': 1},
        {'a': 1},
      ]) {
        expect(
          () => parse({'kind': 'arithmetic', ...bad}),
          throwsA(isA<ContentException>()),
          reason: '$bad',
        );
      }
    });
  });

  group('alphabet: sounds and big / small letters', () {
    test('letter sounds are heard, not read', () {
      final s = parse({
        'kind': 'letter_recognition',
        'target': 'b',
        'mode': 'sound',
      }) as ChoiceSpec;
      expect(s.audioOnly, isTrue);
      expect(s.prompt.spoken(), contains('buh, like ball'));
      expect(s.correct, {'b'});
    });

    test('see a capital, find the small letter (and back), look-alikes in the same case', () {
      final big = parse({
        'kind': 'letter_recognition',
        'target': 'B',
        'mode': 'case',
      }) as ChoiceSpec;
      expect(big.prompt.picture, const PictureRef('glyph:b'));
      expect(big.options.every((o) => o.id == o.id.toUpperCase()), isTrue);
      final small = parse({
        'kind': 'letter_recognition',
        'target': 'g',
        'mode': 'case',
      }) as ChoiceSpec;
      expect(small.prompt.picture, const PictureRef('glyph:G'));
      expect(small.prompt.spoken(), contains('find the small one'));
    });

    test('capitals can be traced, and a different letter fails', () {
      final l = parse({'kind': 'trace', 'glyph': 'L'}) as TraceSpec;
      final t = parse({'kind': 'trace', 'glyph': 'T'}) as TraceSpec;
      TraceAnswer along(TraceSpec s) => TraceAnswer([
        for (final st in s.strokes) TraceSpec.resample(st, 0.02),
      ]);
      expect(judge(l, along(l)).correct, isTrue);
      expect(judge(t, along(l)).correct, isFalse);
      for (final c in 'AEFHIKLMNOTUVWXYZC'.split('')) {
        expect(Glyphs.strokes(c), isNotNull, reason: c);
      }
    });

    test('big and small letters are named for screen readers', () {
      expect(const PictureRef('glyph:A').describe(), 'big A');
      expect(const PictureRef('glyph:a').describe(), 'small a');
    });
  });

  group('puzzles', () {
    test('jigsaw: every piece has one place; wrong drops are mistakes', () {
      final s = parse({
        'kind': 'jigsaw',
        'picture': 'char:pip',
        'grid': 3,
      }) as JigsawSpec;
      expect(s.tokens, hasLength(9));
      expect(s.targets, hasLength(9));
      expect(s.tokens.map((t) => t.id).join(), isNot('p0p1p2p3p4p5p6p7p8'));
      expect(s.fits('p4', 's4'), isTrue);
      expect(s.fits('p4', 's5'), isFalse);
      expect(s.targets.first.spoken(), 'top left');
      expect(s.targets[4].spoken(), 'middle');
      final all = {for (var i = 0; i < 9; i++) 'p$i': 's$i'};
      final v = judge(s, PlaceAnswer(all, mistakes: 2));
      expect((v.correct, v.mistakes), (true, 2));
      expect(judge(s, const PlaceAnswer({'p0': 's0'})).correct, isFalse);
      expect(registry.hint(s, 2).reveal, hasLength(2));
      for (final bad in [
        {'grid': 3},
        {'picture': 'char:pip', 'grid': 5},
      ]) {
        expect(
          () => parse({'kind': 'jigsaw', ...bad}),
          throwsA(isA<ContentException>()),
        );
      }
    });

    test('shape completion: pick the half that finishes the shape', () {
      final s = parse({
        'kind': 'shape_complete',
        'shape': 'heart',
        'missing': 'right',
        'distractors': ['star', 'circle'],
      }) as ChoiceSpec;
      expect(s.prompt.picture, const PictureRef('gap:heart:right'));
      expect(
        s.options.map((o) => o.picture!.value),
        containsAll([
          'half:heart:right',
          'half:star:right',
          'half:circle:right',
        ]),
      );
      expect(judge(s, const PickAnswer({'heart'})).correct, isTrue);
      expect(judge(s, const PickAnswer({'star'})).correct, isFalse);
      expect(
        () => parse({'kind': 'shape_complete', 'shape': 'blob'}),
        throwsA(isA<ContentException>()),
      );
    });
  });

  group('pictures with colour and size (sorting)', () {
    test('modifiers are read, and named for screen readers', () {
      const p = PictureRef('shape:circle?color=red&size=small');
      expect(
        (p.scheme, p.name, p.color, p.size),
        ('shape', 'circle', 'red', 'small'),
      );
      expect(p.describe(), 'small red circle');
      const odd = PictureRef('icon:cat?color=pink&size=huge');
      expect(
        (odd.color, odd.size),
        (null, null),
        reason: 'unknown values are ignored',
      );
      expect(const PictureRef('count:3:apple').describe(), '3 apple');
    });
  });

  group('completion summary', () {
    test('right answers, and for memory the moves and time', () {
      final src = game('memory-match').forLevel('easy');
      final eng = SessionEngine(registry, src.level!.apply(roomy));
      final t0 = DateTime.utc(2026, 11, 19, 9);
      var run = eng.begin(
        eng.create(
          sessionId: 's',
          childId: 'c',
          activityId: 'memory-match',
          items: src.build(registry, roomy, 's'),
          now: t0,
        ),
        t0,
      );
      for (final t in [21000, 33000]) {
        final (next, _) = eng.answer(
          run,
          MemoryAnswer(flips: 4, pairsFound: 3, timeMs: t),
          t0,
        );
        run = eng.next(next, t0);
      }
      final sum = RunSummary.of(run);
      expect(sum.lines, ['2 of 2 right', '8 moves', 'Time 0:54']);
      expect(RunSummary.clock(125000), '2:05');
    });
  });

  group('performance', () {
    test('building every level of every game is fast (100 sessions < 2 s)', () {
      final sw = Stopwatch()..start();
      var n = 0;
      for (var i = 0; i < 100; i++) {
        for (final g in demoGames) {
          for (final l in game(g.slug).levels) {
            n += game(g.slug)
                .forLevel(l.id)
                .build(registry, roomy, 's$i')
                .length;
          }
        }
      }
      sw.stop();
      expect(n, greaterThan(1000));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('judging 10 000 answers is fast (< 1 s), tracing included', () {
      final trace = parse({'kind': 'trace', 'glyph': 'M'}) as TraceSpec;
      final along = TraceAnswer([
        for (final st in trace.strokes) TraceSpec.resample(st, 0.02),
      ]);
      final sum = parse({'kind': 'arithmetic', 'a': 4, 'op': '+', 'b': 3});
      final sw = Stopwatch()..start();
      for (var i = 0; i < 5000; i++) {
        judge(sum, const PickAnswer({'7'}));
        judge(trace, along);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('a saved run stays small (snapshot of the biggest level < 4 KB)', () {
      for (final g in demoGames) {
        final src = game(g.slug).forLevel('hard');
        final eng = SessionEngine(registry, roomy);
        final t0 = DateTime.utc(2026);
        final run = eng.create(
          sessionId: 's',
          childId: 'c',
          activityId: g.slug,
          items: src.build(registry, roomy, 's'),
          now: t0,
          level: 'hard',
        );
        expect(
          jsonEncode(run.toSnapshot(t0)).length,
          lessThan(4096),
          reason: g.slug,
        );
      }
    });
  });
}
