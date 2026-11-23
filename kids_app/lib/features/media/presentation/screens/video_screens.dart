import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../child_profiles/presentation/child_providers.dart';
import '../../../kids_home/presentation/widgets/kids_shell.dart';
import '../../../learning/domain/catalog.dart';
import '../../../learning/presentation/learning_providers.dart';
import '../../../learning/presentation/widgets/kid_widgets.dart';
import '../../../learning/presentation/widgets/kids_content.dart';
import '../../domain/media.dart';
import '../media_providers.dart';
import '../widgets/media_thumb.dart';
import '../widgets/media_widgets.dart';

/// Related videos: same category first, then same subject; only what this child may see.
List<ActivitySummary> relatedVideos(
  KidsData d,
  ActivitySummary a, {
  int limit = 8,
}) {
  final videos = d.catalog.activities
      .where((x) => x.type == ActivityType.video && x.id != a.id && d.canSee(x))
      .toList();
  return [
    ...videos.where(
      (x) => x.categoryId != null && x.categoryId == a.categoryId,
    ),
    ...videos.where(
      (x) =>
          x.categoryId != a.categoryId &&
          x.subjectId != null &&
          x.subjectId == a.subjectId,
    ),
    ...videos.where(
      (x) => x.categoryId != a.categoryId && x.subjectId != a.subjectId,
    ),
  ].take(limit).toList();
}

// =============================================================================================
// Video details (K12 detail)
// =============================================================================================

