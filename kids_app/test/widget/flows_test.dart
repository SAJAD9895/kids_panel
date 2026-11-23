import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/core/error/failure.dart';
import 'package:kids_app/demo/demo_backend.dart';

import '../helpers/test_app.dart';

/// End-to-end flows on the in-memory backend: the same screens, router and controllers as
/// the real app; only the repositories are the demo ones.
void main() {
  setUpAll(loadAppFonts);

  Future<void> enterChild(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField).first, name);
    await tapLabel(tester, 'May');
    await tapText(tester, '2021');
    await tapLabel(tester, 'Next');
  }

  Future<void> enterGateCode(WidgetTester tester) async {
    expect(find.text('five, two, eight'), findsOneWidget);
    for (final d in ['5', '2', '8']) {
      await tapLabel(tester, d);
    }
  }

  for (final size in [tablet, phone]) {
    testWidgets(
      'F01 sign-up: child → buddy → grown-up → code → family created → kids home (${size.width.toInt()} wide)',
      (tester) async {
        final demo = await pumpApp(tester, size: size);
        expect(find.text('Learn, play and grow together!'), findsOneWidget);

        await tapLabel(tester, "Grown-ups: let's set up");
        expect(
          find.text("What's your child's first name or nickname?"),
          findsOneWidget,
        );

        await enterChild(tester, 'Kai');
        expect(find.text('Pick your buddy!'), findsOneWidget);
        expect(find.text('Kai'), findsOneWidget);
        await tapLabel(tester, 'Buddy Rumble');
        await tapLabel(tester, "That's me!");

        expect(find.text('Create your family account'), findsOneWidget);
        // consents are required
        await tester.enterText(
          find.widgetWithText(TextField, 'Email'),
          'new.parent@example.test',
        );
        await tapText(tester, 'Send my code');
        expect(
          find.text('Please tick both required boxes to continue.'),
          findsOneWidget,
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

        expect(find.text('Check your email'), findsOneWidget);
        expect(find.textContaining('n•••@example.test'), findsOneWidget);
        // wrong code first
        await tester.enterText(find.byType(TextField).first, '000000');
        await tester.pumpAndSettle();
        expect(find.text(const InvalidCodeFailure().message), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, DemoBackend.code);
        await tester.pumpAndSettle();

        expect(find.text('Hi, Kai!'), findsOneWidget);
        expect(demo.currentUser?.email, 'new.parent@example.test');
        final kids = await demo.listChildren();
        expect(kids.single.nickname, 'Kai');
        expect(kids.single.birthYearMonth.iso, '2021-05');
        expect(kids.single.avatarId, 'avatar-04', reason: 'Rumble is buddy-04');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('K05 validation: name, birth month, age range', (tester) async {
    await pumpApp(tester);
    await tapLabel(tester, "Grown-ups: let's set up");
    await tapLabel(tester, 'Next');
    expect(
      find.text("Add your child's first name or a nickname."),
      findsOneWidget,
    );
    expect(find.text('Pick the month and the year.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'mia@example.com');
    await tapLabel(tester, 'December');
    await tapText(tester, '2025');
    await tapLabel(tester, 'Next');
    expect(
      find.text(
        'Just a first name or nickname, please: no email addresses or numbers.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Children need to be at least one year old to play.'),
      findsOneWidget,
    );
    expect(find.text('Pick your buddy!'), findsNothing);
  });

  testWidgets(
    'F03 sign in, pick a player, grown-up gate, manage children, sign out',
    (tester) async {
      final demo = await pumpApp(tester);
      await tapLabel(tester, 'I already have an account');
      expect(find.text('Welcome back'), findsOneWidget);

      // unknown email
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'nobody@example.test',
      );
      await tapText(tester, 'Email me a code');
      expect(find.text(const AccountNotFoundFailure().message), findsOneWidget);

      // password sign-in
      await tapText(tester, 'Use a password instead');
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'alice@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'wrong',
      );
      await tapText(tester, 'Sign in');
      expect(
        find.text(const InvalidCredentialsFailure().message),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        DemoBackend.alicePassword,
      );
      await tapText(tester, 'Sign in');

      // two children → K35
      expect(find.text("Who's playing?"), findsOneWidget);
      await tapLabel(tester, 'Leo');
      expect(find.text('Hi, Leo!'), findsOneWidget);
      await tapLabel(tester, 'Leo: switch player');
      await tapLabel(tester, 'Mia');
      expect(find.text('Hi, Mia!'), findsOneWidget);

      // Grown-ups → gate: a wrong try changes nothing, the right numbers open it
      await tapLabel(tester, 'Grown-ups');
      for (final d in ['1', '1', '1']) {
        await tapLabel(tester, d);
      }
      expect(find.text('Not quite. Here are new numbers.'), findsOneWidget);
      expect(find.text('Manage children'), findsNothing);
      await enterGateCode(tester);
      expect(find.text('Manage children'), findsOneWidget);

      // P02: list, add (Plus allows it), edit, delete
      await tapText(tester, 'Manage children');
      expect(find.text('Mia'), findsOneWidget);
      expect(find.textContaining('Born Sep 2020'), findsOneWidget);
      await tapText(tester, 'Add a child');
      await enterChild(tester, 'Ada');
      await tapLabel(tester, 'Add Ada');
      expect(find.text('Ada was added.'), findsOneWidget);
      expect((await demo.listChildren()).map((c) => c.nickname), [
        'Mia',
        'Leo',
        'Ada',
      ]);

      await tapText(tester, 'Leo');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nickname'),
        'Leon',
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Save changes');
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Leon'), findsOneWidget);

      await tapText(tester, 'Ada');
      await tester.dragUntilVisible(
        find.text('Delete Ada’s profile'),
        find
            .byType(ListView)
            .last, // the edit page (the list page is still underneath)
        const Offset(0, -200),
      );
      // the "Saved" message bar covers the bottom of the page until it closes (4 s)
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tapText(tester, 'Delete Ada’s profile');
      await tapText(tester, 'Delete profile');
      expect(find.text('Ada’s profile was deleted.'), findsOneWidget);
      expect((await demo.listChildren()).map((c) => c.nickname), [
        'Mia',
        'Leon',
      ]);

      // sign out → welcome; session state is gone
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      // the dashboard lists the children first; Sign out is at the bottom (after the
      // "deleted" message bar has closed)
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Sign out'),
        find.byType(ListView).first,
        const Offset(0, -300),
      );
      await tapText(tester, 'Sign out');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sign out'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Learn, play and grow together!'), findsOneWidget);
      expect(demo.currentUser, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deleting a child after 10 minutes asks for a fresh code (P17)', (
    tester,
  ) async {
    var now = testNow;
    final demo = DemoBackend(latency: Duration.zero, clock: () => now);
    await pumpApp(tester, backend: demo);
    await tapLabel(tester, 'I already have an account');
    await tapText(tester, 'Use a password instead');
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'alice@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      DemoBackend.alicePassword,
    );
    await tapText(tester, 'Sign in');
    await tapLabel(tester, 'Leo');
    await tapLabel(tester, 'Grown-ups');
    await enterGateCode(tester);
    await tapText(tester, 'Manage children');
    await tapText(tester, 'Leo');

    now = now.add(const Duration(minutes: 15));
    await tester.scrollUntilVisible(
      find.text('Delete Leo’s profile'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapText(tester, 'Delete Leo’s profile');
    await tapText(tester, 'Delete profile');
    expect(find.text('Confirm it’s you'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      DemoBackend.code,
    );
    await tester.pumpAndSettle();
    expect(find.text('Leo’s profile was deleted.'), findsOneWidget);
    expect((await demo.listChildren()).map((c) => c.nickname), ['Mia']);
  });

  testWidgets(
    'new family on Basic can’t add a second child: clear message, nothing lost',
    (tester) async {
      final demo = await pumpApp(tester);
      await tapLabel(tester, "Grown-ups: let's set up");
      await enterChild(tester, 'Kai');
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
      expect(find.text('Hi, Kai!'), findsOneWidget);

      await tapLabel(tester, 'Grown-ups');
      await enterGateCode(tester);
      await tapText(tester, 'Manage children');
      await tapText(tester, 'Add a child');
      await enterChild(tester, 'Ada');
      await tapLabel(tester, 'Add Ada');
      expect(find.text('No room for another profile'), findsOneWidget);
      await tapText(tester, 'OK');
      expect((await demo.listChildren()).map((c) => c.nickname), ['Kai']);
    },
  );

  testWidgets(
    'error and retry: the children list fails to load, then recovers',
    (tester) async {
      final demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
      await pumpApp(tester, backend: demo);
      await tapLabel(tester, 'I already have an account');
      await tapText(tester, 'Use a password instead');
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'alice@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        DemoBackend.alicePassword,
      );
      demo.failNextRead = null;
      await tapText(tester, 'Sign in');
      await tapLabel(tester, 'Mia');
      await tapLabel(tester, 'Grown-ups');
      await enterGateCode(tester);
      await tapText(tester, 'Manage children');

      demo.failNextRead = const NetworkFailure();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      await tapText(tester, 'Try again');
      expect(find.text('Mia'), findsOneWidget);
    },
  );

  testWidgets(
    'a session that ends elsewhere (expired, signed out) returns to Welcome and clears the child',
    (tester) async {
      final demo = await pumpApp(tester);
      await demo.signInWithPassword(
        email: 'alice@example.test',
        password: DemoBackend.alicePassword,
      );
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Mia');
      expect(find.text('Hi, Mia!'), findsOneWidget);
      await demo.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Learn, play and grow together!'), findsOneWidget);
      await demo.signInWithPassword(
        email: 'alice@example.test',
        password: DemoBackend.alicePassword,
      );
      await tester.pumpAndSettle();
      expect(
        find.text("Who's playing?"),
        findsOneWidget,
        reason: 'the previous child is not remembered across sessions',
      );
    },
  );
}
