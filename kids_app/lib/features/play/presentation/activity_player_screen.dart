import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router/routes.dart';
import '../../../core/audio/sfx.dart';
import '../../../core/audio/speech.dart';
import '../../../core/art/characters.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kids_controls.dart';
import '../../../core/widgets/state_views.dart';
import '../../learning/domain/catalog.dart';
import '../../learning/domain/progress_rules.dart';
import '../../learning/presentation/learning_providers.dart';
import '../domain/engine.dart';
import '../domain/item_spec.dart';
import '../domain/kinds/choice_kinds.dart';
import '../domain/run_summary.dart';
import '../domain/session_report.dart';
import 'play_providers.dart';
import 'views/item_views.dart';
import 'widgets/play_widgets.dart';

/// Views per activity type (overridable in tests).
final itemViewRegistryProvider = Provider<ItemViewRegistry>(
  (ref) => ItemViewRegistry.standard(),
);

/// Whether the voice speaks on its own (instructions, questions, feedback). The listen buttons
/// always work.
final autoSpeakProvider = NotifierProvider<AutoSpeakController, bool?>(
  AutoSpeakController.new,
);

class AutoSpeakController extends Notifier<bool?> {
  @override
  bool? build() => null; // null = follow the age policy

  void set(bool on) => state = on;
}

/// Whether game sound effects play (the pause sheet switch). Separate from the voice.
final soundsOnProvider = NotifierProvider<SoundsOnController, bool>(
  SoundsOnController.new,
);

class SoundsOnController extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool on) => state = on;
}

/// The full-screen player for any engine activity (K11 frame): intro, items, feedback,
/// completion. Knows nothing about individual activity types: it asks the registries.
class ActivityPlayerScreen extends ConsumerStatefulWidget {
  const ActivityPlayerScreen({super.key, required this.args});

  final PlayArgs args;

  @override
  ConsumerState<ActivityPlayerScreen> createState() =>
      _ActivityPlayerScreenState();
}

