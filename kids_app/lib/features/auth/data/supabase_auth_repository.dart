import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/error/error_mapper.dart';
import '../domain/auth_repository.dart';

/// Supabase Auth with PKCE (set in bootstrap). Tokens never appear in URLs.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth, {this.redirectUrl});

  final GoTrueClient _auth;

  /// Where the magic link returns to (deep link / web URL). Null = the project's Site URL.
  final String? redirectUrl;

  AuthUser? _map(User? u) =>
      u == null ? null : AuthUser(id: u.id, email: u.email);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield currentUser;
    yield* _auth.onAuthStateChange.map((s) => _map(s.session?.user)).distinct();
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> sendEmailCode({
    required String email,
    required bool createUser,
  }) => _guard(
    () => _auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: createUser,
      emailRedirectTo: redirectUrl,
    ),
  );

  @override
  Future<void> verifyEmailCode({required String email, required String code}) =>
      _guard(
        () => _auth.verifyOTP(
          email: email.trim(),
          token: code,
          type: OtpType.email,
        ),
      );

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) => _guard(
    () => _auth.signInWithPassword(email: email.trim(), password: password),
  );

  @override
  Future<void> signInWithProvider(SocialProvider provider) => _guard(
    () => _auth.signInWithOAuth(
      provider == SocialProvider.apple
          ? OAuthProvider.apple
          : OAuthProvider.google,
      redirectTo: redirectUrl,
    ),
  );

  @override
  Future<void> signOut() => _guard(() => _auth.signOut());
}
