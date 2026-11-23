import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'failure.dart';

/// Turns anything the Supabase SDK throws into a [Failure]. Data sources call this in `catch`,
/// so the presentation layer only ever sees [Failure]s.
Failure mapError(Object error) {
  if (error is Failure) return error;
  if (error is TimeoutException ||
      error is ClientException ||
      error is AuthRetryableFetchException) {
    return const NetworkFailure();
  }
  if (error is FunctionException) {
    return _fromProblem(error.status, error.details);
  }
  if (error is AuthException) return _fromAuth(error);
  if (error is PostgrestException) {
    if (error.code == 'PGRST301' || error.code == '401') {
      return const UnauthorizedFailure();
    }
    return const ServerFailure();
  }
  // dart:io SocketException isn't available on the web; match it by name.
  if (error.runtimeType.toString() == 'SocketException') {
    return const NetworkFailure();
  }
  return const ServerFailure();
}

/// Edge Function problem+json: `{type: "CHILD_LIMIT", status: 402, detail}` (api-design.md §4).
Failure _fromProblem(int status, Object? details) {
  final type = details is Map ? details['type'] as String? : null;
  final detail = details is Map ? details['detail'] as String? : null;
  switch (type) {
    case 'VALIDATION':
      return ValidationFailure(detail);
    case 'REAUTH_REQUIRED':
      return const ReauthRequiredFailure();
    case 'CHILD_LIMIT':
      return const ChildLimitFailure();
    case 'FORBIDDEN':
      return const ForbiddenFailure();
    case 'NOT_FOUND':
      return const NotFoundFailure();
    case 'UNAUTHORIZED':
      return const UnauthorizedFailure();
    case 'NEEDS_PLUS':
      return const ContentLockedFailure(LockReason.needsPlus);
    case 'AGE_NOT_SUITABLE':
      return const ContentLockedFailure(LockReason.ageNotSuitable);
    case 'SECTION_DISABLED':
      return const ContentLockedFailure(LockReason.sectionDisabled);
    case 'CATEGORY_BLOCKED':
      return const ContentLockedFailure(LockReason.categoryBlocked);
    case 'SCREEN_TIME_OVER':
      return const ContentLockedFailure(LockReason.screenTimeOver);
    case 'ACCOUNT_SUSPENDED':
      return const AccountSuspendedFailure();
  }
  return switch (status) {
    400 => ValidationFailure(detail),
    401 => const UnauthorizedFailure(),
    402 => const ChildLimitFailure(),
    403 => const ForbiddenFailure(),
    404 => const NotFoundFailure(),
    423 => const ContentLockedFailure(LockReason.sectionDisabled),
    429 => const RateLimitedFailure(),
    _ => const ServerFailure(),
  };
}

Failure _fromAuth(AuthException e) {
  switch (e.code) {
    case 'otp_expired':
      return const InvalidCodeFailure();
    case 'invalid_credentials':
      return const InvalidCredentialsFailure();
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return const RateLimitedFailure();
    case 'otp_disabled':
    case 'signup_disabled':
    case 'user_not_found':
      return const AccountNotFoundFailure();
    case 'session_not_found':
    case 'session_expired':
    case 'refresh_token_not_found':
    case 'refresh_token_already_used':
      return const UnauthorizedFailure();
    case 'validation_failed':
    case 'email_address_invalid':
      return const ValidationFailure();
  }
  if (e.statusCode == '429') return const RateLimitedFailure();
  return const ServerFailure();
}
