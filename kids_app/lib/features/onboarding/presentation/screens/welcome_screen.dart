import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../../core/widgets/kids_page.dart';

/// K02. Two doors: set up a new family, or sign in to an existing one.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = WindowClass.of(context).isAtLeastExpanded;
    final art = Container(
      padding: const EdgeInsets.only(bottom: Space.s10),
      decoration: BoxDecoration(
        color: AppColors.kidsBgAlt,
        borderRadius: BorderRadius.circular(Radii.x2xl + Space.s5),
      ),
      alignment: Alignment.bottomCenter,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CharacterArt(Character.bolt, size: Sizes.kidsArtLg * 0.75),
            const CharacterArt(Character.pip, mood: Mood.happy),
            CharacterArt(Character.nova, size: Sizes.kidsArtLg * 0.75),
          ],
        ),
      ),
    );
    final text = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Learn, play and grow together!',
            style: wide ? KidsText.display : KidsText.title,
            textAlign: wide ? TextAlign.start : TextAlign.center,
          ),
        ),
        const SizedBox(height: Space.s5),
        Text(
          'Games, songs, stories and lessons for ages 2 to 8.',
          style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
          textAlign: wide ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: Space.s8),
        KidsButton(
          label: "Grown-ups: let's set up",
          icon: Icons.auto_awesome_rounded,
          size: KidsButtonSize.xl,
          onPressed: () => context.go(Routes.setupChild),
        ),
        const SizedBox(height: Space.s5),
        KidsButton.soft(
          label: 'I already have an account',
          onPressed: () => context.go(Routes.signIn),
        ),
      ],
    );

    return KidsPage(
      orientation: OrientationPolicy.grownUps,
      child: wide
          ? SizedBox(
              height: Sizes.kidsArtLg * 2.6,
              child: Row(
                children: [
                  Expanded(child: art),
                  const SizedBox(width: Space.s9),
                  Expanded(child: text),
                ],
              ),
            )
          : Column(
              children: [
                SizedBox(height: Sizes.kidsArtLg * 1.2, child: art),
                const SizedBox(height: Space.s8),
                text,
              ],
            ),
    );
  }
}
