import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/app/config/app_config.dart';

String jwt(Map<String, Object> payload) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc(payload)}.signature';
}

const serviceRole = 'service_role'; // secret-scan: allow

void main() {
  const url = 'https://abcdefgh.supabase.co';

  test('dev without a backend runs in demo mode', () {
    const c = AppConfig(environment: AppEnvironment.dev);
    expect(c.isDemo, isTrue);
    expect(c.validate(), isEmpty);
  });

  test('prod must have a backend', () {
    expect(
      const AppConfig(environment: AppEnvironment.prod).validate(),
      isNotEmpty,
    );
    expect(const AppConfig(environment: AppEnvironment.prod).isDemo, isFalse);
  });

  test('a publishable key is accepted', () {
    const c = AppConfig(
      environment: AppEnvironment.prod,
      supabaseUrl: url,
      supabasePublishableKey: 'sb_publishable_abc123',
    );
    expect(c.validate(), isEmpty);
    final legacyAnon = jwt({'role': 'anon', 'iss': 'supabase'});
    expect(
      AppConfig(
        environment: AppEnvironment.prod,
        supabaseUrl: url,
        supabasePublishableKey: legacyAnon,
      ).validate(),
      isEmpty,
    );
  });

  test('a secret or service-role key is refused', () {
    expect(AppConfig.looksLikeSecretKey('sb_secret_abc123'), isTrue);
    expect(AppConfig.looksLikeSecretKey(jwt({'role': serviceRole})), isTrue);
    expect(AppConfig.looksLikeSecretKey(jwt({'role': 'anon'})), isFalse);
    final c = AppConfig(
      environment: AppEnvironment.dev,
      supabaseUrl: url,
      supabasePublishableKey: jwt({'role': serviceRole}),
    );
    expect(c.validate().single, contains('secret'));
  });

  test('http only for a local stack in dev', () {
    const local = AppConfig(
      environment: AppEnvironment.dev,
      supabaseUrl: 'http://127.0.0.1:54321',
      supabasePublishableKey: 'k',
    );
    expect(local.validate(), isEmpty);
    const prodHttp = AppConfig(
      environment: AppEnvironment.prod,
      supabaseUrl: 'http://127.0.0.1:54321',
      supabasePublishableKey: 'k',
    );
    expect(prodHttp.validate(), isNotEmpty);
    const remoteHttp = AppConfig(
      environment: AppEnvironment.dev,
      supabaseUrl: 'http://abc.supabase.co',
      supabasePublishableKey: 'k',
    );
    expect(remoteHttp.validate(), isNotEmpty);
  });

  test('url and key come together', () {
    expect(
      const AppConfig(
        environment: AppEnvironment.dev,
        supabaseUrl: url,
      ).validate(),
      isNotEmpty,
    );
  });
}
