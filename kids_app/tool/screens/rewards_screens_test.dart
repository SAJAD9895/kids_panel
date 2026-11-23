// Screenshots for docs/gamification/screens/ (not part of `flutter test`; it lives in tool/).
//   flutter test --update-goldens tool/screens/rewards_screens_test.dart
// Renders the real app on the demo backend with the app's fonts and the bundled badge art.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kids_app/app/router/routes.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/demo/demo_rewards.dart';
import 'package:kids_app/features/rewards/domain/rewards.dart';
import 'package:kids_app/features/rewards/presentation/rewards_providers.dart';

import '../../test/helpers/test_app.dart';

const _out = '../../../docs/gamification/screens';

void main() {
  setUpAll(loadAppFonts);
  setUp(
    () =>
        TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          disableAnimations: true,
        ),
  );

  Future<DemoBackend> start(WidgetTester tester, Size size) async {
    final demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
    await pumpApp(tester, size: size, backend: demo);
    await demo.signInWithPassword(
      email: 'alice@example.test',
      password: DemoBackend.alicePassword,
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Mia');
    return demo;
  }

  BuildContext ctx(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  /// Decodes the bundled badge pictures (real image decoding needs real async).
  Future<void> loadArt(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final b in demoBadges) {
        for (final s in ['256', '512']) {
          final path =
              'assets/dev_media/public-assets/${b.art.replaceFirst('/512.webp', '/$s.webp')}';
          await rootBundle.load(path);
        }
      }
      for (final e in find.byType(Image).evaluate()) {
        final img = e.widget as Image;
        await precacheImage(img.image, e);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await loadArt(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/$name.png'),
    );
  }

  testWidgets('G01 My rewards (tablet)', (tester) async {
    await start(tester, tablet);
    GoRouter.of(ctx(tester)).go(Routes.rewards);
    await tester.pumpAndSettle();
    await shot(tester, 'G01-my-rewards');
  });

  testWidgets('G02 badge collection (tablet)', (tester) async {
    await start(tester, tablet);
    GoRouter.of(ctx(tester)).go(Routes.rewards);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.textContaining('My badges'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await shot(tester, 'G02-badge-collection');
  });

  testWidgets('G03 a badge celebration (phone)', (tester) async {
    await start(tester, phone);
    ProviderScope.containerOf(ctx(tester))
        .read(celebrationQueueProvider.notifier)
        .push(
          const RewardEvents(
            childId: 'child-mia',
            stars: 4,
            dailyGoalDone: true,
            badges: [
              (
                key: 'badge-streak-3',
                title: 'Three learning days',
                bonusStars: 1,
                art: 'badges/streak-3/1/512.webp',
              ),
            ],
          ),
        );
    await tester.pumpAndSettle();
    await shot(tester, 'G03-celebration-badge');
  });

  testWidgets('G04 parent: rewards and goals (desktop)', (tester) async {
    await start(tester, desktop);
    await tapLabel(tester, 'Grown-ups');
    for (final d in ['5', '2', '8']) {
      await tapLabel(tester, d);
    }
    GoRouter.of(ctx(tester)).go(Routes.childRewards('child-mia'));
    await tester.pumpAndSettle();
    await shot(tester, 'G04-parent-rewards-goals');
  });

  testWidgets('G05 home with the goal card (phone)', (tester) async {
    await start(tester, phone);
    await shot(tester, 'G05-home-daily-goal');
  });
}
