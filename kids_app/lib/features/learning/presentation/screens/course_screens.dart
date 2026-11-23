import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../kids_home/presentation/widgets/kids_shell.dart';
import '../../domain/catalog.dart';
import '../../domain/progress_rules.dart';
import '../learning_providers.dart';
import '../widgets/kid_widgets.dart';
import '../widgets/kids_content.dart';

/// Loads one course tree and shows not-found / error / loading the kid way.
class _WithTree extends ConsumerWidget {
  const _WithTree({required this.courseId, required this.builder});

  final String courseId;
  final List<Widget> Function(BuildContext context, KidsData d, CourseTree tree)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(courseTreeProvider(courseId));
    final title =
        tree.value?.course.title.of() ??
        ref.watch(catalogProvider).value?.course(courseId)?.title.of() ??
        '';
    return KidsContent(
      header: KidsTopBar(title: title),
      builder: (context, d) => switch (tree) {
        AsyncValue(:final value?) => builder(context, d, value),
        AsyncValue(:final error?) when error is NotFoundFailure => [
          KidsEmpty(
            title: "We couldn't find that course",
            action: KidsButton(
              label: 'Back home',
              icon: Icons.home_rounded,
              onPressed: () => context.go(Routes.kids),
            ),
          ),
        ],
        AsyncValue(hasError: true) => [
          const SizedBox(height: Space.s9),
          KidsErrorView(
            onRetry: () => ref.invalidate(courseTreeProvider(courseId)),
          ),
        ],
        _ => const [
          SizedBox(height: Space.s7),
          LoadingRegion(
            child: Skeleton(height: Sizes.kidsHeroH, radius: Radii.x2xl),
          ),
          SizedBox(height: Space.s8),
          ShelfSkeleton(),
        ],
      },
    );
  }
}

