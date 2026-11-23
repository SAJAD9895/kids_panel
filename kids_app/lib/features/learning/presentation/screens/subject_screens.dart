import '../../../media/presentation/media_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../kids_home/presentation/widgets/kids_shell.dart';
import '../../domain/catalog.dart';
import '../../domain/progress_rules.dart';
import '../learning_providers.dart';
import '../widgets/kid_widgets.dart';
import '../widgets/kids_content.dart';

/// K21 (explore part): every subject as a big bubble.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => KidsContent(
    header: const KidsTopBar(title: 'What shall we learn?'),
    builder: (context, d) {
      if (d.catalog.subjects.isEmpty) {
        return const [
          KidsEmpty(
            title: 'Nothing to explore yet',
            message: 'Bolt is still making new things to learn.',
          ),
        ];
      }
      return [
        const SizedBox(height: Space.s8),
        Wrap(
          spacing: Space.s7,
          runSpacing: Space.s7,
          children: [
            for (final (i, s) in d.catalog.subjects.indexed)
              PopIn(
                index: i,
                child: SubjectBubble(
                  subject: s,
                  onPressed: () => context.push(Routes.subject(s.key)),
                ),
              ),
          ],
        ),
      ];
    },
  );
}

enum _TypeFilter { all, games, videos, songs, stories }

/// K08: one subject. Its learning paths and courses first (the learning route), then all its
/// activities with type filters.
class SubjectScreen extends ConsumerStatefulWidget {
  const SubjectScreen({super.key, required this.subjectKey});

  final String subjectKey;

