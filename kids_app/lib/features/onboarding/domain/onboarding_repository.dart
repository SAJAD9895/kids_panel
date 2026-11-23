import '../../child_profiles/domain/child_profile.dart';

/// Family onboarding (flow F01). The child's details stay on the device until the parent has
/// signed in and consented; then ONE call creates the account, consents and first child
/// (`POST /onboarding/complete` → private.onboard_family).

enum ConsentType { terms, privacyPolicy, childDataCollection, marketing }

class Consent {
  const Consent(this.type, this.policyVersion);

  final ConsentType type;
  final String policyVersion;

  Map<String, Object?> toJson() => {
    'type': switch (type) {
      ConsentType.terms => 'terms',
      ConsentType.privacyPolicy => 'privacy_policy',
      ConsentType.childDataCollection => 'child_data_collection',
      ConsentType.marketing => 'marketing',
    },
    'policyVersion': policyVersion,
    // Verifiable parental consent: the parent proved control of the email (code or link),
    // and the server sends a confirmation email (docs/backend/authentication.md §4).
    'method': type == ConsentType.childDataCollection
        ? 'email_plus'
        : 'checkbox',
  };
}

class OnboardingRequest {
  const OnboardingRequest({
    required this.timezone,
    required this.child,
    required this.consents,
    this.uiLocale,
    this.marketingOptIn = false,
  });

  /// IANA name, e.g. `Europe/London`. The household's day (stars, limits) is computed from it.
  final String timezone;
  final String? uiLocale;
  final bool marketingOptIn;
  final ChildDetails child;
  final List<Consent> consents;

  Map<String, Object?> toJson() {
    final c = child.toJson()..removeWhere((k, v) => v == null);
    return {
      'timezone': timezone,
      'uiLocale': ?uiLocale,
      'marketingOptIn': marketingOptIn,
      'child': c,
      'consents': [for (final x in consents) x.toJson()],
    };
  }
}

class OnboardingResult {
  const OnboardingResult({
    required this.accountId,
    required this.childId,
    required this.created,
  });

  final String accountId;
  final String? childId;
  final bool created;
}

abstract interface class OnboardingRepository {
  /// Whether this signed-in parent already belongs to a family account.
  Future<bool> hasFamilyAccount(String userId);

  /// Idempotent: calling it twice returns the same account with `created == false`.
  Future<OnboardingResult> complete(OnboardingRequest request);
}
