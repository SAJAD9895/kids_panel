import 'routes.dart';

/// Where the app should be, given the session. Pure, so every rule is unit-tested
/// (test/app/guards_test.dart). Returns null to stay, or the path to go to.
///
/// Rules (docs/architecture/02-flutter-architecture.md §2.4):
///  - not signed in → onboarding and sign-in screens only
///  - signed in, no family yet → finish setup (child details + consents, then create)
///  - signed in with a family → kids area; a child must be picked first
///  - Parents Area → only with an open parental gate (5 minutes)

enum AuthStatus { unknown, signedOut, signedIn }

enum FamilyStatus { unknown, none, exists }

class GuardState {
  const GuardState({
    required this.auth,
    this.family = FamilyStatus.unknown,
    this.onboardingReady = false,
    this.childDraftReady = false,
    this.childSelected = false,
    this.gateOpen = false,
  });

  final AuthStatus auth;
  final FamilyStatus family;

  /// The onboarding child draft and the required consents are both there.
  final bool onboardingReady;

  /// The onboarding child draft has a name and birth month (consents may still be missing).
  final bool childDraftReady;
  final bool childSelected;
  final bool gateOpen;
}

const _signedOutRoutes = {
  Routes.welcome,
  Routes.setupChild,
  Routes.setupBuddy,
  Routes.setupGrownUp,
  Routes.signIn,
  Routes.verifyCode,
};

const _setupRoutes = {
  Routes.setupChild,
  Routes.setupBuddy,
  Routes.setupGrownUp,
  Routes.setupFinish,
};

String? redirectFor(GuardState s, Uri location) {
  final path = location.path;

  if (s.auth == AuthStatus.unknown) {
    return path == Routes.splash ? null : Routes.splash;
  }

  if (s.auth == AuthStatus.signedOut) {
    if (_signedOutRoutes.contains(path)) return null;
    return Routes.welcome;
  }

  // signed in
  switch (s.family) {
    case FamilyStatus.unknown:
      return path == Routes.splash ? null : Routes.splash;

    case FamilyStatus.none:
      // Signed in but no family: collect what's missing, then create it.
      if (s.onboardingReady) {
        return path == Routes.setupFinish ? null : Routes.setupFinish;
      }
      if (path == Routes.setupFinish) {
        return s.childDraftReady ? Routes.setupGrownUp : Routes.setupChild;
      }
      if (_setupRoutes.contains(path)) return null;
      return s.childDraftReady ? Routes.setupGrownUp : Routes.setupChild;

    case FamilyStatus.exists:
      final home = s.childSelected ? Routes.kids : Routes.whoIsPlaying;
      if (path == Routes.splash ||
          _signedOutRoutes.contains(path) ||
          _setupRoutes.contains(path)) {
        return home;
      }
      if (Routes.isKids(path) && !s.childSelected) return Routes.whoIsPlaying;
      if (Routes.isParents(path) && !s.gateOpen) {
        return Uri(
          path: Routes.gate,
          queryParameters: {'next': location.toString()},
        ).toString();
      }
      return null;
  }
}
