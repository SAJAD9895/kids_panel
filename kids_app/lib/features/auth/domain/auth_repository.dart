/// Parent authentication (docs/backend/authentication.md). Children never sign in.
/// Pure Dart: implementations live in `data/` (Supabase) and `lib/demo/` (in-memory).
library;

class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}

enum SocialProvider { apple, google }

abstract interface class AuthRepository {
  AuthUser? get currentUser;

  /// Emits the current user (or null) first, then every change: sign-in, sign-out, a session
  /// restored from storage, or a refresh that failed.
  Stream<AuthUser?> authStateChanges();

  /// Sends the email with a magic link and a 6-digit code.
  /// [createUser] is true for sign-up; false for sign-in, which then fails with
  /// [AccountNotFoundFailure] for an unknown email.
  Future<void> sendEmailCode({required String email, required bool createUser});

  /// Exchanges the 6-digit code for a session. Throws [InvalidCodeFailure].
  Future<void> verifyEmailCode({required String email, required String code});

  /// Optional password sign-in (P16). Throws [InvalidCredentialsFailure].
  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  /// Apple / Google through the browser (OAuth + PKCE).
  Future<void> signInWithProvider(SocialProvider provider);

  /// Signs out this device and clears the stored session.
  Future<void> signOut();
}

final _email = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$");

bool isValidEmail(String value) => _email.hasMatch(value.trim());

/// `parent@example.com` → `p•••@example.com` (shown on the code screen).
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  return '${email[0]}•••${email.substring(at)}';
}
