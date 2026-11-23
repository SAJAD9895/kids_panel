import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/clock/clock.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../../core/widgets/kids_page.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../onboarding/presentation/onboarding_providers.dart';
import '../../domain/child_profile.dart';
import '../widgets/birth_month_picker.dart';

/// K05: the child's nickname and birth month. Used for the first child (F01, before sign-up:
/// nothing leaves the device yet) and for adding a child later (F13, from the Parents Area).
class ChildDetailsScreen extends ConsumerStatefulWidget {
  const ChildDetailsScreen({super.key, required this.flow});

  final ChildFlow flow;

  @override
  ConsumerState<ChildDetailsScreen> createState() => _ChildDetailsScreenState();
}

class _ChildDetailsScreenState extends ConsumerState<ChildDetailsScreen> {
  late final TextEditingController _name;
  int? _month;
  int? _year;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(childDraftProvider(widget.flow));
    _name = TextEditingController(text: draft.nickname);
    _month = draft.birthYearMonth?.month;
    _year = draft.birthYearMonth?.year;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  BirthYearMonth? get _birth => (_month != null && _year != null)
      ? BirthYearMonth(_year!, _month!)
      : null;

  String? get _nameError => validateNickname(_name.text)?.message;

  String? get _birthError {
    final b = _birth;
    if (b == null) return 'Pick the month and the year.';
    return b.validate(ref.read(clockProvider)())?.message;
  }

  void _next() {
    setState(() => _submitted = true);
    if (_nameError != null || _birthError != null) return;
    ref
        .read(childDraftProvider(widget.flow).notifier)
        .setDetails(_name.text, _birth!);
    context.go(
      widget.flow == ChildFlow.onboarding
          ? Routes.setupBuddy
          : Routes.newChildBuddy,
    );
  }

  void _back() => context.go(
    widget.flow == ChildFlow.onboarding ? Routes.welcome : Routes.children,
  );

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final wide = WindowClass.of(context).isAtLeastExpanded;
    final signedInDuringSetup =
        widget.flow == ChildFlow.onboarding &&
        ref.watch(currentUserIdProvider) != null;
    final birth = _birth;
    final ageHint = birth != null && birth.validate(now) == null
        ? ' (age ${birth.ageInYears(now)} → "${LearningStage.forAge(birth.ageInYears(now)).label}")'
        : '';

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            "What's your child's first name or nickname?",
            style: KidsText.heading,
          ),
        ),
        const SizedBox(height: Space.s4),
        TextField(
          controller: _name,
          maxLength: nicknameMaxLength,
          textCapitalization: TextCapitalization.words,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _next(),
          style: KidsText.title.copyWith(fontFamily: FontFamilies.kids),
          decoration: InputDecoration(
            hintText: 'Nickname',
            hintStyle: KidsText.title.copyWith(
              fontFamily: FontFamilies.kids,
              color: AppColors.kidsInkMuted,
            ),
            counterText: '',
            filled: true,
            fillColor: AppColors.kidsSurface,
            hoverColor: AppColors.kidsSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Space.s7,
              vertical: Space.s5,
            ),
            enabledBorder: _border(AppColors.kidsInkMuted),
            focusedBorder: _border(AppColors.kidsInk, Space.s2),
            errorBorder: _border(AppColors.uiDanger),
            focusedErrorBorder: _border(AppColors.uiDanger),
            errorText: _submitted ? _nameError : null,
            errorStyle: KidsText.caption.copyWith(color: AppColors.uiDanger),
          ),
        ),
        const SizedBox(height: Space.s3),
        Text(
          'Only shown in the app. No last names, please.',
          style: KidsText.caption,
        ),
        const SizedBox(height: Space.s8),
        Semantics(
          header: true,
          child: Text('Birthday month and year', style: KidsText.heading),
        ),
        const SizedBox(height: Space.s4),
        BirthMonthPicker(
          month: _month,
          year: _year,
          years: pickerYears(now),
          onMonth: (m) => setState(() => _month = m),
          onYear: (y) => setState(() => _year = y),
        ),
        const SizedBox(height: Space.s4),
        if (_submitted && _birthError != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _birthError!,
              style: KidsText.caption.copyWith(color: AppColors.uiDanger),
            ),
          )
        else
          Text(
            'We only keep the month and year, to pick the right activities$ageHint.',
            style: KidsText.caption,
          ),
        const SizedBox(height: Space.s8),
        KidsButton(
          label: 'Next',
          trailingIcon: Icons.arrow_forward_rounded,
          size: KidsButtonSize.xl,
          fill: AppColors.kidsMeFill,
          onPressed: _next,
        ),
      ],
    );

    return KidsPage(
      orientation: OrientationPolicy.grownUps,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!signedInDuringSetup) ...[
                KidsIconButton(
                  icon: Icons.arrow_back_rounded,
                  label: 'Back',
                  onPressed: _back,
                ),
                const SizedBox(width: Space.s6),
              ],
              const StepDots(count: 3, index: 0),
              const Spacer(),
              const Flexible(
                child: KidsTagChip(
                  icon: Icons.verified_user_outlined,
                  label: 'Grown-up helps here',
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s8),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: Sizes.uiSidebarW,
                  child: Column(
                    children: [
                      const CharacterArt(Character.pip, mood: Mood.happy),
                      const SizedBox(height: Space.s4),
                      SpeechBubble(
                        widget.flow == ChildFlow.onboarding
                            ? 'Nice to meet you!'
                            : 'A new friend!',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.s10),
                Expanded(child: form),
              ],
            )
          else
            form,
        ],
      ),
    );
  }

  static OutlineInputBorder _border(Color c, [double width = 3]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
        borderSide: BorderSide(color: c, width: width),
      );
}
