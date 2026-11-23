import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../../core/widgets/kids_page.dart';
import '../../../../core/widgets/state_views.dart';
import '../child_providers.dart';

/// K35 "Who's playing?". Big buddy tiles; no add button (adding a child is in the Parents
/// Area, behind the gate). With exactly one child it picks that child and moves on.
class WhoIsPlayingScreen extends ConsumerWidget {
  const WhoIsPlayingScreen({super.key});

  void _pick(BuildContext context, WidgetRef ref, String id) {
    ref.read(selectedChildIdProvider.notifier).select(id);
    context.go(Routes.kids);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    final selected = ref.watch(selectedChildIdProvider);
    ref.watch(avatarsProvider); // buddy art for each child

    final list = children.value;
    if (list != null &&
        list.length == 1 &&
        selected == null &&
        !children.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _pick(context, ref, list.single.id);
      });
    }

    return KidsPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text("Who's playing?", style: KidsText.title),
                ),
              ),
              GrownUpsButton(onPressed: () => context.go(Routes.parents)),
            ],
          ),
          const SizedBox(height: Space.s9),
          children.when(
            skipLoadingOnRefresh: false,
            loading: () => LoadingRegion(
              child: Wrap(
                spacing: Space.s8,
                runSpacing: Space.s8,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < 2; i++)
                    const Skeleton(
                      width: Sizes.kidsArtLg * 0.8,
                      height: Sizes.kidsArtLg,
                      radius: Radii.x2xl,
                    ),
                ],
              ),
            ),
            error: (_, _) => KidsErrorView(
              onRetry: () => ref.read(childrenProvider.notifier).reload(),
            ),
            data: (list) => list.isEmpty
                ? EmptyStateView(
                    kids: true,
                    title: 'Ask a grown-up to add a player',
                    message:
                        'Grown-ups can add a profile in the Grown-ups area.',
                    action: GrownUpsButton(
                      onPressed: () => context.go(Routes.parents),
                    ),
                  )
                : Wrap(
                    spacing: Space.s8,
                    runSpacing: Space.s8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final c in list.take(5))
                        SelectableTile(
                          size: Sizes.kidsArtLg * 0.8,
                          selected: c.id == selected,
                          semanticLabel: c.nickname,
                          caption: c.nickname,
                          onPressed: () => _pick(context, ref, c.id),
                          child: BuddyArt(
                            ref.watch(buddyArtIndexProvider(c.avatarId)),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
