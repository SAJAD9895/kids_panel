import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/features/auth/domain/auth_repository.dart';
import 'package:kids_app/features/child_profiles/domain/child_profile.dart';
import 'package:kids_app/features/onboarding/domain/onboarding_repository.dart';

void main() {
  test('email validation and masking', () {
    expect(isValidEmail('parent@example.com'), isTrue);
    expect(isValidEmail(' parent@example.com '), isTrue);
    expect(isValidEmail('parent@example'), isFalse);
    expect(isValidEmail('no at sign'), isFalse);
    expect(maskEmail('parent@example.com'), 'p•••@example.com');
  });

  test('onboarding request matches the onboard_family contract', () {
    final json = const OnboardingRequest(
      timezone: 'Europe/London',
      uiLocale: 'en',
      child: ChildDetails(
        nickname: 'Kai',
        birthYearMonth: BirthYearMonth(2021, 5),
      ),
      consents: [
        Consent(ConsentType.terms, '2026-11'),
        Consent(ConsentType.privacyPolicy, '2026-11'),
        Consent(ConsentType.childDataCollection, '2026-11'),
      ],
    ).toJson();
    expect(json['timezone'], 'Europe/London');
    expect(json['child'], {
      'nickname': 'Kai',
      'birthYearMonth': '2021-05',
    }, reason: 'null avatar left out');
    expect(json['consents'], [
      {'type': 'terms', 'policyVersion': '2026-11', 'method': 'checkbox'},
      {
        'type': 'privacy_policy',
        'policyVersion': '2026-11',
        'method': 'checkbox',
      },
      {
        'type': 'child_data_collection',
        'policyVersion': '2026-11',
        'method': 'email_plus',
      },
    ]);
    // The client never names a user, an account or a role: the server takes them from the JWT.
    final text = json.toString();
    for (final forbidden in [
      'userId',
      'user_id',
      'accountId',
      'account_id',
      'role',
      'evidence',
    ]) {
      expect(text.contains(forbidden), isFalse, reason: forbidden);
    }
  });
}
