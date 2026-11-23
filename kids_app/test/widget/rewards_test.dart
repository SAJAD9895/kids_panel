import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kids_app/app/router/routes.dart';
import 'package:kids_app/core/error/failure.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/features/learning/presentation/learning_providers.dart';
import 'package:kids_app/features/play/domain/session_report.dart';
import 'package:kids_app/features/play/presentation/play_providers.dart';
import 'package:kids_app/features/rewards/domain/rewards.dart';
import 'package:kids_app/features/rewards/presentation/rewards_providers.dart';

import '../helpers/game_walker.dart';
import '../helpers/test_app.dart';

/// Phase 12: rewards in the app. Real games through the real player on the demo backend
/// (which applies the same reward rules as private.apply_rewards), the celebrations, the
/// Rewards screen, the parent page, and layout.
void main() {
  setUpAll(loadAppFonts);
  void reduceMotion(bool on) {
    final b = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher;
    on
        ? b.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
            disableAnimations: true,
          )
        : b.clearAccessibilityFeaturesTestValue();
  }

  setUp(() => reduceMotion(true));
  tearDown(() => reduceMotion(false));

  late DemoBackend demo;

  Future<void> signIn(
    WidgetTester tester, {
    String child = 'Mia',
    Size size = tablet,
  }) async {
    demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
    await pumpApp(tester, size: size, backend: demo);
    await demo.signInWithPassword(
      email: 'alice@example.test',
      password: DemoBackend.alicePassword,
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, child);
  }

  BuildContext ctx(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);
  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(ctx(tester));

  Future<void> go(WidgetTester tester, String path) async {
    GoRouter.of(ctx(tester)).go(path);
    await tester.pumpAndSettle();
  }

  Finder label(Pattern p) => find.bySemanticsLabel(p);

  /// Scrolls the page (a lazy list) from the top until [f] is built and on screen.
  Future<void> see(WidgetTester tester, Finder f) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, 6000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      f,
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> toTop(WidgetTester tester) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, 6000));
    await tester.pumpAndSettle();
  }

  PlayerView view(WidgetTester tester, String slug) => container(tester).read(
    playerProvider((
      activityId: slug,
      courseId: null,
      stepId: null,
      source: PlaySource.feed,
    )),
  );

  /// Plays a game's Easy level, every answer right. With [settle] false, it stops a moment
  /// after "Finish" (to catch the short "+1 star" banner before it goes). [beforeFinish] runs
  /// just before "Finish" (e.g. to go offline for the finished-session upload only).
  Future<void> playEasy(
    WidgetTester tester,
    String slug, {
    bool settle = true,
    void Function()? beforeFinish,
  }) async {
    GoRouter.of(ctx(tester)).push(Routes.play(slug));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Level 1 of 3: Easy');
    await tapLabel(tester, 'Play');
    final walker = GameWalker(tester);
    final total = view(tester, slug).run!.items.length;
    for (var i = 0; i < total; i++) {
      await walker.answerRight(view(tester, slug).run!.item);
      if (i < total - 1) {
        await tapLabel(tester, 'Next');
        continue;
      }
      beforeFinish?.call();
      final finish = find.bySemanticsLabel('Finish').first;
      await tester.ensureVisible(finish);
      await tester.tap(finish);
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        for (var k = 0; k < 4; k++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
    }
  }

  Future<void> enterGate(WidgetTester tester) async {
    await tapLabel(tester, 'Grown-ups');
    for (final d in ['5', '2', '8']) {
      await tapLabel(tester, d);
    }
  }

  testWidgets(
    "a child's first game: one card for the badge and its stars; Yay closes it; nothing again",
    (tester) async {
      await signIn(tester, child: 'Leo');
      await playEasy(tester, 'memory-match');
      expect(find.text('New badge: First game!'), findsOneWidget);
      expect(find.text('+2 stars'), findsOneWidget);
      expect(
        find.text('You did it!'),
        findsOneWidget,
      ); // the finish screen, underneath
      await tapText(tester, 'Yay!');
      expect(find.text('Yay!'), findsNothing);
      // nothing is celebrated twice: the outbox is empty, another flush sends nothing
      await container(tester).read(syncServiceProvider).flush();
      await tester.pumpAndSettle();
      expect(find.text('Yay!'), findsNothing);
      expect(demo.ledgerOf('child-leo').balance, 2);
    },
  );

  testWidgets(
    'a star-only finish shows a small banner that goes away by itself (no button)',
    (tester) async {
      await signIn(tester, child: 'Leo');
      await playEasy(tester, 'memory-match');
      await dismissCelebrations(tester); // the first-game card
      await tapLabel(tester, 'Home');
      await playEasy(tester, 'picture-match', settle: false);
      expect(label('+1 star!'), findsOneWidget);
      expect(find.text('Yay!'), findsNothing);
      await tester.pumpAndSettle();
      expect(label('+1 star!'), findsNothing);
    },
  );

  testWidgets(
    "reaching today's goal (2, set by a parent) is celebrated once, with a break suggestion",
    (tester) async {
      await signIn(tester, child: 'Leo');
      await demo.saveGoals('child-leo', const GoalSettings(dailyActivities: 2));
      await playEasy(tester, 'memory-match');
      await dismissCelebrations(tester);
      await tapLabel(tester, 'Home');
      await playEasy(tester, 'picture-match');
      // one card for everything: the goal's badge leads; the goal and the stars are listed
      expect(find.text('New badge: Goal getter!'), findsOneWidget);
      expect(find.text("Today's goal reached"), findsOneWidget);
      expect(
        find.text('+3 stars'),
        findsOneWidget,
      ); // activity + goal + badge bonus
      expect(
        find.text('Great learning today. Maybe time for a break?'),
        findsOneWidget,
      );
      await tapText(tester, 'Yay!');
      await tapLabel(tester, 'Home');
      await playEasy(tester, 'sort-it-out', settle: false);
      expect(find.text("Today's goal reached"), findsNothing);
      expect(label('+1 star!'), findsOneWidget); // just a star now
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'offline: no celebration until the server confirms; then exactly once',
    (tester) async {
      await signIn(tester, child: 'Leo');
      await playEasy(
        tester,
        'memory-match',
        beforeFinish: () => demo.failNextSync = const NetworkFailure(),
      );
      expect(find.text('Yay!'), findsNothing);
      expect(demo.ledgerOf('child-leo').balance, 0);
      await container(tester).read(syncServiceProvider).flush(); // back online
      await tester.pumpAndSettle();
      expect(find.text('New badge: First game!'), findsOneWidget);
      await tapText(tester, 'Yay!');
      await container(tester).read(syncServiceProvider).flush();
      await tester.pumpAndSettle();
      expect(find.text('Yay!'), findsNothing);
      expect(demo.ledgerOf('child-leo').balance, 2);
    },
  );

  testWidgets(
    'celebrations wait outside the kid zone, and belong to their own child',
    (tester) async {
      await signIn(tester);
      final q = container(tester).read(celebrationQueueProvider.notifier);
      q.push(const RewardEvents(childId: 'child-leo', courseCompleted: true));
      await tester.pumpAndSettle();
      expect(
        find.text('You finished a whole course!'),
        findsNothing,
      ); // Mia plays
      q.push(
        const RewardEvents(
          childId: 'child-mia',
          stars: 5,
          courseCompleted: true,
        ),
      );
      await go(tester, Routes.gate);
      expect(find.text('You finished a whole course!'), findsNothing);
      await go(tester, Routes.kids);
      expect(find.text('You finished a whole course!'), findsOneWidget);
      expect(find.text('+5 stars'), findsOneWidget);
      await tapText(tester, 'Yay!');
      expect(find.text('You finished a whole course!'), findsNothing);
      expect(container(tester).read(celebrationQueueProvider), hasLength(1));
    },
  );

  testWidgets(
    'reduce motion: the card shows a still picture; otherwise it animates once',
    (tester) async {
      await signIn(tester);
      container(tester)
          .read(celebrationQueueProvider.notifier)
          .push(const RewardEvents(childId: 'child-mia', weeklyGoalDone: true));
      await tester.pump();
      await tester.pump();
      expect(find.text("You reached this week's goal!"), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      await tapText(tester, 'Yay!');

      reduceMotion(false);
      container(tester)
          .read(celebrationQueueProvider.notifier)
          .push(
            const RewardEvents(childId: 'child-mia', courseCompleted: true),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('You finished a whole course!'), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle(); // it plays once and stops
      expect(tester.hasRunningAnimations, isFalse);
      await tapText(tester, 'Yay!');
    },
  );

  testWidgets(
    "My rewards: Mia's stars, goals, learning days, what's new, achievements and badges",
    (tester) async {
      await signIn(tester);
      final ledger = demo.ledgerOf('child-mia');
      // Home's goal card opens the Rewards screen
      final goal = label(RegExp(r"^Today's goal done: 3 stars"));
      await tester.ensureVisible(goal);
      await tester.tap(goal);
      await tester.pumpAndSettle();
      expect(find.text('My rewards'), findsWidgets);
      expect(label('I have ${ledger.balance} stars'), findsOneWidget);
      expect(label('Today: done. Well done!'), findsOneWidget);
      // testNow is a Wednesday; Mia learned on Monday and today: 2 of 4 days this week
      expect(label('This week: 2 of 4 days'), findsOneWidget);
      await see(tester, label('2 learning days in a row'));
      expect(find.text('My best: 2 days'), findsOneWidget);
      expect(
        label('Learning calendar: 2 learning days in the last 6 weeks'),
        findsOneWidget,
      );
      await see(tester, find.text('New for me'));
      await see(tester, label('1 islands'));
      expect(label('2 daily goals'), findsOneWidget);
      await see(tester, find.text('My badges (3 of 16)'));

      final firstGame = label(RegExp(r'^First game, earned \d+ Nov 2026$'));
      await see(tester, firstGame);
      await tester.tap(firstGame);
      await tester.pumpAndSettle();
      expect(find.text('You finished your very first game.'), findsOneWidget);
      expect(find.textContaining('Earned '), findsOneWidget);
      expect(find.text('It gave you 1 bonus star.'), findsOneWidget);
      Navigator.of(
        tester.element(find.text('You finished your very first game.')),
      ).pop(); // close the sheet
      await tester.pumpAndSettle();

      final locked = label(
        'Seven learning days, not yet. Learn on 7 days in a row. One rest day in between is fine.',
      );
      await see(tester, locked);
      await tester.tap(locked);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Not yet. Learn on 7 days in a row. One rest day in between is fine.',
        ),
        findsOneWidget,
      );
      Navigator.of(tester.element(find.textContaining('Not yet.'))).pop();
      await tester.pumpAndSettle();

      await toTop(tester);
      await tapText(tester, 'How do I get stars?');
      expect(find.text('How I get stars'), findsOneWidget);
      expect(find.text('Finish a whole course: 5 bonus stars'), findsOneWidget);
    },
  );

  testWidgets('rewards fail to load, then recover (Try again)', (tester) async {
    await signIn(tester);
    await go(tester, Routes.me); // nothing on Me holds the rewards summary
    demo.failNextRead = const NetworkFailure();
    await go(tester, Routes.rewards); // a fresh load, which fails
    expect(find.text('Try again'), findsOneWidget);
    await tapText(tester, 'Try again');
    await see(tester, find.text('My badges (3 of 16)'));
  });

  testWidgets(
    'P18: a parent sees rewards and history, reads how it works, sets goals; Home follows',
    (tester) async {
      await signIn(tester, child: 'Leo');
      await enterGate(tester);
      await tapText(tester, 'Manage children');
      await tapText(tester, 'Mia');
      await see(tester, find.text('Rewards and goals'));
      await tapText(tester, 'Rewards and goals');
      final ledger = demo.ledgerOf('child-mia');
      expect(find.text('Mia: rewards and goals'), findsOneWidget);
      expect(find.text('${ledger.balance}'), findsWidgets);
      expect(find.text('2 (best 2)'), findsOneWidget);
      expect(find.text('3 of 16'), findsOneWidget);
      await see(tester, find.text('Badges earned (3 of 16)'));
      await see(tester, find.text('Finished an island')); // the star history
      await see(tester, find.text('Badge: First game'));
      await see(
        tester,
        find.text(
          'Stars are never taken away, and they can’t be bought or spent.',
        ),
      );
      await see(
        tester,
        find.text('No leaderboards or comparisons with other children.'),
      );

      // goals: Save stays off until something changes; then switch Mia's goals off
      final save = find.ancestor(
        of: find.text('Save goals'),
        matching: find.byType(FilledButton),
      );
      await see(tester, save);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await see(tester, find.text('Use learning goals'));
      await tapText(tester, 'Use learning goals');
      await tapText(tester, 'Save goals');
      expect(find.text('Saved'), findsOneWidget);
      expect(ledger.settings.enabled, isFalse);

      // Leo's daily goal → 1
      await go(tester, Routes.childRewards('child-leo'));
      expect(find.text('Leo: rewards and goals'), findsOneWidget);
      await see(tester, find.text('No badges yet.'));
      await see(tester, find.text('No stars yet.'));
      await see(tester, find.text('Daily goal'));
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 activity').last);
      await tester.pumpAndSettle();
      await tapText(tester, 'Save goals');
      expect(demo.ledgerOf('child-leo').settings.dailyActivities, 1);

      await go(tester, Routes.kids);
      await tester.pump(
        const Duration(seconds: 6),
      ); // the "Saved" snack bar times out
      await tester.pumpAndSettle();
      expect(label(RegExp(r"^Today's goal: 0 of 1 stars")), findsOneWidget);
      await playEasy(tester, 'memory-match');
      expect(find.text('New badge: First game!'), findsOneWidget);
      expect(find.text("Today's goal reached"), findsOneWidget);
      await tapText(tester, 'Yay!');
    },
  );

  testWidgets('Home hides the goal when a parent switched goals off', (
    tester,
  ) async {
    await signIn(tester);
    expect(find.text('You did it today!'), findsOneWidget);
    await demo.saveGoals('child-mia', const GoalSettings(enabled: false));
    container(tester)
      ..invalidate(rewardsProvider('child-mia'))
      ..invalidate(childProgressProvider('child-mia'));
    await tester.pumpAndSettle();
    expect(find.text('You did it today!'), findsNothing);
    expect(find.text("Today's stars"), findsNothing);
  });

  for (final (name, size) in [
    ('phone', phone),
    ('phone sideways', phoneLandscape),
    ('tablet', tablet),
    ('desktop', desktop),
  ]) {
    testWidgets('layout ($name): My rewards, a badge, a celebration, P18', (
      tester,
    ) async {
      await signIn(tester, size: size);
      final handle = tester.ensureSemantics();
      Future<void> check(String what) async {
        await expectLater(
          tester,
          meetsGuideline(iOSTapTargetGuideline),
          reason: what,
        );
        await expectLater(
          tester,
          meetsGuideline(labeledTapTargetGuideline),
          reason: what,
        );
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: what,
        );
        expect(tester.takeException(), isNull, reason: what);
      }

      await go(tester, Routes.rewards);
      await check('rewards');
      await see(tester, find.textContaining('My badges'));
      await check('rewards, badges');

      container(tester)
          .read(celebrationQueueProvider.notifier)
          .push(
            const RewardEvents(
              childId: 'child-mia',
              stars: 4,
              dailyGoalDone: true,
              badges: [
                (
                  key: 'badge-week-1',
                  title: 'Great week',
                  bonusStars: 2,
                  art: 'badges/week-1/1/512.webp',
                ),
              ],
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('New badge: Great week!'), findsOneWidget);
      await check('celebration');
      await dismissCelebrations(tester);

      await go(tester, Routes.kids);
      await enterGate(tester);
      await go(tester, Routes.childRewards('child-mia'));
      expect(find.text('Mia: rewards and goals'), findsOneWidget);
      await check('P18');
      handle.dispose();
    });
  }
}
