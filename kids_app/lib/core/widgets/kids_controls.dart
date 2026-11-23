import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Shared pressable surface for the kid controls: raised shadow, sinks 4 px when pressed,
/// 4 px focus ring, works with tap, mouse, Enter and Space (docs/design/components.md).
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.onPressed,
    required this.builder,
    required this.borderRadius,
    required this.semanticLabel,
    this.selected,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final Widget Function(BuildContext context, bool pressed) builder;
  final BorderRadius borderRadius;
  final String semanticLabel;
  final bool? selected;
  final String? tooltip;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool v) {
    if (_enabled && v != _pressed) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: Motion.instant,
          curve: Motion.easeStandard,
          transform: Matrix4.translationValues(0, _pressed ? Space.s2 : 0, 0),
          foregroundDecoration: _focused
              ? BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: Border.all(
                    color: AppColors.kidsFocus,
                    width: Space.s2,
                  ),
                )
              : null,
          child: Opacity(
            opacity: _enabled ? 1 : 0.5,
            child: widget.builder(context, _pressed),
          ),
        ),
      ),
    );
    child = Semantics(
      container: true,
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: child,
    );
    if (widget.tooltip != null) {
      child = Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }
}

enum KidsButtonSize { regular, xl }

/// The big pill button of the kid zone (`.kbtn`). Never smaller than `tap-kids` (64).
class KidsButton extends StatelessWidget {
  const KidsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.fill = AppColors.kidsPlayFill,
    this.size = KidsButtonSize.regular,
    this.busy = false,
    this.semanticLabel,
  });

  /// White button with a line border (`.kbtn.soft`).
  const KidsButton.soft({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.size = KidsButtonSize.regular,
    this.busy = false,
    this.semanticLabel,
  }) : fill = AppColors.kidsSurface;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color fill;
  final KidsButtonSize size;

  /// Shows a spinner in place of the icon and ignores taps; the label stays for screen readers.
  final bool busy;

  /// Screen-reader label when [label] is a symbol (e.g. "⌫").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final xl = size == KidsButtonSize.xl;
    final radius = BorderRadius.circular(Radii.pill);
    final textStyle = KidsText.label.copyWith(
      fontSize: xl ? KidsType.heading.size : null,
    );
    final iconSize = xl ? Sizes.iconKids : Sizes.iconLg;
    return _Pressable(
      onPressed: busy ? null : onPressed,
      borderRadius: radius,
      semanticLabel: semanticLabel ?? label,
      builder: (context, pressed) => Container(
        constraints: BoxConstraints(
          minHeight: xl ? Sizes.tapKidsXl : Sizes.tapKids,
          minWidth: Sizes.tapKids,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: xl ? Space.s10 - Space.s2 : Space.s8 - Space.s2,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: radius,
          border: fill == AppColors.kidsSurface
              ? Border.all(color: AppColors.kidsLine, width: 3)
              : null,
          boxShadow: pressed ? Shadows.kidPressed : Shadows.kidRaised,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox.square(
                dimension: iconSize,
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.kidsInk,
                ),
              )
            else if (icon != null)
              Icon(icon, size: iconSize, color: AppColors.kidsInk),
            if (busy || icon != null) const SizedBox(width: Space.s4),
            Flexible(
              child: Text(label, style: textStyle, textAlign: TextAlign.center),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: Space.s4),
              Icon(trailingIcon, size: iconSize, color: AppColors.kidsInk),
            ],
          ],
        ),
      ),
    );
  }
}

/// Round icon button (`.kicon`): back, close, hear. Needs a [label] for screen readers.
class KidsIconButton extends StatelessWidget {
  const KidsIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _Pressable(
    onPressed: onPressed,
    borderRadius: BorderRadius.circular(Radii.pill),
    semanticLabel: label,
    tooltip: label,
    builder: (context, pressed) => Container(
      width: Sizes.tapKids,
      height: Sizes.tapKids,
      decoration: BoxDecoration(
        color: AppColors.kidsSurface,
        shape: BoxShape.circle,
        boxShadow: pressed ? Shadows.kidPressed : Shadows.kidRaised,
      ),
      child: Icon(icon, size: Sizes.iconKids, color: AppColors.kidsInk),
    ),
  );
}

/// The "Grown-ups" pill in the corner of kid screens. Always leads to the parental gate.
class GrownUpsButton extends StatelessWidget {
  const GrownUpsButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _Pressable(
    onPressed: onPressed,
    borderRadius: BorderRadius.circular(Radii.pill),
    semanticLabel: 'Grown-ups',
    builder: (context, pressed) => Container(
      height: Sizes.tapKids,
      padding: const EdgeInsets.symmetric(horizontal: Space.s6 - Space.s1),
      decoration: BoxDecoration(
        color: AppColors.kidsSurface,
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: pressed ? Shadows.kidPressed : Shadows.kidRaised,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: Sizes.iconLg,
            color: AppColors.kidsInk,
          ),
          const SizedBox(width: Space.s3),
          Text(
            'Grown-ups',
            style: KidsText.caption.copyWith(color: AppColors.kidsInk),
          ),
        ],
      ),
    ),
  );
}

