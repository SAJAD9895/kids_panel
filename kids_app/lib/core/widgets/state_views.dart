import 'package:flutter/material.dart';

import '../art/characters.dart';
import '../error/failure.dart';
import '../theme/app_theme.dart';
import 'kids_controls.dart';

/// Loading, error and empty states shared by every screen (docs/design/states.md).
/// Loading uses skeletons that pulse, not spinners, so the layout doesn't jump.

/// A rounded placeholder block that gently pulses. Respects "reduce motion".
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = Space.s7,
    this.radius = Radii.lg,
    this.color = AppColors.kidsLine,
  });

  final double? width;
  final double height;
  final double radius;
  final Color color;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.slow * 3);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
    child: Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

/// Screen-reader friendly wrapper for a block of skeletons.
class LoadingRegion extends StatelessWidget {
  const LoadingRegion({super.key, required this.child, this.label = 'Loading'});

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    liveRegion: true,
    child: ExcludeSemantics(child: child),
  );
}

/// Kid-facing error: a character and a retry button. No error text, ever (02-flutter §2.5).
class KidsErrorView extends StatelessWidget {
  const KidsErrorView({super.key, required this.onRetry, this.compact = false});

  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CharacterArt(
          Character.bolt,
          size: compact ? Sizes.kidsBuddyTile : Sizes.kidsArtLg - Space.s9,
        ),
        const SizedBox(height: Space.s5),
        Text(
          "Oops! Let's try that again.",
          style: KidsText.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.s6),
        KidsButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
          fill: AppColors.kidsLearnFill,
        ),
      ],
    ),
  );
}

/// Grown-up error: the failure's message and a retry button.
class GrownUpErrorView extends StatelessWidget {
  const GrownUpErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is Failure
        ? (error as Failure).message
        : const ServerFailure().message;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: Space.s10,
              color: AppColors.uiTextMuted,
            ),
            const SizedBox(height: Space.s5),
            Text(message, style: UiText.body, textAlign: TextAlign.center),
            const SizedBox(height: Space.s5),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state: a character, a title, a line of help and an optional action.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    this.message,
    this.character = Character.pip,
    this.action,
    this.kids = false,
  });

  final String title;
  final String? message;
  final Character character;
  final Widget? action;

  /// Kid styling (Fredoka / Nunito) instead of the grown-up styles.
  final bool kids;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Space.s7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CharacterArt(
            character,
            size: kids ? Sizes.kidsArtLg - Space.s9 : Sizes.kidsBuddyTile,
            mood: Mood.happy,
          ),
          const SizedBox(height: Space.s5),
          Text(
            title,
            style: kids ? KidsText.heading : UiText.h2,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: Space.s3),
            Text(
              message!,
              style: kids
                  ? KidsText.body.copyWith(color: AppColors.kidsInkMuted)
                  : UiText.small,
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: Space.s6), action!],
        ],
      ),
    ),
  );
}
