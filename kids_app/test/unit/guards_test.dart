import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/app/router/guards.dart';
import 'package:kids_app/app/router/routes.dart';

void main() {
  String? go(GuardState s, String path) => redirectFor(s, Uri.parse(path));

  const signedOut = GuardState(auth: AuthStatus.signedOut);
  const newParent = GuardState(
    auth: AuthStatus.signedIn,
    family: FamilyStatus.none,
  );
  const family = GuardState(
    auth: AuthStatus.signedIn,
    family: FamilyStatus.exists,
  );
  const playing = GuardState(
    auth: AuthStatus.signedIn,
    family: FamilyStatus.exists,
    childSelected: true,
  );

  test('while the session is restored, everything waits on the splash', () {
    expect(
      go(const GuardState(auth: AuthStatus.unknown), Routes.kids),
      Routes.splash,
    );
    expect(
      go(const GuardState(auth: AuthStatus.unknown), Routes.splash),
      isNull,
    );
    expect(
      go(const GuardState(auth: AuthStatus.signedIn), Routes.parents),
      Routes.splash,
    );
  });

  test('signed out: onboarding and sign-in only', () {
    for (final p in [
      Routes.welcome,
      Routes.setupChild,
      Routes.setupBuddy,
      Routes.setupGrownUp,
      Routes.signIn,
      Routes.verifyCode,
    ]) {
      expect(go(signedOut, p), isNull, reason: p);
    }
    for (final p in [
      Routes.splash,
      Routes.kids,
      Routes.whoIsPlaying,
      Routes.parents,
      Routes.children,
      Routes.gate,
      Routes.setupFinish,
    ]) {
      expect(go(signedOut, p), Routes.welcome, reason: p);
    }
  });

  test(
    'signed in without a family: collect the child and consents, then finish',
    () {
      expect(go(newParent, Routes.kids), Routes.setupChild);
      expect(go(newParent, Routes.parents), Routes.setupChild);
      expect(go(newParent, Routes.setupBuddy), isNull);
      expect(go(newParent, Routes.setupFinish), Routes.setupChild);
      const draft = GuardState(
        auth: AuthStatus.signedIn,
        family: FamilyStatus.none,
        childDraftReady: true,
      );
      expect(go(draft, Routes.verifyCode), Routes.setupGrownUp);
      expect(
        go(draft, Routes.setupFinish),
        Routes.setupGrownUp,
        reason: 'consents still missing',
      );
      const ready = GuardState(
        auth: AuthStatus.signedIn,
        family: FamilyStatus.none,
        childDraftReady: true,
        onboardingReady: true,
      );
      expect(go(ready, Routes.verifyCode), Routes.setupFinish);
      expect(go(ready, Routes.setupFinish), isNull);
    },
  );

  test('with a family: pick a child first, never back into onboarding', () {
    expect(go(family, Routes.splash), Routes.whoIsPlaying);
    expect(go(family, Routes.kids), Routes.whoIsPlaying);
    expect(go(family, Routes.setupChild), Routes.whoIsPlaying);
    expect(go(family, Routes.signIn), Routes.whoIsPlaying);
    expect(go(playing, Routes.setupFinish), Routes.kids);
    expect(go(playing, Routes.kids), isNull);
    expect(go(playing, Routes.whoIsPlaying), isNull, reason: 'switch player');
  });

  test(
    'the Parents Area needs the gate, and comes back to the page asked for',
    () {
      expect(go(playing, Routes.parents), '/gate?next=%2Fparents');
      expect(
        go(playing, Routes.child('abc')),
        '/gate?next=%2Fparents%2Fchildren%2Fabc',
      );
      expect(go(playing, Routes.gate), isNull);
      const open = GuardState(
        auth: AuthStatus.signedIn,
        family: FamilyStatus.exists,
        childSelected: true,
        gateOpen: true,
      );
      expect(go(open, Routes.children), isNull);
      expect(go(open, Routes.newChild), isNull);
    },
  );

  test(
    'a parents-looking path that is not under /parents is not treated as one',
    () {
      expect(Routes.isParents('/parentsX'), isFalse);
      expect(Routes.isParents('/parents'), isTrue);
    },
  );
}
