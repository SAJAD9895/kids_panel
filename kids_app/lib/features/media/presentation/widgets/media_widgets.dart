import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../learning/domain/catalog.dart';
import '../../../learning/domain/progress.dart';
import '../../../learning/presentation/widgets/kid_widgets.dart';
import '../../domain/media.dart';
import '../media_providers.dart';

/// 0:07, 1:23, 12:05.
String clock(Duration d) {
  final s = d.inSeconds.clamp(0, 359999);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Seek bar with the times either side. Screen readers hear "Video position, 0:12 of 0:36"
/// and can step it with swipe up / down (5 % a step).
class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    required this.snapshot,
    required this.onSeek,
    required this.label,
    this.onDark = false,
  });

  final PlaybackSnapshot snapshot;
  final ValueChanged<Duration> onSeek;
  final String label;
  final bool onDark;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final total = s.duration.inMilliseconds;
    final value = _dragging ?? s.fraction;
    final buffered = total <= 0
        ? 0.0
        : (s.buffered.inMilliseconds / total).clamp(0.0, 1.0);
    final ink = widget.onDark ? AppColors.kidsOnScrim : AppColors.kidsInk;
    final time = KidsText.label.copyWith(color: ink);
    return Row(
      children: [
        Text(clock(s.position), style: time),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: Space.s3,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: Space.s5,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: Sizes.tapKidsSecondary / 2,
              ),
              activeTrackColor: AppColors.kidsPlayFill,
              thumbColor: AppColors.kidsPlayFill,
              inactiveTrackColor: widget.onDark
                  ? AppColors.kidsInkMuted
                  : AppColors.kidsLine,
              secondaryActiveTrackColor: widget.onDark
                  ? AppColors.kidsLine
                  : AppColors.kidsPlaySoft,
            ),
            child: Slider(
              value: value,
              secondaryTrackValue: buffered,
              label: widget.label,
              semanticFormatterCallback: (v) =>
                  '${widget.label}, ${clock(Duration(milliseconds: (v * total).round()))} of ${clock(s.duration)}',
              onChanged: total <= 0
                  ? null
                  : (v) => setState(() => _dragging = v),
              onChangeEnd: total <= 0
                  ? null
                  : (v) {
                      setState(() => _dragging = null);
                      widget.onSeek(
                        Duration(milliseconds: (v * total).round()),
                      );
                    },
            ),
          ),
        ),
        Text(clock(s.duration), style: time),
      ],
    );
  }
}

/// "Loading…" while a file opens or the network is slow (after 8 s: "Slow internet").
class BufferingIndicator extends StatelessWidget {
  const BufferingIndicator({super.key, this.slow = false, this.onDark = false});

