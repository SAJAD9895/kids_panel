import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/auth_repository.dart';

/// The signed-in parent, or null. Restored from secure storage at start-up by Supabase.
final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Just the user id, so dependants don't rebuild when only the token refreshes.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider.select((s) => s.value?.id)),
);

/// Whether this sign-in creates a family (sign-up) or opens an existing one.
enum EmailCodePurpose { signUp, signIn }

class EmailCodeRequest {
  const EmailCodeRequest({
    required this.email,
    required this.purpose,
    required this.sentAt,
  });

  final String email;
  final EmailCodePurpose purpose;
  final DateTime sentAt;
}

/// The email a code was last sent to (shown and used on the code screen, K04).
final emailCodeProvider =
    NotifierProvider<EmailCodeController, EmailCodeRequest?>(
      EmailCodeController.new,
    );

class EmailCodeController extends Notifier<EmailCodeRequest?> {
  @override
  EmailCodeRequest? build() => null;

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  Future<void> send(String email, EmailCodePurpose purpose) async {
    final clean = email.trim().toLowerCase();
    await _auth.sendEmailCode(
      email: clean,
      createUser: purpose == EmailCodePurpose.signUp,
    );
    state = EmailCodeRequest(
      email: clean,
      purpose: purpose,
      sentAt: DateTime.now(),
    );
  }

  Future<void> resend() async {
    final r = state;
    if (r != null) await send(r.email, r.purpose);
  }

  /// On success the auth state changes and the router moves on by itself.
  Future<void> verify(String code) async {
    final r = state;
    if (r == null) return;
    await _auth.verifyEmailCode(email: r.email, code: code);
  }

  void clear() => state = null;
}
