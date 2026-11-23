import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../core/audio/sfx.dart';
import '../features/parents/data/supabase_parent_data.dart';
import '../features/rewards/data/supabase_rewards_repository.dart';
import '../features/media/data/media_data.dart';
import '../features/media/presentation/media_urls.dart';
import '../features/media/presentation/players.dart';
import '../core/audio/speech.dart';
import '../demo/demo_backend.dart';
import '../features/play/data/play_data.dart';
import '../features/auth/data/secure_session_storage.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/child_profiles/data/supabase_child_profiles_repository.dart';
import '../features/learning/data/supabase_learning_repositories.dart';
import '../features/onboarding/data/supabase_onboarding_repository.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'providers.dart';

/// Starts the app: validates the build config, connects to Supabase (or the demo backend)
/// and wires the repositories into Riverpod.
Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  // On the web, pages opened with push (course, island, activity) also update the address bar.
  GoRouter.optionURLReflectsImperativeAPIs = true;

  final problems = config.validate();
  if (problems.isNotEmpty) {
    runApp(ConfigErrorApp(problems: problems));
    return;
  }

  final overrides = [
    appConfigProvider.overrideWithValue(config),
    timezoneProvider.overrideWithValue(_deviceTimezone),
    sessionStoreProvider.overrideWithValue(
      PrefsSessionStore(await SharedPreferences.getInstance()),
    ),
    speechProvider.overrideWithValue(TtsSpeechService()),
    soundEffectsProvider.overrideWithValue(AudioSoundEffects()),
    mediaPositionStoreProvider.overrideWithValue(
      PrefsMediaPositionStore(await SharedPreferences.getInstance()),
    ),
    ...backendOverrides(config, config.isDemo ? null : await _connect(config)),
  ];
  await _initAudio();

  runApp(
    ProviderScope(
      overrides: overrides,
      // Repositories already map errors to Failures and screens offer "Try again";
      // automatic retries would only hide errors from the parent.
      retry: (_, _) => null,
      child: const KidsLearningApp(),
    ),
  );
}

Future<SupabaseClient> _connect(AppConfig config) async {
  final supabase = await Supabase.initialize(
    url: config.supabaseUrl!,
    publishableKey: config.supabasePublishableKey!,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      // Keychain / Keystore on mobile; the browser's storage on the web.
      localStorage: kIsWeb ? null : const SecureSessionStorage(),
    ),
  );
  return supabase.client;
}

/// Background audio (lock screen, notification) and audio focus (calls, other apps). Mobile
/// only; if it fails, songs still play while the app is open.
Future<void> _initAudio() async {
  if (kIsWeb) return;
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'app.kidslearning.audio',
      androidNotificationChannelName: 'Songs and stories',
      androidNotificationOngoing: true,
    );
    JustAudioBackend.backgroundReady = true;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (_) {
    JustAudioBackend.backgroundReady = false;
  }
}

/// Every repository, for the demo backend or Supabase. Public so a test can check that each
/// provider is wired in both modes.
List<Override> backendOverrides(AppConfig config, SupabaseClient? client) {
  if (client == null) {
    final demo = DemoBackend();
    return [
      authRepositoryProvider.overrideWithValue(demo),
      onboardingRepositoryProvider.overrideWithValue(demo),
      childProfilesRepositoryProvider.overrideWithValue(demo),
      catalogRepositoryProvider.overrideWithValue(demo),
      progressRepositoryProvider.overrideWithValue(demo),
      activityContentRepositoryProvider.overrideWithValue(demo),
      playRepositoryProvider.overrideWithValue(demo),
      mediaRepositoryProvider.overrideWithValue(demo),
      mediaControlsRepositoryProvider.overrideWithValue(demo),
      rewardsRepositoryProvider.overrideWithValue(demo),
      parentReportsRepositoryProvider.overrideWithValue(demo),
      accountRepositoryProvider.overrideWithValue(demo),
      mediaUrlsProvider.overrideWithValue(const AssetMediaUrls()),
    ];
  }
  final media = SupabaseMediaRepository(client);
  return [
    authRepositoryProvider.overrideWithValue(
      SupabaseAuthRepository(client.auth, redirectUrl: config.authRedirectUrl),
    ),
    onboardingRepositoryProvider.overrideWithValue(
      SupabaseOnboardingRepository(client),
    ),
    childProfilesRepositoryProvider.overrideWithValue(
      SupabaseChildProfilesRepository(client),
    ),
    catalogRepositoryProvider.overrideWithValue(
      SupabaseCatalogRepository(client),
    ),
    progressRepositoryProvider.overrideWithValue(
      SupabaseProgressRepository(client),
    ),
    // Phase 9's game content and session upload were missing here (found in Phase 11).
    activityContentRepositoryProvider.overrideWithValue(
      SupabaseActivityContentRepository(client),
    ),
    playRepositoryProvider.overrideWithValue(SupabasePlayRepository(client)),
    rewardsRepositoryProvider.overrideWithValue(
      SupabaseRewardsRepository(client),
    ),
    parentReportsRepositoryProvider.overrideWithValue(
      SupabaseParentReportsRepository(client),
    ),
    accountRepositoryProvider.overrideWithValue(
      SupabaseAccountRepository(client),
    ),
    mediaRepositoryProvider.overrideWithValue(media),
    mediaControlsRepositoryProvider.overrideWithValue(media),
    mediaUrlsProvider.overrideWithValue(PublicBucketUrls(config.supabaseUrl!)),
  ];
}

Future<String> _deviceTimezone() async {
  try {
    final tz = await FlutterTimezone.getLocalTimezone();
    final id = tz.identifier;
    return id.contains('/') || id == 'UTC' ? id : 'Etc/UTC';
  } catch (_) {
    return 'Etc/UTC';
  }
}