/// Selectable pill (`.seg`), e.g. a month or a year. Selected = section fill + raised shadow.
class PillChoice extends StatelessWidget {
  const PillChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.semanticLabel,
    this.fill = AppColors.kidsMeFill,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final String? semanticLabel;
  final Color fill;

  @override
  Widget build(BuildContext context) => _Pressable(
    onPressed: onSelected,
    selected: selected,
    borderRadius: BorderRadius.circular(Radii.pill),
    semanticLabel: semanticLabel ?? label,
    builder: (context, pressed) => AnimatedContainer(
      duration: Motion.fast,
      constraints: const BoxConstraints(minHeight: Sizes.tapKidsSecondary),
      padding: const EdgeInsets.symmetric(horizontal: Space.s6 + Space.s1),
      decoration: BoxDecoration(
        color: selected ? fill : AppColors.kidsSurface,
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: selected ? Shadows.kidRaised : null,
      ),
      // A Row sizes to its text (an alignment would stretch the pill to the full width)
      // and centres it vertically in the 56 dp target.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: KidsText.body,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ),
        ],
      ),
    ),
  );
}

/// A tile that holds a buddy (or any art) and can be selected (K06, K35).
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    super.key,
    required this.child,
    required this.selected,
    required this.onPressed,
    required this.semanticLabel,
    this.size = Sizes.kidsBuddyTile,
    this.caption,
  });

  final Widget child;
  final bool selected;
  final VoidCallback onPressed;
  final String semanticLabel;
  final double size;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final tile = _Pressable(
      onPressed: onPressed,
      selected: selected,
      borderRadius: BorderRadius.circular(Radii.xl + Space.s4),
      semanticLabel: semanticLabel,
      builder: (context, pressed) => Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: Motion.fast,
            width: size,
            height: size,
            padding: const EdgeInsets.all(Space.s4),
            decoration: BoxDecoration(
              color: AppColors.kidsSurface,
              borderRadius: BorderRadius.circular(Radii.xl + Space.s4),
              border: Border.all(
                color: selected ? AppColors.kidsInk : AppColors.kidsSurface,
                width: Space.s2,
              ),
              boxShadow: pressed ? Shadows.kidPressed : Shadows.kidRaised,
            ),
            child: child,
          ),
          if (selected)
            Positioned(
              top: -Space.s4,
              right: -Space.s4,
              child: Container(
                width: Space.s9,
                height: Space.s9,
                decoration: const BoxDecoration(
                  color: AppColors.kidsSuccessFill,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.kidsInk,
                ),
              ),
            ),
        ],
      ),
    );
    if (caption == null) return tile;
    // The name sits outside the tile's semantics node (the tile already carries it as its
    // label), but tapping it still picks the tile.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        const SizedBox(height: Space.s4),
        GestureDetector(
          onTap: onPressed,
          excludeFromSemantics: true,
          child: ExcludeSemantics(
            child: SizedBox(
              width: size,
              child: Text(
                caption!,
                style: KidsText.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Progress dots (`.dots`): the current step is a wide pill.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Step ${index + 1} of $count',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: Motion.base,
              margin: const EdgeInsets.symmetric(horizontal: Space.s2),
              width: i == index ? Space.s8 : Space.s4,
              height: Space.s4,
              decoration: BoxDecoration(
                color: i == index ? AppColors.kidsInk : AppColors.kidsLine,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
        ],
      ),
    ),
  );
}

/// White rounded bubble with a short line from a character (`.sheet`).
class SpeechBubble extends StatelessWidget {
  const SpeechBubble(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Space.s7,
      vertical: Space.s5 - Space.s1,
    ),
    decoration: BoxDecoration(
      color: AppColors.kidsSurface,
      borderRadius: BorderRadius.circular(Radii.x2xl),
      boxShadow: Shadows.pop,
    ),
    child: Text(text, style: KidsText.label, textAlign: TextAlign.center),
  );
}

/// Small chip with an icon (`.tchip`), e.g. "Grown-up helps here".
class KidsTagChip extends StatelessWidget {
  const KidsTagChip({
    super.key,
    required this.icon,
    required this.label,
    this.ink = AppColors.kidsMeInk,
  });

  final IconData icon;
  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Space.s4,
      vertical: Space.s2,
    ),
    decoration: BoxDecoration(
      color: AppColors.kidsSurface,
      borderRadius: BorderRadius.circular(Radii.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: Sizes.iconMd, color: ink),
        const SizedBox(width: Space.s2 + Space.s1),
        Flexible(
          child: Text(label, style: KidsText.caption.copyWith(color: ink)),
        ),
      ],
    ),
  );
}
