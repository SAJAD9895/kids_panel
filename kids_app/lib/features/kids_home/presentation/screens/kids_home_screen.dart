import '../../../media/presentation/media_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../child_profiles/presentation/child_providers.dart';
import '../../../learning/domain/catalog.dart';
import '../../../learning/domain/progress.dart';
import '../../../learning/domain/progress_rules.dart';
import '../../../learning/presentation/learning_providers.dart';
import '../../../learning/presentation/widgets/kid_widgets.dart';
import '../../../rewards/domain/rewards.dart';
import '../../../rewards/presentation/rewards_providers.dart';
import '../../../rewards/presentation/widgets/reward_widgets.dart';
import '../../../learning/presentation/widgets/kids_content.dart';
import '../widgets/kids_shell.dart';

/// K07 Home: greeting, today's star goal, "Keep going", subjects, today's games, recently
/// played, and the treasures the child has earned. Everything comes from the database for the
/// selected child; nothing here is hard-coded content.
class KidsHomeScreen extends ConsumerWidget {
  const KidsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    final name = child?.nickname;
    // Today's goal as the server keeps it (a goal reached stays reached if a parent then
    // raises it); the progress data stands in while the summary loads.
    final today = child == null
        ? null
        : ref.watch(rewardsProvider(child.id)).value?.day;
    return KidsContent(
      header: KidsTopBar(
        title: name == null ? 'Hi there!' : 'Hi, $name!',
        showBack: false,
      ),
      builder: (context, d) {
        if (d.catalog.isEmpty) {
          return [
            const KidsEmpty(
              title: 'New games are on their way!',
              message: 'Bolt is still building games, songs and stories. Come back soon!',
            ),
          ];
        }
        final wide = WindowClass.of(context).isAtLeastExpanded;
        final recommended = Recommendations.forChild(
          d.catalog,
          d.progress,
          ageMonths: d.ageMonths,
          hasPlus: d.hasPlus,
        );
        final recent = [
          for (final r in d.progress.recent) ?d.catalog.activity(r.activityId),
        ].where((a) => !a.isMedia || d.canSee(a)).toList();
        final subjects = _subjectsWithContent(d.catalog);
        // Rows the content team curates for Home (Game room, Play together, …).
        final rows = [
          for (final c in d.catalog.collections)
            if (c.surface == 'home' && c.kind == 'row')
              (
                c,
                [
                  for (final id in c.activityIds)
                    if (d.catalog.activity(id) case final a?)
                      if (a.suitsAge(d.ageMonths)) a,
                ],
              ),
        ].where((r) => r.$2.isNotEmpty);
        return [
          const SizedBox(height: Space.s7),
          if (wide)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(flex: 3, child: _KeepGoing()),
                  const SizedBox(width: Space.s6),
                  if (d.progress.goals.enabled)
                    Expanded(
                      flex: 2,
                      child: _DailyGoal(
                        status:
                            today ??
                            GoalStatus(
                              target: d.progress.goals.dailyActivities,
                              progress: d.progress.starsToday,
                            ),
                      ),
                    ),
                ],
              ),
            )
          else ...[
            const _KeepGoing(),
            if (d.progress.goals.enabled) ...[
              const SizedBox(height: Space.s6),
              _DailyGoal(
                status:
                    today ??
                    GoalStatus(
                      target: d.progress.goals.dailyActivities,
                      progress: d.progress.starsToday,
                    ),
              ),
            ],
          ],
          ShelfTitle(
            'Explore',
            action: KidsIconButton(
              icon: Icons.grid_view_rounded,
              label: 'All subjects',
              onPressed: () => context.push(Routes.subjects),
            ),
          ),
          Shelf(
            children: [
              for (final s in subjects.take(8))
                SubjectBubble(
                  subject: s,
                  onPressed: () => context.push(Routes.subject(s.key)),
                ),
            ],
          ),
          if (recommended.isNotEmpty) ...[
            const ShelfTitle('Games for today'),
            Shelf(
              children: [
                for (final a in recommended)
                  ActivityCard(
                    activity: a,
                    locked: d.locked(a),
                    favorite: d.progress.favoriteIds.contains(a.id),
                  ),
              ],
            ),
          ],
          for (final (c, items) in rows) ...[
            ShelfTitle(c.title.of()),
            Shelf(
              children: [
                for (final a in items)
                  ActivityCard(
                    activity: a,
                    locked: d.locked(a),
                    favorite: d.progress.favoriteIds.contains(a.id),
                  ),
              ],
            ),
          ],
          const ShelfTitle('Played lately'),
          if (recent.isEmpty)
            Text(
              'Games you play will show up here.',
              style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
            )
          else
            Shelf(
              children: [
                for (final a in recent.take(8))
                  ActivityCard(
                    activity: a,
                    locked: d.locked(a),
                    favorite: d.progress.favoriteIds.contains(a.id),
                  ),
              ],
            ),
          const ShelfTitle('My treasures'),
          TreasuresRow(progress: d.progress, showMore: true),
        ];
      },
    );
  }

  /// Subjects that have something in them first, then the rest (they show "coming soon").
  static List<Subject> _subjectsWithContent(Catalog c) {
    final used = {
      ...c.activities.map((a) => a.subjectId),
      ...c.courses.map((x) => x.subjectId),
    };
    return [
      ...c.subjects.where((s) => used.contains(s.id)),
      ...c.subjects.where((s) => !used.contains(s.id)),
    ];
  }
}

