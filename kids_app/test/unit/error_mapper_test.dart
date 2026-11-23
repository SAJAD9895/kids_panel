import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:kids_app/core/error/error_mapper.dart';
import 'package:kids_app/core/error/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Edge Function problem types map to failures', () {
    Failure f(int status, Object? details) =>
        mapError(FunctionException(status: status, details: details));
    expect(
      f(402, {'type': 'CHILD_LIMIT', 'status': 402}),
      isA<ChildLimitFailure>(),
    );
    expect(f(401, {'type': 'REAUTH_REQUIRED'}), isA<ReauthRequiredFailure>());
    expect(f(404, {'type': 'NOT_FOUND'}), isA<NotFoundFailure>());
    expect(
      f(400, {
        'type': 'VALIDATION',
        'detail': 'child must be between 1 and 12 years old',
      }),
      isA<ValidationFailure>().having(
        (v) => v.detail,
        'detail',
        contains('between 1 and 12'),
      ),
    );
    expect(f(500, 'oops'), isA<ServerFailure>());
    expect(f(429, null), isA<RateLimitedFailure>());
  });

  test('auth errors map to failures', () {
    expect(
      mapError(
        const AuthApiException(
          'expired',
          code: 'otp_expired',
          statusCode: '403',
        ),
      ),
      isA<InvalidCodeFailure>(),
    );
    expect(
      mapError(
        const AuthApiException(
          'bad',
          code: 'invalid_credentials',
          statusCode: '400',
        ),
      ),
      isA<InvalidCredentialsFailure>(),
    );
    expect(
      mapError(
        const AuthApiException(
          'slow down',
          code: 'over_email_send_rate_limit',
          statusCode: '429',
        ),
      ),
      isA<RateLimitedFailure>(),
    );
    expect(
      mapError(
        const AuthApiException(
          'no signups',
          code: 'otp_disabled',
          statusCode: '422',
        ),
      ),
      isA<AccountNotFoundFailure>(),
    );
  });

  test('network errors and unknowns', () {
    expect(mapError(ClientException('offline')), isA<NetworkFailure>());
    expect(mapError(StateError('?')), isA<ServerFailure>());
    expect(
      mapError(const ChildLimitFailure()),
      isA<ChildLimitFailure>(),
      reason: 'failures pass through',
    );
  });

  test('messages are for grown-ups and never leak internals', () {
    for (final f in const <Failure>[
      NetworkFailure(),
      ServerFailure(),
      ValidationFailure('SQL detail'),
      ChildLimitFailure(),
    ]) {
      expect(f.message, isNot(contains('SQL')));
      expect(f.message, isNot(contains('Exception')));
    }
  });
}
