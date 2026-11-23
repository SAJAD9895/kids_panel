import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/characters.dart';
import '../layout/window_class.dart';
import '../theme/app_theme.dart';
import 'kids_controls.dart';

const _artBesideCard =
    Sizes.uiFormW +
    Sizes.uiSidebarW +
    Space.s8 +
    (Space.s11 - Space.s3) +
    Space.s9 * 2;

/// The grown-up zone (`.gzone`): a calm background, a character with a short line on wide
/// screens, and a white card holding the form. Forms for parents live here, never in kid UI.
class GrownUpZone extends StatelessWidget {
  const GrownUpZone({
    super.key,
    required this.child,
    this.character = Character.bolt,
    this.bubble,
    this.leading,
  });

  final Widget child;
  final Character character;
  final String? bubble;

  /// Optional control above the card (e.g. a back button).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    // The character sits beside the card only when both fit (phone landscape is 844 wide).
    final wide = MediaQuery.sizeOf(context).width >= _artBesideCard;
    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Sizes.uiFormW),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: wide ? Space.s9 : Space.s7,
          vertical: wide ? Space.s8 + Space.s2 : Space.s7,
        ),
        decoration: BoxDecoration(
          color: AppColors.uiBg,
          borderRadius: BorderRadius.circular(Radii.x2xl),
          boxShadow: Shadows.pop,
        ),
        child: child,
      ),
    );
    return ColoredBox(
      color: AppColors.kidsBgAlt,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(wide ? Space.s9 : Space.s5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(height: Space.s5),
                ],
                wide
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: Sizes.uiSidebarW + Space.s8,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (bubble != null) ...[
                                  SpeechBubble(bubble!),
                                  const SizedBox(height: Space.s5),
                                ],
                                CharacterArt(
                                  character,
                                  size: Sizes.kidsArtLg - Space.s6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Space.s11 - Space.s3),
                          Flexible(child: card),
                        ],
                      )
                    : card,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small uppercase label at the top of a grown-up card (`.gtag`).
class GrownUpTag extends StatelessWidget {
  const GrownUpTag({
    super.key,
    required this.label,
    this.icon = Icons.shield_outlined,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Space.s4 - Space.s1,
      vertical: Space.s2,
    ),
    decoration: BoxDecoration(
      color: AppColors.uiPrimarySoft,
      borderRadius: BorderRadius.circular(Radii.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: Sizes.iconSm, color: AppColors.uiOnPrimarySoft),
        const SizedBox(width: Space.s2 + Space.s1),
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: UiText.caption.copyWith(
              color: AppColors.uiOnPrimarySoft,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Busy-aware primary button for grown-up forms.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(Sizes.tapUi + Space.s2),
      ),
      child: busy
          ? Semantics(
              label: label,
              child: const SizedBox.square(
                dimension: Sizes.iconMd,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.uiOnPrimary,
                ),
              ),
            )
          : Text(label),
    ),
  );
}

/// Inline error message for grown-up forms (announced to screen readers).
class FormErrorText extends StatelessWidget {
  const FormErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(
        color: AppColors.uiDangerSoft,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: Sizes.iconMd,
            color: AppColors.uiDanger,
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Text(
              message,
              style: UiText.small.copyWith(color: AppColors.uiDanger),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A checkbox row whose whole label is tappable (consents on K03).
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget label;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: () => onChanged(!value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sizes.tapUi),
        child: Row(
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            const SizedBox(width: Space.s2),
            Expanded(
              child: DefaultTextStyle(
                style: UiText.small.copyWith(color: AppColors.uiText),
                child: label,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Six boxes for the email code (K04, P17). One real text field underneath, so paste,
/// one-time-code autofill and screen readers all work.
class CodeInput extends StatefulWidget {
  const CodeInput({
    super.key,
    required this.controller,
    this.onCompleted,
    this.hasError = false,
    this.autofocus = true,
  });

  static const length = 6;

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool autofocus;

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  void _changed() {
    setState(() {});
    final text = widget.controller.text;
    if (text.length == CodeInput.length) widget.onCompleted?.call(text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final current = text.length.clamp(0, CodeInput.length - 1);
    final boxes = Row(
      children: [
        for (var i = 0; i < CodeInput.length; i++) ...[
          if (i > 0) const SizedBox(width: Space.s3),
          Expanded(
            child: AspectRatio(
              aspectRatio: 0.86,
              child: AnimatedContainer(
                duration: Motion.fast,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.uiBg,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: widget.hasError
                        ? AppColors.uiDanger
                        : (_focus.hasFocus && i == current)
                        ? AppColors.uiFocus
                        : AppColors.uiBorderInput,
                    width: _focus.hasFocus && i == current ? 2 : 1,
                  ),
                ),
                child: Text(i < text.length ? text[i] : '', style: UiText.h1),
              ),
            ),
          ),
        ],
      ],
    );
    return GestureDetector(
      onTap: _focus.requestFocus,
      excludeFromSemantics:
          true, // the text field below carries the label and the actions
      child: Stack(
        children: [
          ExcludeSemantics(child: boxes),
          Positioned.fill(
            child: Opacity(
              opacity: 0.01,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(CodeInput.length),
                ],
                showCursor: false,
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centred content column with a readable max width, used by Parents Area screens.
class GrownUpPage extends StatelessWidget {
  const GrownUpPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final wide = WindowClass.of(context).isAtLeastMedium;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Sizes.uiFormW * 1.6),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? Space.s8 : Space.s6,
            vertical: Space.s7,
          ),
          children: children,
        ),
      ),
    );
  }
}