class _ActivityPlayerScreenState extends ConsumerState<ActivityPlayerScreen>
    with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycle;
  late final SpeechService _speech;
  late final SoundEffects _sfx;
  String? _lastSpokenItem;
  String? _celebrated;

  PlayerController get _c => ref.read(playerProvider(widget.args).notifier);

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechProvider); // kept: `ref` can't be used in dispose
    _sfx = ref.read(soundEffectsProvider);
    // Leaving the app (call, home button, tab switch) pauses the clock and saves the run.
    _lifecycle = AppLifecycleListener(
      onHide: () => _c.leave(),
      onShow: () => _c.resume(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _speech.stop();
    super.dispose();
  }

  bool get _autoSpeak =>
      ref.read(autoSpeakProvider) ??
      ref.read(playerProvider(widget.args)).policy.autoSpeak;

  void _say(String text) => _speech.speak(text);

  void _sound(Sfx s) {
    if (ref.read(soundsOnProvider)) _sfx.play(s);
  }

  void _maybeSpeakItem(RunState run) {
    if (run.phase == PlayPhase.completed && _celebrated != run.sessionId) {
      _celebrated = run.sessionId;
      _sound(Sfx.complete);
    }
    if (run.phase != PlayPhase.question) return;
    final key = '${run.sessionId}/${run.index}';
    if (_lastSpokenItem == key) return;
    _lastSpokenItem = key;
    if (_autoSpeak) _say(run.item.prompt.spoken());
  }

  Future<void> _exit() async {
    await _c.leave();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.kids);
    }
  }

  Future<void> _pauseSheet() async {
    _c.pause();
    final leave = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.kidsSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.x2xl)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.s8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CharacterArt(
                Character.nova,
                size: Sizes.kidsBuddyTile,
                mood: Mood.happy,
              ),
              const SizedBox(height: Space.s4),
              Semantics(
                container: true,
                header: true,
                child: Text('Taking a break', style: KidsText.title),
              ),
              const SizedBox(height: Space.s7),
              Wrap(
                spacing: Space.s5,
                runSpacing: Space.s5,
                alignment: WrapAlignment.center,
                children: [
                  KidsButton(
                    label: 'Keep playing',
                    icon: Icons.play_arrow_rounded,
                    fill: AppColors.kidsMeFill,
                    size: KidsButtonSize.xl,
                    onPressed: () => Navigator.pop(sheet, false),
                  ),
                  KidsButton.soft(
                    label: 'Stop for now',
                    icon: Icons.logout_rounded,
                    onPressed: () => Navigator.pop(sheet, true),
                  ),
                ],
              ),
              const SizedBox(height: Space.s5),
              Consumer(
                builder: (context, ref, _) {
                  final on =
                      ref.watch(autoSpeakProvider) ??
                      ref.read(playerProvider(widget.args)).policy.autoSpeak;
                  final sounds = ref.watch(soundsOnProvider);
                  return Wrap(
                    spacing: Space.s5,
                    runSpacing: Space.s5,
                    alignment: WrapAlignment.center,
                    children: [
                      KidsButton.soft(
                        label: on ? 'Voice on' : 'Voice off',
                        icon: on
                            ? Icons.record_voice_over_rounded
                            : Icons.voice_over_off_rounded,
                        onPressed: () =>
                            ref.read(autoSpeakProvider.notifier).set(!on),
                      ),
                      KidsButton.soft(
                        label: sounds ? 'Sounds on' : 'Sounds off',
                        icon: sounds
                            ? Icons.music_note_rounded
                            : Icons.music_off_rounded,
                        onPressed: () =>
                            ref.read(soundsOnProvider.notifier).set(!sounds),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (leave == true) {
      await _exit();
    } else {
      _c.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(playerProvider(widget.args));
    ref.listen(playerProvider(widget.args).select((v) => v.run), (_, run) {
      if (run != null) _maybeSpeakItem(run);
    });
    final run = view.run;
    final title = view.source?.activity.title.of() ?? '';

    final Widget body = switch (view.stage) {
      PlayerStage.loading => const LoadingRegion(
        child: Center(
          child: Skeleton(
            width: Sizes.kidsArtLg,
            height: Sizes.kidsArtLg,
            radius: Radii.x2xl,
          ),
        ),
      ),
      PlayerStage.error => KidsErrorView(onRetry: _c.retryLoad),
      PlayerStage.unsupported => _Message(
        character: Character.bolt,
        title: 'Almost ready!',
        message: 'Bolt is still building “$title”. Come back soon to play!',
        action: KidsButton(
          label: 'Back',
          icon: Icons.arrow_back_rounded,
          onPressed: _exit,
        ),
      ),
      PlayerStage.resumeOffer => _Message(
        character: Character.pip,
        title: 'Keep going?',
        message:
            'You started “$title” before. Shall we carry on where you stopped?',
        action: Wrap(
          spacing: Space.s5,
          runSpacing: Space.s5,
          alignment: WrapAlignment.center,
          children: [
            KidsButton(
              label: 'Keep going',
              icon: Icons.play_arrow_rounded,
              fill: AppColors.kidsMeFill,
              size: KidsButtonSize.xl,
              onPressed: _c.continueSaved,
            ),
            KidsButton.soft(
              label: 'Start over',
              icon: Icons.refresh_rounded,
              onPressed: _c.startOver,
            ),
          ],
        ),
      ),
      PlayerStage.playing => switch (run!.phase) {
        PlayPhase.intro => _Intro(
          source: view.source!,
          onPlay: () {
            _sound(Sfx.tap);
            _c.start();
          },
          onListen: () => _say(_introText(view.source!)),
          onLevel: (id) {
            _sound(Sfx.tap);
            _c.chooseLevel(id);
          },
        ),
        PlayPhase.completed => _Completion(
          view: view,
          args: widget.args,
          onAgain: _c.playAgain,
          onNextLevel: _c.playNextLevel,
          onExit: _exit,
        ),
        _ => _Playing(
          view: view,
          onPause: _pauseSheet,
          onListen: () => _say(run.item.prompt.spoken()),
          onHint: () {
            final h = _c.useHint();
            if (!h.text.isEmpty) _say(h.text.of());
          },
          submit: (a) {
            final e = _c.submit(a);
            HapticFeedback.mediumImpact();
            final fb = ref.read(playerProvider(widget.args)).run?.feedback;
            if (fb == FeedbackKind.correct) _sound(Sfx.correct);
            if (fb == FeedbackKind.tryAgain) _sound(Sfx.tryAgain);
            if (_autoSpeak) {
              _say(switch (fb) {
                FeedbackKind.correct =>
                  e.mistakes == 0 ? 'Great job!' : 'You did it!',
                FeedbackKind.tryAgain => 'Almost! Try again.',
                _ => "Here's the answer. Let's keep going!",
              });
            }
          },
          onRetry: _c.retry,
          onNext: _c.next,
          speak: _say,
          sound: _sound,
        ),
      },
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // System back / Esc never leaves a game straight away: it opens the pause sheet.
        if (view.stage == PlayerStage.playing &&
            (run?.phase == PlayPhase.question ||
                run?.phase == PlayPhase.feedback)) {
          _pauseSheet();
        } else {
          _exit();
        }
      },
      child: OrientationScope(
        policy: OrientationPolicy.kids,
        child: Scaffold(
          backgroundColor: AppColors.kidsBg,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(child: body),
                if (view.stage != PlayerStage.playing ||
                    run?.phase == PlayPhase.intro)
                  Positioned(
                    left: Space.s5,
                    top: Space.s5,
                    child: KidsIconButton(
                      icon: Icons.close_rounded,
                      label: 'Close',
                      onPressed: _exit,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _introText(ActivitySource s) {
    final t = s.intro.spoken();
    return t.isEmpty ? s.activity.title.of() : t;
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.character,
    required this.title,
    required this.message,
    required this.action,
  });

  final Character character;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(Space.s8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CharacterArt(character, mood: Mood.happy),
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
          const SizedBox(height: Space.s8),
          action,
        ],
      ),
    ),
  );
}

/// Character, title, one line, a big Play and a Listen button. A picture of the first item's
/// kind shows what kind of game it is (visual instructions for pre-readers).
class _Intro extends StatelessWidget {
  const _Intro({
    required this.source,
    required this.onPlay,
    required this.onListen,
    required this.onLevel,
  });

  final ActivitySource source;
  final VoidCallback onPlay;
  final VoidCallback onListen;
  final void Function(String levelId) onLevel;

  static IconData kindIcon(String kind) => switch (kind) {
    'trace' => Icons.draw_rounded,
    'memory' => Icons.style_rounded,
    'drag_to_target' || 'sort' => Icons.pan_tool_alt_rounded,
    'match_pairs' => Icons.compare_arrows_rounded,
    'word_build' || 'fill_blank' => Icons.abc_rounded,
    'puzzle' => Icons.extension_rounded,
    'audio_choice' => Icons.hearing_rounded,
    'number_recognition' || 'arithmetic' => Icons.pin_outlined,
    'jigsaw' || 'shape_complete' => Icons.extension_rounded,
    _ => Icons.touch_app_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final introText = source.intro.text.of();
    // Don't repeat the title.
    final intro = introText.trim() == source.activity.title.of().trim()
        ? ''
        : introText;
    final firstKind = '${source.rawItems.first['kind']}';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CharacterArt(Character.bolt, mood: Mood.happy),
                const SizedBox(width: Space.s6),
                Container(
                  width: Sizes.kidsBuddyTile,
                  height: Sizes.kidsBuddyTile,
                  decoration: const BoxDecoration(
                    color: AppColors.kidsPlaySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    kindIcon(firstKind),
                    size: Sizes.tapKids,
                    color: AppColors.kidsPlayInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.s6),
            Semantics(
              container: true,
              header: true,
              child: Text(
                source.activity.title.of(),
                style: KidsText.title,
                textAlign: TextAlign.center,
              ),
            ),
            if (intro.isNotEmpty) ...[
              const SizedBox(height: Space.s3),
              Text(
                intro,
                style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (source.levels.length > 1) ...[
              const SizedBox(height: Space.s6),
              Wrap(
                spacing: Space.s4,
                runSpacing: Space.s4,
                alignment: WrapAlignment.center,
                children: [
                  for (final (i, l) in source.levels.indexed)
                    PillChoice(
                      label: l.label.isEmpty ? 'Level ${i + 1}' : l.label.of(),
                      semanticLabel:
                          'Level ${i + 1} of ${source.levels.length}: '
                          '${l.label.isEmpty ? 'Level ${i + 1}' : l.label.of()}',
                      selected: l.id == source.levelId,
                      onSelected: () => onLevel(l.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Space.s8),
            Wrap(
              spacing: Space.s5,
              runSpacing: Space.s5,
              alignment: WrapAlignment.center,
              children: [
                KidsButton(
                  label: 'Play',
                  icon: Icons.play_arrow_rounded,
                  size: KidsButtonSize.xl,
                  fill: AppColors.kidsMeFill,
                  onPressed: onPlay,
                ),
                KidsIconButton(
                  icon: Icons.volume_up_rounded,
                  label: 'Listen',
                  onPressed: onListen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The question area with its top bar and the feedback panel.
class _Playing extends ConsumerWidget {
  const _Playing({
    required this.view,
    required this.onPause,
    required this.onListen,
    required this.onHint,
    required this.submit,
    required this.onRetry,
    required this.onNext,
    required this.speak,
    required this.sound,
  });

  final PlayerView view;
  final VoidCallback onPause;
  final VoidCallback onListen;
  final VoidCallback onHint;
  final void Function(ItemAnswer) submit;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final void Function(String) speak;
  final void Function(Sfx) sound;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = view.run!;
    final spec = run.item;
    final registry = ref.watch(kindRegistryProvider);
    final fb = run.phase == PlayPhase.feedback ? run.feedback : null;
    final ctx = ItemViewContext(
      spec: spec,
      hint: view.hint,
      feedback: fb,
      solution: fb == FeedbackKind.revealed ? registry.solution(spec) : null,
      submit: submit,
      speak: speak,
      policy: view.policy,
      sound: sound,
      paused: run.resumedAt == null,
    );
    final audioOnly = spec is ChoiceSpec && spec.audioOnly;
    final wide = WindowClass.of(context).isAtLeastMedium;
    final hintOffer =
        fb == FeedbackKind.tryAgain &&
        view.policy.offerHintAfterWrong &&
        run.current.hintLevel == 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Space.s5),
          child: Row(
            children: [
              KidsIconButton(
                icon: Icons.pause_rounded,
                label: 'Pause',
                onPressed: onPause,
              ),
              const SizedBox(width: Space.s4),
              Expanded(
                child: ItemDots(
                  total: run.items.length,
                  index: run.index,
                  done: [for (final p in run.progress) p.done],
                ),
              ),
              const SizedBox(width: Space.s4),
              KidsIconButton(
                icon: Icons.lightbulb_rounded,
                label: 'Hint',
                onPressed: fb == null ? onHint : null,
              ),
              const SizedBox(width: Space.s3),
              KidsIconButton(
                icon: Icons.volume_up_rounded,
                label: 'Hear it again',
                onPressed: onListen,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            // Each question starts at the top (not where the last one was scrolled to).
            key: PageStorageKey('${run.sessionId}/${run.index}'),
            padding: EdgeInsets.symmetric(
              horizontal: wide ? Space.s10 : Space.s5,
              vertical: Space.s3,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Sizes.uiContentMax * 0.75,
                ),
                child: Column(
                  children: [
                    PromptBar(
                      prompt: spec.prompt,
                      onListen: onListen,
                      audioOnly: audioOnly,
                      extra: view.hint.text.isEmpty
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(top: Space.s3),
                              child: TypeHint(text: view.hint.text.of()),
                            ),
                    ),
                    const SizedBox(height: Space.s6),
                    KeyedSubtree(
                      key: ValueKey(
                        // one view per item: it clears itself on "Try again" (keeping the
                        // wrong pick visible while the feedback shows)
                        '${run.sessionId}/${run.index}',
                      ),
                      child: ref
                          .watch(itemViewRegistryProvider)
                          .build(context, ctx),
                    ),
                    const SizedBox(height: Space.s12 + Space.s10),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: Motion.base,
          transitionBuilder: (child, a) => SizeTransition(
            sizeFactor: a,
            alignment: Alignment.topCenter,
            child: child,
          ),
          child: fb == null
              ? const SizedBox.shrink()
              : _FeedbackPanel(
                  key: ValueKey(fb),
                  kind: fb,
                  mistakes: run.current.mistakes,
                  isLast: run.isLast,
                  hintOffer: hintOffer,
                  onRetry: onRetry,
                  onNext: onNext,
                  onHint: () {
                    onRetry();
                    onHint();
                  },
                ),
        ),
      ],
    );
  }
}

class TypeHint extends StatelessWidget {
  const TypeHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Hint: $text',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s5,
          vertical: Space.s3,
        ),
        decoration: BoxDecoration(
          color: AppColors.kidsListenSoft,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lightbulb_rounded, color: AppColors.kidsListenInk),
            const SizedBox(width: Space.s3),
            Flexible(
              child: Text(
                text,
                style: KidsText.body.copyWith(color: AppColors.kidsListenInk),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    super.key,
    required this.kind,
    required this.mistakes,
    required this.isLast,
    required this.hintOffer,
    required this.onRetry,
    required this.onNext,
    required this.onHint,
  });

  final FeedbackKind kind;
  final int mistakes;
  final bool isLast;
  final bool hintOffer;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    final (color, ink, icon, title) = switch (kind) {
      FeedbackKind.correct => (
        AppColors.kidsMeSoft,
        AppColors.kidsSuccess,
        Icons.celebration_rounded,
        mistakes == 0 ? 'Great job!' : 'You did it!',
      ),
      FeedbackKind.tryAgain => (
        AppColors.kidsPlaySoft,
        AppColors.kidsPlayInk,
        Icons.replay_rounded,
        'Almost! Try again.',
      ),
      FeedbackKind.revealed => (
        AppColors.kidsLearnSoft,
        AppColors.kidsLearnInk,
        Icons.visibility_rounded,
        "Here's the answer!",
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          Space.s7,
          Space.s6,
          Space.s7,
          Space.s6,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.x2xl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.s5,
            runSpacing: Space.s4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Pop(
                    child: Icon(icon, color: ink, size: Sizes.tapKids),
                  ),
                  const SizedBox(width: Space.s4),
                  Text(title, style: KidsText.title.copyWith(color: ink)),
                ],
              ),
              Wrap(
                spacing: Space.s4,
                runSpacing: Space.s4,
                children: [
                  if (kind == FeedbackKind.tryAgain) ...[
                    if (hintOffer)
                      KidsButton.soft(
                        label: 'Show me a hint',
                        icon: Icons.lightbulb_rounded,
                        onPressed: onHint,
                      ),
                    KidsButton(
                      label: 'Try again',
                      icon: Icons.replay_rounded,
                      fill: AppColors.kidsPlayFill,
                      onPressed: onRetry,
                    ),
                  ] else
                    KidsButton(
                      label: isLast ? 'Finish' : 'Next',
                      trailingIcon: Icons.arrow_forward_rounded,
                      fill: AppColors.kidsMeFill,
                      onPressed: onNext,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pop extends StatelessWidget {
  const _Pop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: Motion.slow,
      curve: Motion.easeBounce,
      builder: (context, t, c) => Transform.scale(scale: t, child: c),
      child: child,
    );
  }
}

/// "You did it!": celebration stars, the star from the server, and where to go next.
class _Completion extends ConsumerWidget {
  const _Completion({
    required this.view,
    required this.args,
    required this.onAgain,
    required this.onNextLevel,
    required this.onExit,
  });

  final PlayerView view;
  final PlayArgs args;
  final VoidCallback onAgain;
  final VoidCallback onNextLevel;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = view.run!;
    final stars = run.celebrationStars;
    final outcome = view.outcome;
    final next = _nextActivity(ref);
    final nextLevel = view.source?.nextLevel;
    final summary = RunSummary.of(run).lines;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              label: '$stars of 3 stars',
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      _Pop(
                        child: Icon(
                          i < stars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: Sizes.tapKidsXl,
                          color: i < stars
                              ? AppColors.kidsStar
                              : AppColors.kidsLine,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const CharacterArt(
              Character.pip,
              size: Sizes.kidsBuddyTile + Space.s8,
              mood: Mood.happy,
            ),
            const SizedBox(height: Space.s4),
            Semantics(
              container: true,
              header: true,
              child: Text(
                'You did it!',
                style: KidsText.display,
                textAlign: TextAlign.center,
              ),
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: Space.s3),
              Text(
                summary.join('  ·  '),
                style: KidsText.heading,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: Space.s3),
            Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                view.syncing
                    ? 'Saving…'
                    : view.savedOffline
                    ? 'Saved on this device. It will be sent when you are online.'
                    : outcome?.starAwarded ?? false
                    ? 'You earned a star today!'
                    : outcome?.courseCompleted ?? false
                    ? 'You finished the whole course!'
                    : 'All done!',
                style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Space.s8),
            Wrap(
              spacing: Space.s5,
              runSpacing: Space.s5,
              alignment: WrapAlignment.center,
              children: [
                if (nextLevel != null)
                  KidsButton(
                    label: 'Next level',
                    semanticLabel:
                        'Next level: ${nextLevel.label.isEmpty ? 'harder' : nextLevel.label.of()}',
                    trailingIcon: Icons.trending_up_rounded,
                    size: KidsButtonSize.xl,
                    fill: AppColors.kidsMeFill,
                    onPressed: onNextLevel,
                  )
                else if (next != null)
                  KidsButton(
                    label: next.$2,
                    trailingIcon: Icons.arrow_forward_rounded,
                    size: KidsButtonSize.xl,
                    fill: AppColors.kidsMeFill,
                    onPressed: () => context.pushReplacement(next.$1),
                  ),
                KidsButton.soft(
                  label: 'Play again',
                  icon: Icons.replay_rounded,
                  onPressed: onAgain,
                ),
                KidsButton.soft(
                  label: args.courseId == null ? 'Home' : 'Back to the island',
                  icon: args.courseId == null
                      ? Icons.home_rounded
                      : Icons.map_rounded,
                  onPressed: onExit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// In a lesson: the next step (from the server's answer, else the rules). Otherwise the next
  /// suggested game the child can open.
  (String, String)? _nextActivity(WidgetRef ref) {
    final d = ref.watch(kidsDataProvider).value;
    if (d == null) return null;
    if (args.courseId != null) {
      final tree = ref.watch(courseTreeProvider(args.courseId!)).value;
      if (tree == null) return null;
      final done = {
        ...d.progress.completedStepIds,
        if (args.stepId != null && (view.outcome?.stepCompleted ?? false))
          args.stepId!,
      };
      final ns = ProgressRules.nextStep(tree, done);
      if (ns == null || ns.step.id == args.stepId) return null;
      return (
        Uri(
          path: Routes.play(ns.step.activity.id),
          queryParameters: {'course': args.courseId, 'step': ns.step.id},
        ).toString(),
        'Next step',
      );
    }
    final picks = Recommendations.forChild(
      d.catalog,
      d.progress,
      ageMonths: d.ageMonths,
      hasPlus: d.hasPlus,
      limit: 20,
    );
    final pick = picks
        .where(
          (a) =>
              a.id != args.activityId &&
              !d.locked(a) &&
              a.type == ActivityType.game,
        )
        .firstOrNull;
    if (pick == null) return null;
    return (Routes.play(pick.id), 'Next game');
  }
}

/// Source of a play route from its query (`?from=` …).
PlaySource playSourceFrom(String? v, {required bool fromCourse}) => fromCourse
    ? PlaySource.course
    : PlaySource.values.firstWhere(
        (s) => s.name == v,
        orElse: () => PlaySource.feed,
      );
