import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../learning/domain/catalog.dart';
import '../../../learning/presentation/learning_providers.dart';
import '../../../learning/presentation/widgets/kid_widgets.dart';
import '../../domain/media.dart';
import '../media_providers.dart';
import '../widgets/media_thumb.dart';
import '../widgets/media_widgets.dart';

/// K33 audio player (full screen): cover, play / pause, previous / next, progress, repeat,
/// shuffle and the list. The music keeps playing when the child leaves this screen (mini
/// player) and, on phones, with the screen off.
class SongPlayerScreen extends ConsumerStatefulWidget {
  const SongPlayerScreen({super.key, required this.activityId, this.stepId});

  final String activityId;

  /// The lesson step it was opened from.
  final String? stepId;

  @override
  ConsumerState<SongPlayerScreen> createState() => _SongPlayerScreenState();
}

class _SongPlayerScreenState extends ConsumerState<SongPlayerScreen> {
  bool _started = false;

  void _start(KidsData d) {
    if (_started) return;
    _started = true;
    final audio = ref.read(audioProvider);
    final songs = d.catalog.activities
        .where(
          (a) =>
              (a.type == ActivityType.song ||
                  a.type == ActivityType.audiobook) &&
              d.canSee(a) &&
              !d.locked(a),
        )
        .toList();
    final me = d.catalog.activity(widget.activityId);
    if (me == null) return;
    if (d.locked(me)) {
      // Plus song for a Basic family: the player shows the lock (the server would refuse too).
      Future.microtask(() {
        if (mounted) showAskGrownUpSheet(context);
      });
      return;
    }
    // Already playing this song (opened from the mini player): just show it.
    if (audio.active && audio.currentId == me.id) return;
    final list = songs.any((s) => s.id == me.id) ? songs : [me, ...songs];
    Future.microtask(
      () => ref
          .read(audioProvider.notifier)
          .playList(list, startId: me.id, stepId: widget.stepId),
    );
  }

