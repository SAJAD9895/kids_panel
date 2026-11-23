/// Every error a repository can raise, as seen by the presentation layer
/// (docs/architecture/02-flutter-architecture.md §2.5).
///
/// [message] is written for grown-ups. Children never see error text: kid screens show
/// a friendly illustration and a retry button instead.
sealed class Failure implements Exception {
  const Failure();

  String get message;

  @override
  String toString() => '$runtimeType: $message';
}

final class NetworkFailure extends Failure {
  const NetworkFailure();
  @override
  String get message =>
      "We couldn't connect. Check the internet connection and try again.";
}

/// The session is missing or expired.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure();
  @override
  String get message => 'Please sign in again.';
}

/// A destructive action (deleting a child) needs a fresh sign-in code.
final class ReauthRequiredFailure extends Failure {
  const ReauthRequiredFailure();
  @override
  String get message => 'For your security, confirm with a new code first.';
}

/// The plan's child limit is reached (Basic: 1).
final class ChildLimitFailure extends Failure {
  const ChildLimitFailure();
  @override
  String get message =>
      "Your plan doesn't include more child profiles. Plus lets you add up to five.";
}

final class InvalidCodeFailure extends Failure {
  const InvalidCodeFailure();
  @override
  String get message =>
      "That code didn't match or has expired. Check the latest email or send a new code.";
}

final class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure();
  @override
  String get message => "That email and password don't match.";
}

final class RateLimitedFailure extends Failure {
  const RateLimitedFailure();
  @override
  String get message => 'Too many tries. Please wait a minute and try again.';
}

/// The account for that email doesn't exist (sign-in with a code, no sign-up).
final class AccountNotFoundFailure extends Failure {
  const AccountNotFoundFailure();
  @override
  String get message =>
      "We couldn't find an account with that email. Set up a new family instead?";
}

final class ValidationFailure extends Failure {
  const ValidationFailure([this.detail]);
  final String? detail;
  @override
  String get message =>
      "Some details weren't accepted. Check them and try again.";
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure();
  @override
  String get message => "We couldn't find that. It may have been removed.";
}

final class ForbiddenFailure extends Failure {
  const ForbiddenFailure();
  @override
  String get message => "This account can't do that.";
}

/// Support restricted the family's account (403 ACCOUNT_SUSPENDED, admin CMS): nothing can be
/// played or synced until it's lifted. Shown to grown-ups; children see the locked message.
final class AccountSuspendedFailure extends Failure {
  const AccountSuspendedFailure();
  @override
  String get message =>
      'This account is on hold. A grown-up can contact support to sort it out.';
}

final class ServerFailure extends Failure {
  const ServerFailure();
  @override
  String get message => 'Something went wrong on our side. Please try again.';
}

/// Why the server refused to open something (POST /play/launch, Phase 11).
enum LockReason {
  /// Plus content, family on Basic (402 NEEDS_PLUS).
  needsPlus,

  /// Outside the activity's age window (403 AGE_NOT_SUITABLE).
  ageNotSuitable,

  /// The parent switched the section (Watch / Listen) off (423 SECTION_DISABLED).
  sectionDisabled,

  /// The parent switched the category off (423 CATEGORY_BLOCKED).
  categoryBlocked,

  /// Today's watching / listening time is used up (423 SCREEN_TIME_OVER).
  screenTimeOver,
}

final class ContentLockedFailure extends Failure {
  const ContentLockedFailure(this.reason);
  final LockReason reason;
  @override
  String get message => switch (reason) {
    LockReason.needsPlus => 'Ask a grown-up to open this one.',
    LockReason.ageNotSuitable => 'This one is for a different age.',
    LockReason.sectionDisabled ||
    LockReason.categoryBlocked => 'A grown-up switched this off.',
    LockReason.screenTimeOver => "That's all for today!",
  };
}
