import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/core/gate/parental_gate.dart';

import '../helpers/test_app.dart';

void main() {
  final now = DateTime(2026, 11, 18, 10);
  final start = GateState(challenge: const GateChallenge([5, 2, 8]));

  test('challenge is read as words', () {
    expect(const GateChallenge([5, 2, 8]).words, 'five, two, eight');
    expect(GateChallenge.random(Random(1)).digits, hasLength(3));
  });

  test('the right numbers open the gate for 5 minutes', () {
    var s = start;
    for (final d in [5, 2, 8]) {
      s = GateRules.tap(s, d, now, FixedRandom([1, 1, 1]));
    }
    expect(s.isOpen(now), isTrue);
    expect(s.isOpen(now.add(const Duration(minutes: 4, seconds: 59))), isTrue);
    expect(s.isOpen(now.add(gateTokenLifetime)), isFalse);
  });

  test('a wrong answer stays closed and changes the numbers', () {
    var s = start;
    for (final d in [5, 2, 9]) {
      s = GateRules.tap(s, d, now, FixedRandom([1, 3, 7]));
    }
    expect(s.isOpen(now), isFalse);
    expect(s.lastAttemptFailed, isTrue);
    expect(s.challenge.digits, [1, 3, 7]);
    expect(s.entered, isEmpty);
  });

  test('backspace removes the last digit', () {
    var s = GateRules.tap(start, 5, now, Random());
    s = GateRules.tap(s, 3, now, Random());
    s = GateRules.backspace(s);
    expect(s.entered, [5]);
    expect(GateRules.backspace(start).entered, isEmpty);
  });
}
