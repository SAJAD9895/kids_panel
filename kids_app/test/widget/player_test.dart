import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kids_app/app/router/routes.dart';
import 'package:kids_app/core/audio/speech.dart';
import 'package:kids_app/core/error/failure.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/features/play/data/play_data.dart';
import 'package:kids_app/features/play/domain/engine.dart';
import 'package:kids_app/features/play/domain/item_spec.dart';
import 'package:kids_app/features/play/domain/kinds/arrange_kinds.dart';
import 'package:kids_app/features/play/domain/kinds/memory_trace_kinds.dart';
import 'package:kids_app/features/play/domain/session_report.dart';
import 'package:kids_app/features/play/presentation/play_providers.dart';

import '../helpers/test_app.dart';

/// The activity player, on the demo backend, through the real router and screens.
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

  Future<void> signIn(
    WidgetTester tester, {
    String child = 'Mia',
    Size size = tablet,
  }) async {
    demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
    store = MemorySessionStore();
    speech = RecordingSpeechService();
    await pumpApp(
      tester,
      size: size,
      backend: demo,
      store: store,
      speech: speech,
    );
    await demo.signInWithPassword(
      email: 'alice@example.test',
      password: DemoBackend.alicePassword,
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, child);
  }

  Future<void> open(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location);
    await tester.pumpAndSettle();
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

  RunState run(
    WidgetTester tester,
    String activityId, {
    String? course,
    String? step,
  }) => container(tester)
      .read(
        playerProvider((
          activityId: activityId,
          courseId: course,
          stepId: step,
          source: course != null ? PlaySource.course : PlaySource.feed,
        )),
      )
      .run!;

  Future<void> next(WidgetTester tester) async {
    final f = find.bySemanticsLabel(RegExp(r'^(Next|Finish)$'));
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Future<void> traceAlong(WidgetTester tester, TraceSpec spec) async {
    final box = tester.getRect(find.bySemanticsLabel(RegExp('^Tracing area')));
    Offset at(Pt p) =>
        Offset(box.left + p.x * box.width, box.top + p.y * box.height);
    for (final stroke in spec.strokes) {
      final pts = TraceSpec.resample(stroke, 0.03);
      final g = await tester.startGesture(at(pts.first));
      for (final p in pts.skip(1)) {
        await g.moveTo(at(p));
      }
      await g.up();
    }
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Check');
  }

  testWidgets(
    'every activity type plays end to end in one session, and the session is reported',
    (tester) async {
      await signIn(tester);
      await open(tester, Routes.play('engine-sampler'));
      expect(find.text('Try everything!'), findsOneWidget);
      await tapLabel(tester, 'Listen');
      expect(speech.said.last, contains('one of every kind'));
      await tapLabel(tester, 'Play');

      // 1 multiple choice
      expect(find.bySemanticsLabel('Question 1 of 16'), findsOneWidget);
      await tapLabel(tester, 'banana');
      expect(find.text('Great job!'), findsOneWidget);
      await next(tester);
      // 2 image-based
      await tapLabel(tester, 'bird');
      await next(tester);
      // 3 audio-based: no text, a listen button
      expect(find.bySemanticsLabel('Listen to the question'), findsOneWidget);
      expect(speech.said.last, 'Find the cat.');
      await tapLabel(tester, 'cat');
      await next(tester);
      // 4 letter recognition
      await tapLabel(tester, 'm');
      await next(tester);
      // 5 number recognition
      await tapLabel(tester, '7');
      await next(tester);
      // 6 drag and drop (tap the token, then where it goes)
      await tapLabel(tester, 'fish');
      await tapLabel(tester, 'water');
      await tapLabel(tester, 'bird');
      await tapLabel(tester, 'tree');
      await next(tester);
      // 7 sorting
      for (final (thing, bin) in [
        ('cow', 'Animals'),
        ('apple', 'Food'),
        ('duck', 'Animals'),
      ]) {
        await tapLabel(tester, thing);
        await tester.tap(find.bySemanticsLabel(RegExp('^$bin(,|\$)')).first);
        await tester.pumpAndSettle();
      }
      await next(tester);
      // 8 matching pairs: the word on the left, its picture on the right
      for (final w in ['cat', 'sun', 'car']) {
        await tester.tap(find.bySemanticsLabel(w).first);
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel(w).last);
        await tester.pumpAndSettle();
      }
      await next(tester);
      // 9 fill the blank
      await tapLabel(tester, 'moo');
      expect(find.bySemanticsLabel('The cow says moo'), findsOneWidget);
      await next(tester);
      // 10 word building
      for (final l in ['c', 'a', 't']) {
        await tapLabel(tester, l);
      }
      await next(tester);
      // 11 memory: open each pair
      final memory = run(tester, 'engine-sampler').item as MemorySpec;
      final pairs = <String, List<int>>{};
      for (final (i, c) in memory.cards.indexed) {
        pairs.putIfAbsent(MemorySpec.pairOf(c.id), () => []).add(i);
      }
      for (final idx in pairs.values) {
        for (final i in idx) {
          await tapLabel(tester, 'Card ${i + 1}, face down');
        }
      }
      await next(tester);
      // 12 puzzle: swap pieces until the picture is whole
      var puzzle = run(tester, 'engine-sampler').item as OrderSpec;
      var layout = [...puzzle.start];
      for (var pos = 0; pos < layout.length; pos++) {
        final want = puzzle.order[pos];
        if (layout[pos] == want) continue;
        final from = layout.indexOf(want);
        await tapLabel(
          tester,
          'Piece ${puzzle.order.indexOf(layout[pos]) + 1}, in place ${pos + 1}',
        );
        await tapLabel(
          tester,
          'Piece ${puzzle.order.indexOf(want) + 1}, in place ${from + 1}',
        );
        layout[from] = layout[pos];
        layout[pos] = want;
      }
      await next(tester);
      // 13 tracing
      await traceAlong(tester, run(tester, 'engine-sampler').item as TraceSpec);
      expect(find.text('Great job!'), findsOneWidget);
      await next(tester);
      // 14 adding: 2 apples + 1 apple
      expect(
        find.bySemanticsLabel(RegExp('two apples and one more')),
        findsOneWidget,
      );
      await tapLabel(tester, '3');
      expect(find.text('Great job!'), findsOneWidget);
      await next(tester);
      // 15 shape completion
      await tapLabel(tester, 'the right side of a circle');
      expect(find.text('Great job!'), findsOneWidget);
      await next(tester);
      // 16 jigsaw: one wrong drop first (bounces back), then every piece in its place
      final jig = run(tester, 'engine-sampler').item as JigsawSpec;
      Future<void> tapSem(String pattern) async {
        final f = find.bySemanticsLabel(RegExp(pattern)).first;
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tapSem(r'^Piece 1(,|$)');
      await tapSem('^Place 2,');
      expect(find.bySemanticsLabel(RegExp(r'^Piece 1(,|$)')), findsOneWidget);
      for (final t in [...jig.tokens]) {
        final i = JigsawSpec.indexOf(t.id);
        await tapSem('^Piece ${i + 1}(,|\$)');
        await tapSem('^Place ${i + 1},');
      }
      expect(
        find.text('You did it!'),
        findsOneWidget,
        reason: 'right, with a mistake',
      );
      expect(run(tester, 'engine-sampler').current.mistakes, 1);
      await next(tester);

      expect(find.text('You did it!'), findsOneWidget);
      expect(find.text('You earned a star today!'), findsOneWidget);
      final reports = demo.received
          .where((r) => r.activityId == 'engine-sampler')
          .toList();
      expect(reports.map((r) => r.status), [
        SessionStatus.started,
        SessionStatus.completed,
      ]);
      final done = reports.last;
      expect(done.sessionId, reports.first.sessionId);
      expect(done.totalCount, 16);
      expect(done.correctCount, 16);
      expect(done.score, greaterThanOrEqualTo(90));
      expect(
        done.items.map((i) => i['k']).toSet().length,
        16,
        reason: 'every type ran',
      );
      expect(store.outbox, isEmpty, reason: 'delivered');
      expect(store.snapshots, isEmpty, reason: 'nothing left to resume');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wrong answers: try again, a hint narrows the choice, the last try shows the answer',
    (tester) async {
      await signIn(tester);
      await open(tester, Routes.play('find-the-b'));
      await tapLabel(tester, 'Play');
      final spec = run(tester, 'find-the-b').item;
      final wrong =
          (spec as dynamic).options.firstWhere((o) => o.id != 'b').id as String;

      await tapLabel(tester, wrong);
      expect(find.text('Almost! Try again.'), findsOneWidget);
      expect(find.bySemanticsLabel('$wrong, not this one'), findsOneWidget);
      // young players are offered a hint right away
      await tapLabel(tester, 'Show me a hint');
      expect(find.bySemanticsLabel(RegExp('^Hint: ')), findsOneWidget);
      await tapLabel(tester, 'Hint'); // level 2: a wrong option is greyed out
      expect(run(tester, 'find-the-b').current.hintLevel, 2);

      // wrong twice more (with an option the hint didn't grey out) → the answer is shown
      final view = container(tester).read(
        playerProvider((
          activityId: 'find-the-b',
          courseId: null,
          stepId: null,
          source: PlaySource.feed,
        )),
      );
      final stillOpen = ((spec as dynamic).options as List)
          .map((o) => o.id as String)
          .where((id) => id != 'b' && !view.hint.eliminate.contains(id))
          .first;
      await tapLabel(tester, stillOpen);
      await tapLabel(tester, 'Try again');
      await tapLabel(tester, stillOpen);
      expect(find.text("Here's the answer!"), findsOneWidget);
      expect(find.bySemanticsLabel('b, this is the answer'), findsOneWidget);
      final p = run(tester, 'find-the-b').current;
      expect((p.revealed, p.correct, p.wrongAttempts), (true, false, 3));
      await next(tester);
      expect(find.bySemanticsLabel('Question 2 of 3'), findsOneWidget);
    },
  );

  testWidgets(
    'an interrupted run continues where it stopped, in the same session',
    (tester) async {
      await signIn(tester);
      await open(tester, Routes.play('find-the-b'));
      await tapLabel(tester, 'Play');
      final sessionId = run(tester, 'find-the-b').sessionId;
      await tapLabel(tester, 'b');
      await next(tester);

      // the child stops: pause sheet → stop for now
      await tapLabel(tester, 'Pause');
      expect(find.text('Taking a break'), findsOneWidget);
      await tapLabel(tester, 'Stop for now');
      expect(
        store.snapshots,
        hasLength(1),
        reason: 'the run is saved on the device',
      );
      expect(
        demo.received.where((r) => r.status != SessionStatus.started),
        isEmpty,
        reason: 'not reported as abandoned',
      );

      await open(tester, Routes.play('find-the-b'));
      expect(find.text('Keep going?'), findsOneWidget);
      await tapLabel(tester, 'Keep going');
      expect(find.bySemanticsLabel('Question 2 of 3'), findsOneWidget);
      expect(run(tester, 'find-the-b').sessionId, sessionId);
      await tapLabel(tester, 'd');
      await next(tester);
      await tapLabel(tester, 'p');
      await next(tester);
      expect(find.text('You did it!'), findsOneWidget);
      final done = demo.received
          .where((r) => r.status == SessionStatus.completed)
          .single;
      expect(done.sessionId, sessionId);
      expect(done.correctCount, 3);
      expect(store.snapshots, isEmpty);
    },
  );

  testWidgets(
    '"Start over" closes the old run as abandoned and starts a new session',
    (tester) async {
      await signIn(tester);
      await open(tester, Routes.play('find-the-b'));
      await tapLabel(tester, 'Play');
      final first = run(tester, 'find-the-b').sessionId;
      await tapLabel(tester, 'b');
      await tapLabel(tester, 'Pause');
      await tapLabel(tester, 'Stop for now');
      await open(tester, Routes.play('find-the-b'));
      await tapLabel(tester, 'Start over');
      await tester.pumpAndSettle();
      expect(
        find.text('Find the letter'),
        findsOneWidget,
        reason: 'back at the intro',
      );
      final abandoned = demo.received
          .where((r) => r.status == SessionStatus.abandoned)
          .single;
      expect(abandoned.sessionId, first);
      expect(abandoned.correctCount, 1);
      await tapLabel(tester, 'Play');
      expect(run(tester, 'find-the-b').sessionId, isNot(first));
    },
  );

  testWidgets(
    'offline: the finished session waits in the outbox and is sent later',
    (tester) async {
      await signIn(tester);
      await open(tester, Routes.play('more-or-less'));
      await tapLabel(tester, 'Play');
      await tapLabel(tester, 'five apples');
      await next(tester);
      demo.failNextSync = const NetworkFailure();
      await tapLabel(tester, 'two carrots');
      await next(tester);
      expect(
        find.text('Saved on this device. It will be sent when you are online.'),
        findsOneWidget,
      );
      expect(
        store.outbox.values.map((r) => r.status),
        contains(SessionStatus.completed),
      );

      final outcomes = await container(tester)
          .read(syncServiceProvider)
          .flush();
      await tester.pumpAndSettle();
      expect(outcomes.where((o) => o.status == 'accepted'), isNotEmpty);
      expect(store.outbox, isEmpty);
      expect(
        demo.received.where(
          (r) =>
              r.activityId == 'more-or-less' &&
              r.status == SessionStatus.completed,
        ),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'a lesson step: progress is saved, the island updates, "Next step" opens the next one',
    (tester) async {
      await signIn(tester, child: 'Leo');
      await tapLabel(tester, 'Start'); // Keep going → island 1
      await tapLabel(tester, 'Warm-up: Letters check-in, play next');
      await tapLabel(tester, 'Play'); // activity screen
      await tapLabel(tester, 'Play'); // player intro
      // the quiz from the questions table: "Which one is a / b / c?"
      for (final l in ['a', 'b', 'c']) {
        await tapLabel(tester, l);
        await next(tester);
      }
      expect(find.text('You did it!'), findsOneWidget);
      final done = demo.received
          .where((r) => r.status == SessionStatus.completed)
          .single;
      expect(done.lessonStepId, 'letters-1-step-1');
      expect(done.responses, hasLength(3), reason: 'one answer per question');
      expect(
        demo.progress['child-leo']!.completedStepIds,
        contains('letters-1-step-1'),
      );

      await tapLabel(tester, 'Next step');
      expect(
        find.text('Find the letter'),
        findsOneWidget,
        reason: 'island 1 step 2 is "Find the b"',
      );
    },
  );

  testWidgets('an activity without engine content says "Almost ready!"', (
    tester,
  ) async {
    await signIn(tester);
    await open(tester, Routes.play('pip-meets-a-snail'));
    expect(find.text('Almost ready!'), findsOneWidget);
    await tapLabel(tester, 'Back');
    expect(find.text('Hi, Mia!'), findsOneWidget);
  });

  testWidgets('phone size: the player and every control fit', (tester) async {
    await signIn(tester, size: phoneLandscape);
    await open(tester, Routes.play('shape-homes'));
    await tapLabel(tester, 'Play');
    for (final shape in ['circle', 'square', 'triangle']) {
      await tapLabel(tester, shape);
      await tester.tap(find.bySemanticsLabel(RegExp('^$shape(,|\$)')).last);
      await tester.pumpAndSettle();
    }
    expect(find.text('Great job!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
