import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/rewards/presentation/widgets/celebration_host.dart';
import 'app_info.dart';
import 'router/app_router.dart';
import 'session.dart';

class KidsLearningApp extends ConsumerWidget {
  const KidsLearningApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionProvider); // resets session state when the parent changes
    return MaterialApp.router(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
      // New rewards are celebrated over the kid zone (docs/gamification/reward-system.md).
      builder: (context, child) =>
          CelebrationHost(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Shown instead of the app when the build configuration is unsafe or incomplete
/// (e.g. a secret key passed as the publishable key). Nothing is initialised.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.problems});

  final List<String> problems;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.s8),
          children: [
            Text('This build can’t start', style: UiText.h1),
            const SizedBox(height: Space.s5),
            for (final p in problems) ...[
              Text('• $p', style: UiText.body),
              const SizedBox(height: Space.s3),
            ],
            const SizedBox(height: Space.s5),
            Text('See docs/flutter/environments.md.', style: UiText.small),
          ],
        ),
      ),
    ),
  );
}