class VideoDetailsScreen extends ConsumerWidget {
  const VideoDetailsScreen({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childId = ref.watch(selectedChildIdProvider);
    final positions = childId == null
        ? null
        : ref.watch(mediaPositionsProvider(childId)).value;
    return KidsContent(
      header: const KidsTopBar(title: 'Watch'),
      builder: (context, d) {
        final a = d.catalog.activity(activityId);
        if (a == null || a.type != ActivityType.video) {
          return const [
            KidsEmpty(
              title: 'Not found',
              message: "We couldn't find this video.",
            ),
          ];
        }
        if (!d.canSee(a)) {
          return const [
            SizedBox(height: Space.s9),
            KidsEmpty(
              title: 'Not today',
              message: 'A grown-up switched this off.',
            ),
          ];
        }
        final locked = d.locked(a);
        final resume = MediaRules.resumeAt(positions?[a.id]);
        final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
        final related = relatedVideos(d, a);
        void play() => locked
            ? showAskGrownUpSheet(context)
            : context.push(Routes.videoPlay(a.id));
        final art = CardTap(
          semanticLabel:
              '${locked ? 'Ask a grown-up' : 'Play'} ${a.title.of()}',
          onPressed: play,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (a.thumbnail != null)
                  MediaThumb(
                    path: a.thumbnail!,
                    width: wide ? Sizes.uiContentMax / 2 : Sizes.uiContentMax,
                  )
                else
                  ColoredBox(
                    color: AppColors.kidsWatchSoft,
                    child: Center(child: ActivityArt(a)),
                  ),
                Center(
                  child: Container(
                    width: Sizes.tapKidsXl,
                    height: Sizes.tapKidsXl,
                    decoration: const BoxDecoration(
                      color: AppColors.kidsSurface,
                      shape: BoxShape.circle,
                      boxShadow: Shadows.kidRaised,
                    ),
                    child: Icon(
                      locked ? Icons.lock_rounded : Icons.play_arrow_rounded,
                      size: Sizes.iconKids * 1.5,
                      color: AppColors.kidsWatchInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        final category = d.catalog.category(a.categoryId);
        final subject = d.catalog.subject(a.subjectId);
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(a.title.of(), style: KidsText.title),
            ),
            if (!a.description.isEmpty) ...[
              const SizedBox(height: Space.s3),
              Text(
                a.description.of(),
                style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
              ),
            ],
            const SizedBox(height: Space.s4),
            Wrap(
              spacing: Space.s3,
              runSpacing: Space.s3,
              children: [
                if (a.minutes != null)
                  TypeChip(
                    icon: Icons.schedule_rounded,
                    label: '${a.minutes} min',
                    ink: AppColors.kidsWatchInk,
                  ),
                if (category != null)
                  TypeChip(
                    icon: Icons.category_rounded,
                    label: category.name.of(),
                    ink: AppColors.kidsWatchInk,
                  ),
                if (subject != null)
                  TypeChip(
                    icon: Icons.lightbulb_rounded,
                    label: subject.name.of(),
                    ink: AppColors.kidsLearnInk,
                  ),
              ],
            ),
            const SizedBox(height: Space.s6),
            KidsButton(
              label: locked
                  ? 'Ask a grown-up'
                  : (resume != null ? 'Keep watching' : 'Play'),
              icon: locked ? Icons.lock_rounded : Icons.play_arrow_rounded,
              size: KidsButtonSize.xl,
              fill: AppColors.kidsWatchFill,
              onPressed: play,
            ),
            if (resume != null && !locked) ...[
              const SizedBox(height: Space.s3),
              Text(
                'You stopped at ${clock(resume)}',
                style: KidsText.label.copyWith(color: AppColors.kidsInkMuted),
              ),
            ],
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
            const SizedBox(height: Space.s6),
            info,
          ],
          if (related.isNotEmpty) ...[
            const ShelfTitle('More to watch'),
            MediaShelf(items: related, locked: d.locked),
          ],
        ];
      },
    );
  }
}

// =============================================================================================
// Video player (K13, full screen)
// =============================================================================================

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key, required this.activityId, this.stepId});

  final String activityId;

  /// The lesson step it was opened from (completing the video completes the step).
  final String? stepId;
  MediaArgs get args => (activityId: activityId, stepId: stepId);

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _controlsVisible = true;
  bool _resumeNoteVisible = true;
  Timer? _hide;
  late final VideoController _c;

  @override
  void initState() {
    super.initState();
    _c = ref.read(videoProvider(widget.args).notifier);
    // A call, the home button, another app: the video stops (and remembers where).
    _lifecycle = AppLifecycleListener(onHide: _c.pause);
  }

  @override
  void dispose() {
    _hide?.cancel();
    _lifecycle.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _hide?.cancel();
    final v = ref.read(videoProvider(widget.args));
    if (v.fullscreen && v.snapshot.playing) {
      _hide = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    }
  }

  Future<void> _close() async {
    await _c.leave();
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go(Routes.watch);
  }

  void _setFullscreen(bool on) {
    _c.setFullscreen(on);
    SystemChrome.setEnabledSystemUIMode(
      on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    _showControls();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(videoProvider(widget.args));
    final data = ref.watch(kidsDataProvider).value;
    final activity = data?.catalog.activity(widget.activityId);
    final title = activity?.title.of() ?? '';
    final ready = v.stage == MediaStage.ready;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: OrientationScope(
        policy: OrientationPolicy.kids,
        child: Scaffold(
          backgroundColor: ready ? AppColors.kidsScrim : AppColors.kidsBg,
          body: SafeArea(
            child: switch (v.stage) {
              MediaStage.loading => const Center(child: BufferingIndicator()),
              MediaStage.ready => _player(v, title, data, activity),
              _ => MediaStateView(
                stage: v.stage,
                lock: v.lock,
                what: 'this video',
                onRetry: _c.load,
                onBack: _close,
              ),
            },
          ),
        ),
      ),
    );
  }

  Widget _player(
    VideoView v,
    String title,
    KidsData? data,
    ActivitySummary? activity,
  ) {
    final s = v.snapshot;
    final backend = _c.backend;
    final showBars = !v.fullscreen || _controlsVisible || !s.playing;
    final next = data == null || activity == null
        ? null
        : relatedVideos(data, activity, limit: 1).firstOrNull;
    final video = backend == null
        ? const SizedBox.shrink()
        : Center(
            child: AspectRatio(
              aspectRatio: backend.aspectRatio,
              child: Semantics(
                label: 'Video: $title',
                image: true,
                child: ExcludeSemantics(child: backend.view()),
              ),
            ),
          );
    final caption = v.captionsOn && s.caption.trim().isNotEmpty
        ? Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: showBars ? Sizes.tapKidsXl + Space.s9 : Space.s7,
                left: Space.s7,
                right: Space.s7,
              ),
              child: Semantics(
                liveRegion: true,
                label: 'Caption: ${s.caption}',
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.s5,
                      vertical: Space.s3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.kidsScrim.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Text(
                      s.caption,
                      textAlign: TextAlign.center,
                      style: KidsText.heading.copyWith(
                        color: AppColors.kidsOnScrim,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          video,
          caption,
          if (s.error != null)
            Center(
              child: _OnDark(
                child: MediaStateView(
                  stage: MediaStage.error,
                  what: 'this video',
                  onRetry: _c.retry,
                  onBack: _close,
                ),
              ),
            )
          else if (s.buffering && !v.finished)
            Center(child: BufferingIndicator(slow: v.slow, onDark: true)),
          if (v.finished)
            Center(
              child: _Finished(
                next: next,
                onAgain: _c.toggle,
                onMore: _close,
                onNext: next == null
                    ? null
                    : () => context.pushReplacement(Routes.videoPlay(next.id)),
              ),
            ),
          if (showBars && !v.finished) ...[
            // Fixed-height bars: a bar that grew would cover (and swallow taps on) the rest.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: Sizes.tapKids + Space.s5 * 2,
              child: _topBar(v, title),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: Sizes.tapKidsXl + Space.s7,
              child: _bottomBar(v),
            ),
            if (s.error == null && !s.buffering)
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoundButton(
                      icon: Icons.replay_10_rounded,
                      label: 'Back 10 seconds',
                      onPressed: () => _c.skip(const Duration(seconds: -10)),
                    ),
                    const SizedBox(width: Space.s7),
                    _RoundButton(
                      icon: s.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      label: s.playing ? 'Pause' : 'Play',
                      big: true,
                      onPressed: () {
                        _c.toggle();
                        _showControls();
                      },
                    ),
                    const SizedBox(width: Space.s7),
                    _RoundButton(
                      icon: Icons.forward_10_rounded,
                      label: 'Forward 10 seconds',
                      onPressed: () => _c.skip(const Duration(seconds: 10)),
                    ),
                  ],
                ),
              ),
          ],
          if (v.resumedFrom != null && _resumeNoteVisible && !v.finished)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: Sizes.tapKidsXl + Space.s6),
                child: _ResumeNote(
                  from: v.resumedFrom!,
                  onStartAgain: () {
                    _c.restart();
                    setState(() => _resumeNoteVisible = false);
                  },
                  onClose: () => setState(() => _resumeNoteVisible = false),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topBar(VideoView v, String title) => Container(
    padding: const EdgeInsets.all(Space.s5),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.kidsScrim.withValues(alpha: 0.7),
          AppColors.kidsScrim.withValues(alpha: 0),
        ],
      ),
    ),
    child: Row(
      children: [
        KidsIconButton(
          icon: Icons.close_rounded,
          label: 'Close',
          onPressed: _close,
        ),
        const SizedBox(width: Space.s5),
        Expanded(
          child: Text(
            title,
            style: KidsText.heading.copyWith(color: AppColors.kidsOnScrim),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (v.hasCaptions) ...[
          KidsIconButton(
            icon: v.captionsOn
                ? Icons.closed_caption_rounded
                : Icons.closed_caption_disabled_rounded,
            label: v.captionsOn ? 'Captions on' : 'Captions off',
            onPressed: _c.toggleCaptions,
          ),
          const SizedBox(width: Space.s4),
        ],
        SpeedButton(speed: v.snapshot.speed, onChanged: _c.setSpeed),
      ],
    ),
  );

  Widget _bottomBar(VideoView v) => Container(
    padding: const EdgeInsets.fromLTRB(Space.s6, Space.s5, Space.s5, Space.s5),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          AppColors.kidsScrim.withValues(alpha: 0.7),
          AppColors.kidsScrim.withValues(alpha: 0),
        ],
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: SeekBar(
            snapshot: v.snapshot,
            label: 'Video position',
            onDark: true,
            onSeek: _c.seek,
          ),
        ),
        const SizedBox(width: Space.s4),
        KidsIconButton(
          icon: v.fullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          label: v.fullscreen ? 'Exit full screen' : 'Full screen',
          onPressed: () => _setFullscreen(!v.fullscreen),
        ),
      ],
    ),
  );
}