/// "Keep going": the next step of the course the child is doing, else the first course of the
/// path for their age.
class _KeepGoing extends ConsumerWidget {
  const _KeepGoing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(kidsDataProvider).value;
    if (d == null) return const SizedBox.shrink();
    final enrolled = d.progress.enrollments
        .where((e) => !e.completed)
        .map((e) => e.courseId)
        .toList();
    final path = Recommendations.pathFor(d.catalog, d.ageMonths);
    final courseId =
        enrolled.firstOrNull ??
        path?.courseIds.firstOrNull ??
        d.catalog.courses.firstOrNull?.id;
    if (courseId == null) return const SizedBox.shrink();
    final t = ref.watch(courseTreeProvider(courseId)).value;
    if (t == null) {
      return Container(
        height: Sizes.kidsHeroH * 0.8,
        decoration: BoxDecoration(
          color: AppColors.kidsLearnSoft,
          borderRadius: BorderRadius.circular(Radii.x2xl),
        ),
      );
    }
    final next = ProgressRules.nextStep(t, d.progress.completedStepIds);
    final started =
        enrolled.contains(courseId) ||
        ProgressRules.courseState(t, d.progress) == ProgressState.inProgress;
    final fraction = ProgressRules.courseFraction(
      t,
      d.progress.completedStepIds,
    );
    final narrow = WindowClass.of(context) == WindowClass.compact;
    return Container(
      padding: const EdgeInsets.all(Space.s7),
      decoration: BoxDecoration(
        color: AppColors.kidsLearnSoft,
        borderRadius: BorderRadius.circular(Radii.x2xl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TypeChip(
                  icon: started
                      ? Icons.auto_stories_rounded
                      : Icons.flag_rounded,
                  label: started ? 'Keep going' : 'Start here',
                  ink: AppColors.kidsLearnInk,
                ),
                const SizedBox(height: Space.s4),
                Text(
                  t.course.title.of(),
                  style: KidsText.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (next != null) ...[
                  const SizedBox(height: Space.s2),
                  Text(
                    '${next.lesson.title.of()} · ${next.step.activity.title.of()}',
                    style: KidsText.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: Space.s5),
                KidsButton(
                  label: started ? 'Continue' : 'Start',
                  icon: Icons.play_arrow_rounded,
                  fill: AppColors.kidsLearnFill,
                  onPressed: () => context.push(
                    next == null
                        ? Routes.course(courseId)
                        : Routes.lesson(courseId, next.lesson.id),
                  ),
                ),
              ],
            ),
          ),
          if (!narrow) ...[
            const SizedBox(width: Space.s5),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProgressRing(
                  value: fraction,
                  label: '${(fraction * 100).round()}%',
                  semanticLabel:
                      '${(fraction * 100).round()} percent of the course done',
                ),
                const SizedBox(height: Space.s3),
                const CharacterArt(
                  Character.bolt,
                  size: Sizes.kidsBuddyTile,
                  mood: Mood.happy,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Today's goal (set by a grown-up; one star per different activity per day). Opens Rewards.
class _DailyGoal extends StatelessWidget {
  const _DailyGoal({required this.status});

  final GoalStatus status;

  @override
  Widget build(BuildContext context) {
    final stars = status.progress;
    final goal = status.target;
    final done = status.done;
    final shown = stars.clamp(0, goal);
    final left = goal - shown;
    // Up to 5 stars are drawn; bigger goals show a bar instead.
    final drawn = goal <= 5;
    return Semantics(
      container: true,
      button: true,
      label: done
          ? "Today's goal done: $stars stars. Open my rewards"
          : "Today's goal: $shown of $goal stars. Open my rewards",
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.kidsListenSoft,
          borderRadius: BorderRadius.circular(Radii.x2xl),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.x2xl),
            onTap: () => context.push(Routes.rewards),
            child: Padding(
              padding: const EdgeInsets.all(Space.s7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    done ? 'You did it today!' : "Today's stars",
                    style: KidsText.heading,
                  ),
                  const SizedBox(height: Space.s4),
                  if (drawn)
                    Wrap(
                      spacing: Space.s3,
                      children: [
                        for (var i = 0; i < goal; i++)
                          AnimatedScale(
                            scale: i < shown ? 1 : 0.85,
                            duration: Motion.slow,
                            curve: Motion.easeBounce,
                            child: Icon(
                              i < shown
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: Sizes.tapKids,
                              color: i < shown
                                  ? AppColors.kidsStar
                                  : AppColors.kidsListenInk,
                            ),
                          ),
                      ],
                    )
                  else
                    GoalBar(fraction: shown / goal, label: '$shown of $goal'),
                  const SizedBox(height: Space.s3),
                  Text(
                    done
                        ? 'Every star after this is a bonus.'
                        : 'Finish $left more ${left == 1 ? 'activity' : 'activities'} to fill the stars.',
                    style: KidsText.caption.copyWith(
                      color: AppColors.kidsListenInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Achievements preview: stars, stickers, badges (→ Me).
class TreasuresRow extends StatelessWidget {
  const TreasuresRow({
    super.key,
    required this.progress,
    this.showMore = false,
  });

  final ChildProgress progress;
  final bool showMore;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.s5,
    runSpacing: Space.s5,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _TreasureTile(
        icon: Icons.star_rounded,
        color: AppColors.kidsStar,
        value: progress.starsTotal,
        label: 'stars',
      ),
      _TreasureTile(
        icon: Icons.emoji_nature_rounded,
        color: AppColors.kidsPlayInk,
        value: progress.stickers,
        label: 'stickers',
      ),
      _TreasureTile(
        icon: Icons.workspace_premium_rounded,
        color: AppColors.kidsLearnInk,
        value: progress.badges.length,
        label: 'badges',
      ),
      if (showMore)
        KidsButton.soft(
          label: 'See all',
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: () => context.push(Routes.rewards),
        ),
    ],
  );
}

class _TreasureTile extends StatelessWidget {
  const _TreasureTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$value $label',
    child: ExcludeSemantics(
      child: Container(
        width: Sizes.kidsAlbumW * 0.75,
        padding: const EdgeInsets.symmetric(vertical: Space.s5),
        decoration: BoxDecoration(
          color: AppColors.kidsSurface,
          borderRadius: BorderRadius.circular(Radii.xl),
          boxShadow: Shadows.kidRaised,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: Sizes.iconKids + Space.s3),
            const SizedBox(height: Space.s2),
            Text('$value', style: KidsText.title),
            Text(
              label,
              style: KidsText.caption.copyWith(color: AppColors.kidsInk),
            ),
          ],
        ),
      ),
    ),
  );
}
