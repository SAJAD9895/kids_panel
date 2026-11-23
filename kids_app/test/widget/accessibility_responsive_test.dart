import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kids_app/app/router/routes.dart';
import 'package:kids_app/core/theme/tokens.g.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/features/child_profiles/domain/child_profile.dart';

import '../helpers/sampler.dart';
import '../helpers/test_app.dart';

/// docs/design/accessibility.md §6: tap targets, labels and contrast on every screen of this
/// phase, at phone, tablet and desktop sizes. A layout overflow fails the test too.
void main() {
  setUpAll(loadAppFonts);

  Future<void> checkScreen(
    WidgetTester tester,
    String name, {
    bool kids = true,
  }) async {
    final handle = tester.ensureSemantics();
    await expectLater(
      tester,
      meetsGuideline(iOSTapTargetGuideline),
      reason: name,
    );
    await expectLater(
      tester,
      meetsGuideline(labeledTapTargetGuideline),
      reason: name,
    );
    await expectLater(
      tester,
      meetsGuideline(textContrastGuideline),
      reason: name,
    );
    // Kid controls: never smaller than tap-kids-secondary (56), whatever the window.
    final kidControls = kids
        ? [
            find.bySemanticsLabel('Next'),
            find.bySemanticsLabel('Back'),
            find.bySemanticsLabel('Grown-ups'),
          ]
        : <Finder>[];
    for (final w in kidControls) {
      for (final e in w.evaluate()) {
        final size = (e.renderObject! as RenderBox).size;
        expect(
          size.shortestSide,
          greaterThanOrEqualTo(Sizes.tapKidsSecondary),
          reason: '$name: ${e.widget}',
        );
      }
    }
    expect(tester.takeException(), isNull, reason: name);
    handle.dispose();
  }

  Future<void> walk(WidgetTester tester, Size size) async {
    final demo = await pumpApp(tester, size: size);
    await checkScreen(tester, 'K02 welcome');
    await tapLabel(tester, "Grown-ups: let's set up");
    await checkScreen(tester, 'K05 child details');
    await tester.enterText(find.byType(TextField).first, 'Kai');
    await tapLabel(tester, 'May');
    await tapText(tester, '2021');
    await tapLabel(tester, 'Next');
    await checkScreen(tester, 'K06 buddy');
    await tapLabel(tester, "That's me!");
    await checkScreen(tester, 'K03 sign-up', kids: false);
    await tapLabel(tester, 'Back');
    await tapLabel(tester, 'Back');
    await tapLabel(tester, 'Back');
    await tapLabel(tester, 'I already have an account');
    await checkScreen(tester, 'sign in', kids: false);
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'alice@example.test',
    );
    await tapText(tester, 'Email me a code');
    await checkScreen(tester, 'K04 code', kids: false);
    await tester.enterText(find.byType(TextField).first, DemoBackend.code);
    await tester.pumpAndSettle();
    await checkScreen(tester, 'K35 who is playing');
    await tapLabel(tester, 'Mia');
    await checkScreen(tester, 'K07 kids home');
    await tapLabel(tester, 'Grown-ups');
    await checkScreen(tester, 'K20 gate');
    for (final d in ['5', '2', '8']) {
      await tapLabel(tester, d);
    }
    await checkScreen(tester, 'P01 parents', kids: false);
    await tapText(tester, 'Manage children');
    await checkScreen(tester, 'P02 children', kids: false);
    await tapText(tester, 'Leo');
    await checkScreen(tester, 'P02 edit', kids: false);
    expect(demo.currentUser, isNotNull);
  }

  for (final (name, size) in [
    ('phone', phone),
    ('phone landscape', phoneLandscape),
    ('tablet', tablet),
    ('desktop', desktop),
  ]) {
    testWidgets(
      'every screen: tap targets, labels, contrast, no overflow ($name)',
      (tester) => walk(tester, size),
    );
  }

  /// Phase 8 screens, with "reduce motion" on so the island's bouncing Pip lets the test settle.
  Future<void> tapShown(WidgetTester tester, String label) async {
    final f = find.bySemanticsLabel(label);
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tapLabel(tester, label);
  }

  Future<void> walkLearning(WidgetTester tester, Size size) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final demo = await pumpApp(tester, size: size);
    await demo.signInWithPassword(
      email: 'alice@example.test',
      password: DemoBackend.alicePassword,
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Mia');
    await checkScreen(tester, 'K07 home');
    await tapShown(tester, 'All subjects');
    await checkScreen(tester, 'K21 subjects');
    await tapLabel(tester, 'Letters');
    await checkScreen(tester, 'K08 subject');
    await tapShown(tester, 'Learning path Starting school');
    await checkScreen(tester, 'learning path');
    await tapShown(tester, 'Course Letters a to h, started');
    await checkScreen(tester, 'K09 course');
    await tapShown(tester, 'Island 2: d e f, 0 of 3 steps');
    await checkScreen(tester, 'K10 island');
    await tapShown(tester, 'Watch: Pip meets a snail, play next');
    await checkScreen(tester, 'activity');
    await tapLabel(tester, 'Learn');
    await checkScreen(tester, 'Learn');
    await tapShown(tester, 'See all');
    await checkScreen(tester, 'course list');
    await tapLabel(tester, 'Listen');
    await checkScreen(tester, 'Listen');
    await tapLabel(tester, 'Me');
    await checkScreen(tester, 'K17 me');
  }

  for (final (name, size) in [
    ('phone', phone),
    ('phone landscape', phoneLandscape),
    ('tablet', tablet),
    ('desktop', desktop),
  ]) {
    testWidgets(
      'learning screens: tap targets, labels, contrast, no overflow ($name)',
      (tester) => walkLearning(tester, size),
    );
  }

  testWidgets('a 20-character nickname fits everywhere it is shown', (
    tester,
  ) async {
    final demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
    await pumpApp(tester, size: phoneLandscape, backend: demo);
    await demo.signInWithPassword(
      email: 'alice@example.test',
      password: DemoBackend.alicePassword,
    );
    await demo.updateChild(
      'child-mia',
      const ChildDetails(
        nickname: 'Maximiliana-Josefina',
        birthYearMonth: BirthYearMonth(2022, 3),
        avatarId: 'avatar-04',
      ),
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Maximiliana-Josefina');
    expect(find.textContaining('Maximiliana'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text scaled to 200% still lays out (grown-up forms)', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, size: phone);
    await tapLabel(tester, 'I already have an account');
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /// Phase 9: the player on every activity type, at a small phone in landscape (the Kids
  /// Area's phone orientation) and a tablet: tap targets, labels, contrast, no overflow.
  for (final (name, size) in [
    ('phone landscape', phoneLandscape),
    ('tablet', tablet),
    ('desktop', desktop),
  ]) {
    testWidgets(
      'player, every activity type: tap targets, labels, contrast, no overflow ($name)',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final demo = await pumpApp(tester, size: size);
        await demo.signInWithPassword(
          email: 'alice@example.test',
          password: DemoBackend.alicePassword,
        );
        await tester.pumpAndSettle();
        await tapLabel(tester, 'Mia');
        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .push(Routes.play('engine-sampler'));
        await tester.pumpAndSettle();
        await checkScreen(tester, 'player intro', kids: false);
        await tapLabel(tester, 'Play');
        await playSampler(
          tester,
          beforeAnswer: (kind) =>
              checkScreen(tester, 'player: $kind', kids: false),
        );
        await checkScreen(tester, 'player completion', kids: false);
      },
    );
  }
}
