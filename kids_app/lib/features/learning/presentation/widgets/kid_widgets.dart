import '../../../media/presentation/widgets/media_thumb.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/catalog.dart';
import '../../domain/progress_rules.dart';

/// Colour family of a rail section (`kids-<section>-fill/soft/ink`).
class SectionPalette {
  const SectionPalette(this.fill, this.soft, this.ink);

  final Color fill;
  final Color soft;
  final Color ink;

  static const play = SectionPalette(
    AppColors.kidsPlayFill,
    AppColors.kidsPlaySoft,
    AppColors.kidsPlayInk,
  );
  static const learn = SectionPalette(
    AppColors.kidsLearnFill,
    AppColors.kidsLearnSoft,
    AppColors.kidsLearnInk,
  );
  static const watch = SectionPalette(
    AppColors.kidsWatchFill,
    AppColors.kidsWatchSoft,
    AppColors.kidsWatchInk,
  );
  static const listen = SectionPalette(
    AppColors.kidsListenFill,
    AppColors.kidsListenSoft,
    AppColors.kidsListenInk,
  );
  static const me = SectionPalette(
    AppColors.kidsMeFill,
    AppColors.kidsMeSoft,
    AppColors.kidsMeInk,
  );

  static SectionPalette forType(ActivityType t) => switch (t.section) {
    KidsSection.watch => watch,
    KidsSection.listen => listen,
    _ => play,
  };
}

/// How a subject looks: its colour family and an icon (Material Symbols, Apache 2.0).
({SectionPalette palette, IconData icon}) subjectLook(
  String? key,
) => switch (key) {
  'letters' => (palette: SectionPalette.learn, icon: Icons.abc_rounded),
  'numbers' => (palette: SectionPalette.play, icon: Icons.pin_outlined),
  'shapes' => (palette: SectionPalette.listen, icon: Icons.category_rounded),
  'science' => (palette: SectionPalette.watch, icon: Icons.science_rounded),
  'nature' => (palette: SectionPalette.me, icon: Icons.eco_rounded),
  'music' => (palette: SectionPalette.listen, icon: Icons.music_note_rounded),
  'art' => (palette: SectionPalette.play, icon: Icons.palette_rounded),
  'feelings' => (palette: SectionPalette.learn, icon: Icons.favorite_rounded),
  'health' => (palette: SectionPalette.me, icon: Icons.spa_rounded),
  'english' => (palette: SectionPalette.watch, icon: Icons.translate_rounded),
  'thinking' => (palette: SectionPalette.learn, icon: Icons.psychology_rounded),
  'moving' => (
    palette: SectionPalette.play,
    icon: Icons.directions_run_rounded,
  ),
  _ => (palette: SectionPalette.learn, icon: Icons.star_rounded),
};

IconData typeIcon(ActivityType t) => switch (t) {
  ActivityType.video => Icons.tv_rounded,
  ActivityType.song => Icons.music_note_rounded,
  ActivityType.story || ActivityType.audiobook => Icons.menu_book_rounded,
  ActivityType.quiz => Icons.fact_check_rounded,
  _ => Icons.sports_esports_rounded,
};

String typeLabel(ActivityType t) => switch (t) {
  ActivityType.video => 'Video',
  ActivityType.song => 'Song',
  ActivityType.story => 'Story',
  ActivityType.audiobook => 'Audiobook',
  ActivityType.quiz => 'Check-in',
  _ => 'Game',
};

int _hash(String s) => s.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff);

/// Placeholder art for an activity until thumbnails exist: one of our characters, or a big
/// type icon, picked from the slug so it never changes between visits.
class ActivityArt extends StatelessWidget {
  const ActivityArt(
    this.activity, {
    super.key,
    this.size = Sizes.kidsCardArtH * 0.62,
  });

  final ActivitySummary activity;
  final double size;

  @override
  Widget build(BuildContext context) {
    final h = _hash(activity.slug);
    final palette = SectionPalette.forType(activity.type);
    if (activity.type == ActivityType.video) {
      return Container(
        width: size * 0.6,
        height: size * 0.6,
        decoration: const BoxDecoration(
          color: AppColors.kidsSurface,
          shape: BoxShape.circle,
          boxShadow: Shadows.kidRaised,
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          size: size * 0.4,
          color: AppColors.kidsInk,
        ),
      );
    }
    if (h % 3 == 0) {
      return Icon(
        typeIcon(activity.type),
        size: size * 0.6,
        color: palette.ink,
      );
    }
    return CharacterArt(
      Character.values[h % Character.values.length],
      size: size * 0.75,
      mood: h.isEven ? Mood.happy : Mood.normal,
    );
  }
}

/// Small chip with an icon on a card or header (`.tchip`).
class TypeChip extends StatelessWidget {
  const TypeChip({
    super.key,
    required this.icon,
    required this.label,
    this.ink = AppColors.kidsInk,
    this.background = AppColors.kidsSurface,
  });

