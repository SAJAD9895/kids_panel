import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../kids_home/presentation/widgets/kids_shell.dart';
import '../../domain/catalog.dart';
import '../../domain/progress_rules.dart';
import '../learning_providers.dart';
import '../widgets/kid_widgets.dart';
import '../widgets/kids_content.dart';
import 'subject_screens.dart';

/// Learn (rail): the path that suits the child's age, other paths, and courses by stage.
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => KidsContent(
    header: const KidsTopBar(title: 'Learn', showBack: false),
    builder: (context, d) {
      if (d.catalog.courses.isEmpty) {
        return const [
          KidsEmpty(
            title: 'Courses are coming soon!',
            message: 'Bolt is still writing the first lessons.',
          ),
        ];
      }
      final mine = Recommendations.pathFor(d.catalog, d.ageMonths);
      final others = d.catalog.paths.where((p) => p != mine).toList();
      return [
        if (mine != null) ...[
          const ShelfTitle('My path'),
          Shelf(
            children: [
              PathCard(path: mine, recommended: true),
              for (final p in others) PathCard(path: p),
            ],
          ),
        ],
        ShelfTitle(
          'Courses',
          action: KidsButton.soft(
            label: 'See all',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: () => context.push(Routes.courses),
          ),
        ),
        CourseShelf(courseIds: [for (final c in d.catalog.courses) c.id]),
      ];
    },
  );
}

/// Course listing: every course as a grid, optionally for one stage.
class CourseListScreen extends ConsumerStatefulWidget {
  const CourseListScreen({super.key});

  @override
  ConsumerState<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends ConsumerState<CourseListScreen> {
  Stage? _stage;

  static String _stageName(Stage s) => switch (s) {
    Stage.toddler => 'Tiny',
    Stage.preschool => 'Little',
    Stage.kindergarten => 'Big',
    Stage.grade1 => 'Star',
    Stage.grade2 => 'Super',
  };

  @override
  Widget build(BuildContext context) => KidsContent(
    header: const KidsTopBar(title: 'All courses'),
    builder: (context, d) {
      if (d.catalog.courses.isEmpty) {
        return const [KidsEmpty(title: 'Courses are coming soon!')];
      }
      final stages = Stage.values
          .where((s) => d.catalog.courses.any((c) => c.stage == s))
          .toList();
      final courses = d.catalog.courses
          .where((c) => _stage == null || c.stage == _stage)
          .toList();
      return [
        const SizedBox(height: Space.s6),
        Wrap(
          spacing: Space.s4,
          runSpacing: Space.s4,
          children: [
            PillChoice(
              label: 'All',
              selected: _stage == null,
              fill: AppColors.kidsLearnFill,
              onSelected: () => setState(() => _stage = null),
            ),
            for (final s in stages)
              PillChoice(
                label: _stageName(s),
                semanticLabel: '${_stageName(s)} explorers',
                selected: _stage == s,
                fill: AppColors.kidsLearnFill,
                onSelected: () => setState(() => _stage = s),
              ),
          ],
        ),
        const SizedBox(height: Space.s7),
        CourseShelf(courseIds: [for (final c in courses) c.id], grid: true),
      ];
    },
  );
}

/// A learning path: its courses in order, joined by a trail. Each course opens after the one
/// before it is done.
class LearningPathScreen extends ConsumerWidget {
  const LearningPathScreen({super.key, required this.pathId});

  final String pathId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title =
        ref.watch(catalogProvider).value?.path(pathId)?.title.of() ?? '';
    return KidsContent(
      header: KidsTopBar(title: title),
      builder: (context, d) {
        final path = d.catalog.path(pathId);
        if (path == null) {
          return [
            KidsEmpty(
              title: "We couldn't find that path",
              action: _homeButton(context),
            ),
          ];
        }
        if (path.courseIds.isEmpty) {
          return const [KidsEmpty(title: 'This path is still being built')];
        }
        final trees = ref.watch(courseTreesProvider(path.courseIds.join(',')));
        return [
          const SizedBox(height: Space.s4),
          Text(
            path.description.of(),
            style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
          ),
          const SizedBox(height: Space.s7),
          switch (trees) {
            AsyncValue(:final value?) => _PathTrail(trees: value, data: d),
            AsyncValue(hasError: true) => KidsErrorRetry(
              onRetry: () => ref.invalidate(courseTreeProvider),
            ),
            _ => const ShelfSkeleton(count: 2),
          },
        ];
      },
    );
  }
}

class _PathTrail extends StatelessWidget {
  const _PathTrail({required this.trees, required this.data});

  final List<CourseTree> trees;
  final KidsData data;

  @override
  Widget build(BuildContext context) {
    final states = ProgressRules.pathStates(
      trees,
      data.progress,
      hasPlus: data.hasPlus,
    );
    final wide = WindowClass.of(context).isAtLeastMedium;
    final children = <Widget>[];
    for (var i = 0; i < trees.length; i++) {
      if (i > 0) {
        children.add(
          _Trail(
            vertical: !wide,
            done: states[i - 1].state == ProgressState.completed,
          ),
        );
      }
      children.add(
        PopIn(
          index: i,
          child: CourseCard(
            course: trees[i].course,
            subjectKey: data.catalog.subject(trees[i].course.subjectId)?.key,
            status: states[i],
            fraction: ProgressRules.courseFraction(
              trees[i],
              data.progress.completedStepIds,
            ),
          ),
        ),
      );
    }
    children.add(
      _Trail(
        vertical: !wide,
        done: states.every((s) => s.state == ProgressState.completed),
      ),
    );
    children.add(
      Semantics(
        container: true,
        label: 'End of the path',
        child: const CharacterArt(
          Character.nova,
          size: Sizes.kidsBuddyTile,
          mood: Mood.happy,
        ),
      ),
    );
    return wide
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children,
            ),
          )
        : Column(children: children);
  }
}

/// Dotted trail between two path stops; solid when the stop before is done.
class _Trail extends StatelessWidget {
  const _Trail({required this.vertical, required this.done});

  final bool vertical;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.kidsSuccessFill : AppColors.kidsLine;
    final dots = [
      for (var i = 0; i < 4; i++)
        Container(
          width: Space.s4,
          height: Space.s4,
          margin: const EdgeInsets.all(Space.s2),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
    ];
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(Space.s3),
        child: vertical ? Column(children: dots) : Row(children: dots),
      ),
    );
  }
}

Widget _homeButton(BuildContext context) => KidsButton(
  label: 'Back home',
  icon: Icons.home_rounded,
  onPressed: () => context.go(Routes.kids),
);
