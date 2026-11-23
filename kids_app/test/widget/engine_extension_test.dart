import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kids_app/app/app.dart';
import 'package:kids_app/app/config/app_config.dart';
import 'package:kids_app/app/providers.dart';
import 'package:kids_app/app/router/routes.dart';
import 'package:kids_app/core/audio/speech.dart';
import 'package:kids_app/core/clock/clock.dart';
import 'package:kids_app/core/gate/gate_controller.dart';
import 'package:kids_app/core/widgets/kids_controls.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/features/learning/domain/catalog.dart';
import 'package:kids_app/features/play/data/play_data.dart';
import 'package:kids_app/features/play/domain/item_spec.dart';
import 'package:kids_app/features/play/domain/play_repositories.dart';
import 'package:kids_app/features/play/domain/registry.dart';
import 'package:kids_app/features/play/domain/session_report.dart';
import 'package:kids_app/features/play/presentation/activity_player_screen.dart';
import 'package:kids_app/features/play/presentation/play_providers.dart';
import 'package:kids_app/features/play/presentation/views/item_views.dart';

import '../helpers/test_app.dart';

/// A brand-new activity type, written only here: "tap the drum N times".
class DrumSpec extends ItemSpec {
  const DrumSpec({
    required super.id,
    required super.prompt,
    required this.times,
  }) : super(kind: 'drum');
  final int times;
}

class DrumKind extends ActivityKind<DrumSpec> {
  const DrumKind();
  @override
  String get key => 'drum';
  @override
  DrumSpec parse(Map<String, dynamic> json, ParseContext ctx) => DrumSpec(
    id: ctx.itemId,
    prompt: Prompt.fromJson(json['prompt']),
    times: json['times'] as int,
  );
  @override
  Verdict evaluate(DrumSpec spec, ItemAnswer answer) =>
      answer is PickAnswer && answer.ids.length == spec.times
      ? const Verdict.right()
      : const Verdict.wrong();
}

class DrumView extends StatefulWidget {
  const DrumView({super.key, required this.ctx});
  final ItemViewContext ctx;
  @override
  State<DrumView> createState() => _DrumViewState();
}

class _DrumViewState extends State<DrumView> {
  final hits = <String>{};
  @override
  Widget build(BuildContext context) => KidsButton(
    label: 'Drum',
    onPressed: () {
      hits.add('${hits.length}');
      if (hits.length == (widget.ctx.spec as DrumSpec).times) {
        widget.ctx.submit(PickAnswer({...hits}));
      }
    },
  );
}

class _DrumContent implements ActivityContentRepository {
  @override
  Future<ActivitySource> load(String activityId) async => ActivitySource(
    activity: const ActivitySummary(
      id: 'drums',
      slug: 'drums',
      type: ActivityType.game,
      title: LocalizedText({'en': 'Drums'}),
    ),
    rawItems: const [
      {'kind': 'drum', 'times': 3, 'prompt': 'Tap three times'},
    ],
  );
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'a new activity type plays in the unchanged player, with progress reported',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.view.physicalSize = tablet;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
      final sent = <SessionReport>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(environment: AppEnvironment.dev),
            ),
            authRepositoryProvider.overrideWithValue(demo),
            onboardingRepositoryProvider.overrideWithValue(demo),
            childProfilesRepositoryProvider.overrideWithValue(demo),
            catalogRepositoryProvider.overrideWithValue(demo),
            progressRepositoryProvider.overrideWithValue(demo),
            activityContentRepositoryProvider.overrideWithValue(_DrumContent()),
            playRepositoryProvider.overrideWithValue(_Recorder(sent)),
            sessionStoreProvider.overrideWithValue(MemorySessionStore()),
            speechProvider.overrideWithValue(RecordingSpeechService()),
            clockProvider.overrideWithValue(() => testNow),
            gateRandomProvider.overrideWithValue(FixedRandom()),
            // the only two lines a new type needs:
            kindRegistryProvider.overrideWithValue(
              KindRegistry.standard()..register(const DrumKind()),
            ),
            itemViewRegistryProvider.overrideWithValue(
              ItemViewRegistry.standard()
                ..register('drum', (c, x) => DrumView(ctx: x)),
            ),
          ],
          retry: (_, _) => null,
          child: const KidsLearningApp(),
        ),
      );
      await tester.pumpAndSettle();
      await demo.signInWithPassword(
        email: 'alice@example.test',
        password: DemoBackend.alicePassword,
      );
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Mia');
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push(Routes.play('drums'));
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Play');
      for (var i = 0; i < 3; i++) {
        await tapLabel(tester, 'Drum');
      }
      expect(find.text('Great job!'), findsOneWidget);
      await tapLabel(tester, 'Finish');
      expect(find.text('You did it!'), findsOneWidget);
      expect(sent.map((r) => r.status), contains(SessionStatus.completed));
      expect(sent.last.items.single['k'], 'drum');
    },
  );
}

class _Recorder implements PlayRepository {
  _Recorder(this.sent);
  final List<SessionReport> sent;
  @override
  Future<List<SyncOutcome>> sync(List<SessionReport> reports) async {
    sent.addAll(reports);
    return [
      for (final r in reports)
        SyncOutcome(sessionId: r.sessionId, status: 'accepted'),
    ];
  }
}