  void _close() => context.canPop() ? context.pop() : context.go(Routes.listen);

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(kidsDataProvider).value;
    if (d != null) _start(d);
    final a = ref.watch(audioProvider);
    final c = ref.read(audioProvider.notifier);
    final current = d?.catalog.activity(a.currentId ?? widget.activityId);
    final wide = WindowClass.of(context).isAtLeastMedium;
    final body = switch (a.stage) {
      MediaStage.ready ||
      MediaStage.loading => _player(context, a, c, current, d, wide),
      _ => MediaStateView(
        stage: a.stage,
        lock: a.lock,
        what: 'this song',
        onRetry: c.retry,
        onBack: _close,
      ),
    };
    return OrientationScope(
      policy: OrientationPolicy.kids,
      child: Scaffold(
        backgroundColor: AppColors.kidsListenSoft,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Space.s5),
                child: Row(
                  children: [
                    KidsIconButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      label: 'Close player',
                      onPressed: _close,
                    ),
                    const Spacer(),
                    if (a.active)
                      KidsIconButton(
                        icon: Icons.stop_rounded,
                        label: 'Stop the music',
                        onPressed: () async {
                          await c.stop();
                          if (mounted) _close();
                        },
                      ),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  Widget _player(
    BuildContext context,
    AudioView a,
    AudioController c,
    ActivitySummary? current,
    KidsData? d,
    bool wide,
  ) {
    final s = a.snapshot;
    final q = a.queue;
    final cover = AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.x2xl),
        child: current?.thumbnail == null
            ? ColoredBox(
                color: AppColors.kidsListenFill,
                child: current == null
                    ? null
                    : Center(child: ActivityArt(current)),
              )
            : MediaThumb(
                path: current!.thumbnail!,
                width: Sizes.kidsArtLg * 1.4,
              ),
      ),
    );
    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            current?.title.of() ?? '',
            style: KidsText.title,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: Space.s5),
        if (a.stage == MediaStage.loading || (s.buffering && s.error == null))
          const SizedBox(
            height: Sizes.tapKids + Space.s7,
            child: Center(child: BufferingIndicator()),
          )
        else if (s.error != null)
          KidsButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            onPressed: c.retry,
          )
        else
          SeekBar(snapshot: s, label: 'Song position', onSeek: c.seek),
        const SizedBox(height: Space.s4),
        // Wraps on narrow screens (a phone held sideways) instead of overflowing.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: Space.s4,
          children: [
            KidsIconButton(
              icon: q?.shuffle ?? false
                  ? Icons.shuffle_on_rounded
                  : Icons.shuffle_rounded,
              label: q?.shuffle ?? false ? 'Shuffle on' : 'Shuffle off',
              onPressed: q == null ? null : c.toggleShuffle,
            ),
            const SizedBox(width: Space.s5),
            KidsIconButton(
              icon: Icons.skip_previous_rounded,
              label: 'Previous',
              onPressed: q == null ? null : c.previous,
            ),
            const SizedBox(width: Space.s5),
            KidsButton(
              label: s.playing ? 'Pause' : 'Play',
              icon: s.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: KidsButtonSize.xl,
              fill: AppColors.kidsListenFill,
              onPressed: q == null ? null : c.toggle,
            ),
            const SizedBox(width: Space.s5),
            KidsIconButton(
              icon: Icons.skip_next_rounded,
              label: 'Next',
              onPressed: q?.hasNext ?? false ? c.next : null,
            ),
            const SizedBox(width: Space.s5),
            KidsIconButton(
              icon: switch (q?.repeat ?? SongRepeat.off) {
                SongRepeat.one => Icons.repeat_one_on_rounded,
                SongRepeat.all => Icons.repeat_on_rounded,
                SongRepeat.off => Icons.repeat_rounded,
              },
              label: switch (q?.repeat ?? SongRepeat.off) {
                SongRepeat.one => 'Repeat this song',
                SongRepeat.all => 'Repeat all',
                SongRepeat.off => 'Repeat off',
              },
              onPressed: q == null ? null : c.cycleRepeat,
            ),
          ],
        ),
      ],
    );
    final list = q == null || d == null
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: Space.s6),
              Text('Songs', style: KidsText.heading),
              const SizedBox(height: Space.s3),
              for (final (i, k) in q.order.indexed)
                () {
                  final id = q.ids[k];
                  final song = d.catalog.activity(id);
                  final now = i == q.index;
                  return Semantics(
                    button: true,
                    selected: now,
                    label:
                        '${song?.title.of() ?? ''}${now ? ', playing now' : ''}',
                    excludeSemantics: true,
                    onTap: () => c.select(id),
                    child: InkWell(
                      onTap: () => c.select(id),
                      borderRadius: BorderRadius.circular(Radii.lg),
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: Sizes.tapKidsSecondary,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.s4,
                        ),
                        decoration: BoxDecoration(
                          color: now ? AppColors.kidsSurface : null,
                          borderRadius: BorderRadius.circular(Radii.lg),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              now
                                  ? Icons.graphic_eq_rounded
                                  : Icons.music_note_rounded,
                              color: AppColors.kidsListenInk,
                            ),
                            const SizedBox(width: Space.s4),
                            Expanded(
                              child: Text(
                                song?.title.of() ?? '',
                                style: KidsText.label,
                              ),
                            ),
                            if (song?.minutes != null)
                              Text(
                                '${song!.minutes} min',
                                style: KidsText.caption,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }(),
            ],
          );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.s7, 0, Space.s7, Space.s9),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.uiContentMax),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: Sizes.kidsArtLg * 1.4, child: cover),
                    const SizedBox(width: Space.s9),
                    Expanded(child: Column(children: [controls, list])),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(width: Sizes.kidsArtLg, child: cover),
                    const SizedBox(height: Space.s6),
                    controls,
                    list,
                  ],
                ),
        ),
      ),
    );
  }
}

/// The bar above the kids' navigation while a song plays: title, play / pause, next, stop;
/// tap it to open the full player.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(audioProvider);
    if (!a.active || a.currentId == null) return const SizedBox.shrink();
    final c = ref.read(audioProvider.notifier);
    final s = a.snapshot;
    return Material(
      color: AppColors.kidsListenSoft,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.kidsLine, width: Space.s1),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s5,
            vertical: Space.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Now playing: ${a.title}. Open the player',
                  excludeSemantics: true,
                  onTap: () => context.push(Routes.song(a.currentId!)),
                  child: InkWell(
                    onTap: () => context.push(Routes.song(a.currentId!)),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: Sizes.tapKidsSecondary,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.music_note_rounded,
                            color: AppColors.kidsListenInk,
                            size: Sizes.iconKids,
                          ),
                          const SizedBox(width: Space.s4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  a.title,
                                  style: KidsText.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: Space.s2),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    Radii.pill,
                                  ),
                                  child: LinearProgressIndicator(
                                    value: s.fraction,
                                    minHeight: Space.s2,
                                    color: AppColors.kidsListenInk,
                                    backgroundColor: AppColors.kidsLine,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.s4),
              KidsIconButton(
                icon: s.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                label: s.playing ? 'Pause' : 'Play',
                onPressed: c.toggle,
              ),
              const SizedBox(width: Space.s3),
              KidsIconButton(
                icon: Icons.skip_next_rounded,
                label: 'Next song',
                onPressed: a.queue?.hasNext ?? false ? c.next : null,
              ),
              const SizedBox(width: Space.s3),
              KidsIconButton(
                icon: Icons.close_rounded,
                label: 'Stop the music',
                onPressed: c.stop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
