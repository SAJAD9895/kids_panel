import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/demo/demo_activity_content.dart';
import 'package:kids_app/demo/demo_games.dart';
import 'package:kids_app/features/learning/domain/catalog.dart';
import 'package:kids_app/features/play/data/play_data.dart';
import 'package:kids_app/features/play/data/quiz_mapping.dart';
import 'package:kids_app/features/play/domain/engine.dart';
import 'package:kids_app/features/play/domain/item_spec.dart';
import 'package:kids_app/features/play/domain/kinds/choice_kinds.dart';
import 'package:kids_app/features/play/domain/registry.dart';
import 'package:kids_app/features/play/domain/session_report.dart';

void main() {
  final registry = KindRegistry.standard();
  const policy = DifficultyPolicy(maxOptions: 4, maxAttempts: 3);
  const engine = SessionEngine.new;
  final eng = engine(registry, policy);
  final t0 = DateTime.utc(2026, 11, 18, 10);
  DateTime at(int s) => t0.add(Duration(seconds: s));

  ActivitySource source(List<Map<String, Object?>> items) => ActivitySource(
    activity: const ActivitySummary(
      id: 'act',
      slug: 'act',
      type: ActivityType.game,
      title: LocalizedText({'en': 'Test'}),
    ),
    rawItems: [for (final i in items) i.cast<String, dynamic>()],
  );

  final letters = source([
    {'kind': 'letter_recognition', 'target': 'b'},
    {'kind': 'letter_recognition', 'target': 'd'},
  ]);

  RunState start({String id = 'session-1', ActivitySource? src}) {
    final s = src ?? letters;
    return eng.begin(
      eng.create(
        sessionId: id,
        childId: 'child',
        activityId: 'act',
        items: s.build(registry, policy, id),
        now: t0,
      ),
      t0,
    );
  }

  group('engine', () {
    test(
      'right first time: full marks, then the next item, then completed',
      () {
        var s = start();
        expect((s.phase, s.index), (PlayPhase.question, 0));
        final (a, v) = eng.answer(s, const PickAnswer({'b'}), at(4));
        expect(v.correct, isTrue);
        expect(
          (a.phase, a.feedback),
          (PlayPhase.feedback, FeedbackKind.correct),
        );
        s = eng.next(a, at(5));
        expect(s.index, 1);
        s = eng.next(eng.answer(s, const PickAnswer({'d'}), at(9)).$1, at(10));
        expect(s.phase, PlayPhase.completed);
        expect(
          (s.score, s.correctCount, s.incorrectCount, s.celebrationStars),
          (100, 2, 0, 3),
        );
        expect(s.endedAt, at(10));
        expect(s.progress.first.spentMs, 4000);
      },
    );

    test('wrong → try again → right: lower points, attempts counted', () {
      var s = start();
      s = eng.answer(s, const PickAnswer({'d'}), at(2)).$1;
      expect(s.feedback, FeedbackKind.tryAgain);
      expect(eng.next(s, at(3)).index, 0, reason: "can't skip a try-again");
      s = eng.retry(s, at(3));
      expect(s.phase, PlayPhase.question);
      s = eng.answer(s, const PickAnswer({'b'}), at(5)).$1;
      expect(s.current.attempts, 2);
      expect(s.current.points, 0.75);
      expect(s.current.answers, [
        ['d'],
        ['b'],
      ]);
    });

    test(
      'out of tries: the answer is revealed, the item scores 0, play goes on',
      () {
        var s = start();
        for (var i = 0; i < 3; i++) {
          s = eng.answer(s, const PickAnswer({'d'}), at(i * 2)).$1;
          if (s.feedback == FeedbackKind.tryAgain) {
            s = eng.retry(s, at(i * 2 + 1));
          }
        }
        expect(s.feedback, FeedbackKind.revealed);
        expect(
          (s.current.revealed, s.current.correct, s.current.points),
          (true, false, 0.0),
        );
        expect(
          eng.answer(s, const PickAnswer({'b'}), at(9)).$1.current.correct,
          isFalse,
          reason: 'no answers after the reveal',
        );
        s = eng.next(s, at(10));
        expect(s.index, 1);
      },
    );

    test(
      'hints raise the level until there is nothing more, and cost points',
      () {
        var s = start();
        final (a, h1) = eng.hint(s);
        expect(h1.text.isEmpty, isFalse);
        final (b, h2) = eng.hint(a);
        expect(h2.eliminate, isNotEmpty);
        final (c, _) = eng.hint(b);
        expect(c.current.hintLevel, 2, reason: 'no third level for choices');
        s = eng.answer(c, const PickAnswer({'b'}), at(3)).$1;
        expect(s.current.points, closeTo(0.8, 1e-9));
        expect(s.hintsUsed, 2);
      },
    );

    test('pauses do not count as time played', () {
      var s = start();
      s = eng.pause(s, at(10));
      s = eng.resume(s, at(70)); // a minute away
      expect(s.activeMsAt(at(80)), 20000);
    });

    test('snapshot → restore: same session, same items, same progress; finished items are skipped', () {
      var s = start();
      s = eng
          .answer(s, const PickAnswer({'d'}), at(2))
          .$1; // wrong, still on item 0
      final json =
          jsonDecode(jsonEncode(s.toSnapshot(at(3)))) as Map<String, dynamic>;
      final items = letters.build(
        registry,
        policy,
        json['sessionId'] as String,
      );
      final r = eng.restore(json, items)!;
      expect(
        (r.sessionId, r.index, r.phase),
        ('session-1', 0, PlayPhase.question),
      );
      expect(r.current.wrongAttempts, 1);
      expect(r.activeMs, 3000);
      expect(
        [
          for (final i in r.items)
            (i as ChoiceSpec).options.map((o) => o.id).join(),
        ],
        [
          for (final i in s.items)
            (i as ChoiceSpec).options.map((o) => o.id).join(),
        ],
        reason: 'options in the same order (seeded by the session id)',
      );

      var done = eng.retry(s, at(4));
      done = eng
          .answer(done, const PickAnswer({'b'}), at(5))
          .$1; // item 0 done, feedback showing
      final r2 = eng.restore(
        jsonDecode(jsonEncode(done.toSnapshot(at(6)))) as Map<String, dynamic>,
        items,
      )!;
      expect(r2.index, 1, reason: 'continue with the next item');
    });

    test('restore refuses a snapshot when the content changed', () {
      final s = start();
      final snap =
          jsonDecode(jsonEncode(s.toSnapshot(at(1)))) as Map<String, dynamic>;
      final other = source([
        {'kind': 'letter_recognition', 'target': 'q'},
      ]).build(registry, policy, 'session-1');
      expect(eng.restore(snap, other), isNull);
      expect(
        eng.restore({
          ...snap,
          'v': 99,
        }, letters.build(registry, policy, 'session-1')),
        isNull,
      );
    });

    test('play again: new session, everything reset, run counted', () {
      final s = eng.next(
        eng.answer(start(), const PickAnswer({'b'}), at(1)).$1,
        at(2),
      );
      final again = eng.again(s, sessionId: 'session-2', now: at(3));
      expect(
        (again.sessionId, again.run, again.index, again.correctCount),
        ('session-2', 2, 0, 0),
      );
    });

    test('an activity needs items', () {
      expect(
        () => eng.create(
          sessionId: 'x',
          childId: 'c',
          activityId: 'a',
          items: const [],
          now: t0,
        ),
        throwsA(isA<ContentException>()),
      );
    });
  });

  group('session report (POST /play/sync item)', () {
    test('start and end reports match the server contract', () {
      var s = start();
      final started = SessionReport.started(
        s,
        source: PlaySource.course,
        platform: 'ios',
        appVersion: '1.0.0',
      );
      expect(started.toJson()['result'], isNull);
      expect((started.toJson()['session'] as Map)['status'], 'started');
      s = eng.next(eng.answer(s, const PickAnswer({'b'}), at(2)).$1, at(3));
      s = eng.next(eng.answer(s, const PickAnswer({'d'}), at(5)).$1, at(6));
      final ended = SessionReport.ended(
        s,
        now: at(6),
        source: PlaySource.course,
        platform: 'ios',
        appVersion: '1.0.0',
      );
      final json = ended.toJson();
      final session = json['session'] as Map, result = json['result'] as Map;
      expect(session.keys.toSet(), {
        'id',
        'childId',
        'activityId',
        'source',
        'platform',
        'appVersion',
        'contentVersion',
        'status',
        'startedAt',
        'endedAt',
      });
      expect(session['status'], 'completed');
      expect(session['source'], 'course');
      expect(
        (
          result['completed'],
          result['score'],
          result['correctCount'],
          result['totalCount'],
          result['durationMs'],
        ),
        (true, 100, 2, 2, 6000),
      );
      expect(
        ((result['metrics'] as Map)['items'] as List).first,
        containsPair('k', 'letter_recognition'),
      );
      expect(
        utf8.encode(jsonEncode(result['metrics'])).length,
        lessThan(8192),
        reason: 'activity_results.metrics limit',
      );
      final back = SessionReport.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(
        (back.sessionId, back.status, back.score, back.items.length),
        (s.sessionId, SessionStatus.completed, 100, 2),
      );
    });

    test('leaving early is "abandoned" with what was done so far', () {
      var s = start();
      s = eng.answer(s, const PickAnswer({'b'}), at(2)).$1;
      final r = SessionReport.ended(
        s,
        now: at(3),
        source: PlaySource.feed,
        platform: 'web',
        appVersion: '1.0.0',
      );
      expect(
        (r.status, r.completed, r.score, r.totalCount),
        (SessionStatus.abandoned, false, null, 1),
      );
    });

    test('quiz items report one response per question and attempt, with the answer id', () {
      final quiz = source([
        itemFromQuestion({
          'id': 'q1',
          'type': 'single_choice',
          'prompt': {'en': 'Which one is a?'},
          'answers': [
            {
              'id': 'ans-a',
              'position': 0,
              'content': {'en': 'a'},
              'is_correct': true,
            },
            {
              'id': 'ans-b',
              'position': 1,
              'content': {'en': 'b'},
              'is_correct': false,
            },
          ],
        })!,
      ]);
      var s = start(src: quiz);
      s = eng.retry(
        eng.answer(s, const PickAnswer({'ans-b'}), at(1)).$1,
        at(2),
      );
      s = eng.next(eng.answer(s, const PickAnswer({'ans-a'}), at(3)).$1, at(4));
      final r = SessionReport.ended(
        s,
        now: at(4),
        source: PlaySource.feed,
        platform: 'web',
        appVersion: '1.0.0',
      );
      expect(r.responses, [
        {
          'questionId': 'q1',
          'attempt': 1,
          'isCorrect': false,
          'answerId': 'ans-b',
          'responseMs': null,
        },
        {
          'questionId': 'q1',
          'attempt': 2,
          'isCorrect': true,
          'answerId': 'ans-a',
          'responseMs': 2000,
        },
      ]);
    });
  });

  group('quiz mapping', () {
    test('choice, listen, match and order questions', () {
      expect(
        itemFromQuestion({
          'id': 'q',
          'type': 'listen_choose',
          'prompt': {'en': 'Find the dog'},
          'answers': [],
        })!['kind'],
        'audio_choice',
      );
      final match = itemFromQuestion({
        'id': 'q',
        'type': 'match',
        'prompt': {'en': 'Match'},
        'answers': [
          {
            'id': '1',
            'position': 0,
            'content': {'en': 'cat'},
            'match_key': 'a',
          },
          {
            'id': '2',
            'position': 1,
            'content': {'picture': 'icon:cat'},
            'match_key': 'a',
          },
          {
            'id': '3',
            'position': 2,
            'content': {'en': 'sun'},
            'match_key': 'b',
          },
          {
            'id': '4',
            'position': 3,
            'content': {'picture': 'icon:sun'},
            'match_key': 'b',
          },
        ],
      })!;
      expect(match['kind'], 'match_pairs');
      expect((match['pairs'] as List).first, {
        'left': {
          'id': '1',
          'label': {'en': 'cat'},
        },
        'right': {'id': '2', 'picture': 'icon:cat'},
      });
      final order = itemFromQuestion({
        'id': 'q',
        'type': 'order',
        'prompt': {'en': 'In order'},
        'answers': [
          {
            'id': 'x',
            'position': 0,
            'content': {'en': 'grow'},
            'correct_order': 2,
          },
          {
            'id': 'y',
            'position': 1,
            'content': {'en': 'plant'},
            'correct_order': 0,
          },
        ],
      })!;
      expect(
        [for (final p in order['pieces'] as List) (p as Map)['id']],
        ['y', 'x'],
      );
      expect(
        itemFromQuestion({
          'id': 'q',
          'type': 'tap_somewhere_new',
          'answers': [],
        }),
        isNull,
      );
    });

    test(
      'a Supabase row (games.config + questions) becomes a playable source',
      () {
        final src = SupabaseActivityContentRepository.sourceFromRow({
          'id': 'a1',
          'slug': 'x',
          'type': 'game',
          'title': {'en': 'X'},
          'difficulty': 2,
          'content_version': 3,
          'games': {
            'config': {
              'intro': 'Hello',
              'items': [
                {'kind': 'trace', 'glyph': 'o'},
              ],
            },
          },
          'questions': [],
        });
        expect(
          (
            src.playable,
            src.difficulty,
            src.contentVersion,
            src.intro.text.of(),
          ),
          (true, 2, 3, 'Hello'),
        );
        expect(src.build(registry, policy, 's').single.kind, 'trace');
      },
    );
  });

  test('the seed and the demo content are the same (seed.sql §14 is generated from it)', () {
    final seed = File('../supabase/seed.sql').readAsStringSync();
    final rows = RegExp(
      r"update games set config = '(.*)'::jsonb -- engine:([a-z0-9-]+)",
    ).allMatches(seed);
    final fromSeed = {
      for (final m in rows)
        m.group(2)!: jsonDecode(m.group(1)!.replaceAll("''", "'")),
    };
    expect(fromSeed.keys.toSet(), {
      ...demoActivityContent.keys,
      ...demoGameContent.keys,
    }, reason: 'run: dart run tool/seed_content_sql.dart --write');
    for (final e in {...demoActivityContent, ...demoGameContent}.entries) {
      expect(
        fromSeed[e.key],
        jsonDecode(jsonEncode(e.value)),
        reason: '${e.key} differs: dart run tool/seed_content_sql.dart --write',
      );
    }
  });

  test('every piece of demo content parses for every age', () {
    for (final age in [24, 48, 72, 108]) {
      final p = DifficultyPolicy.forChild(ageMonths: age);
      for (final e in demoActivityContent.entries) {
        final src = source([
          for (final i in e.value['items']! as List)
            (i as Map).cast<String, Object?>(),
        ]);
        expect(
          () => src.build(registry, p, 's'),
          returnsNormally,
          reason: '${e.key} at $age months',
        );
      }
    }
  });

  group('outbox (on-device store)', () {
    test('memory store: snapshots and outbox by key', () async {
      final store = MemorySessionStore();
      await store.saveSnapshot('c', 'a', {'x': 1});
      expect(await store.loadSnapshot('c', 'a'), {'x': 1});
      await store.clearSnapshot('c', 'a');
      expect(await store.loadSnapshot('c', 'a'), isNull);
      final s = start();
      final r1 = SessionReport.started(
        s,
        source: PlaySource.feed,
        platform: 'web',
        appVersion: '1',
      );
      await store.enqueue(r1);
      await store.enqueue(r1); // same key: replaced, not doubled
      expect(await store.pending(), hasLength(1));
    });
  });
}
