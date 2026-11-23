import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/gate/gate_controller.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/grown_up.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../../core/widgets/kids_page.dart';
import '../../../child_profiles/presentation/child_providers.dart';

/// K20: the grown-up check in front of the Parents Area. Tap the three numbers written as
/// words. Child-proofing, not security (docs/backend/authentication.md §7).
class ParentalGateScreen extends ConsumerWidget {
  const ParentalGateScreen({super.key, this.next});

  /// Where to go after the check. Only Parents Area paths are accepted.
  final String? next;

  String get _target {
    final n = next;
    if (n == null) return Routes.parents;
    final uri = Uri.tryParse(n);
    return uri != null &&
            !uri.hasScheme &&
            !uri.hasAuthority &&
            Routes.isParents(uri.path)
        ? n
        : Routes.parents;
  }

  void _close(BuildContext context, WidgetRef ref) => context.go(
    ref.read(selectedChildIdProvider) == null
        ? Routes.whoIsPlaying
        : Routes.kids,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(gateProvider);
    ref.listen(gateProvider.select((g) => g.unlockedUntil), (_, until) {
      if (until != null) context.go(_target);
    });
    final controller = ref.read(gateProvider.notifier);
    final wide = WindowClass.of(context).isAtLeastMedium;

    final prompt = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const GrownUpTag(label: 'Grown-ups only'),
        const SizedBox(height: Space.s5),
        Text('Tap these numbers:', style: KidsText.title),
        const SizedBox(height: Space.s3),
        Semantics(
          liveRegion: true,
          child: Text(
            gate.challenge.words,
            style: KidsText.display.copyWith(
              fontSize: Sizes.iconKids + Space.s3,
            ),
          ),
        ),
        const SizedBox(height: Space.s5),
        Semantics(
          label: '${gate.entered.length} of 3 numbers entered',
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: Space.s3),
                  Container(
                    width: Sizes.tapKids,
                    height: Sizes.tapKids,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i < gate.entered.length
                          ? AppColors.kidsMeFill
                          : AppColors.kidsSurface,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: i == gate.entered.length
                          ? Border.all(color: AppColors.kidsInkMuted, width: 3)
                          : null,
                    ),
                    child: Text(
                      i < gate.entered.length ? '${gate.entered[i]}' : '',
                      style: KidsText.title,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.s4),
        if (gate.lastAttemptFailed)
          Semantics(
            liveRegion: true,
            child: Text(
              'Not quite. Here are new numbers.',
              style: KidsText.caption.copyWith(color: AppColors.uiDanger),
            ),
          )
        else
          Text(
            'Written as words, so little ones can’t follow along.',
            style: KidsText.caption,
          ),
      ],
    );

    final keypad = _Keypad(
      onDigit: controller.tap,
      onBackspace: controller.backspace,
    );

    return CallbackShortcuts(
      bindings: {
        for (var d = 0; d <= 9; d++) ...{
          SingleActivator(
            LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + d),
          ): () =>
              controller.tap(d),
          SingleActivator(
            LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + d),
          ): () =>
              controller.tap(d),
        },
        const SingleActivator(LogicalKeyboardKey.backspace):
            controller.backspace,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _close(context, ref),
      },
      child: Focus(
        autofocus: true,
        child: KidsPage(
          background: AppColors.kidsBgAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KidsIconButton(
                icon: Icons.close_rounded,
                label: 'Close',
                onPressed: () => _close(context, ref),
              ),
              const SizedBox(height: Space.s6),
              Center(
                child: wide
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: prompt),
                          const SizedBox(width: Space.s12),
                          keypad,
                        ],
                      )
                    : Column(
                        children: [
                          prompt,
                          const SizedBox(height: Space.s8),
                          keypad,
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(int d) => _Key(label: '$d', onPressed: () => onDigit(d));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ]) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in row) ...[
                if (d != row.first) const SizedBox(width: Space.s4),
                key(d),
              ],
            ],
          ),
          const SizedBox(height: Space.s4),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: Sizes.tapKidsXl),
            const SizedBox(width: Space.s4),
            key(0),
            const SizedBox(width: Space.s4),
            _Key(label: '⌫', semanticLabel: 'Delete', onPressed: onBackspace),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.onPressed,
    this.semanticLabel,
  });

  final String label;
  final String? semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: Sizes.tapKidsXl,
    child: KidsButton(
      label: label,
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      fill: AppColors.kidsSurface,
    ),
  );
}