  final IconData icon;
  final String label;
  final Color ink;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Space.s4 - Space.s1,
      vertical: Space.s2,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(Radii.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: Sizes.iconMd, color: ink),
        const SizedBox(width: Space.s2 + Space.s1),
        Flexible(
          child: Text(
            label,
            style: KidsText.caption.copyWith(color: ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Done / Now / Next (locked) / Ask a grown-up badge.
class StateBadge extends StatelessWidget {
  const StateBadge(this.status, {super.key});

  final NodeStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.needsGrownUp) {
      return const TypeChip(
        icon: Icons.lock_rounded,
        label: 'Ask a grown-up',
        ink: AppColors.kidsOnScrim,
        background: AppColors.kidsScrim,
      );
    }
    return switch (status.state) {
      ProgressState.completed => const TypeChip(
        icon: Icons.check_rounded,
        label: 'Done',
        ink: AppColors.kidsSuccess,
        background: AppColors.kidsMeSoft,
      ),
      ProgressState.inProgress => const TypeChip(
        icon: Icons.directions_walk_rounded,
        label: 'Now',
        ink: AppColors.kidsLearnInk,
        background: AppColors.kidsLearnSoft,
      ),
      ProgressState.available => const TypeChip(
        icon: Icons.play_arrow_rounded,
        label: 'Start',
        ink: AppColors.kidsPlayInk,
        background: AppColors.kidsPlaySoft,
      ),
      ProgressState.locked => const TypeChip(
        icon: Icons.lock_outline_rounded,
        label: 'Later',
        ink: AppColors.kidsInkMuted,
        background: AppColors.kidsBgAlt,
      ),
    };
  }
}

/// A card that springs in when it first appears (skipped with "reduce motion").
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow + Motion.instant * math.min(index, 6),
      curve: Motion.easeBounce,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * Space.s7),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Activity card (`.ccard`): art on the section's soft colour, type chip, title, and a lock or
/// a done star. Tapping always opens the activity screen; locks are explained there.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.locked = false,
    this.done = false,
    this.favorite = false,
    this.width = Sizes.kidsCardW,
    this.query = const {},
  });

  final ActivitySummary activity;
  final bool locked;
  final bool done;
  final bool favorite;
  final double width;
  final Map<String, String> query;

  @override
  Widget build(BuildContext context) {
    final palette = SectionPalette.forType(activity.type);
    final title = activity.title.of();
    final label = [
      typeLabel(activity.type),
      title,
      if (locked) 'ask a grown-up',
      if (done) 'played today',
    ].join(', ');
    return SizedBox(
      width: width,
      child: CardTap(
        semanticLabel: label,
        onPressed: () => context.push(
          query.isEmpty
              ? Routes.open(activity.id, activity.type.name)
              : Uri(
                  path: Routes.activity(activity.id),
                  queryParameters: query,
                ).toString(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: width * Sizes.kidsCardArtH / Sizes.kidsCardW,
              color: palette.soft,
              child: Stack(
                children: [
                  if (activity.thumbnail != null)
                    Positioned.fill(
                      child: Opacity(
                        opacity: locked ? 0.55 : 1,
                        child: MediaThumb(
                          path: activity.thumbnail!,
                          width: width,
                          fallback: ActivityArt(
                            activity,
                            size: width * 0.62 * 160 / 240,
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Opacity(
                        opacity: locked ? 0.55 : 1,
                        child: ActivityArt(
                          activity,
                          size: width * 0.62 * 160 / 240,
                        ),
                      ),
                    ),
                  Positioned(
                    left: Space.s4,
                    top: Space.s4,
                    child: TypeChip(
                      icon: typeIcon(activity.type),
                      label: typeLabel(activity.type),
                      ink: palette.ink,
                    ),
                  ),
                  if (favorite)
                    const Positioned(
                      right: Space.s4,
                      top: Space.s4,
                      child: CircleAvatar(
                        radius: Space.s6,
                        backgroundColor: AppColors.kidsSurface,
                        child: Icon(
                          Icons.star_rounded,
                          color: AppColors.kidsStar,
                        ),
                      ),
                    ),
                  if (locked)
                    const Positioned(
                      left: Space.s4,
                      right: Space.s4,
                      bottom: Space.s4,
                      child: Center(
                        child: TypeChip(
                          icon: Icons.lock_rounded,
                          label: 'Ask a grown-up',
                          ink: AppColors.kidsOnScrim,
                          background: AppColors.kidsScrim,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.s5,
                Space.s4,
                Space.s4,
                Space.s5,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: KidsText.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (done)
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.kidsStar,
                      size: Sizes.iconKids,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A raised white card that is one big button (whole card is the tap target).
class CardTap extends StatefulWidget {
  const CardTap({
    super.key,
    required this.child,
    required this.onPressed,
    required this.semanticLabel,
    this.selected = false,
    this.color = AppColors.kidsSurface,
  });

  final Widget child;
  final VoidCallback onPressed;
  final String semanticLabel;
  final bool selected;
  final Color color;

  @override
  State<CardTap> createState() => _CardTapState();
}

class _CardTapState extends State<CardTap> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.xl);
    return Semantics(
      container: true,
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1,
            duration: Motion.instant,
            child: AnimatedContainer(
              duration: Motion.fast,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: radius,
                boxShadow: _pressed ? Shadows.kidPressed : Shadows.kidRaised,
                border: widget.selected || _focused
                    ? Border.all(color: AppColors.kidsFocus, width: Space.s2)
                    : null,
              ),
              child: ClipRRect(borderRadius: radius, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round progress ring with a label in the middle; animates to its value.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.label,
    this.size = Sizes.kidsNode,
    this.color = AppColors.kidsLearnFill,
    this.semanticLabel,
  });

  final double value;
  final String label;
  final double size;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel ?? label,
    child: ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
            ? Duration.zero
            : Motion.celebrate,
        curve: Motion.easeDecelerate,
        builder: (context, v, _) => SizedBox.square(
          dimension: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: v,
                strokeWidth: size / 8,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: AppColors.kidsSurface,
              ),
              Center(
                child: Text(
                  label,
                  style: KidsText.label.copyWith(fontSize: size / 4.5),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Star count pill (`.jar`).
class StarCounter extends StatelessWidget {
  const StarCounter({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$count stars',
    child: ExcludeSemantics(
      child: Container(
        height: Sizes.tapKids,
        padding: const EdgeInsets.only(left: Space.s3, right: Space.s6),
        decoration: BoxDecoration(
          color: AppColors.kidsSurface,
          borderRadius: BorderRadius.circular(Radii.pill),
          boxShadow: Shadows.kidRaised,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: Sizes.tapKids - Space.s5,
              height: Sizes.tapKids - Space.s5,
              decoration: const BoxDecoration(
                color: AppColors.kidsListenSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_rounded,
                color: AppColors.kidsStar,
                size: Sizes.iconKids,
              ),
            ),
            const SizedBox(width: Space.s3),
            Text('$count', style: KidsText.label),
          ],
        ),
      ),
    ),
  );
}

/// Row heading (`.khead`) with an optional action.
class ShelfTitle extends StatelessWidget {
  const ShelfTitle(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.s8, bottom: Space.s5),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            header: true,
            child: Text(title, style: KidsText.heading),
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// A sideways row of cards: never wraps, the next card peeks (design README §4.1).
class Shelf extends StatelessWidget {
  const Shelf({super.key, required this.children, this.height});

  final List<Widget> children;
  final double? height;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    padding: const EdgeInsets.only(bottom: Space.s5, right: Space.s7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: Space.s6),
          PopIn(index: i, child: children[i]),
        ],
      ],
    ),
  );
}

/// Round subject bubble (`.bubble`).
class SubjectBubble extends StatelessWidget {
  const SubjectBubble({
    super.key,
    required this.subject,
    required this.onPressed,
    this.count,
  });

  final Subject subject;
  final VoidCallback onPressed;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final look = subjectLook(subject.key);
    final name = subject.name.of();
    final tile = Container(
      width: Sizes.kidsNode + Space.s3,
      height: Sizes.kidsNode + Space.s3,
      decoration: BoxDecoration(
        color: look.palette.soft,
        borderRadius: BorderRadius.circular(Radii.xl + Space.s4),
        boxShadow: Shadows.kidRaised,
      ),
      child: Icon(
        look.icon,
        size: Sizes.iconKids * 1.6,
        color: look.palette.ink,
      ),
    );
    return SizedBox(
      width: Sizes.kidsNode + Space.s7,
      child: TileWithCaption(label: name, onPressed: onPressed, tile: tile),
    );
  }
}

/// A big tappable tile with its name underneath. The tile is the button (one screen-reader
/// node, labelled with the name); the caption repeats the name visually and is tappable too,
/// but stays out of the button's node so text contrast is measured against the page.
class TileWithCaption extends StatelessWidget {
  const TileWithCaption({
    super.key,
    required this.label,
    required this.onPressed,
    required this.tile,
    this.selected,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget tile;
  final bool? selected;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        container: true,
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: GestureDetector(
          onTap: onPressed,
          child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) => onPressed(),
              ),
            },
            child: tile,
          ),
        ),
      ),
      const SizedBox(height: Space.s3),
      GestureDetector(
        onTap: onPressed,
        excludeFromSemantics: true,
        child: ExcludeSemantics(
          child: Text(
            label,
            style: KidsText.caption.copyWith(color: AppColors.kidsInk),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ],
  );
}

/// Course card: subject colour, title, island count, state, progress bar.
class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.status,
    required this.fraction,
    this.subjectKey,
    this.width = Sizes.kidsCardW + Space.s9,
  });

  final Course course;
  final NodeStatus status;
  final double fraction;
  final String? subjectKey;
  final double width;

  @override
  Widget build(BuildContext context) {
    final look = subjectLook(subjectKey);
    final title = course.title.of();
    final stateWord = switch (status.state) {
      ProgressState.completed => 'done',
      ProgressState.inProgress => 'started',
      ProgressState.locked => 'later',
      ProgressState.available => 'new',
    };
    return SizedBox(
      width: width,
      child: CardTap(
        semanticLabel:
            'Course $title, $stateWord${status.needsGrownUp ? ', ask a grown-up' : ''}',
        selected: status.state == ProgressState.inProgress,
        onPressed: () => context.push(Routes.course(course.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: Sizes.kidsCardArtH * 0.8,
              color: status.state == ProgressState.locked
                  ? AppColors.kidsBgAlt
                  : look.palette.soft,
              child: Stack(
                children: [
                  Center(
                    child: status.state == ProgressState.locked
                        ? const Icon(
                            Icons.lock_outline_rounded,
                            size: Sizes.iconKids * 1.5,
                            color: AppColors.kidsInkMuted,
                          )
                        : Icon(
                            look.icon,
                            size: Sizes.iconKids * 2.2,
                            color: look.palette.ink,
                          ),
                  ),
                  Positioned(
                    left: Space.s4,
                    top: Space.s4,
                    child: StateBadge(status),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.s5,
                Space.s4,
                Space.s5,
                Space.s5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: KidsText.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Space.s2),
                  Text(
                    '${course.lessonCount} ${course.lessonCount == 1 ? 'island' : 'islands'}',
                    style: KidsText.caption,
                  ),
                  if (status.state == ProgressState.inProgress) ...[
                    const SizedBox(height: Space.s3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.pill),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: Space.s3,
                        color: look.palette.fill,
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
    );
  }
}

/// Skeleton shelf while kid content loads.
class ShelfSkeleton extends StatelessWidget {
  const ShelfSkeleton({
    super.key,
    this.count = 3,
    this.height = Sizes.kidsCardArtH + Space.s11,
  });

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) => LoadingRegion(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: Space.s6),
            Skeleton(width: Sizes.kidsCardW, height: height, radius: Radii.xl),
          ],
        ],
      ),
    ),
  );
}

/// K30: shown when a child taps something that needs Plus. No prices, no "buy" words: the
/// buddy points at the Grown-ups button (the gate comes next).
Future<void> showAskGrownUpSheet(BuildContext context) {
  // A message bar would cover the sheet's buttons.
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.kidsSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.x2xl)),
    ),
    builder: (sheetContext) => _KidSheet(
      character: Character.nova,
      title: 'Ask a grown-up!',
      message: 'A grown-up can open this one for you.',
      primary: KidsButton(
        label: 'Get a grown-up',
        icon: Icons.lock_outline_rounded,
        fill: AppColors.kidsLearnFill,
        onPressed: () {
          Navigator.pop(sheetContext);
          context.go(Routes.parents);
        },
      ),
      secondary: KidsButton.soft(
        label: 'Maybe later',
        onPressed: () => Navigator.pop(sheetContext),
      ),
    ),
  );
}

