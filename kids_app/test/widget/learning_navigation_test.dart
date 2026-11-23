import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/core/error/failure.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/demo/demo_catalog.dart';
import 'package:kids_app/features/learning/domain/progress.dart';

import '../helpers/test_app.dart';

/// Phase 8: home and learning navigation on the demo backend (the seed's content).
void main() {
  setUpAll(loadAppFonts);

  // The island screen has a gently bouncing Pip; with "reduce motion" on (as some families
  // set it) everything still works and the tests can wait for the screen to settle.
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

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<DemoBackend> signInAsAlice(
    WidgetTester tester, {
    Size size = tablet,
    DemoBackend? backend,
    String child = 'Mia',
  }) async {
    final demo = await pumpApp(tester, size: size, backend: backend);
    await demo.signInWithPassword(
      email: 'alice@example.test',
      password: DemoBackend.alicePassword,
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, child);
    return demo;
  }

  Future<DemoBackend> signUpBasicFamily(WidgetTester tester) async {
    final demo = await pumpApp(tester);
    await tapLabel(tester, "Grown-ups: let's set up");
    await tester.enterText(find.byType(TextField).first, 'Kai');
    await tapLabel(tester, 'May');
    await tapText(tester, '2021');
    await tapLabel(tester, 'Next');
    await tapLabel(tester, "That's me!");
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'basic@example.test',
    );
    await tapText(
      tester,
      'I agree to the Terms and the Privacy Policy. (required)',
    );
    await tapText(
      tester,
      'I’m the parent or guardian, and I agree to my child’s learning data being used to run the app. (required)',
    );
    await tapText(tester, 'Send my code');
    await tester.enterText(find.byType(TextField).first, DemoBackend.code);
    await tester.pumpAndSettle();
    return demo;
  }

  testWidgets(
    'home shows the child: greeting, goal, keep going, subjects, picks, recent, treasures',
    (tester) async {
      final demo = await signInAsAlice(tester);
      expect(find.text('Hi, Mia!'), findsOneWidget);
      // The balance: Mia's activity stars plus her bonus stars (island, goal, badges).
      final balance = demo.ledgerOf('child-mia').balance;
      expect(balance, greaterThan(3));
      expect(find.bySemanticsLabel('$balance stars'), findsWidgets);
      expect(
        find.text('You did it today!'),
        findsOneWidget,
        reason: 'Mia has 3 stars today',
      );
      expect(find.text('Keep going'), findsOneWidget);
      expect(find.text('Letters a to h'), findsOneWidget);
      expect(find.textContaining('Island 2: d e f'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.bySemanticsLabel('Letters'), findsOneWidget);
      await scrollTo(tester, find.text('Games for today'));
      await scrollTo(tester, find.text('Played lately'));
      await scrollTo(tester, find.text('My treasures'));
      expect(find.bySemanticsLabel('2 stickers'), findsOneWidget);
      // first game, first island, goal getter: earned by the rules (seed history, §18)
      expect(
        find.bySemanticsLabel(
          '${demo.ledgerOf('child-mia').earned.length} badges',
        ),
        findsOneWidget,
      );
      expect(demo.ledgerOf('child-mia').earned.keys, {
        'badge-first-game',
        'badge-first-island',
        'badge-goal-1',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home → Subject → Learning path → Course → Island → Activity, with every state',
    (tester) async {
      await signInAsAlice(tester);

      await tapLabel(tester, 'Letters');
      expect(find.text('Learning paths'), findsOneWidget);
      expect(find.text('Play and explore'), findsOneWidget);

      await tapLabel(tester, 'Learning path Starting school');
      expect(
        find.textContaining('Letters and numbers before school'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Course Letters a to h, started'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Course Counting to 10, later'),
        findsOneWidget,
        reason: 'opens after the first course',
      );

      await tapLabel(tester, 'Course Letters a to h, started');
      expect(find.text('Islands'), findsOneWidget);
      expect(find.bySemanticsLabel('Island 1: a b c, done'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Island 2: d e f, 0 of 3 steps'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Island 3: g h, finish the island before first'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('38 percent done'), findsOneWidget);

      // a locked island explains itself and stays put
      await tapLabel(tester, 'Island 3: g h, finish the island before first');
      expect(find.text('Finish island 2 first!'), findsOneWidget);
      expect(find.text('Islands'), findsOneWidget);

      await tapLabel(tester, 'Island 2: d e f, 0 of 3 steps');
      expect(
        find.bySemanticsLabel('Watch: Pip meets a snail, play next'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Sing: The counting train, locked'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Island prize, finish every step to open it'),
        findsOneWidget,
      );

      await tapLabel(tester, 'Sing: The counting train, locked');
      expect(find.text('Do the step before this one first!'), findsOneWidget);

      await tapLabel(tester, 'Watch: Pip meets a snail, play next');
      expect(find.text('Nova follows a raindrop'), findsNothing);
      expect(find.text('Play'), findsOneWidget);
      await tapLabel(tester, 'Play');
      // Phase 11: videos play in the video player (a fake player in tests)
      expect(find.bySemanticsLabel(RegExp('^Video: ')), findsOneWidget);
      await tapLabel(tester, 'Close'); // player → activity

      // back up the chain
      await tapLabel(tester, 'Back');
      expect(
        find.bySemanticsLabel('Island prize, finish every step to open it'),
        findsOneWidget,
      );
      await tapLabel(tester, 'Back');
      expect(find.text('Islands'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a step opened from its island knows when it is not open yet', (
    tester,
  ) async {
    await signInAsAlice(tester, child: 'Leo');
    await tapLabel(tester, 'Start');
    // Leo has done nothing: island 1 step 1 is next; step 2 waits
    await tapLabel(tester, 'Play: Find the b, locked');
    expect(find.text('Do the step before this one first!'), findsOneWidget);
    await tapLabel(tester, 'Warm-up: Letters check-in, play next');
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets(
    'switching player switches everything: name, progress, keep going',
    (tester) async {
      await signInAsAlice(tester);
      expect(find.text('Keep going'), findsOneWidget);
      await scrollTo(tester, find.text('Played lately'));
      expect(
        find.text('Pip meets a snail'),
        findsWidgets,
        reason: 'Mia played it lately',
      );

      await tapLabel(tester, 'Mia: switch player');
      expect(find.text("Who's playing?"), findsOneWidget);
      await tapLabel(tester, 'Leo');

      expect(find.text('Hi, Leo!'), findsOneWidget);
      expect(
        find.text('Start here'),
        findsOneWidget,
        reason: 'Leo has no course yet',
      );
      expect(find.text('Keep going'), findsNothing);
      await scrollTo(tester, find.text('Games you play will show up here.'));
      expect(find.bySemanticsLabel('0 stars'), findsWidgets);

      // and back
      await scrollTo(tester, find.bySemanticsLabel('Leo: switch player'));
      await tapLabel(tester, 'Leo: switch player');
      await tapLabel(tester, 'Mia');
      expect(find.text('Keep going'), findsOneWidget);
    },
  );

  testWidgets('empty database: friendly empty states everywhere, no errors', (
    tester,
  ) async {
    final demo = DemoBackend(
      latency: Duration.zero,
      clock: () => testNow,
      content: DemoCatalog.empty(),
    );
    await signInAsAlice(tester, backend: demo);
    expect(find.text('New games are on their way!'), findsOneWidget);
    await tapLabel(tester, 'Learn');
    expect(find.text('Courses are coming soon!'), findsOneWidget);
    await tapLabel(tester, 'Watch');
    expect(find.text('Nothing here yet'), findsOneWidget);
    await tapLabel(tester, 'Me');
    expect(find.text('Saved games'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a subject with nothing in it says "coming soon"', (
    tester,
  ) async {
    // Every subject has something in the seed now: empty Art for this test.
    final demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
    demo.content = demo.content.without((a) => a.subjectId == 'subject-art');
    await signInAsAlice(tester, backend: demo);
    await tapLabel(tester, 'All subjects');
    await tapLabel(tester, 'Art');
    expect(find.text('Coming soon!'), findsOneWidget);
  });

  testWidgets(
    'loading shows skeletons; an error shows Bolt and "Try again", which recovers',
    (tester) async {
      final demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
      demo.failNextCatalog = const NetworkFailure();
      await signInAsAlice(tester, backend: demo);
      expect(find.text("Oops! Let's try that again."), findsOneWidget);
      expect(find.text('Keep going'), findsNothing);
      await tapLabel(tester, 'Try again');
      expect(find.text('Keep going'), findsOneWidget);

      // loading: slow the backend down, open a fresh child's home, see skeletons first
      demo.latency = const Duration(seconds: 1);
      await tapLabel(tester, 'Mia: switch player');
      await tester.tap(find.bySemanticsLabel('Leo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel('Loading'), findsWidgets);
      demo.latency = Duration.zero;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Hi, Leo!'), findsOneWidget);
    },
  );

  testWidgets(
    'Basic family: Plus content shows "Ask a grown-up", which leads to the gate',
    (tester) async {
      await signUpBasicFamily(tester);
      expect(find.text('Hi, Kai!'), findsOneWidget);
      await tapLabel(tester, 'Learn');
      expect(
        find.bySemanticsLabel('Course Counting to 10, new, ask a grown-up'),
        findsWidgets,
      );
      await tapLabel(tester, 'Course Counting to 10, new, ask a grown-up');
      await tapText(tester, 'Start');
      expect(find.text('Ask a grown-up!'), findsOneWidget);
      expect(find.textContaining('£'), findsNothing);
      expect(find.textContaining('buy'), findsNothing);
      await tapText(tester, 'Get a grown-up');
      expect(find.text('Tap these numbers:'), findsOneWidget);
    },
  );

  testWidgets(
    'Me: buddy, stage, treasures, badges, saved games, change buddy',
    (tester) async {
      final demo = await signInAsAlice(tester);
      await tapLabel(tester, 'Me');
      expect(find.text('Mia'), findsWidgets);
      expect(find.text('Little explorer'), findsOneWidget);
      expect(find.text('First island'), findsOneWidget);
      expect(find.text('Saved games'), findsOneWidget);
      expect(find.text('Shape homes'), findsOneWidget);

      await tapLabel(tester, 'Change my buddy');
      expect(find.text('Pick your buddy!'), findsOneWidget);
      await tapLabel(tester, 'Buddy Bun');
      await tapLabel(tester, 'Use this buddy');
      expect(
        find.text('Little explorer'),
        findsOneWidget,
        reason: 'back on Me',
      );
      final mia = (await demo.listChildren()).firstWhere(
        (c) => c.nickname == 'Mia',
      );
      expect(mia.avatarId, 'avatar-01');
    },
  );

  testWidgets(
    'Watch and Listen show their rows; switched-off sections disappear from the rail',
    (tester) async {
      final demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
      demo.progress['child-leo'] = const ChildProgress(
        sections: SectionSwitches(watch: false),
      );
      await signInAsAlice(tester, backend: demo);
      await tapLabel(tester, 'Watch');
      Future<void> seeShelf(String title) async {
        await tester.dragUntilVisible(
          find.text(title),
          find.byType(ListView).first,
          const Offset(0, -250),
        );
        expect(find.text(title), findsOneWidget);
      }

      await seeShelf('Shows');
      await tapLabel(tester, 'Listen');
      await seeShelf('Bedtime stories');

      await tapLabel(tester, 'Mia: switch player');
      await tapLabel(tester, 'Leo');
      expect(find.bySemanticsLabel('Watch'), findsNothing);
      expect(find.bySemanticsLabel('Listen'), findsOneWidget);
    },
  );

  testWidgets(
    'phone portrait: bottom bar, avatar in the header, the whole chain still works',
    (tester) async {
      await signInAsAlice(tester, size: phone);
      expect(find.bySemanticsLabel('Mia: switch player'), findsOneWidget);
      await tapLabel(tester, 'Continue');
      expect(
        find.bySemanticsLabel('Watch: Pip meets a snail, play next'),
        findsOneWidget,
      );
      await tapLabel(tester, 'Watch: Pip meets a snail, play next');
      expect(find.text('Play'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
