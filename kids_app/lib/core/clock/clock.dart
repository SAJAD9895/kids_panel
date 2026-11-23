import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time, injectable so tests can move it (gate expiry, resend countdowns, ages).
typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);
