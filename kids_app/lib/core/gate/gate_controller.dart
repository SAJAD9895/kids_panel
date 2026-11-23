import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../clock/clock.dart';
import 'parental_gate.dart';

/// Source of randomness for the gate (overridden in tests for a known challenge).
final gateRandomProvider = Provider<Random>((ref) => Random.secure());

/// Session state: the gate token lives in memory only and is cleared on sign-out.
final gateProvider = NotifierProvider<GateController, GateState>(
  GateController.new,
);

class GateController extends Notifier<GateState> {
  @override
  GateState build() =>
      GateState(challenge: GateChallenge.random(ref.watch(gateRandomProvider)));

  void tap(int digit) => state = GateRules.tap(
    state,
    digit,
    ref.read(clockProvider)(),
    ref.read(gateRandomProvider),
  );

  void backspace() => state = GateRules.backspace(state);

  /// Closes the Parents Area (back to kids, or sign-out).
  void lock() => state = GateState(
    challenge: GateChallenge.random(ref.read(gateRandomProvider)),
  );

  bool isOpen() => state.isOpen(ref.read(clockProvider)());
}