  @override
  ConsumerState<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends ConsumerState<SubjectScreen> {
  _TypeFilter _filter = _TypeFilter.all;

  bool _matches(ActivitySummary a) => switch (_filter) {
    _TypeFilter.all => true,
    _TypeFilter.games =>
      a.type == ActivityType.game || a.type == ActivityType.quiz,
    _TypeFilter.videos => a.type == ActivityType.video,
    _TypeFilter.songs => a.type == ActivityType.song,
    _TypeFilter.stories =>
      a.type == ActivityType.story || a.type == ActivityType.audiobook,
  };

  @override
  Widget build(BuildContext context) {
    final look = subjectLook(widget.subjectKey);
    final subject = ref
        .watch(catalogProvider)
        .value
        ?.subjectByKey(widget.subjectKey);
    return KidsContent(
      header: KidsTopBar(title: subject?.name.of() ?? ''),
      builder: (context, d) {
        final s = d.catalog.subjectByKey(widget.subjectKey);
        if (s == null) {
          return [
            KidsEmpty(
              title: "We couldn't find that",
              action: KidsButton(
                label: 'Back home',
                icon: Icons.home_rounded,
                onPressed: () => context.go(Routes.kids),
              ),
            ),
          ];
        }
        final courses = d.catalog.courses
            .where((c) => c.subjectId == s.id)
            .toList();
        final paths = d.catalog.paths
            .where(
              (p) => p.courseIds.any((id) => courses.any((c) => c.id == id)),
            )
            .toList();
        final activities = d.catalog.activities
            .where((a) => a.subjectId == s.id)
            // videos, songs, stories: the parent's switches and categories apply here too
            .where((a) => !a.isMedia || d.canSee(a))
            .toList();
        final shown = activities.where(_matches).toList();
        if (courses.isEmpty && activities.isEmpty) {
          return [
            const KidsEmpty(
              title: 'Coming soon!',
              message: 'Bolt is still making things for this one. Try another subject!',
            ),
          ];
        }
        return [
          const SizedBox(height: Space.s5),
          Container(
            height: Space.s3,
            decoration: BoxDecoration(
              color: look.palette.fill,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
          ),
          if (paths.isNotEmpty) ...[
            const ShelfTitle('Learning paths'),
            Shelf(children: [for (final p in paths) PathCard(path: p)]),
          ],
          if (courses.isNotEmpty) ...[
            const ShelfTitle('Courses'),
            CourseShelf(courseIds: [for (final c in courses) c.id]),
          ],
          if (activities.isNotEmpty) ...[
            const ShelfTitle('Play and explore'),
            Wrap(
              spacing: Space.s4,
              runSpacing: Space.s4,
              children: [
                for (final f in _TypeFilter.values)
                  PillChoice(
                    label: switch (f) {
                      _TypeFilter.all => 'All',
                      _TypeFilter.games => 'Games',
                      _TypeFilter.videos => 'Videos',
                      _TypeFilter.songs => 'Songs',
                      _TypeFilter.stories => 'Stories',
                    },
                    selected: _filter == f,
                    fill: look.palette.fill,
                    onSelected: () => setState(() => _filter = f),
                  ),
              ],
            ),
            const SizedBox(height: Space.s6),
            if (shown.isEmpty)
              Text(
                'None of these yet. Try "All".',
                style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
              )
            else
              Wrap(
                spacing: Space.s6,
                runSpacing: Space.s6,
                children: [
                  for (final (i, a) in shown.indexed)
                    PopIn(
                      index: i,
                      child: ActivityCard(
                        activity: a,
                        locked: d.locked(a),
                        favorite: d.progress.favoriteIds.contains(a.id),
                      ),
                    ),
                ],
              ),
          ],
        ];
      },
    );
  }
}

/// A learning path tile: title, description, number of courses.
class PathCard extends StatelessWidget {
  const PathCard({super.key, required this.path, this.recommended = false});

  final LearningPath path;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final title = path.title.of();
    return SizedBox(
      width: Sizes.kidsCardW + Space.s11,
      child: CardTap(
        semanticLabel:
            'Learning path $title${recommended ? ', just right for you' : ''}',
        color: AppColors.kidsMeSoft,
        onPressed: () => context.push(Routes.path(path.id)),
        child: Padding(
          padding: const EdgeInsets.all(Space.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.map_rounded,
                    color: AppColors.kidsMeInk,
                    size: Sizes.iconKids,
                  ),
                  const SizedBox(width: Space.s3),
                  if (recommended)
                    const Flexible(
                      child: TypeChip(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Just right for you',
                        ink: AppColors.kidsMeInk,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.s4),
              Text(
                title,
                style: KidsText.heading,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Space.s2),
              Text(
                path.description.of(),
                style: KidsText.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Space.s4),
              Text(
                '${path.courseIds.length} ${path.courseIds.length == 1 ? 'course' : 'courses'}',
                style: KidsText.caption.copyWith(color: AppColors.kidsMeInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Course cards with their live state (needs each course's tree, fetched in parallel).
class CourseShelf extends ConsumerWidget {
  const CourseShelf({super.key, required this.courseIds, this.grid = false});

  final List<String> courseIds;
  final bool grid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(kidsDataProvider).value;
    final trees = ref.watch(courseTreesProvider(courseIds.join(',')));
    return switch (trees) {
      AsyncValue(:final value?) when d != null => () {
        final cards = [
          for (final t in value)
            CourseCard(
              course: t.course,
              subjectKey: d.catalog.subject(t.course.subjectId)?.key,
              status: ProgressRules.courseStatus(
                t,
                d.progress,
                hasPlus: d.hasPlus,
              ),
              fraction: ProgressRules.courseFraction(
                t,
                d.progress.completedStepIds,
              ),
            ),
        ];
        return grid
            ? Wrap(
                spacing: Space.s6,
                runSpacing: Space.s6,
                children: [
                  for (final (i, c) in cards.indexed) PopIn(index: i, child: c),
                ],
              )
            : Shelf(children: cards);
      }(),
      AsyncValue(hasError: true) => KidsErrorRetry(
        onRetry: () => ref.invalidate(courseTreeProvider),
      ),
      _ => const ShelfSkeleton(count: 2),
    };
  }
}

/// Inline retry for one part of a page (the rest of the page keeps working).
class KidsErrorRetry extends StatelessWidget {
  const KidsErrorRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.cloud_off_rounded,
        color: AppColors.kidsInkMuted,
        size: Sizes.iconKids,
      ),
      const SizedBox(width: Space.s4),
      KidsButton.soft(
        label: 'Try again',
        icon: Icons.refresh_rounded,
        onPressed: onRetry,
      ),
    ],
  );
}
