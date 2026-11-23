import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../child_profiles/domain/child_profile.dart';
import '../../child_profiles/presentation/child_providers.dart';
import '../domain/onboarding_repository.dart';

/// Does the signed-in parent have a family account yet? null while signed out.
final familyStatusProvider = FutureProvider<bool?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.read(onboardingRepositoryProvider).hasFamilyAccount(userId);
});

/// Which flow a child form belongs to: first-time setup (F01) or adding a child later (F13).
enum ChildFlow { onboarding, addChild }

/// A child being set up. Lives only on the device until it is submitted.
class ChildDraft {
  const ChildDraft({this.nickname = '', this.birthYearMonth, this.avatarId});

  final String nickname;
  final BirthYearMonth? birthYearMonth;
  final String? avatarId;

  bool get hasDetails =>
      validateNickname(nickname) == null && birthYearMonth != null;

  ChildDetails toDetails() => ChildDetails(
    nickname: nickname.trim(),
    birthYearMonth: birthYearMonth!,
    avatarId: avatarId,
  );

  ChildDraft copyWith({
    String? nickname,
    BirthYearMonth? birthYearMonth,
    String? avatarId,
  }) => ChildDraft(
    nickname: nickname ?? this.nickname,
    birthYearMonth: birthYearMonth ?? this.birthYearMonth,
    avatarId: avatarId ?? this.avatarId,
  );
}

final childDraftProvider =
    NotifierProvider.family<ChildDraftController, ChildDraft, ChildFlow>(
      ChildDraftController.new,
    );

class ChildDraftController extends Notifier<ChildDraft> {
  ChildDraftController(this.flow);

  final ChildFlow flow;

  @override
  ChildDraft build() => const ChildDraft();

  void setDetails(String nickname, BirthYearMonth birth) =>
      state = state.copyWith(nickname: nickname.trim(), birthYearMonth: birth);

  void setAvatar(String avatarId) => state = state.copyWith(avatarId: avatarId);

  void reset() => state = const ChildDraft();
}

/// The parent's answers on K03. Required: terms + privacy, and child data collection.
class ConsentChoices {
  const ConsentChoices({
    this.termsAndPrivacy = false,
    this.childData = false,
    this.marketing = false,
  });

  final bool termsAndPrivacy;
  final bool childData;
  final bool marketing;

  bool get requiredGiven => termsAndPrivacy && childData;

  ConsentChoices copyWith({
    bool? termsAndPrivacy,
    bool? childData,
    bool? marketing,
  }) => ConsentChoices(
    termsAndPrivacy: termsAndPrivacy ?? this.termsAndPrivacy,
    childData: childData ?? this.childData,
    marketing: marketing ?? this.marketing,
  );
}

final consentChoicesProvider =
    NotifierProvider<ConsentChoicesController, ConsentChoices>(
      ConsentChoicesController.new,
    );

class ConsentChoicesController extends Notifier<ConsentChoices> {
  @override
  ConsentChoices build() => const ConsentChoices();

  void update(ConsentChoices c) => state = c;
}

/// Ready to create the family: a child draft plus the required consents.
final onboardingReadyProvider = Provider<bool>(
  (ref) =>
      ref.watch(childDraftProvider(ChildFlow.onboarding)).hasDetails &&
      ref.watch(consentChoicesProvider).requiredGiven,
);

/// Submits onboarding once (`POST /onboarding/complete`).
final onboardingSubmitProvider =
    AsyncNotifierProvider<OnboardingSubmitController, void>(
      OnboardingSubmitController.new,
    );

class OnboardingSubmitController extends AsyncNotifier<void> {
  bool _running = false;

  @override
  Future<void> build() async {}

  Future<void> submit() async {
    if (_running) return;
    _running = true;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final draft = ref.read(childDraftProvider(ChildFlow.onboarding));
      final consents = ref.read(consentChoicesProvider);
      final config = ref.read(appConfigProvider);
      final v = config.policyVersion;
      final result = await ref
          .read(onboardingRepositoryProvider)
          .complete(
            OnboardingRequest(
              timezone: await ref.read(timezoneProvider)(),
              child: draft.toDetails(),
              marketingOptIn: consents.marketing,
              consents: [
                Consent(ConsentType.terms, v),
                Consent(ConsentType.privacyPolicy, v),
                Consent(ConsentType.childDataCollection, v),
              ],
            ),
          );
      if (result.childId != null) {
        ref.read(selectedChildIdProvider.notifier).select(result.childId!);
      }
      ref.read(childDraftProvider(ChildFlow.onboarding).notifier).reset();
      ref.read(consentChoicesProvider.notifier).update(const ConsentChoices());
      ref.invalidate(childrenProvider);
      ref.invalidate(familyStatusProvider);
    });
    _running = false;
  }
}
