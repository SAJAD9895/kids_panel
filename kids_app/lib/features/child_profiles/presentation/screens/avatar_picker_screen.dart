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
import '../../../../core/widgets/state_views.dart';
import '../../../onboarding/presentation/onboarding_providers.dart';
import '../child_providers.dart';

/// K06: pick a buddy.
///  - `.step`: a step of a flow. Onboarding goes on to the grown-up step; adding a child
///    creates the child here (POST /children).
///  - `.pick`: change the buddy of an existing child; pops with the chosen avatar id.
class AvatarPickerScreen extends ConsumerStatefulWidget {
  const AvatarPickerScreen.step({super.key, required ChildFlow this.flow})
    : selectedId = null;

  const AvatarPickerScreen.pick({super.key, this.selectedId}) : flow = null;

  final ChildFlow? flow;
  final String? selectedId;

  @override
  ConsumerState<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends ConsumerState<AvatarPickerScreen> {
  String? _selected;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final flow = widget.flow;
    _selected = flow == null
        ? widget.selectedId
        : ref.read(childDraftProvider(flow)).avatarId;
  }

  Future<void> _confirm() async {
    final flow = widget.flow;
    if (flow == null) {
      context.pop(_selected);
      return;
    }
    final draft = ref.read(childDraftProvider(flow).notifier);
    if (_selected != null) draft.setAvatar(_selected!);
    if (flow == ChildFlow.onboarding) {
      context.go(Routes.setupGrownUp);
      return;
    }
    // Adding a child from the Parents Area: create it now.
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final details = ref.read(childDraftProvider(flow)).toDetails();
      await ref.read(childrenProvider.notifier).add(details);
      draft.reset();
      if (!mounted) return;
      context.go(Routes.children);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${details.nickname} was added.')),
        );
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (f is ChildLimitFailure) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No room for another profile'),
            content: Text(f.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(f.message)));
      }
    }
  }

  void _back() {
    final flow = widget.flow;
    if (flow == null) {
      context.pop();
    } else {
      context.go(
        flow == ChildFlow.onboarding ? Routes.setupChild : Routes.newChild,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatars = ref.watch(avatarsProvider);
    final flow = widget.flow;
    final name = flow == null
        ? null
        : ref.watch(childDraftProvider(flow)).nickname;
    final list = avatars.value;
    // Preselect the first buddy so the flow stays short (F01 tap budget).
    if (_selected == null && list != null && list.isNotEmpty && flow != null) {
      _selected = list.first.id;
    }
    final selectedAvatar = list?.where((a) => a.id == _selected).firstOrNull;
    final wide = WindowClass.of(context).isAtLeastExpanded;

    final grid = avatars.when(
      skipLoadingOnRefresh: false,
      loading: () => LoadingRegion(
        label: 'Loading buddies',
        child: Wrap(
          spacing: Space.s6,
          runSpacing: Space.s6,
          children: [
            for (var i = 0; i < 6; i++)
              const Skeleton(
                width: Sizes.kidsBuddyTile,
                height: Sizes.kidsBuddyTile,
                radius: Radii.xl + Space.s4,
              ),
          ],
        ),
      ),
      error: (_, _) => KidsErrorView(
        compact: true,
        onRetry: () => ref.invalidate(avatarsProvider),
      ),
      data: (list) => list.isEmpty
          ? Text(
              'No buddies yet. You can pick one later.',
              style: KidsText.body,
            )
          : Wrap(
              spacing: Space.s6,
              runSpacing: Space.s6,
              children: [
                for (final a in list)
                  SelectableTile(
                    selected: a.id == _selected,
                    semanticLabel:
                        'Buddy ${buddyNames[a.artIndex % buddyCount]}',
                    onPressed: () => setState(() => _selected = a.id),
                    child: BuddyArt(a.artIndex),
                  ),
              ],
            ),
    );

    final preview = Container(
      width: wide ? Sizes.uiSidebarW + Space.s9 : double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: Space.s8,
        horizontal: Space.s6,
      ),
      decoration: BoxDecoration(
        color: AppColors.kidsMeSoft,
        borderRadius: BorderRadius.circular(Radii.x2xl + Space.s5),
      ),
      child: Column(
        children: [
          BuddyArt(
            selectedAvatar?.artIndex ?? 0,
            size: wide ? Sizes.kidsArtLg : Sizes.kidsBuddyTile,
          ),
          if (name != null && name.isNotEmpty) ...[
            const SizedBox(height: Space.s4),
            Text(
              name,
              style: KidsText.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (selectedAvatar != null)
            Text(
              buddyNames[selectedAvatar.artIndex % buddyCount],
              style: KidsText.caption,
            ),
        ],
      ),
    );

    final canConfirm =
        !_busy && (list != null && (list.isEmpty || _selected != null));
    final buttonLabel = switch (flow) {
      null => 'Use this buddy',
      ChildFlow.onboarding => "That's me!",
      ChildFlow.addChild => 'Add ${name ?? 'child'}',
    };

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Pick your buddy!', style: KidsText.title),
        ),
        const SizedBox(height: Space.s7),
        grid,
        const SizedBox(height: Space.s8),
        KidsButton(
          label: buttonLabel,
          trailingIcon: Icons.celebration_rounded,
          size: KidsButtonSize.xl,
          fill: AppColors.kidsMeFill,
          busy: _busy,
          onPressed: canConfirm ? _confirm : null,
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
              KidsIconButton(
                icon: Icons.arrow_back_rounded,
                label: 'Back',
                onPressed: _busy ? null : _back,
              ),
              if (flow != null) ...[
                const SizedBox(width: Space.s6),
                const StepDots(count: 3, index: 1),
              ],
            ],
          ),
          const SizedBox(height: Space.s6),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                preview,
                const SizedBox(width: Space.s11 - Space.s3),
                Expanded(child: content),
              ],
            )
          else ...[
            preview,
            const SizedBox(height: Space.s7),
            content,
          ],
        ],
      ),
    );
  }
}