  final bool slow;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: slow ? 'Slow internet. Still loading.' : 'Loading',
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: Sizes.tapKids,
            child: CircularProgressIndicator(
              strokeWidth: Space.s2,
              color: onDark ? AppColors.kidsOnScrim : AppColors.kidsPlayFill,
            ),
          ),
          if (slow) ...[
            const SizedBox(height: Space.s4),
            Text(
              'Slow internet… still loading',
              style: KidsText.label.copyWith(
                color: onDark ? AppColors.kidsOnScrim : AppColors.kidsInk,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Every way a video, song or story can't play (yet): offline, server trouble, locked by Plus
/// or a parent's switch, used-up time (K29), not available.
class MediaStateView extends StatelessWidget {
  const MediaStateView({
    super.key,
    required this.stage,
    this.lock,
    required this.onRetry,
    required this.onBack,
    this.what = 'this',
  });

  final MediaStage stage;
  final LockReason? lock;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  /// "this video", "this song", "this story".
  final String what;

  @override
  Widget build(BuildContext context) {
    final (character, mood, title, message) = switch (stage) {
      MediaStage.offline => (
        Character.bolt,
        Mood.happy,
        "You're offline",
        'Videos, songs and stories need the internet. Games still work!',
      ),
      MediaStage.timeUp => (
        Character.pip,
        Mood.normal,
        "That's all for today!",
        'Time for something else. See you tomorrow!',
      ),
      MediaStage.locked when lock == LockReason.needsPlus => (
        Character.nova,
        Mood.happy,
        'Ask a grown-up!',
        'A grown-up can open $what for you.',
      ),
      MediaStage.locked => (
        Character.nova,
        Mood.happy,
        'Not today',
        'A grown-up switched $what off.',
      ),
      MediaStage.unavailable => (
        Character.bolt,
        Mood.happy,
        'Almost ready!',
        '${what[0].toUpperCase()}${what.substring(1)} is still on its way. Try another one!',
      ),
      _ => (
        Character.bolt,
        Mood.happy,
        'Oops!',
        "We couldn't play $what. Let's try again.",
      ),
    };
    final retry = stage == MediaStage.offline || stage == MediaStage.error;
    final grownUp =
        stage == MediaStage.timeUp ||
        (stage == MediaStage.locked && lock == LockReason.needsPlus);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CharacterArt(character, size: Sizes.kidsBuddyTile, mood: mood),
            const SizedBox(height: Space.s5),
            Semantics(
              header: true,
              liveRegion: true,
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
              runSpacing: Space.s5,
              alignment: WrapAlignment.center,
              children: [
                if (retry)
                  KidsButton(
                    label: 'Try again',
                    icon: Icons.refresh_rounded,
                    fill: AppColors.kidsMeFill,
                    onPressed: onRetry,
                  ),
                if (grownUp)
                  KidsButton(
                    label: 'Grown-ups',
                    icon: Icons.lock_outline_rounded,
                    fill: AppColors.kidsLearnFill,
                    onPressed: () => context.go(Routes.parents),
                  ),
                KidsButton.soft(
                  label: 'Back',
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tap to change the speed (0.75× → 1× → 1.25×).
class SpeedButton extends StatelessWidget {
  const SpeedButton({super.key, required this.speed, required this.onChanged});

  final double speed;
  final ValueChanged<double> onChanged;

  static String label(double s) =>
      s == 1 ? '1×' : '${s.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '')}×';

  @override
  Widget build(BuildContext context) {
    final i = videoSpeeds.indexWhere((s) => (s - speed).abs() < 0.01);
    final next = videoSpeeds[(i + 1) % videoSpeeds.length];
    return KidsButton.soft(
      label: label(speed),
      semanticLabel: 'Speed ${label(speed)}. Change to ${label(next)}',
      icon: Icons.speed_rounded,
      onPressed: () => onChanged(next),
    );
  }
}

/// A row of cards that builds only what's on screen (long rows, slow devices).
class MediaShelf extends StatelessWidget {
  const MediaShelf({
    super.key,
    required this.items,
    this.progress = const {},
    required this.locked,
  });

  final List<ActivitySummary> items;

  /// Activity id → how far the child got (continue rows).
  final Map<String, ResumePoint> progress;
  final bool Function(ActivitySummary) locked;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    final title = KidsText.label;
    // card art + two lines of title + the card's padding + the progress stripe
    final height =
        Sizes.kidsCardArtH +
        scale.scale(title.fontSize!) * (title.height ?? 1.25) * 2 +
        Space.s4 +
        Space.s5 +
        Space.s5 +
        (progress.isEmpty ? 0 : Space.s4);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(right: Space.s7),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.s6),
        itemBuilder: (context, i) {
          final a = items[i];
          final p = progress[a.id];
          final card = ActivityCard(activity: a, locked: locked(a));
          if (p == null) return card;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              card,
              const SizedBox(height: Space.s3),
              SizedBox(
                width: Sizes.kidsCardW,
                child: Semantics(
                  label: p.page != null
                      ? 'Page ${p.page! + 1} of ${p.pages}'
                      : '${(p.fraction * 100).round()} percent watched',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: LinearProgressIndicator(
                      value: p.fraction,
                      minHeight: Space.s2,
                      color: AppColors.kidsPlayFill,
                      backgroundColor: AppColors.kidsLine,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
