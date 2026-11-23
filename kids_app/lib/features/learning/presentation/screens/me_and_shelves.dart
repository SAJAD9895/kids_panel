import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../child_profiles/domain/child_profile.dart';
import '../../../child_profiles/presentation/child_providers.dart';
import '../../../kids_home/presentation/screens/kids_home_screen.dart';
import '../../../kids_home/presentation/widgets/kids_shell.dart';
import '../widgets/kid_widgets.dart';
import '../widgets/kids_content.dart';

/// K17 Me: the child's buddy and name, stage, treasures, badges, saved games, switch player.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    final count = ref.watch(childrenProvider).value?.length ?? 0;
    return KidsContent(
      header: const KidsTopBar(title: 'Me', showBack: false),
      builder: (context, d) {
        if (child == null) return const [];
        final age = child.birthYearMonth.ageInYears(DateTime.now());
        final wide = WindowClass.of(context).isAtLeastExpanded;
        final card = Container(
          padding: const EdgeInsets.all(Space.s8),
          decoration: BoxDecoration(
            color: AppColors.kidsMeSoft,
            borderRadius: BorderRadius.circular(Radii.x2xl + Space.s5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'my-buddy',
                child: BuddyArt(
                  ref.watch(buddyArtIndexProvider(child.avatarId)),
                  size: Sizes.kidsArtLg * 0.8,
                ),
              ),
              const SizedBox(height: Space.s5),
              Text(
                child.nickname,
                style: KidsText.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Space.s3),
              TypeChip(
                icon: Icons.explore_rounded,
                label: LearningStage.forAge(age).label,
                ink: AppColors.kidsMeInk,
              ),
              const SizedBox(height: Space.s6),
              KidsButton.soft(
                label: 'Change my buddy',
                icon: Icons.palette_rounded,
                onPressed: () => _changeBuddy(context, ref, child),
              ),
            ],
          ),
        );
        final favorites = [
          for (final id in d.progress.favoriteIds) ?d.catalog.activity(id),
        ];
        final side = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TreasuresRow(progress: d.progress),
            const SizedBox(height: Space.s5),
            KidsButton(
              label: 'My rewards',
              icon: Icons.emoji_events_rounded,
              fill: AppColors.kidsListenFill,
              onPressed: () => context.push(Routes.rewards),
            ),
            const ShelfTitle('My badges'),
            if (d.progress.badges.isEmpty)
              Text(
                'Finish an island to win your first badge!',
                style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
              )
            else
              Wrap(
                spacing: Space.s4,
                runSpacing: Space.s4,
                children: [
                  for (final b in d.progress.badges)
                    TypeChip(
                      icon: Icons.workspace_premium_rounded,
                      label: b.title,
                      ink: AppColors.kidsLearnInk,
                      background: AppColors.kidsLearnSoft,
                    ),
                ],
              ),
            const SizedBox(height: Space.s7),
            Wrap(
              spacing: Space.s5,
              runSpacing: Space.s5,
              children: [
                if (count > 1)
                  KidsButton.soft(
                    label: 'Switch player',
                    icon: Icons.people_alt_rounded,
                    onPressed: () => showPlayerSwitcher(context),
                  ),
              ],
            ),
          ],
        );
        return [
          const SizedBox(height: Space.s7),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: Sizes.kidsArtLg * 1.6, child: card),
                const SizedBox(width: Space.s8),
                Expanded(child: side),
              ],
            )
          else ...[
            card,
            const SizedBox(height: Space.s7),
            side,
          ],
          const ShelfTitle('Saved games'),
          if (favorites.isEmpty)
            Text(
              'Games you save will wait for you here.',
              style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
            )
          else
            Shelf(
              children: [
                for (final a in favorites)
                  ActivityCard(
                    activity: a,
                    locked: d.locked(a),
                    favorite: true,
                  ),
              ],
            ),
        ];
      },
    );
  }

  /// K06 in pick mode, then PATCH /children/:id with the new buddy.
  Future<void> _changeBuddy(
    BuildContext context,
    WidgetRef ref,
    ChildProfile child,
  ) async {
    final query = child.avatarId == null
        ? ''
        : '?selected=${Uri.encodeQueryComponent(child.avatarId!)}';
    final picked = await context.push<String>('${Routes.meBuddy}$query');
    if (picked == null || picked == child.avatarId) return;
    try {
      await ref
          .read(childrenProvider.notifier)
          .edit(
            child.id,
            ChildDetails(
              nickname: child.nickname,
              birthYearMonth: child.birthYearMonth,
              avatarId: picked,
            ),
          );
    } on Failure {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text("Your buddy didn't change. Try again!"),
            ),
          );
      }
    }
  }
}

/// Watch / Listen: the rows (collections) for that rail section.
class SectionShelvesScreen extends ConsumerWidget {
  const SectionShelvesScreen({
    super.key,
    required this.surface,
    required this.title,
  });

  /// `watch` or `listen`.
  final String surface;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) => KidsContent(
    header: KidsTopBar(title: title, showBack: false),
    builder: (context, d) {
      final rows = d.catalog.collections
          .where(
            (c) =>
                c.surface == surface &&
                d.ageMonths >= c.ageMinMonths &&
                d.ageMonths <= c.ageMaxMonths,
          )
          .toList();
      final shelves = [
        for (final c in rows)
          if (c.activityIds.map(d.catalog.activity).nonNulls.isNotEmpty) c,
      ];
      if (shelves.isEmpty) {
        return [
          KidsEmpty(
            title: 'Nothing here yet',
            message:
                'New ${surface == 'watch' ? 'shows' : 'songs and stories'} are on their way!',
          ),
        ];
      }
      return [
        for (final c in shelves) ...[
          ShelfTitle(c.title.of()),
          Shelf(
            children: [
              for (final a in c.activityIds.map(d.catalog.activity).nonNulls)
                ActivityCard(
                  activity: a,
                  locked: d.locked(a),
                  favorite: d.progress.favoriteIds.contains(a.id),
                ),
            ],
          ),
        ],
        const SizedBox(height: Space.s7),
        const Center(
          child: CharacterArt(
            Character.nova,
            size: Sizes.kidsBuddyTile,
            mood: Mood.happy,
          ),
        ),
      ];
    },
  );
}
