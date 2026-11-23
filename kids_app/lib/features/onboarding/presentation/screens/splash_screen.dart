import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_info.dart';
import '../../../../app/session.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../onboarding_providers.dart';

/// K01. Shown while the saved session is restored and the family is looked up. If the lookup
/// fails (offline), the grown-up gets a retry instead of an endless splash.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentUserIdProvider) != null;
    final family = ref.watch(familyStatusProvider);
    final failed = signedIn && family.hasError && !family.isLoading;

    return Scaffold(
      backgroundColor: AppColors.kidsBg,
      body: Stack(
        children: [
          const _Blob(
            color: AppColors.kidsListenSoft,
            size: Sizes.kidsArtLg * 2,
            left: -Space.s12,
            top: -Space.s12,
          ),
          const _Blob(
            color: AppColors.kidsLearnSoft,
            size: Sizes.kidsArtLg * 1.4,
            right: -Space.s9,
            bottom: -Space.s12,
          ),
          const _Blob(
            color: AppColors.kidsPlaySoft,
            size: Sizes.kidsArtLg * 0.7,
            right: Sizes.kidsArtLg,
            top: Space.s12 * 1.5,
          ),
          SafeArea(
            child: Center(
              child: failed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GrownUpErrorView(
                          error: family.error!,
                          onRetry: () => ref.invalidate(familyStatusProvider),
                        ),
                        TextButton(
                          onPressed: () => ref.read(sessionProvider).signOut(),
                          child: const Text('Sign out'),
                        ),
                      ],
                    )
                  : Semantics(
                      label: 'Loading $appName',
                      liveRegion: true,
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CharacterArt(Character.pip, mood: Mood.happy),
                            const SizedBox(height: Space.s6),
                            Text(
                              appName,
                              style: KidsText.display,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: Space.s6),
                            const SizedBox(
                              width: Space.s12,
                              child: LinearProgressIndicator(
                                minHeight: Space.s3,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(Radii.pill),
                                ),
                                color: AppColors.kidsInk,
                                backgroundColor: AppColors.kidsLine,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.color,
    required this.size,
    this.left,
    this.top,
    this.right,
    this.bottom,
  });

  final Color color;
  final double size;
  final double? left, top, right, bottom;

  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}
