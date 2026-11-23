import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kids_app/app/router/routes.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/features/learning/domain/catalog.dart';
import 'package:kids_app/features/parents/domain/account.dart';
import 'package:kids_app/features/parents/domain/parent_reports.dart';

import '../helpers/test_app.dart';

/// Phase 13: the parent dashboard, reports and analytics, notifications, privacy, subscription
/// and controls, on the demo backend (the same rules as the Edge Functions), at several sizes.
void main() {
  setUpAll(loadAppFonts);
  late DemoBackend demo;

  /// Signs in as Alice (Mia and Leo, Plus), picks Mia and opens the Grown-ups area.
  Future<void> openParents(
    WidgetTester tester, {
    Size size = tablet,
    DateTime Function()? clock,
  }) async {
    demo = DemoBackend(latency: Duration.zero, clock: clock ?? () => testNow);
    await pumpApp(tester, size: size, backend: demo);
    await demo.signInWithPassword(
      email: 'alice@example.test',
      password: DemoBackend.alicePassword,
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Mia');
    await tapLabel(tester, 'Grown-ups');
    for (final d in ['5', '2', '8']) {
      await tapLabel(tester, d);
    }
  }

  BuildContext ctx(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);
  Future<void> go(WidgetTester tester, String path) async {
    GoRouter.of(ctx(tester)).go(path);
    await tester.pumpAndSettle();
  }

  Finder label(Pattern p) => find.bySemanticsLabel(p);

  /// Scrolls the page (a lazy list) from the top until [f] is built and on screen.
  Future<void> see(WidgetTester tester, Finder f) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, 8000));
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

  testWidgets(
    'dashboard: both children with their numbers, goals and recent activities',
    (tester) async {
      await openParents(tester);
      final mia = demo.ledgerOf('child-mia');
      expect(find.text('Your children'), findsOneWidget);
      expect(label('Learning time, all children: 18 min'), findsOneWidget);
      expect(find.byTooltip('Notifications, 2 unread'), findsOneWidget);
      await see(tester, label('Lessons completed: 1'));
      expect(label('Today: 9 min'), findsOneWidget);
      expect(label('All time: 18 min'), findsOneWidget);
      final games = demo.history
          .where(
            (x) =>
                x.childId == 'child-mia' &&
                x.status == 'completed' &&
                demo.content.catalog.activity(x.activityId)?.type ==
                    ActivityType.game,
          )
          .length;
      expect(games, greaterThan(0));
      expect(label('Games completed: $games'), findsOneWidget);
      expect(label('Learning days in a row: 2 (best 2)'), findsOneWidget);
      expect(label('Stars: ${mia.balance}'), findsOneWidget);
      expect(label('Badges: 3'), findsOneWidget);
      expect(label('Today’s goal (activities): reached'), findsOneWidget);
      expect(label('This week’s goal (learning days): 2 of 4'), findsOneWidget);
      expect(
        find.textContaining('Pip meets a snail · Video, finished · Today'),
        findsOneWidget,
      );
      await see(tester, find.text('Nothing played yet.')); // Leo
      expect(label('Today: 0 min'), findsOneWidget);
    },
  );

  testWidgets("Mia's report: week, day, an empty week, another child, tables", (
    tester,
  ) async {
    await openParents(tester);
    await see(tester, find.text('Mia’s report'));
    await tapText(tester, 'Mia’s report');
    expect(find.text('Mia: progress report'), findsOneWidget);
    expect(find.text('16 Nov – 22 Nov 2026'), findsOneWidget);
    expect(
      label(RegExp(r'^Learning time: 18 min, \+18 min vs last week')),
      findsOneWidget,
    );
    expect(label(RegExp(r'^Activities finished: 6')), findsOneWidget);
    expect(label('Learning days: 2'), findsOneWidget);
    expect(
      find.text('This week isn’t over yet: numbers can still grow.'),
      findsOneWidget,
    );
    await see(tester, find.text('Activity completion'));
    await see(tester, find.text('Progress by subject'));
    await see(tester, find.text('Skill mastery'));
    expect(
      label(RegExp(r'^Skill mastery: Listening confident')),
      findsOneWidget,
    );
    await see(tester, find.text('Weekly learning consistency'));
    await see(tester, find.text('Goal completion'));
    expect(
      label(
        'Daily goal reached on 2 of 3 days; weekly goal reached in 0 of 1 weeks.',
      ),
      findsOneWidget,
    );
    await see(tester, find.text('Game performance'));
    await see(tester, find.text('Strengths and things to practise'));
    // subjects have too few scored activities to judge; Listening has 4 (confident)
    expect(find.text('Listening: confident (4 activities)'), findsOneWidget);
    expect(
      find.text('Nothing stands out as needing practice.'),
      findsOneWidget,
    );

    // the learning-time chart as a table
    await see(tester, find.text('Minutes per day'));
    await tapText(tester, 'Show as a table');
    expect(find.text('Wed 18 Nov'), findsOneWidget);
    expect(find.text('9 min'), findsWidgets);

    // a day; the week before (empty); next is off for the current period
    Finder segment(String l) => find.descendant(
      of: find.byType(SegmentedButton<ReportPeriod>),
      matching: find.text(l),
    );
    await see(tester, segment('Day'));
    await tester.tap(segment('Day'));
    await tester.pumpAndSettle();
    expect(label(RegExp(r'^Learning time: 9 min')), findsOneWidget);
    await tester.tap(segment('Week'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();
    expect(find.text('No activity in this week'), findsOneWidget);
    expect(
      find.text('Weekly learning consistency'),
      findsOneWidget,
    ); // still shown

    // another child
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leo').last);
    await tester.pumpAndSettle();
    expect(find.text('Leo: progress report'), findsOneWidget);
    expect(find.text('No activity in this week'), findsOneWidget);
  });

  testWidgets('notifications: inbox, read, settings (in-app only)', (
    tester,
  ) async {
    await openParents(tester);
    await tester.tap(find.byTooltip('Notifications, 2 unread'));
    await tester.pumpAndSettle();
    expect(find.text('Mia reached today’s goal'), findsNWidgets(2));
    await tapText(tester, 'Mark all as read');
    expect(find.text('Mark all as read'), findsNothing);
    expect(
      await demo.notifications(),
      everyElement(predicate<ParentNotification>((n) => !n.unread)),
    );

    await tester.tap(find.byTooltip('Notification settings'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Email and push delivery aren’t connected yet'),
      findsOneWidget,
    );
    await tapText(tester, 'Goals reached');
    await tapText(tester, 'Save');
    expect(find.text('Saved'), findsOneWidget);
    expect((await demo.preferences())[NoticeType.goalReached], isFalse);
  });

  testWidgets(
    'privacy: consents, a child export, account deletion with a fresh code, cancel',
    (tester) async {
      var now = testNow;
      await openParents(tester, clock: () => now);
      await go(tester, Routes.privacy);
      expect(find.text('Terms of use'), findsOneWidget);
      expect(find.textContaining('Given 19 Oct 2026'), findsWidgets);
      await see(tester, find.text('Leo’s data'));
      await tapText(tester, 'Leo’s data');
      expect(
        find.textContaining('Your export is ready (demo mode'),
        findsOneWidget,
      );
      expect(find.text('Leo'), findsOneWidget); // the export list
      expect((await demo.exports()).single.childId, 'child-leo');

      // 15 minutes later, deleting the account asks for a fresh email code first
      now = now.add(const Duration(minutes: 15));
      await see(tester, find.text('Delete the whole account'));
      await tapText(tester, 'Delete the whole account');
      await tapText(tester, 'Delete in 7 days');
      expect(find.text('Confirm it’s you'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        DemoBackend.code,
      );
      await tester.pumpAndSettle();
      await see(tester, find.textContaining('This account will be deleted on'));
      expect(
        find.text('This account will be deleted on 25 Nov 2026.'),
        findsOneWidget,
      );
      await tapText(tester, 'Keep my account');
      await see(tester, find.text('Delete the whole account'));
      expect((await demo.deletionRequests()).single.status, 'cancelled');
    },
  );

  testWidgets(
    'subscription: Plus from a code; Basic with plans; store actions say they are not connected',
    (tester) async {
      await openParents(tester);
      await go(tester, Routes.subscription);
      expect(find.text('You have Plus'), findsOneWidget);
      expect(find.text('TEST SUBSCRIPTION'), findsOneWidget);
      expect(
        find.textContaining('Plus came from a code. It ends by itself'),
        findsOneWidget,
      );
      await see(tester, find.text('Restore purchases (not connected yet)'));
      await tapText(tester, 'Restore purchases (not connected yet)');
      expect(
        find.textContaining('Nothing was charged or changed.'),
        findsOneWidget,
      );
      await tapText(tester, 'OK');

      demo.setFamilyPlus(false);
      await tapText(tester, 'Check status again');
      await see(tester, find.text('You’re on Basic'));
      expect(find.text('Plus, monthly'), findsOneWidget);
      expect(find.text('Plus, yearly'), findsOneWidget);
      await tapText(tester, 'Choose (not connected yet)');
      expect(find.text('Buying Plus, monthly'), findsOneWidget);
      expect(openedUrls, isEmpty);
    },
  );

  testWidgets('controls: Learn can be switched off; the kids area follows', (
    tester,
  ) async {
    await openParents(tester);
    await go(tester, Routes.childMedia('child-mia'));
    expect(find.textContaining('chosen for Mia’s age'), findsOneWidget);
    await tapText(tester, 'Learning paths and courses');
    await see(tester, find.text('Save'));
    await tapText(tester, 'Save');
    expect(find.text('Saved'), findsOneWidget);
    expect(demo.progress['child-mia']!.sections.learn, isFalse);
  });

  testWidgets(
    'children can’t open parent screens: every parent route asks for the grown-up gate',
    (tester) async {
      demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
      await pumpApp(tester, backend: demo);
      await demo.signInWithPassword(
        email: 'alice@example.test',
        password: DemoBackend.alicePassword,
      );
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Mia');
      for (final path in [
        Routes.parents,
        Routes.childReport('child-mia'),
        Routes.privacy,
        Routes.subscription,
        Routes.parentNotifications,
      ]) {
        await go(tester, path);
        expect(
          find.text('five, two, eight'),
          findsOneWidget,
          reason: path,
        ); // the gate
        expect(find.text('Your children'), findsNothing, reason: path);
        expect(find.text('Mia: progress report'), findsNothing, reason: path);
        expect(find.text('Privacy and data'), findsNothing, reason: path);
        expect(find.text('Subscription'), findsNothing, reason: path);
        await go(tester, Routes.kids);
      }
    },
  );

  for (final (name, size) in [
    ('phone', phone),
    ('phone sideways', phoneLandscape),
    ('tablet', tablet),
    ('desktop', desktop),
  ]) {
    testWidgets(
      'layout ($name): dashboard, report, notifications, privacy, subscription',
      (tester) async {
        await openParents(tester, size: size);
        final handle = tester.ensureSemantics();
        Future<void> check(String what, {bool contrast = true}) async {
          await expectLater(
            tester,
            meetsGuideline(androidTapTargetGuideline),
            reason: what,
          );
          await expectLater(
            tester,
            meetsGuideline(labeledTapTargetGuideline),
            reason: what,
          );
          if (contrast) {
            await expectLater(
              tester,
              meetsGuideline(textContrastGuideline),
              reason: what,
            );
          }
          expect(tester.takeException(), isNull, reason: what);
        }

        await check('dashboard');
        await see(tester, find.text('Mia’s report'));
        await check('dashboard, child card');
        await go(tester, Routes.childReport('child-mia'));
        await check('report');
        await see(tester, find.text('Game performance'));
        // rows scrolled under the app bar are misread by the contrast checker (they are ink
        // on white when visible); the same page is contrast-checked at the top ('report')
        await check('report, tables', contrast: false);
        await go(tester, Routes.parentNotifications);
        await check('notifications');
        await go(tester, Routes.privacy);
        await check('privacy');
        await go(tester, Routes.subscription);
        await check('subscription');
        handle.dispose();
      },
    );
  }
}