/// Shown for Play until the game engine exists (Phase 9+).
Future<void> showComingSoonSheet(BuildContext context, String title) {
  // A message bar would cover the sheet's buttons.
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.kidsSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.x2xl)),
    ),
    builder: (sheetContext) => _KidSheet(
      character: Character.bolt,
      title: 'Almost ready!',
      message: 'Bolt is still building “$title”. Come back soon to play!',
      primary: KidsButton(
        label: 'OK!',
        icon: Icons.thumb_up_alt_rounded,
        fill: AppColors.kidsMeFill,
        onPressed: () => Navigator.pop(sheetContext),
      ),
    ),
  );
}

class _KidSheet extends StatelessWidget {
  const _KidSheet({
    required this.character,
    required this.title,
    required this.message,
    required this.primary,
    this.secondary,
  });

  final Character character;
  final String title;
  final String message;
  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(Space.s8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CharacterArt(character, size: Sizes.kidsBuddyTile, mood: Mood.happy),
          const SizedBox(height: Space.s5),
          Semantics(
            container: true,
            header: true,
            child: Text(
              title,
              style: KidsText.title,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Space.s3),
          Text(
            message,
            style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.s7),
          Wrap(
            spacing: Space.s5,
            runSpacing: Space.s4,
            alignment: WrapAlignment.center,
            children: [primary, ?secondary],
          ),
        ],
      ),
    ),
  );
}
