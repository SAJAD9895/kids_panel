import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/core/error/failure.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/features/child_profiles/domain/child_profile.dart';
import 'package:kids_app/features/onboarding/domain/onboarding_repository.dart';

void main() {
  var now = DateTime(2026, 11, 18, 10);
  late DemoBackend demo;
  setUp(() => demo = DemoBackend(latency: Duration.zero, clock: () => now));
  tearDown(() => demo.dispose());

  const kai = ChildDetails(
    nickname: 'Kai',
    birthYearMonth: BirthYearMonth(2021, 5),
  );
  OnboardingRequest request(List<ConsentType> consents) => OnboardingRequest(
    timezone: 'Europe/London',
    child: kai,
    consents: [for (final c in consents) Consent(c, '2026-11')],
  );

  test('the demo enforces the same rules as the server', () async {
    await demo.verifyEmailCode(
      email: 'new@example.test',
      code: DemoBackend.code,
    );
    expect(await demo.hasFamilyAccount(demo.currentUser!.id), isFalse);
    await expectLater(
      demo.complete(request([ConsentType.terms])),
      throwsA(isA<ValidationFailure>()),
    );

    final r = await demo.complete(request(ConsentType.values.take(3).toList()));
    expect(r.created, isTrue);
    final again = await demo.complete(
      request(ConsentType.values.take(3).toList()),
    );
    expect(again.created, isFalse, reason: 'idempotent');
    expect(again.childId, r.childId);

    // Basic: one child
    await expectLater(demo.addChild(kai), throwsA(isA<ChildLimitFailure>()));
  });

  test('wrong code, unknown account', () async {
    await expectLater(
      demo.verifyEmailCode(email: 'a@example.test', code: '000000'),
      throwsA(isA<InvalidCodeFailure>()),
    );
    await expectLater(
      demo.sendEmailCode(email: 'nobody@example.test', createUser: false),
      throwsA(isA<AccountNotFoundFailure>()),
    );
  });

  test('deleting a child needs a recent sign-in', () async {
    await demo.signInWithPassword(
      email: 'alice@example.test',
      password: DemoBackend.alicePassword,
    );
    now = now.add(const Duration(minutes: 11));
    await expectLater(
      demo.deleteChild('child-leo'),
      throwsA(isA<ReauthRequiredFailure>()),
    );
    await demo.verifyEmailCode(
      email: 'alice@example.test',
      code: DemoBackend.code,
    );
    await demo.deleteChild('child-leo');
    expect((await demo.listChildren()).map((c) => c.nickname), ['Mia']);
  });
}
