import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../../core/widgets/kids_page.dart';
import '../onboarding_providers.dart';

/// Creates the family (account, consents, first child) in one server call, then the router
/// moves on to the Kids Area. On failure the parent can retry or go back and fix the details.
class FinishSetupScreen extends ConsumerStatefulWidget {
  const FinishSetupScreen({super.key});

  @override
  ConsumerState<FinishSetupScreen> createState() => _FinishSetupScreenState();
}

class _FinishSetupScreenState extends ConsumerState<FinishSetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(onboardingSubmitProvider.notifier).submit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(onboardingSubmitProvider);
    final error = submit.hasError ? submit.error : null;
    final message = error is Failure
        ? error.message
        : const ServerFailure().message;

    return KidsPage(
      orientation: OrientationPolicy.grownUps,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Space.s9),
            CharacterArt(
              Character.pip,
              mood: error == null ? Mood.happy : Mood.normal,
            ),
            const SizedBox(height: Space.s6),
            if (error == null)
              Semantics(
                liveRegion: true,
                child: Column(
                  children: [
                    Text(
                      'Getting everything ready…',
                      style: KidsText.title,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Space.s6),
                    const SizedBox(
                      width: Space.s12 * 2,
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
              )
            else ...[
              Text(
                "We couldn't finish setting up",
                style: KidsText.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.s4),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Space.s8),
              Wrap(
                spacing: Space.s5,
                runSpacing: Space.s5,
                alignment: WrapAlignment.center,
                children: [
                  KidsButton(
                    label: 'Try again',
                    icon: Icons.refresh_rounded,
                    fill: AppColors.kidsLearnFill,
                    onPressed: () =>
                        ref.read(onboardingSubmitProvider.notifier).submit(),
                  ),
                  KidsButton.soft(
                    label: 'Edit details',
                    onPressed: () {
                      // Consents are asked again after editing, so the router lets the parent go back.
                      ref
                          .read(consentChoicesProvider.notifier)
                          .update(const ConsentChoices());
                      context.go(Routes.setupChild);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
