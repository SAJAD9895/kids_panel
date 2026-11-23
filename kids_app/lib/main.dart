import 'app/bootstrap.dart';
import 'app/config/app_config.dart';

/// Run with an environment file (see docs/flutter/environments.md):
///   flutter run --dart-define-from-file=env/dev.json
/// Without one, a dev build starts in demo mode on in-memory data.
Future<void> main() => bootstrap(AppConfig.fromEnvironment());
