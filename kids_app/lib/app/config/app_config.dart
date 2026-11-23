import 'dart:convert';

/// Which deployment the build talks to. Chosen at build time, never at runtime.
enum AppEnvironment { dev, prod }

/// Roles a client key must never carry.
const _serviceRole = 'service_role'; // secret-scan: allow
const _privilegedRoles = {_serviceRole, 'supabase_admin'};

/// Build-time configuration, read from `--dart-define-from-file=env/<env>.json`.
///
/// Only PUBLIC values belong here: the Supabase project URL and its publishable key.
/// The secret (service-role) key and the database URL must never reach the app;
/// [validate] refuses to start if one is passed by mistake.
class AppConfig {
  const AppConfig({
    required this.environment,
    this.supabaseUrl,
    this.supabasePublishableKey,
    this.authRedirectUrl,
    this.enableAppleSignIn = false,
    this.enableGoogleSignIn = false,
    this.termsUrl = 'https://example.com/terms',
    this.privacyUrl = 'https://example.com/privacy',
    this.policyVersion = '2026-11',
  });

  factory AppConfig.fromEnvironment() {
    String? read(String value) => value.trim().isEmpty ? null : value.trim();
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    return AppConfig(
      environment: env == 'prod' ? AppEnvironment.prod : AppEnvironment.dev,
      supabaseUrl: read(const String.fromEnvironment('SUPABASE_URL')),
      supabasePublishableKey: read(
        const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      ),
      authRedirectUrl: read(const String.fromEnvironment('AUTH_REDIRECT_URL')),
      enableAppleSignIn: const bool.fromEnvironment('ENABLE_APPLE_SIGN_IN'),
      enableGoogleSignIn: const bool.fromEnvironment('ENABLE_GOOGLE_SIGN_IN'),
      termsUrl:
          read(const String.fromEnvironment('TERMS_URL')) ??
          'https://example.com/terms',
      privacyUrl:
          read(const String.fromEnvironment('PRIVACY_URL')) ??
          'https://example.com/privacy',
      policyVersion:
          read(const String.fromEnvironment('POLICY_VERSION')) ?? '2026-11',
    );
  }

  final AppEnvironment environment;
  final String? supabaseUrl;
  final String? supabasePublishableKey;

  /// Where the magic link sends the parent back (deep link on mobile, the app URL on the web).
  final String? authRedirectUrl;
  final bool enableAppleSignIn;
  final bool enableGoogleSignIn;
  final String termsUrl;
  final String privacyUrl;

  /// Version of the terms / privacy policy the parent agrees to (parental_consents.policy_version).
  final String policyVersion;

  /// No backend configured in a dev build: the app runs on in-memory demo data.
  bool get isDemo => environment == AppEnvironment.dev && supabaseUrl == null;

  /// Problems that must stop the app from starting. Empty means the config is usable.
  List<String> validate() {
    final problems = <String>[];
    final url = supabaseUrl;
    final key = supabasePublishableKey;
    if (environment == AppEnvironment.prod && (url == null || key == null)) {
      problems.add(
        'A production build needs SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
      );
    }
    if ((url == null) != (key == null)) {
      problems.add(
        'Set both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, or neither (demo mode).',
      );
    }
    if (url != null) {
      final uri = Uri.tryParse(url);
      final local =
          uri != null &&
          (uri.host == 'localhost' ||
              uri.host == '127.0.0.1' ||
              uri.host == '10.0.2.2');
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        problems.add('SUPABASE_URL is not a valid URL.');
      } else if (uri.scheme != 'https' &&
          !(local && environment == AppEnvironment.dev)) {
        problems.add(
          'SUPABASE_URL must use https (http is allowed only for a local stack in dev).',
        );
      }
    }
    if (key != null && looksLikeSecretKey(key)) {
      problems.add(
        'SUPABASE_PUBLISHABLE_KEY is a secret (service-role) key. '
        'Never ship it in the app: use the publishable key from Project Settings › API Keys.',
      );
    }
    return problems;
  }

  /// True for Supabase secret keys (`sb_secret_…`) and legacy service-role JWTs.
  static bool looksLikeSecretKey(String key) {
    if (key.startsWith('sb_secret_')) return true;
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final role = (jsonDecode(payload) as Map<String, dynamic>)['role'];
      return _privilegedRoles.contains(role);
    } catch (_) {
      return false;
    }
  }
}
