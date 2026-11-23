import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/routes.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../learning/presentation/learning_providers.dart';
import '../../domain/media.dart';
import '../media_providers.dart';
import '../widgets/media_widgets.dart';

/// K32 book reader (full screen): one illustrated page at a time, the words beside it with the
/// sentence being read highlighted, narration play / pause, page turns by arrows or swipe,
/// "Read to me" (turns the pages itself), a slower voice, and continue reading.
class StoryReaderScreen extends ConsumerStatefulWidget {
  const StoryReaderScreen({super.key, required this.activityId, this.stepId});

  final String activityId;

  /// The lesson step it was opened from (completing the video completes the step).
  final String? stepId;
  MediaArgs get args => (activityId: activityId, stepId: stepId);

  @override
  ConsumerState<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends ConsumerState<StoryReaderScreen> {
  late final AppLifecycleListener _lifecycle;
  late final StoryController _c;
  bool _continueNote = true;

  @override
  void initState() {
    super.initState();
    _c = ref.read(storyProvider(widget.args).notifier);
    // A call or the home button: narration stops and the reading clock pauses.
    _lifecycle = AppLifecycleListener(
      onHide: () => _c.setPaused(true),
      onShow: () => _c.setPaused(false),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _c.leave();
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go(Routes.listen);
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(storyProvider(widget.args));
    final title =
        ref
            .watch(kidsDataProvider)
            .value
            ?.catalog
            .activity(widget.activityId)
            ?.title
            .of() ??
        '';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: OrientationScope(
        policy: OrientationPolicy.kids,
        child: Scaffold(
          backgroundColor: AppColors.kidsBg,
          body: SafeArea(
            child: switch (v.stage) {
              MediaStage.loading => const Center(child: BufferingIndicator()),
              MediaStage.ready => _reader(context, v, title),
              _ => MediaStateView(
                stage: v.stage,
                lock: v.lock,
                what: 'this story',
                onRetry: _c.load,
                onBack: _close,
              ),
            },
          ),
        ),
      ),
    );
  }

  Widget _reader(BuildContext context, StoryView v, String title) {
    final pages = v.pages;
    final page = pages[v.page];
    final last = v.page == pages.length - 1;
    final wide =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final picture = ClipRRect(
      borderRadius: BorderRadius.circular(Radii.x2xl),
      child: AspectRatio(
        aspectRatio: (page.image.width ?? 16) / (page.image.height ?? 10),
        child: Semantics(
          image: true,
          label: 'Picture for page ${v.page + 1}',
          child: _PageImage(file: page.image),
        ),
      ),
    );
    final words = _Words(
      sentences: page.sentences(),
      highlight: v.sentence,
      onTapSentence: (s) => ref.read(speechProvider).speak(s),
    );
    final end = last
        ? Padding(
            padding: const EdgeInsets.only(top: Space.s6),
            child: Column(
              children: [
                Semantics(
                  header: true,
                  child: Text('The end!', style: KidsText.title),
                ),
                const SizedBox(height: Space.s4),
                Wrap(
                  spacing: Space.s4,
                  runSpacing: Space.s4,
                  alignment: WrapAlignment.center,
                  children: [
                    KidsButton.soft(
                      label: 'Read again',
                      icon: Icons.replay_rounded,
                      onPressed: () => _c.goTo(0),
                    ),
                    KidsButton.soft(
                      label: 'More stories',
                      icon: Icons.menu_book_rounded,
                      onPressed: _close,
                    ),
                  ],
                ),
              ],
            ),
          )
        : const SizedBox.shrink();
    final content = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 3, child: Center(child: picture)),
              const SizedBox(width: Space.s7),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [words, end],
                  ),
                ),
              ),
            ],
          )
        : SingleChildScrollView(
            child: Column(
              children: [
                picture,
                const SizedBox(height: Space.s5),
                words,
                end,
              ],
            ),
          );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.s5,
            Space.s5,
            Space.s5,
            Space.s3,
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
                  style: KidsText.heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _Toggle(
                on: v.readToMe,
                icon: Icons.auto_stories_rounded,
                label: 'Read to me',
                onChanged: _c.setReadToMe,
              ),
              const SizedBox(width: Space.s3),
              _Toggle(
                on: v.slowVoice,
                icon: Icons.slow_motion_video_rounded,
                label: 'Slow voice',
                onChanged: _c.setSlowVoice,
              ),
            ],
          ),
        ),
        if (v.startedFrom != null && v.startedFrom! > 0 && _continueNote)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s3),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Space.s4,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Carrying on from page ${v.startedFrom! + 1}',
                    style: KidsText.label,
                  ),
                ),
                KidsButton.soft(
                  label: 'Start at the beginning',
                  icon: Icons.first_page_rounded,
                  onPressed: () {
                    _c.goTo(0);
                    setState(() => _continueNote = false);
                  },
                ),
              ],
            ),
          ),
        Expanded(
          child: GestureDetector(
            // Swipe left / right to turn the page.
            onHorizontalDragEnd: (d) {
              final vx = d.primaryVelocity ?? 0;
              if (vx < -200) _c.nextPage();
              if (vx > 200) _c.previousPage();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s7),
              child: content,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.s5),
          child: Row(
            children: [
              KidsIconButton(
                icon: Icons.arrow_back_rounded,
                label: 'Previous page',
                onPressed: v.page == 0 ? null : _c.previousPage,
              ),
              const SizedBox(width: Space.s5),
              Expanded(
                child: Semantics(
                  label: 'Page ${v.page + 1} of ${pages.length}',
                  liveRegion: true,
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Page ${v.page + 1} of ${pages.length}',
                          style: KidsText.label,
                        ),
                        const SizedBox(height: Space.s2),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          child: LinearProgressIndicator(
                            value: (v.page + 1) / pages.length,
                            minHeight: Space.s3,
                            color: AppColors.kidsListenInk,
                            backgroundColor: AppColors.kidsLine,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.s5),
              KidsButton(
                label: v.narrating ? 'Pause' : 'Read',
                semanticLabel: v.narrating
                    ? 'Pause reading'
                    : 'Read this page to me',
                icon: v.narrating
                    ? Icons.pause_rounded
                    : Icons.volume_up_rounded,
                fill: AppColors.kidsListenFill,
                onPressed: v.narrating ? _c.stopNarration : _c.play,
              ),
              const SizedBox(width: Space.s5),
              KidsIconButton(
                icon: Icons.arrow_forward_rounded,
                label: 'Next page',
                onPressed: last ? null : _c.nextPage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageImage extends StatelessWidget {
  const _PageImage({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width *
        MediaQuery.devicePixelRatioOf(context);
    final ImageProvider base = file.isAsset
        ? AssetImage(file.assetPath)
        : NetworkImage(file.url);
    return Image(
      image: ResizeImage(
        base,
        width: width.ceil().clamp(1, file.width ?? 1024),
        allowUpscaling: false,
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      // A still placeholder while the picture loads (the words are already there to read).
      frameBuilder: (context, child, frame, sync) => frame == null && !sync
          ? const ColoredBox(color: AppColors.kidsBgAlt)
          : child,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: AppColors.kidsBgAlt,
        child: Center(
          child: Icon(Icons.image_not_supported_rounded, size: Sizes.iconKids),
        ),
      ),
    );
  }
}

/// The page's words: the sentence being read is highlighted; tap a sentence to hear it.
class _Words extends StatelessWidget {
  const _Words({
    required this.sentences,
    required this.highlight,
    required this.onTapSentence,
  });

  final List<String> sentences;
  final int highlight;
  final ValueChanged<String> onTapSentence;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.s2,
    runSpacing: Space.s2,
    children: [
      for (final (i, s) in sentences.indexed)
        Semantics(
          button: true,
          label: s,
          hint: 'Tap to hear it',
          excludeSemantics: true,
          onTap: () => onTapSentence(s),
          child: InkWell(
            onTap: () => onTapSentence(s),
            borderRadius: BorderRadius.circular(Radii.md),
            child: AnimatedContainer(
              duration: Motion.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.s2,
                vertical: Space.s1,
              ),
              decoration: BoxDecoration(
                color: i == highlight ? AppColors.kidsListenFill : null,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Text(s, style: KidsText.heading),
            ),
          ),
        ),
    ],
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.on,
    required this.icon,
    required this.label,
    required this.onChanged,
  });

  final bool on;
  final IconData icon;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final narrow = WindowClass.of(context) == WindowClass.compact;
    return Semantics(
      toggled: on,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => onChanged(!on),
      child: narrow
          ? KidsIconButton(
              icon: icon,
              label: label,
              onPressed: () => onChanged(!on),
            )
          : PillChoice(
              label: label,
              selected: on,
              fill: AppColors.kidsListenFill,
              onSelected: () => onChanged(!on),
            ),
    );
  }
}
