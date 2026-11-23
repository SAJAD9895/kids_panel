import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/clock/clock.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/grown_up.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../onboarding/presentation/onboarding_providers.dart';
import '../../domain/child_profile.dart';
import '../child_providers.dart';
import '../widgets/birth_month_picker.dart';

/// P02: the family's child profiles. Add (K05 → K06), open one to edit or delete.
class ChildrenScreen extends ConsumerWidget {
  const ChildrenScreen({super.key});

  void _add(BuildContext context, WidgetRef ref) {
    ref.read(childDraftProvider(ChildFlow.addChild).notifier).reset();
    context.go(Routes.newChild);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    ref.watch(avatarsProvider);
    final now = ref.watch(clockProvider)();

    return OrientationScope(
      policy: OrientationPolicy.grownUps,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Children'),
          leading: BackButton(onPressed: () => context.go(Routes.parents)),
        ),
        floatingActionButton: (children.value?.isNotEmpty ?? false)
            ? FloatingActionButton.extended(
                onPressed: () => _add(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a child'),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: () => ref.read(childrenProvider.notifier).reload(),
          child: children.when(
            skipLoadingOnRefresh: true,
            loading: () => GrownUpPage(
              children: [
                LoadingRegion(
                  label: 'Loading children',
                  child: Column(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        const Skeleton(
                          height: Sizes.tapKids + Space.s5,
                          color: AppColors.uiBorder,
                        ),
                        const SizedBox(height: Space.s4),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            error: (e, _) => GrownUpErrorView(
              error: e,
              onRetry: () => ref.read(childrenProvider.notifier).reload(),
            ),
            data: (list) => list.isEmpty
                ? EmptyStateView(
                    title: 'No child profiles yet',
                    message: 'Add a profile for each child who plays. We only ask for a nickname and a birth month.',
                    action: FilledButton.icon(
                      onPressed: () => _add(context, ref),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add a child'),
                    ),
                  )
                : GrownUpPage(
                    children: [
                      for (final c in list) ...[
                        _ChildTile(child: c, now: now),
                        const SizedBox(height: Space.s4),
                      ],
                      const SizedBox(height: Space.s12),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ChildTile extends ConsumerWidget {
  const _ChildTile({required this.child, required this.now});

  final ChildProfile child;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final age = child.birthYearMonth.ageInYears(now);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minTileHeight: Sizes.tapKids + Space.s5,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.s5,
          vertical: Space.s2,
        ),
        leading: CircleAvatar(
          radius: Sizes.tapUi / 2 + Space.s2,
          backgroundColor: AppColors.kidsMeSoft,
          child: BuddyArt(
            ref.watch(buddyArtIndexProvider(child.avatarId)),
            size: Sizes.tapUi,
          ),
        ),
        title: Text(
          child.nickname,
          style: UiText.bodyStrong,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Born ${formatBirth(child.birthYearMonth)} · ${LearningStage.forAge(age).label}',
          style: UiText.small,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go(Routes.child(child.id)),
      ),
    );
  }
}
