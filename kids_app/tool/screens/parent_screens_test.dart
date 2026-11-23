// Screenshots for docs/parent-dashboard/screens/ (not part of `flutter test`; it lives in tool/).
//   flutter test --update-goldens tool/screens/parent_screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kids_app/app/router/routes.dart';
import 'package:kids_app/demo/demo_backend.dart';

import '../../test/helpers/test_app.dart';

const _out = '../../../docs/parent-dashboard/screens';

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

  Future<void> start(WidgetTester tester, Size size) async {
    final demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
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

  Future<void> go(WidgetTester tester, String path) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
    await tester.pumpAndSettle();
  }

  Future<void> scroll(WidgetTester tester, double dy) async {
    await tester.drag(find.byType(ListView).first, Offset(0, -dy));
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$_out/$name.png'),
  );

  testWidgets('D01 dashboard (desktop)', (tester) async {
    await start(tester, desktop);
    await shot(tester, 'D01-dashboard');
  });

  testWidgets('D02 dashboard child card (phone)', (tester) async {
    await start(tester, phone);
    await scroll(tester, 420);
    await shot(tester, 'D02-dashboard-child-card-phone');
  });

  testWidgets('D03 report (desktop)', (tester) async {
    await start(tester, desktop);
    await go(tester, Routes.childReport('child-mia'));
    await shot(tester, 'D03-report-week');
  });

  testWidgets('D04 report analytics (desktop)', (tester) async {
    await start(tester, desktop);
    await go(tester, Routes.childReport('child-mia'));
    await scroll(tester, 900);
    await shot(tester, 'D04-report-analytics');
  });

  testWidgets('D05 notifications (tablet)', (tester) async {
    await start(tester, tablet);
    await go(tester, Routes.parentNotifications);
    await shot(tester, 'D05-notifications');
  });

  testWidgets('D06 privacy (tablet)', (tester) async {
    await start(tester, tablet);
    await go(tester, Routes.privacy);
    await shot(tester, 'D06-privacy-and-data');
  });

  testWidgets('D07 subscription (phone)', (tester) async {
    await start(tester, phone);
    await go(tester, Routes.subscription);
    await shot(tester, 'D07-subscription');
  });
}
