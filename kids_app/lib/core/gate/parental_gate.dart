import 'dart:math';

/// Parental gate (design K20): three numbers written as words, typed on a keypad.
/// Pre-readers can't follow it. It is child-proofing, NOT security: real protection is on the
/// server (re-authentication for deletions, store confirmation for purchases).
/// Pure Dart: no Flutter imports.

const numberWords = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
];

/// How long the Parents Area stays open after the gate (docs/backend/authentication.md §7).
const gateTokenLifetime = Duration(minutes: 5);

class GateChallenge {
  const GateChallenge(this.digits);

  factory GateChallenge.random(Random random) =>
      GateChallenge(List.generate(3, (_) => random.nextInt(10)));

  final List<int> digits;

  /// "five, two, eight"
  String get words => digits.map((d) => numberWords[d]).join(', ');

  bool matches(List<int> entered) =>
      entered.length == digits.length &&
      Iterable.generate(digits.length).every((i) => entered[i] == digits[i]);
}

class GateState {
  const GateState({
    required this.challenge,
    this.entered = const [],
    this.unlockedUntil,
    this.lastAttemptFailed = false,
  });

  final GateChallenge challenge;
  final List<int> entered;
  final DateTime? unlockedUntil;
  final bool lastAttemptFailed;

  bool isOpen(DateTime now) =>
      unlockedUntil != null && now.isBefore(unlockedUntil!);

  GateState copyWith({
    GateChallenge? challenge,
    List<int>? entered,
    DateTime? unlockedUntil,
    bool? lastAttemptFailed,
    bool clearUnlock = false,
  }) => GateState(
    challenge: challenge ?? this.challenge,
    entered: entered ?? this.entered,
    unlockedUntil: clearUnlock ? null : (unlockedUntil ?? this.unlockedUntil),
    lastAttemptFailed: lastAttemptFailed ?? this.lastAttemptFailed,
  );
}

/// State transitions, kept pure so they are easy to test.
abstract final class GateRules {
  static GateState tap(GateState s, int digit, DateTime now, Random random) {
    if (s.entered.length >= s.challenge.digits.length) return s;
    final entered = [...s.entered, digit];
    if (entered.length < s.challenge.digits.length) {
      return s.copyWith(entered: entered, lastAttemptFailed: false);
    }
    if (s.challenge.matches(entered)) {
      return GateState(
        challenge: GateChallenge.random(random),
        unlockedUntil: now.add(gateTokenLifetime),
      );
    }
    // Wrong: a new challenge every time, so guessing doesn't converge.
    return GateState(
      challenge: GateChallenge.random(random),
      lastAttemptFailed: true,
    );
  }

  static GateState backspace(GateState s) => s.entered.isEmpty
      ? s
      : s.copyWith(
          entered: s.entered.sublist(0, s.entered.length - 1),
          lastAttemptFailed: false,
        );
}