class _OnDark extends StatelessWidget {
  const _OnDark({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(Space.s7),
    decoration: BoxDecoration(
      color: AppColors.kidsBg,
      borderRadius: BorderRadius.circular(Radii.x2xl),
    ),
    child: child,
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.big = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? Sizes.tapKidsXl + Space.s5 : Sizes.tapKids;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: big
                ? AppColors.kidsSurface
                : AppColors.kidsSurface.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            boxShadow: Shadows.kidRaised,
          ),
          child: Icon(icon, size: size * 0.55, color: AppColors.kidsInk),
        ),
      ),
    );
  }
}

class _ResumeNote extends StatelessWidget {
  const _ResumeNote({
    required this.from,
    required this.onStartAgain,
    required this.onClose,
  });

  final Duration from;
  final VoidCallback onStartAgain;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(Space.s6, Space.s3, Space.s3, Space.s3),
    decoration: BoxDecoration(
      color: AppColors.kidsSurface,
      borderRadius: BorderRadius.circular(Radii.pill),
      boxShadow: Shadows.kidRaised,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text('Carrying on from ${clock(from)}', style: KidsText.label),
        ),
        const SizedBox(width: Space.s4),
        KidsButton.soft(
          label: 'Start again',
          icon: Icons.replay_rounded,
          onPressed: onStartAgain,
        ),
        const SizedBox(width: Space.s3),
        KidsIconButton(
          icon: Icons.close_rounded,
          label: 'Hide',
          onPressed: onClose,
        ),
      ],
    ),
  );
}

class _Finished extends StatelessWidget {
  const _Finished({
    required this.next,
    required this.onAgain,
    required this.onMore,
    required this.onNext,
  });

  final ActivitySummary? next;
  final VoidCallback onAgain;
  final VoidCallback onMore;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => _OnDark(
    child: Padding(
      padding: const EdgeInsets.all(Space.s8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            color: AppColors.kidsStar,
            size: Sizes.tapKidsXl,
          ),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              'You watched it all!',
              style: KidsText.title,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Space.s6),
          Wrap(
            spacing: Space.s5,
            runSpacing: Space.s5,
            alignment: WrapAlignment.center,
            children: [
              if (next != null && onNext != null)
                KidsButton(
                  label: 'Next: ${next!.title.of()}',
                  trailingIcon: Icons.arrow_forward_rounded,
                  fill: AppColors.kidsWatchFill,
                  onPressed: onNext,
                ),
              KidsButton.soft(
                label: 'Watch again',
                icon: Icons.replay_rounded,
                onPressed: onAgain,
              ),
              KidsButton.soft(
                label: 'More videos',
                icon: Icons.video_library_rounded,
                onPressed: onMore,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
