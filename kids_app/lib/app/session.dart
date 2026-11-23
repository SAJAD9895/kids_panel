import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/gate/gate_controller.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/child_profiles/presentation/child_providers.dart';
import '../features/learning/presentation/learning_providers.dart';
import '../features/onboarding/presentation/onboarding_providers.dart';
import '../features/play/presentation/play_providers.dart';
import 'providers.dart';

/// Session lifecycle. When the signed-in parent changes (sign-out, expired session, another
/// account), every session provider is reset, so nothing from one family or child can show
/// up on the next one's screens (02-flutter-architecture §2.3).
final sessionProvider = Provider<SessionController>((ref) {
  final controller = SessionController(ref);
  ref.listen<String?>(currentUserIdProvider, (previous, next) {
    if (previous != null && previous != next) controller.reset();
    // Signed in (again): send any sessions finished while offline.
    if (next != null) ref.read(syncServiceProvider).flush();
  }, fireImmediately: true);
  return controller;
});

class SessionController {
  SessionController(this._ref);

  final Ref _ref;

  Future<void> signOut() async {
    await _ref.read(authRepositoryProvider).signOut();
    reset();
  }

  void reset() {
    _ref.invalidate(selectedChildIdProvider);
    _ref.invalidate(gateProvider);
    _ref.invalidate(emailCodeProvider);
    _ref.invalidate(consentChoicesProvider);
    _ref.invalidate(childDraftProvider);
    _ref.invalidate(onboardingSubmitProvider);
    _ref.invalidate(childrenProvider);
    _ref.invalidate(familyStatusProvider);
    _ref.invalidate(catalogProvider);
    _ref.invalidate(courseTreeProvider);
    _ref.invalidate(childProgressProvider);
    _ref.invalidate(familyPlusProvider);
    _ref.invalidate(activitySourceProvider);
  }
}
