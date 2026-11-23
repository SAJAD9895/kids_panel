import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../child_profiles/presentation/child_providers.dart';
import '../../domain/rewards.dart';
import '../rewards_providers.dart';
import 'reward_widgets.dart';

/// Shows confirmed new rewards over the kid zone, one session at a time, oldest first.
///
/// * Stars only: a small "+1 star" banner at the top that goes away by itself.
/// * A badge, a goal, an island, a course or a streak milestone: one card for everything that
///   session earned, closed with one tap. The card never suggests playing more; reaching the
///   daily goal suggests a break instead.
///
/// Celebrations wait while a grown-up is in the parents area, and belong to one child.
class CelebrationHost extends ConsumerStatefulWidget {
  const CelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CelebrationHost> createState() => _CelebrationHostState();
}

class _CelebrationHostState extends ConsumerState<CelebrationHost> {
  RewardEvents? _showing;
  late final GoRouter _router;

  // This sits above the router (MaterialApp.builder), so it never reads providers while it
  // builds: it listens, and decides after the frame what to show.
  @override
  void initState() {
    super.initState();
    _router = ref.read(routerProvider);
    _router.routerDelegate.addListener(_later);
    ref.listenManual(celebrationQueueProvider, (_, _) => _later());
    ref.listenManual(selectedChildIdProvider, (_, _) => _later());
    _later();
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_later);
    super.dispose();
  }

  void _later() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _update());

  void _update() {
    if (!mounted) return;
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    final childId = ref.read(selectedChildIdProvider);
    final next = Routes.isKids(path)
        ? ref.read(celebrationQueueProvider.notifier).nextFor(childId)
        : null;
    if (!identical(next, _showing)) setState(() => _showing = next);
  }

  @override
  Widget build(BuildContext context) {
    final next = _showing;
    return Stack(
      children: [
        widget.child,
        if (next != null)
          Positioned.fill(
            child: _Celebration(
              key: ObjectKey(next),
              events: next,
              onDone: () =>
                  ref.read(celebrationQueueProvider.notifier).done(next),
            ),
          ),
      ],
    );
  }
}

/// What the card says, from the most special thing earned.
class CelebrationContent {
  const CelebrationContent({
    required this.style,
    required this.title,
    this.lines = const [],
    this.badgeArt,
  });

  final CelebrationStyle style;
  final String title;
  final List<String> lines;
  final String? badgeArt;

  /// Null when only stars were earned (the small banner).
  static CelebrationContent? of(RewardEvents e) {
    final lines = <String>[];
    CelebrationContent? head;
    CelebrationContent pick(CelebrationContent c) => head ??= c;
    if (e.courseCompleted) {
      pick(
        const CelebrationContent(
          style: CelebrationStyle.course,
          title: 'You finished a whole course!',
        ),
      );
    }
    for (final b in e.badges) {
      final c = CelebrationContent(
        style: CelebrationStyle.badge,
        title: 'New badge: ${b.title}!',
        badgeArt: b.art,
      );
      if (!identical(pick(c), c)) lines.add('New badge: ${b.title}');
    }
    if (e.streakMilestone case final n?) {
      final c = CelebrationContent(
        style: CelebrationStyle.milestone,
        title: '$n learning days!',
      );
      if (!identical(pick(c), c)) lines.add('$n learning days');
    }
    if (e.weeklyGoalDone) {
      const c = CelebrationContent(
        style: CelebrationStyle.goal,
        title: "You reached this week's goal!",
      );
      if (!identical(pick(c), c)) lines.add("This week's goal reached");
    }
    if (e.dailyGoalDone) {
      const c = CelebrationContent(
        style: CelebrationStyle.goal,
        title: "You reached today's goal!",
      );
      if (!identical(pick(c), c)) lines.add("Today's goal reached");
    }
    if (e.lessonCompleted) {
      const c = CelebrationContent(
        style: CelebrationStyle.stars,
        title: 'Island finished!',
      );
      if (!identical(pick(c), c)) lines.add('Island finished');
    }
    final h = head;
    if (h == null) return null;
    return CelebrationContent(
      style: h.style,
      title: h.title,
      badgeArt: h.badgeArt,
      lines: [
        ...lines,
        if (e.stars > 0) '+${e.stars} ${e.stars == 1 ? 'star' : 'stars'}',
        if (e.dailyGoalDone) 'Great learning today. Maybe time for a break?',
      ],
    );
  }
}

