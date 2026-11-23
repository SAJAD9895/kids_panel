import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kids_app/app/router/routes.dart';
import 'package:kids_app/core/audio/sfx.dart';
import 'package:kids_app/core/audio/speech.dart';
import 'package:kids_app/core/error/failure.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/demo/demo_games.dart';
import 'package:kids_app/features/play/data/play_data.dart';
import 'package:kids_app/features/play/domain/engine.dart';
import 'package:kids_app/features/play/domain/item_spec.dart';
import 'package:kids_app/features/play/domain/kinds/arrange_kinds.dart';
import 'package:kids_app/features/play/domain/kinds/memory_trace_kinds.dart';
import 'package:kids_app/features/play/domain/session_report.dart';
import 'package:kids_app/features/play/presentation/play_providers.dart';

import '../helpers/game_walker.dart';
import '../helpers/test_app.dart';

/// Phase 10: every game of the collection, every level, through the real player on the demo
/// backend: right and wrong answers, retry, levels and "Next level", play again, pause /
/// resume / leave, sounds, progress saving, and layout at three screen sizes.
void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(
    () => TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue(),
  );

  late DemoBackend demo;
  late MemorySessionStore store;
  late RecordingSpeechService speech;
  late RecordingSoundEffects sounds;

  Future<void> signIn(
    WidgetTester tester, {
    String child = 'Mia',
    Size size = tablet,
  }) async {
    demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
    store = MemorySessionStore();
    speech = RecordingSpeechService();
    sounds = RecordingSoundEffects();
    await pumpApp(
      tester,
      size: size,
      backend: demo,
      store: store,
      speech: speech,
      sounds: sounds,
    );
    await demo.signInWithPassword(
      email: 'alice@example.test',
      password: DemoBackend.alicePassword,
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, child);
  }

  Future<void> open(WidgetTester tester, String slug) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .push(Routes.play(slug));
    await tester.pumpAndSettle();
  }

  PlayerView view(WidgetTester tester, String slug) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(
            playerProvider((
              activityId: slug,
              courseId: null,
              stepId: null,
              source: PlaySource.feed,
            )),
          );

  /// Answers every item of the level being played, right, and checks each is judged right.
  Future<void> playLevel(WidgetTester tester, String slug) async {
    final walker = GameWalker(tester);
    final total = view(tester, slug).run!.items.length;
    for (var i = 0; i < total; i++) {
      final item = view(tester, slug).run!.item;
      await walker.answerRight(item);
      expect(
        find.text('Great job!').evaluate().isNotEmpty ||
            find.text('You did it!').evaluate().isNotEmpty,
        isTrue,
        reason: '$slug ${view(tester, slug).source!.levelId} ${item.kind}',
      );
      await tapLabel(tester, i == total - 1 ? 'Finish' : 'Next');
    }
    expect(view(tester, slug).run!.phase, PlayPhase.completed);
  }

  List<SessionReport> ended(String slug) => demo.received
      .where((r) => r.activityId == slug && r.status != SessionStatus.started)
      .toList();

  testWidgets(
    'Home has a Game room with all eight games; a game opens with its levels',
    (tester) async {
      await signIn(tester);
      final room = find.text('Game room');
      // Home builds its shelves lazily: drag the page up until the row appears.
      await tester.dragUntilVisible(
        room,
        find.text('Explore'),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(room, findsOneWidget);
      for (final g in demoGames) {
        expect(find.text(g.title), findsWidgets, reason: g.title);
      }
      await tapText(tester, 'Memory match');
      await tapLabel(tester, 'Play'); // activity screen → player
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      // Mia is 4½: Medium is picked for her; the board has 6 pairs
      expect(view(tester, 'memory-match').source!.levelId, 'medium');
      await tapLabel(tester, 'Level 3 of 3: Hard');
      expect(view(tester, 'memory-match').source!.levelId, 'hard');
      expect(
        (view(tester, 'memory-match').run!.items.single as MemorySpec).pairs,
        8,
      );
      expect(sounds.played, contains(Sfx.tap));
    },
  );

  for (final g in demoGames) {
    testWidgets(
      '${g.title}: Easy → Medium → Hard with "Next level", every answer right, all saved',
      (tester) async {
        await signIn(tester);
        await open(tester, g.slug);
        await tapLabel(tester, 'Level 1 of 3: Easy');
        await tapLabel(tester, 'Play');
        for (final level in ['easy', 'medium', 'hard']) {
          expect(view(tester, g.slug).source!.levelId, level);
          await playLevel(tester, g.slug);
          await dismissCelebrations(tester);
          expect(find.text('You did it!'), findsOneWidget);
          final total = view(tester, g.slug).run!.items.length;
          if (total > 1) {
            expect(
              find.textContaining('$total of $total right'),
              findsOneWidget,
            );
          }
          if (level != 'hard') {
            await tapLabel(
              tester,
              'Next level: ${level == 'easy' ? 'Medium' : 'Hard'}',
            );
          }
        }
        expect(find.bySemanticsLabel(RegExp('^Next level')), findsNothing);
        expect(find.bySemanticsLabel('Play again'), findsOneWidget);

        final reports = ended(g.slug);
        expect(reports.map((r) => r.level), ['easy', 'medium', 'hard']);
        expect(
          reports.every((r) => r.completed && r.correctCount == r.totalCount),
          isTrue,
        );
        expect(reports.map((r) => r.run), [1, 2, 3]);
        expect(
          reports.map((r) => r.sessionId).toSet(),
          hasLength(3),
          reason: 'each level is its own session',
        );
        expect(
          demo.received.where(
            (r) => r.status == SessionStatus.started && r.activityId == g.slug,
          ),
          hasLength(3),
        );
        expect(store.outbox, isEmpty, reason: 'delivered');
        expect(store.snapshots, isEmpty);
        expect(sounds.played, containsAll([Sfx.correct, Sfx.complete]));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'wrong answers and mistakes in every game: try again, hint, then right',
    (tester) async {
      await signIn(tester);
      final walker = GameWalker(tester);
      for (final g in demoGames) {
        await open(tester, g.slug);
        await tapLabel(tester, 'Level 1 of 3: Easy');
        await tapLabel(tester, 'Play');
        final item = view(tester, g.slug).run!.item;
        sounds.played.clear();
        if (await walker.answerWrong(item)) {
          expect(
            find.text('Almost! Try again.'),
            findsOneWidget,
            reason: g.slug,
          );
          expect(sounds.played, contains(Sfx.tryAgain));
          expect(view(tester, g.slug).run!.current.wrongAttempts, 1);
          await tapLabel(tester, 'Try again');
          await walker.answerRight(item);
          expect(
            find.text('Great job!').evaluate().isNotEmpty ||
                find.text('You did it!').evaluate().isNotEmpty,
            isTrue,
          );
        } else {
          // Placing, memory, jigsaw: a wrong move is caught on the spot and counted as a
          // mistake; the item still ends right.
          switch (item) {
            case MemorySpec m:
              final a = m.cards.indexWhere((c) => true);
              final b = m.cards.indexWhere(
                (c) =>
                    MemorySpec.pairOf(c.id) != MemorySpec.pairOf(m.cards[a].id),
              );
              await tapLabel(tester, 'Card ${a + 1}, face down');
              await tapLabel(tester, 'Card ${b + 1}, face down');
              expect(
                find.bySemanticsLabel(RegExp('^1 move, 3 pairs left')),
                findsOneWidget,
              );
              expect(sounds.played.where((s) => s == Sfx.flip), hasLength(2));
              await tester.pump(
                const Duration(seconds: 1),
              ); // the pair turns back
              await tester.pumpAndSettle();
              expect(
                find.bySemanticsLabel('Card ${a + 1}, face down'),
                findsOneWidget,
              );
            case JigsawSpec j:
              await tapLabel(tester, 'Piece 1');
              await tester.tap(
                find.bySemanticsLabel(RegExp('^Place 2,')).first,
              );
              await tester.pumpAndSettle();
              expect(
                find.bySemanticsLabel('Piece 1'),
                findsOneWidget,
                reason: 'bounced',
              );
              expect(j.tokens, hasLength(4));
            case PlaceSpec p:
              final t = p.tokens.first;
              final wrong = p.targets.firstWhere(
                (x) => x.id != p.solution[t.id],
              );
              await tester.tap(find.bySemanticsLabel(t.spoken()).first);
              await tester.pumpAndSettle();
              await tester.tap(
                find
                    .bySemanticsLabel(
                      RegExp('^${RegExp.escape(wrong.spoken())}(,|\$)'),
                    )
                    .last,
              );
              await tester.pumpAndSettle();
              expect(speech.said.last, 'Not there. Try another place!');
            default:
              fail('${g.slug}: no wrong path for ${item.kind}');
          }
          expect(sounds.played, isNotEmpty);
          await walker.answerRight(item);
          final cur = view(tester, g.slug).run!.current;
          expect(cur.correct, isTrue, reason: g.slug);
          if (item is MemorySpec) {
            // a little guessing is allowed (2 flips per pair) before misses cost points
            expect(find.text('Great job!'), findsOneWidget);
          } else {
            expect(find.text('You did it!'), findsOneWidget, reason: g.slug);
            expect(cur.mistakes, greaterThan(0), reason: g.slug);
          }
        }
        // leave this game (saved for later) and go on to the next one
        await tapLabel(tester, 'Pause');
        await tapLabel(tester, 'Stop for now');
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pause, sounds off, leave mid-game, keep going on the same level; play again',
    (tester) async {
      await signIn(tester);
      await open(tester, 'memory-match');
      await tapLabel(tester, 'Level 3 of 3: Hard');
      await tapLabel(tester, 'Play');
      final m = view(tester, 'memory-match').run!.item as MemorySpec;
      final first = MemorySpec.pairOf(m.cards.first.id);
      final mate =
          m.cards.indexWhere((c) => c.id == '$first#2' || c.id == '$first#1') ==
              0
          ? m.cards.lastIndexWhere((c) => MemorySpec.pairOf(c.id) == first)
          : 0;
      await tapLabel(tester, 'Card 1, face down');
      await tapLabel(tester, 'Card ${mate + 1}, face down');
      expect(sounds.played, contains(Sfx.match));
      expect(
        find.bySemanticsLabel(RegExp(r'^1 move, 7 pairs left, time \d:\d\d$')),
        findsOneWidget,
      );

      // pause: the clock stops; sounds can be switched off and the voice kept
      await tapLabel(tester, 'Pause');
      expect(view(tester, 'memory-match').run!.resumedAt, isNull);
      await tapLabel(tester, 'Sounds on');
      expect(find.bySemanticsLabel('Sounds off'), findsOneWidget);
      await tapLabel(tester, 'Keep playing');
      sounds.played.clear();
      await tapLabel(tester, 'Card 2, face down');
      expect(sounds.played, isEmpty, reason: 'sounds off');
      expect(
        speech.said,
        isNotEmpty,
        reason: 'the voice still reads the cards',
      );

      // leave mid-game: saved with its level, not reported as abandoned
      await tapLabel(tester, 'Pause');
      await tapLabel(tester, 'Stop for now');
      expect(store.snapshots.values.single['level'], 'hard');
      expect(ended('memory-match'), isEmpty);
      await open(tester, 'memory-match');
      expect(find.text('Keep going?'), findsOneWidget);
      await tapLabel(tester, 'Keep going');
      final back = view(tester, 'memory-match');
      expect(back.source!.levelId, 'hard');
      expect((back.run!.item as MemorySpec).pairs, 8);
      final sessionId = back.run!.sessionId;
      await GameWalker(tester).answerRight(back.run!.item);
      await tapLabel(tester, 'Finish');
      expect(find.textContaining(RegExp(r'\d+ moves')), findsOneWidget);
      expect(find.textContaining('Time '), findsOneWidget);
      final done = ended('memory-match').single;
      expect(
        (done.sessionId, done.level, done.completed),
        (sessionId, 'hard', true),
      );

      // play again: a new session on the same level
      await tapLabel(tester, 'Play again');
      final again = view(tester, 'memory-match').run!;
      expect((again.level, again.run), ('hard', 2));
      expect(again.sessionId, isNot(sessionId));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a game played offline is saved on the device and sent later', (
    tester,
  ) async {
    await signIn(tester);
    await open(tester, 'quiz-time');
    await tapLabel(tester, 'Level 1 of 3: Easy');
    await tapLabel(tester, 'Play');
    final walker = GameWalker(tester);
    final total = view(tester, 'quiz-time').run!.items.length;
    for (var i = 0; i < total; i++) {
      if (i == total - 1) demo.failNextSync = const NetworkFailure();
      await walker.answerRight(view(tester, 'quiz-time').run!.item);
      await tapLabel(tester, i == total - 1 ? 'Finish' : 'Next');
    }
    expect(
      find.text('Saved on this device. It will be sent when you are online.'),
      findsOneWidget,
    );
    expect(store.outbox, isNotEmpty);
    await tapLabel(tester, 'Play again'); // the next game flushes the outbox
    expect(ended('quiz-time').single.level, 'easy');
  });

  // Layout: every game's hardest level at a phone held sideways, a tablet and a desktop:
  // tap targets, labels, contrast, no overflow, on every item.
  for (final (name, size) in [
    ('phone landscape', phoneLandscape),
    ('tablet', tablet),
    ('desktop', desktop),
  ]) {
    testWidgets('every game, Hard level, laid out for $name', (tester) async {
      await signIn(tester, size: size);
      final handle = tester.ensureSemantics();
      final walker = GameWalker(tester);
      for (final g in demoGames) {
        await open(tester, g.slug);
        await tapLabel(tester, 'Level 3 of 3: Hard');
        await tapLabel(tester, 'Play');
        final total = view(tester, g.slug).run!.items.length;
        for (var i = 0; i < total; i++) {
          final item = view(tester, g.slug).run!.item;
          final why = '${g.slug} ${item.kind} ($name)';
          await expectLater(
            tester,
            meetsGuideline(iOSTapTargetGuideline),
            reason: why,
          );
          await expectLater(
            tester,
            meetsGuideline(labeledTapTargetGuideline),
            reason: why,
          );
          await expectLater(
            tester,
            meetsGuideline(textContrastGuideline),
            reason: why,
          );
          expect(tester.takeException(), isNull, reason: why);
          await walker.answerRight(item);
          await tapLabel(tester, i == total - 1 ? 'Finish' : 'Next');
        }
        await dismissCelebrations(tester);
        expect(find.text('You did it!'), findsOneWidget);
        await tapLabel(tester, 'Home');
      }
      handle.dispose();
    });
  }

  testWidgets(
    'a 16-card memory board fits a phone held sideways without scrolling',
    (tester) async {
      await signIn(tester, size: phoneLandscape);
      await open(tester, 'memory-match');
      await tapLabel(tester, 'Level 3 of 3: Hard');
      await tapLabel(tester, 'Play');
      final screen = tester.getRect(find.byType(Scaffold).first);
      for (var i = 1; i <= 16; i++) {
        final card = tester.getRect(
          find.bySemanticsLabel('Card $i, face down'),
        );
        expect(
          screen.contains(card.bottomRight - const Offset(1, 1)),
          isTrue,
          reason: 'card $i',
        );
        expect(card.width, greaterThanOrEqualTo(64));
      }
    },
  );

  test('every game\'s items are walkable by the helper (no unknown kinds)', () {
    final kinds = {
      for (final g in demoGameContent.values)
        for (final l in g['levels']! as List)
          for (final i in (l as Map)['items'] as List) (i as Map)['kind'],
    };
    expect(
      kinds.difference({
        'memory',
        'match_pairs',
        'drag_to_target',
        'word_build',
        'number_recognition',
        'arithmetic',
        'letter_recognition',
        'trace',
        'sort',
        'jigsaw',
        'shape_complete',
        'puzzle',
        'image_choice',
        'audio_choice',
        'multiple_choice',
        'fill_blank',
      }),
      isEmpty,
    );
    expect(const Pt(0, 0).dist(const Pt(3, 4)), 5);
    expect(JigsawSpec.indexOf('p12'), 12);
  });
}
