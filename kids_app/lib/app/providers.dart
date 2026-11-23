import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:url_launcher/url_launcher.dart';

import '../features/parents/domain/parent_repositories.dart';
import '../features/rewards/domain/rewards_repository.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/child_profiles/domain/child_profiles_repository.dart';
import '../features/media/data/media_data.dart';
import '../features/media/domain/media_repositories.dart';
import '../features/media/presentation/media_urls.dart';
import '../features/media/presentation/players.dart';
import '../core/audio/sfx.dart';
import '../core/audio/speech.dart';
import '../features/learning/domain/learning_repositories.dart';
import '../features/play/domain/play_repositories.dart';
import '../features/onboarding/domain/onboarding_repository.dart';
import 'config/app_config.dart';

/// Infrastructure providers (keep-alive). [bootstrap] overrides them with the Supabase
/// implementations, or with the demo backend; tests override them with fakes.

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider is set in bootstrap'),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      throw UnimplementedError('authRepositoryProvider is set in bootstrap'),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => throw UnimplementedError(
    'onboardingRepositoryProvider is set in bootstrap',
  ),
);

final childProfilesRepositoryProvider = Provider<ChildProfilesRepository>(
  (ref) => throw UnimplementedError(
    'childProfilesRepositoryProvider is set in bootstrap',
  ),
);

/// The device's IANA timezone (e.g. `Europe/London`), sent once at onboarding.
final timezoneProvider = Provider<Future<String> Function()>(
  (ref) =>
      () async => 'Etc/UTC',
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) =>
      throw UnimplementedError('catalogRepositoryProvider is set in bootstrap'),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => throw UnimplementedError(
    'progressRepositoryProvider is set in bootstrap',
  ),
);

final activityContentRepositoryProvider = Provider<ActivityContentRepository>(
  (ref) => throw UnimplementedError(
    'activityContentRepositoryProvider is set in bootstrap',
  ),
);

final playRepositoryProvider = Provider<PlayRepository>(
  (ref) =>
      throw UnimplementedError('playRepositoryProvider is set in bootstrap'),
);

/// Snapshots of unfinished runs and the outbox of unsent sessions (device storage).
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => throw UnimplementedError('sessionStoreProvider is set in bootstrap'),
);

/// Media (Phase 11): launch + heartbeat, the parent's controls, positions on the device,
/// thumbnail URLs, and the players (overridable in tests).
final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) =>
      throw UnimplementedError('mediaRepositoryProvider is set in bootstrap'),
);

/// Parent dashboard and reports (GET /progress/overview, GET /progress/report).
final parentReportsRepositoryProvider = Provider<ParentReportsRepository>(
  (ref) => throw UnimplementedError(
    'parentReportsRepositoryProvider is set in bootstrap',
  ),
);

/// Notifications, preferences, consents, subscription, exports, account deletion.
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) =>
      throw UnimplementedError('accountRepositoryProvider is set in bootstrap'),
);

/// Opens a link outside the app (store subscription pages, export downloads). Tests replace it.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Stars, badges, goals, streak (GET /children/:id/rewards) and the parent's goals.
final rewardsRepositoryProvider = Provider<RewardsRepository>(
  (ref) =>
      throw UnimplementedError('rewardsRepositoryProvider is set in bootstrap'),
);

final mediaControlsRepositoryProvider = Provider<MediaControlsRepository>(
  (ref) => throw UnimplementedError(
    'mediaControlsRepositoryProvider is set in bootstrap',
  ),
);

final mediaPositionStoreProvider = Provider<MediaPositionStore>(
  (ref) => MemoryMediaPositionStore(),
);

final mediaUrlsProvider = Provider<MediaUrls>((ref) => const AssetMediaUrls());

final videoBackendFactoryProvider = Provider<VideoBackend Function()>(
  (ref) => VideoPlayerBackend.new,
);

final audioBackendFactoryProvider = Provider<AudioBackend Function()>(
  (ref) => JustAudioBackend.new,
);

/// Game sound effects (silent by default; the app overrides it in bootstrap).
final soundEffectsProvider = Provider<SoundEffects>(
  (ref) => RecordingSoundEffects(),
);

/// The app's voice (text-to-speech).
final speechProvider = Provider<SpeechService>(
  (ref) => RecordingSpeechService(),
);