class _Celebration extends StatefulWidget {
  const _Celebration({super.key, required this.events, required this.onDone});

  final RewardEvents events;
  final VoidCallback onDone;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final content = CelebrationContent.of(widget.events);

  /// The small banner's life (an animation, not a timer: it stops when the widget goes).
  late final _life = AnimationController(
    vsync: this,
    duration: Motion.celebrate * 3,
  );

  @override
  void initState() {
    super.initState();
    if (content == null) {
      _life.forward().whenComplete(() {
        if (mounted) widget.onDone();
      });
    }
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = content;
    if (c == null) return _banner(context);
    final screen = MediaQuery.sizeOf(context);
    final wide = screen.width >= Breakpoints.medium;
    // Short screens (a phone held sideways) get a smaller picture so "Yay!" stays in view.
    final art = (Sizes.kidsArtLg * (wide ? 0.8 : 0.6)).clamp(
      Sizes.tapKids,
      screen.height * 0.28,
    );
    return Material(
      color: AppColors.kidsScrim.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.s6),
            child: Semantics(
              container: true,
              liveRegion: true,
              namesRoute: true,
              label: c.title,
              child: Container(
                constraints: const BoxConstraints(maxWidth: Sizes.uiFormW),
                padding: const EdgeInsets.all(Space.s8),
                decoration: BoxDecoration(
                  color: AppColors.kidsSurface,
                  borderRadius: BorderRadius.circular(Radii.x2xl),
                  boxShadow: Shadows.pop,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: CelebrationBurst(
                        style: c.style,
                        size: art,
                        child: switch (c.style) {
                          CelebrationStyle.badge => BadgeArt(
                            art: c.badgeArt ?? '',
                            size: art * 0.6,
                          ),
                          CelebrationStyle.course => Icon(
                            Icons.emoji_events_rounded,
                            size: art * 0.45,
                            color: AppColors.kidsStar,
                          ),
                          CelebrationStyle.milestone => Icon(
                            Icons.wb_sunny_rounded,
                            size: art * 0.4,
                            color: AppColors.kidsStar,
                          ),
                          _ => Icon(
                            Icons.star_rounded,
                            size: art * 0.45,
                            color: AppColors.kidsStar,
                          ),
                        },
                      ),
                    ),
                    Text(
                      c.title,
                      style: KidsText.title,
                      textAlign: TextAlign.center,
                    ),
                    for (final l in c.lines) ...[
                      const SizedBox(height: Space.s3),
                      Text(
                        l,
                        style: KidsText.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: Space.s7),
                    KidsButton(
                      label: 'Yay!',
                      icon: Icons.favorite_rounded,
                      fill: AppColors.kidsListenFill,
                      onPressed: widget.onDone,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "+1 star": slides in at the top, stays a moment, fades.
  Widget _banner(BuildContext context) {
    final n = widget.events.stars;
    final still = MediaQuery.disableAnimationsOf(context);
    final text = '+$n ${n == 1 ? 'star' : 'stars'}!';
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: Space.s5),
          child: AnimatedBuilder(
            animation: _life,
            builder: (context, child) {
              final t = _life.value;
              final o = still
                  ? 1.0
                  : t < 0.1
                  ? t / 0.1
                  : t > 0.85
                  ? (1 - t) / 0.15
                  : 1.0;
              return Opacity(
                opacity: o.clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(0, still ? 0 : (1 - o) * -Space.s7),
                  child: child,
                ),
              );
            },
            child: Semantics(
              liveRegion: true,
              label: text,
              child: ExcludeSemantics(
                child: GestureDetector(
                  onTap: widget.onDone,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.s7,
                      vertical: Space.s4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.kidsListenSoft,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      boxShadow: Shadows.pop,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CelebrationBurst(
                          style: CelebrationStyle.stars,
                          size: Sizes.tapKids,
                          child: const Icon(
                            Icons.star_rounded,
                            color: AppColors.kidsStar,
                            size: Sizes.iconKids,
                          ),
                        ),
                        const SizedBox(width: Space.s3),
                        Text(text, style: KidsText.heading),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