/// K09 Course details + lesson ("island") listing.
class CourseScreen extends StatelessWidget {
  const CourseScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context) => _WithTree(
    courseId: courseId,
    builder: (context, d, t) {
      final done = d.progress.completedStepIds;
      final status = ProgressRules.courseStatus(
        t,
        d.progress,
        hasPlus: d.hasPlus,
      );
      final lessonStates = ProgressRules.lessonStates(t, done);
      final next = ProgressRules.nextStep(t, done);
      final fraction = ProgressRules.courseFraction(t, done);
      final minutes = t.allSteps.fold<int>(
        0,
        (n, s) => n + (s.activity.minutes ?? 0),
      );
      final look = subjectLook(d.catalog.subject(t.course.subjectId)?.key);
      final narrow = WindowClass.of(context) == WindowClass.compact;
      final buttonLabel = switch (status.state) {
        ProgressState.completed => 'Play again',
        ProgressState.inProgress =>
          next == null ? 'Open' : 'Continue: Island ${next.lessonIndex + 1}',
        _ => 'Start',
      };
      return [
        const SizedBox(height: Space.s6),
        Container(
          padding: const EdgeInsets.all(Space.s7),
          decoration: BoxDecoration(
            color: look.palette.soft,
            borderRadius: BorderRadius.circular(Radii.x2xl),
          ),
          child: Row(
            children: [
              if (!narrow) ...[
                const CharacterArt(
                  Character.bolt,
                  size: Sizes.kidsBuddyTile + Space.s6,
                  mood: Mood.happy,
                ),
                const SizedBox(width: Space.s7),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.course.description.of(), style: KidsText.heading),
                    const SizedBox(height: Space.s4),
                    Wrap(
                      spacing: Space.s3,
                      runSpacing: Space.s3,
                      children: [
                        TypeChip(
                          icon: Icons.map_rounded,
                          label:
                              '${t.lessons.length} ${t.lessons.length == 1 ? 'island' : 'islands'}',
                          ink: look.palette.ink,
                        ),
                        if (minutes > 0)
                          TypeChip(
                            icon: Icons.schedule_rounded,
                            label: 'about $minutes min',
                            ink: look.palette.ink,
                          ),
                        if (t.course.together)
                          TypeChip(
                            icon: Icons.people_alt_rounded,
                            label: 'with a grown-up',
                            ink: look.palette.ink,
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.s5),
                    KidsButton(
                      label: buttonLabel,
                      icon: status.needsGrownUp
                          ? Icons.lock_rounded
                          : Icons.play_arrow_rounded,
                      size: KidsButtonSize.xl,
                      fill: look.palette.fill,
                      onPressed: () {
                        if (status.needsGrownUp) {
                          showAskGrownUpSheet(context);
                        } else if (t.lessons.isNotEmpty) {
                          final lesson = next?.lesson ?? t.lessons.first;
                          context.push(Routes.lesson(t.course.id, lesson.id));
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.s5),
              ProgressRing(
                value: fraction,
                label: '${(fraction * 100).round()}%',
                color: look.palette.fill,
                semanticLabel: '${(fraction * 100).round()} percent done',
              ),
            ],
          ),
        ),
        const ShelfTitle('Islands'),
        if (t.lessons.isEmpty)
          Text(
            'The islands are still being built.',
            style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
          )
        else
          Wrap(
            spacing: Space.s6,
            runSpacing: Space.s6,
            children: [
              for (var i = 0; i < t.lessons.length; i++)
                PopIn(
                  index: i,
                  child: _IslandCard(
                    courseId: t.course.id,
                    lesson: t.lessons[i],
                    number: i + 1,
                    status: NodeStatus(
                      lessonStates[i],
                      needsGrownUp: status.needsGrownUp,
                    ),
                    done: t.lessons[i].requiredSteps
                        .where((s) => done.contains(s.id))
                        .length,
                    palette: look.palette,
                  ),
                ),
            ],
          ),
      ];
    },
  );
}

class _IslandCard extends StatefulWidget {
  const _IslandCard({
    required this.courseId,
    required this.lesson,
    required this.number,
    required this.status,
    required this.done,
    required this.palette,
  });

  final String courseId;
  final Lesson lesson;
  final int number;
  final NodeStatus status;
  final int done;
  final SectionPalette palette;

  @override
  State<_IslandCard> createState() => _IslandCardState();
}

class _IslandCardState extends State<_IslandCard>
    with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(vsync: this, duration: Motion.slow);

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final locked = s.state == ProgressState.locked;
    final total = widget.lesson.requiredSteps.length;
    final title = widget.lesson.title.of();
    // "Island 2: d e f" → big "d e f" on the card
    final art = title.contains(':')
        ? title.split(':').last.trim()
        : '${widget.number}';
    final bg = switch (s.state) {
      ProgressState.completed => AppColors.kidsMeFill,
      ProgressState.locked => AppColors.kidsBgAlt,
      _ => widget.palette.soft,
    };
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(math.sin(_shake.value * math.pi * 6) * Space.s3, 0),
        child: child,
      ),
      child: SizedBox(
        width: Sizes.kidsCardW + Space.s9,
        child: CardTap(
          semanticLabel:
              '$title, ${locked
                  ? 'finish the island before first'
                  : s.state == ProgressState.completed
                  ? 'done'
                  : '${widget.done} of $total steps'}',
          selected:
              s.state == ProgressState.inProgress ||
              s.state == ProgressState.available,
          onPressed: () {
            if (locked) {
              final reduce =
                  MediaQuery.maybeDisableAnimationsOf(context) ?? false;
              if (!reduce) _shake.forward(from: 0);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text('Finish island ${widget.number - 1} first!'),
                  ),
                );
            } else if (s.needsGrownUp) {
              showAskGrownUpSheet(context);
            } else {
              context.push(Routes.lesson(widget.courseId, widget.lesson.id));
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: Sizes.kidsCardArtH * 0.85,
                color: bg,
                alignment: Alignment.center,
                child: locked
                    ? const Icon(
                        Icons.lock_outline_rounded,
                        size: Sizes.iconKids * 1.5,
                        color: AppColors.kidsInkMuted,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(Space.s4),
                        child: FittedBox(
                          child: Text(art, style: KidsText.display),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Island ${widget.number}',
                            style: KidsText.label,
                          ),
                        ),
                        StateBadge(s),
                      ],
                    ),
                    if (s.state == ProgressState.inProgress && total > 0) ...[
                      const SizedBox(height: Space.s4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.pill),
                        child: LinearProgressIndicator(
                          value: widget.done / total,
                          minHeight: Space.s3,
                          color: widget.palette.fill,
                          backgroundColor: AppColors.kidsLine,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// K10 Island: the steps as stepping stones on a winding trail, with Pip at the current one
/// and the island prize at the end.
class LessonScreen extends StatelessWidget {
  const LessonScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
  });

  final String courseId;
  final String lessonId;

  static IconData stepIcon(String type) => switch (type) {
    'knowledge_check' || 'review' => Icons.fact_check_rounded,
    'trace' => Icons.draw_rounded,
    'video' || 'intro' => Icons.tv_rounded,
    'song' => Icons.music_note_rounded,
    'story' => Icons.menu_book_rounded,
    _ => Icons.sports_esports_rounded,
  };

  static String stepWord(String type) => switch (type) {
    'knowledge_check' => 'Warm-up',
    'review' => 'Review',
    'trace' => 'Trace',
    'intro' || 'video' => 'Watch',
    'song' => 'Sing',
    'story' => 'Story',
    'collect' => 'Collect',
    _ => 'Play',
  };

  @override
  Widget build(BuildContext context) => _WithTree(
    courseId: courseId,
    builder: (context, d, t) {
      final index = t.lessons.indexWhere((l) => l.id == lessonId);
      if (index < 0) {
        return [
          KidsEmpty(
            title: "We couldn't find that island",
            action: KidsButton(
              label: 'Back to the course',
              onPressed: () => context.go(Routes.course(courseId)),
            ),
          ),
        ];
      }
      final lesson = t.lessons[index];
      final lessonState = ProgressRules.lessonStates(
        t,
        d.progress.completedStepIds,
      )[index];
      final steps = ProgressRules.stepStates(
        lesson,
        lessonState,
        d.progress.completedStepIds,
        hasPlus: d.hasPlus,
      );
      final doneCount = steps
          .where((s) => s.state == ProgressState.completed)
          .length;
      return [
        const SizedBox(height: Space.s5),
        Row(
          children: [
            Expanded(
              child: Text(
                lesson.title.of(),
                style: KidsText.heading,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TypeChip(
              icon: Icons.star_rounded,
              label: '$doneCount/${lesson.steps.length}',
              ink: AppColors.kidsListenInk,
              background: AppColors.kidsListenSoft,
            ),
          ],
        ),
        if (lessonState == ProgressState.locked) ...[
          KidsEmpty(
            title: 'Not yet!',
            message: 'Finish island $index first, then this one opens.',
            action: KidsButton(
              label: 'Back to the islands',
              icon: Icons.map_rounded,
              onPressed: () => context.go(Routes.course(courseId)),
            ),
          ),
        ] else if (lesson.steps.isEmpty)
          const KidsEmpty(title: 'This island is still being built')
        else ...[
          const SizedBox(height: Space.s6),
          _SteppingStones(
            courseId: courseId,
            lesson: lesson,
            steps: steps,
            hasPrize: lesson.hasPrize,
          ),
        ],
      ];
    },
  );
}

class _SteppingStones extends StatelessWidget {
  const _SteppingStones({
    required this.courseId,
    required this.lesson,
    required this.steps,
    required this.hasPrize,
  });

  final String courseId;
  final Lesson lesson;
  final List<NodeStatus> steps;
  final bool hasPrize;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final count = lesson.steps.length + (hasPrize ? 1 : 0);
      final wide = c.maxWidth >= Breakpoints.medium;
      // Wide: a wave from left to right. Narrow: a zig-zag going down.
      final node = Sizes.kidsNode;
      final height = wide
          ? Sizes.kidsHeroH * 1.6
          : count * (node + Space.s10) + Space.s8;
      Offset pos(int i) {
        if (wide) {
          final x = count == 1
              ? c.maxWidth / 2
              : node / 2 + (c.maxWidth - node) * i / (count - 1);
          final y =
              height * 0.55 -
              math.sin(i / math.max(1, count - 1) * math.pi * 1.2) *
                  height *
                  0.32;
          return Offset(x, y);
        }
        final x =
            c.maxWidth / 2 +
            (i.isEven ? -1 : 1) * math.min(c.maxWidth / 4, node);
        return Offset(x, node / 2 + Space.s5 + i * (node + Space.s10));
      }

      final points = [for (var i = 0; i < count; i++) pos(i)];
      final current = steps.indexWhere(
        (s) => s.state == ProgressState.inProgress,
      );
      return SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TrailPainter(
                  points,
                  doneUpTo: steps.lastIndexWhere(
                    (s) => s.state == ProgressState.completed,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < lesson.steps.length; i++)
              Positioned(
                left: points[i].dx - node / 2,
                top: points[i].dy - node / 2,
                child: PopIn(
                  index: i,
                  child: _StepNode(
                    courseId: courseId,
                    step: lesson.steps[i],
                    status: steps[i],
                    current: i == current,
                  ),
                ),
              ),
            if (hasPrize)
              Positioned(
                left: points.last.dx - node / 2,
                top: points.last.dy - node / 2,
                child: _PrizeNode(
                  open: steps.every((s) => s.state == ProgressState.completed),
                ),
              ),
            if (current >= 0)
              Positioned(
                left: points[current].dx - Sizes.tapKids / 2,
                top: points[current].dy - node / 2 - Sizes.tapKids - Space.s7,
                child: const _Bounce(
                  child: CharacterArt(
                    Character.pip,
                    size: Sizes.tapKids,
                    mood: Mood.happy,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(this.points, {required this.doneUpTo});

  final List<Offset> points;
  final int doneUpTo;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      path.quadraticBezierTo(a.dx, mid.dy, mid.dx, mid.dy);
      path.quadraticBezierTo(b.dx, mid.dy, b.dx, b.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.kidsSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = Space.s8
        ..strokeCap = StrokeCap.round,
    );
    // dotted centre line
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += Space.s5) {
        final t = m.getTangentForOffset(d);
        if (t == null) continue;
        canvas.drawCircle(
          t.position,
          Space.s2 - 1,
          Paint()..color = AppColors.kidsLearnFill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.points != points || old.doneUpTo != doneUpTo;
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.courseId,
    required this.step,
    required this.status,
    required this.current,
  });

  final String courseId;
  final LessonStep step;
  final NodeStatus status;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final locked = status.state == ProgressState.locked;
    final done = status.state == ProgressState.completed;
    final label =
        '${LessonScreen.stepWord(step.type)}: ${step.activity.title.of()}';
    final stateText = locked
        ? 'locked'
        : done
        ? 'done'
        : status.needsGrownUp
        ? 'ask a grown-up'
        : current
        ? 'play next'
        : 'open';
    return Semantics(
      container: true,
      button: true,
      label: '$label, $stateText',
      excludeSemantics: true,
      onTap: () => _open(context),
      child: GestureDetector(
        onTap: () => _open(context),
        child: SizedBox(
          width: Sizes.kidsNode,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: Motion.base,
                width: Sizes.kidsNode,
                height: Sizes.kidsNode,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: locked
                      ? AppColors.kidsBgAlt
                      : done
                      ? AppColors.kidsMeFill
                      : AppColors.kidsLearnFill,
                  border: locked
                      ? Border.all(
                          color: AppColors.kidsInkMuted,
                          width: Space.s1 + 1,
                        )
                      : current
                      ? Border.all(
                          color: AppColors.kidsSurface,
                          width: Space.s3,
                        )
                      : null,
                  boxShadow: [
                    if (current)
                      const BoxShadow(
                        color: AppColors.kidsLearnSoft,
                        spreadRadius: Space.s4,
                      ),
                    if (!locked) ...Shadows.kidRaised,
                  ],
                ),
                child: Icon(
                  locked
                      ? Icons.lock_outline_rounded
                      : status.needsGrownUp
                      ? Icons.lock_rounded
                      : done
                      ? Icons.check_rounded
                      : LessonScreen.stepIcon(step.type),
                  size: Sizes.iconKids + Space.s2,
                  color: locked ? AppColors.kidsInkMuted : AppColors.kidsInk,
                ),
              ),
              const SizedBox(height: Space.s3),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s4,
                  vertical: Space.s2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.kidsSurface,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: current
                      ? Border.all(color: AppColors.kidsInk, width: Space.s1)
                      : null,
                ),
                child: Text(
                  LessonScreen.stepWord(step.type),
                  style: KidsText.caption.copyWith(color: AppColors.kidsInk),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    if (status.state == ProgressState.locked) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Do the step before this one first!')),
        );
      return;
    }
    context.push(
      Uri(
        path: Routes.activity(step.activity.id),
        queryParameters: {'course': courseId, 'step': step.id},
      ).toString(),
    );
  }
}

class _PrizeNode extends StatelessWidget {
  const _PrizeNode({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: open
        ? 'Island prize, unlocked'
        : 'Island prize, finish every step to open it',
    child: ExcludeSemantics(
      child: SizedBox(
        width: Sizes.kidsNode,
        child: Column(
          children: [
            Container(
              width: Sizes.kidsNode,
              height: Sizes.kidsNode,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: open
                    ? AppColors.kidsListenFill
                    : AppColors.kidsListenSoft,
                border: open
                    ? null
                    : Border.all(
                        color: AppColors.kidsInkMuted,
                        width: Space.s1 + 1,
                      ),
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                size: Sizes.iconKids + Space.s2,
                color: AppColors.kidsInk,
              ),
            ),
            const SizedBox(height: Space.s3),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.s4,
                vertical: Space.s2,
              ),
              decoration: BoxDecoration(
                color: AppColors.kidsSurface,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Text(
                'Prize',
                style: KidsText.caption.copyWith(color: AppColors.kidsInk),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Gentle up-and-down bounce (stops with "reduce motion").
class _Bounce extends StatefulWidget {
  const _Bounce({required this.child});

  final Widget child;

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Motion.celebrate * 1.5,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -_c.value * Space.s3),
      child: child,
    ),
    child: ExcludeSemantics(child: widget.child),
  );
}

/// Activity details: art, what it is, how long, what it practises, and Play. Games aren't
/// built yet, so Play explains that; locked steps and Plus items explain themselves too.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({
    super.key,
    required this.activityId,
    this.courseId,
    this.stepId,
  });

  final String activityId;
  final String? courseId;
  final String? stepId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title =
        ref.watch(catalogProvider).value?.activity(activityId)?.title.of() ??
        '';
    final skills =
        ref.watch(activitySkillsProvider(activityId)).value ??
        const <SkillTag>[];
    final tree = courseId == null
        ? null
        : ref.watch(courseTreeProvider(courseId!)).value;
    return KidsContent(
      header: KidsTopBar(title: title),
      builder: (context, d) {
        final a = d.catalog.activity(activityId);
        if (a == null) {
          return [
            KidsEmpty(
              title: "We couldn't find that one",
              message: 'It may have gone away. Let’s find another!',
              action: KidsButton(
                label: 'Back home',
                icon: Icons.home_rounded,
                onPressed: () => context.go(Routes.kids),
              ),
            ),
          ];
        }
        // Step context (opened from an island): is this step open yet?
        var stepLocked = false;
        if (tree != null && stepId != null) {
          for (final (i, l) in tree.lessons.indexed) {
            final idx = l.steps.indexWhere((s) => s.id == stepId);
            if (idx >= 0) {
              final ls = ProgressRules.lessonStates(
                tree,
                d.progress.completedStepIds,
              )[i];
              stepLocked =
                  ProgressRules.stepStates(
                    l,
                    ls,
                    d.progress.completedStepIds,
                    hasPlus: d.hasPlus,
                  )[idx].state ==
                  ProgressState.locked;
            }
          }
        }
        final locked = d.locked(a);
        final palette = SectionPalette.forType(a.type);
        final wide = WindowClass.of(context).isAtLeastMedium;
        final played = d.progress.recent.any((r) => r.activityId == a.id);
        final art = Container(
          height: Sizes.kidsHeroH,
          decoration: BoxDecoration(
            color: palette.soft,
            borderRadius: BorderRadius.circular(Radii.x2xl),
          ),
          alignment: Alignment.center,
          child: Hero(
            tag: 'activity-${a.id}',
            child: ActivityArt(a, size: Sizes.kidsArtLg),
          ),
        );
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: Space.s3,
              runSpacing: Space.s3,
              children: [
                TypeChip(
                  icon: typeIcon(a.type),
                  label: typeLabel(a.type),
                  ink: palette.ink,
                  background: palette.soft,
                ),
                if (a.minutes != null)
                  TypeChip(
                    icon: Icons.schedule_rounded,
                    label: '${a.minutes} min',
                    ink: palette.ink,
                    background: palette.soft,
                  ),
                if (a.players == 2)
                  TypeChip(
                    icon: Icons.people_alt_rounded,
                    label: 'Play together',
                    ink: palette.ink,
                    background: palette.soft,
                  ),
                if (played)
                  const TypeChip(
                    icon: Icons.history_rounded,
                    label: 'Played before',
                    ink: AppColors.kidsSuccess,
                    background: AppColors.kidsMeSoft,
                  ),
              ],
            ),
            const SizedBox(height: Space.s5),
            if (a.description.of().isNotEmpty)
              Text(a.description.of(), style: KidsText.heading),
            if (skills.isNotEmpty) ...[
              const SizedBox(height: Space.s5),
              Text('You will practise', style: KidsText.caption),
              const SizedBox(height: Space.s3),
              Wrap(
                spacing: Space.s3,
                runSpacing: Space.s3,
                children: [
                  for (final s in skills)
                    TypeChip(
                      icon: Icons.lightbulb_rounded,
                      label: s.name.of(),
                      ink: AppColors.kidsLearnInk,
                      background: AppColors.kidsLearnSoft,
                    ),
                ],
              ),
            ],
            const SizedBox(height: Space.s7),
            KidsButton(
              label: stepLocked
                  ? 'Not yet'
                  : locked
                  ? 'Ask a grown-up'
                  : 'Play',
              icon: stepLocked || locked
                  ? Icons.lock_rounded
                  : Icons.play_arrow_rounded,
              size: KidsButtonSize.xl,
              fill: stepLocked ? AppColors.kidsSurface : palette.fill,
              onPressed: () {
                if (stepLocked) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Do the steps before this one first!'),
                      ),
                    );
                } else if (locked) {
                  showAskGrownUpSheet(context);
                } else {
                  // Videos, songs and stories open their own players; everything else the
                  // engine player (which shows "Almost ready!" for content it can't play).
                  context.push(
                    Uri(
                      path: switch (a.type) {
                        ActivityType.video => Routes.videoPlay(a.id),
                        ActivityType.song ||
                        ActivityType.audiobook => Routes.song(a.id),
                        ActivityType.story => Routes.story(a.id),
                        _ => Routes.play(a.id),
                      },
                      queryParameters: courseId == null && stepId == null
                          ? null
                          : {'course': ?courseId, 'step': ?stepId},
                    ).toString(),
                  );
                }
              },
            ),
          ],
        );
        return [
          const SizedBox(height: Space.s6),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: art),
                const SizedBox(width: Space.s8),
                Expanded(child: info),
              ],
            )
          else ...[
            art,
            const SizedBox(height: Space.s7),
            info,
          ],
        ];
      },
    );
  }
}
