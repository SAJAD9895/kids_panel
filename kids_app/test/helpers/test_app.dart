import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/app/app.dart';
import 'package:kids_app/app/config/app_config.dart';
import 'package:kids_app/app/providers.dart';
import 'package:kids_app/core/clock/clock.dart';
import 'package:kids_app/core/gate/gate_controller.dart';
import 'package:kids_app/core/audio/sfx.dart';

import 'fake_media.dart';

import 'package:kids_app/features/media/data/media_data.dart';
import 'package:kids_app/core/audio/speech.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/features/play/data/play_data.dart';

/// "Today" in every test, so ages and the year chips are stable.
final testNow = DateTime(2026, 11, 18, 10);

/// Links the app asked to open outside (store pages, downloads), newest last.
final openedUrls = <Uri>[];

/// Always produces the gate challenge "five, two, eight".
class FixedRandom implements Random {
  FixedRandom([this.values = const [5, 2, 8]]);
  final List<int> values;
  var _i = 0;
  @override
  int nextInt(int max) => values[_i++ % values.length] % max;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

const phone = Size(390, 844);
const phoneLandscape = Size(844, 390);
const tablet = Size(1180, 820);
const desktop = Size(1440, 900);

/// Real fonts (and Material icons) in tests, so layout, overflow and screenshots match devices.
Future<void> loadAppFonts() async {
  for (final family in ['Fredoka', 'Nunito', 'Inter']) {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
    await loader.load();
  }
  final icons = File(
    '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final bytes = icons.readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  }
}

/// Pumps the whole app on the demo backend (no latency, fixed clock and gate).
Future<DemoBackend> pumpApp(
  WidgetTester tester, {
  Size size = tablet,
  DemoBackend? backend,
  AppConfig? config,
  MemorySessionStore? store,
  RecordingSpeechService? speech,
  RecordingSoundEffects? sounds,
  FakeMedia? media,
  MemoryMediaPositionStore? positions,
}) async {
  final players = media ?? FakeMedia();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final demo =
      backend ?? DemoBackend(latency: Duration.zero, clock: () => testNow);
  addTearDown(demo.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          config ?? const AppConfig(environment: AppEnvironment.dev),
        ),
        authRepositoryProvider.overrideWithValue(demo),
        onboardingRepositoryProvider.overrideWithValue(demo),
        childProfilesRepositoryProvider.overrideWithValue(demo),
        catalogRepositoryProvider.overrideWithValue(demo),
        progressRepositoryProvider.overrideWithValue(demo),
        activityContentRepositoryProvider.overrideWithValue(demo),
        playRepositoryProvider.overrideWithValue(demo),
        sessionStoreProvider.overrideWithValue(store ?? MemorySessionStore()),
        speechProvider.overrideWithValue(speech ?? RecordingSpeechService()),
        soundEffectsProvider.overrideWithValue(
          sounds ?? RecordingSoundEffects(),
        ),
        mediaRepositoryProvider.overrideWithValue(demo),
        mediaControlsRepositoryProvider.overrideWithValue(demo),
        rewardsRepositoryProvider.overrideWithValue(demo),
        parentReportsRepositoryProvider.overrideWithValue(demo),
        accountRepositoryProvider.overrideWithValue(demo),
        urlOpenerProvider.overrideWithValue((uri) async {
          openedUrls.add(uri);
          return true;
        }),
        mediaPositionStoreProvider.overrideWithValue(
          positions ?? MemoryMediaPositionStore(),
        ),
        videoBackendFactoryProvider.overrideWithValue(players.newVideo),
        audioBackendFactoryProvider.overrideWithValue(players.newAudio),
        timezoneProvider.overrideWithValue(() async => 'Europe/London'),
        clockProvider.overrideWithValue(() => testNow),
        gateRandomProvider.overrideWithValue(FixedRandom()),
      ],
      retry: (_, _) => null,
      child: const KidsLearningApp(),
    ),
  );
  await tester.pumpAndSettle();
  return demo;
}

/// Closes any reward celebration card ("Yay!"), e.g. after finishing a game that earned a
/// badge or reached a goal. Star-only banners go away by themselves while settling.
Future<int> dismissCelebrations(WidgetTester tester) async {
  await tester.pumpAndSettle();
  var n = 0;
  while (find.text('Yay!').evaluate().isNotEmpty && n < 10) {
    await tester.ensureVisible(find.text('Yay!').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yay!').last);
    await tester.pumpAndSettle();
    n++;
  }
  return n;
}

/// Taps the widget with this exact semantics label / text and settles.
Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle(); // finish any scroll before tapping
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> tapLabel(WidgetTester tester, String label) async {
  final f = find.bySemanticsLabel(label);
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle(); // finish any scroll before tapping
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}
