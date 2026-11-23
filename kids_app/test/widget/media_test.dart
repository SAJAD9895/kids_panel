import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kids_app/app/router/routes.dart';
import 'package:kids_app/core/audio/speech.dart';
import 'package:kids_app/core/error/failure.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/features/learning/domain/progress.dart';
import 'package:kids_app/features/media/data/media_data.dart';
import 'package:kids_app/features/play/data/play_data.dart';
import 'package:kids_app/features/play/domain/session_report.dart';

import '../helpers/fake_media.dart';
import '../helpers/test_app.dart';

/// Phase 11: videos, songs and stories through the real screens, on the demo backend with fake
/// players (no plugins): playback, resume, interruptions, network trouble, parental controls,
/// limits, background music, story narration, and layout at three sizes.
void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(
    () => TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue(),
  );

  late DemoBackend demo;
  late FakeMedia media;
  late RecordingSpeechService speech;
  late MemorySessionStore store;
  late MemoryMediaPositionStore positions;

  Future<void> signIn(
    WidgetTester tester, {
    String email = 'alice@example.test',
    String child = 'Mia',
    Size size = tablet,
    void Function(DemoBackend)? before,
  }) async {
    demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
    before?.call(demo);
    media = FakeMedia();
    speech = RecordingSpeechService();
    store = MemorySessionStore();
    positions = MemoryMediaPositionStore();
    await pumpApp(
      tester,
      size: size,
      backend: demo,
      media: media,
      speech: speech,
      store: store,
      positions: positions,
    );
    if (email == 'alice@example.test') {
      await demo.signInWithPassword(
        email: email,
        password: DemoBackend.alicePassword,
      );
    } else {
      await demo.signInWithPassword(
        email: email,
        password: DemoBackend.alicePassword,
      );
    }
    await tester.pumpAndSettle();
    if (find.text("Who's playing?").evaluate().isNotEmpty) {
      await tapLabel(tester, child);
    }
  }

  Future<void> open(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location);
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.dragUntilVisible(
      f,
      find.byType(ListView).first,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
  }

  List<SessionReport> reports(String id) =>
      demo.received.where((r) => r.activityId == id).toList();

  // ------------------------------------------------------------------------------------------
  // Video library
  // ------------------------------------------------------------------------------------------

  testWidgets(
    'Watch: featured, picked for you, categories; search, filters, nothing found',
    (tester) async {
      await signIn(tester);
      await tapLabel(tester, 'Watch');
      expect(find.text('Featured'), findsWidgets);
      expect(find.text('Picked for you'), findsOneWidget);
      expect(find.text('Shapes all around'), findsWidgets);
      // only videos here
      expect(find.text('Moon lullaby'), findsNothing);

      await tester.enterText(find.byType(TextField), 'rain why');
      await tester.pumpAndSettle();
      expect(find.text('1 found'), findsOneWidget);
      expect(find.text('Why does it rain?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'dinosaur');
      await tester.pumpAndSettle();
      expect(find.text('Nothing found'), findsOneWidget);
      await tapLabel(tester, 'Clear search');
      expect(find.text('Picked for you'), findsOneWidget);

      await tapLabel(tester, 'Category Colour fun');
      expect(find.text('2 found'), findsOneWidget);
      await tapLabel(tester, 'Subject Art');
      expect(find.text('1 found'), findsOneWidget);
      expect(find.text('Rainbow colours'), findsOneWidget);
      await tapLabel(tester, 'Only short ones, 1 minute or less');
      expect(find.text('1 found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('video details: info, related videos, Play opens the player', (
    tester,
  ) async {
    await signIn(tester);
    await open(tester, Routes.video('shapes-all-around'));
    expect(find.text('Shapes all around'), findsWidgets);
    expect(find.text('Colour fun'), findsOneWidget);
    expect(find.text('More to watch'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Rainbow colours')), findsWidgets);
    await tapLabel(tester, 'Play');
    expect(
      find.bySemanticsLabel(RegExp('^Video: Shapes all around')),
      findsOneWidget,
    );
    expect(
      media.video.opened!.url,
      'asset:assets/dev_media/video/shapes-all-around/mp4/540p.mp4',
    );
    expect(media.video.captionsFile!.url, endsWith('/subs/en.vtt'));
  });

  // ------------------------------------------------------------------------------------------
  // Video player
  // ------------------------------------------------------------------------------------------

  testWidgets(
    'video: captions, speed, skip, full screen; watching to the end is saved',
    (tester) async {
      await signIn(tester);
      await open(tester, Routes.videoPlay('shapes-all-around'));
      final v = media.video;
      expect(v.value.playing, isTrue, reason: 'starts by itself');
      expect(reports('shapes-all-around').single.status, SessionStatus.started);

      v.caption('A circle is round.');
      await tester.pump();
      expect(find.text('A circle is round.'), findsOneWidget);
      await tapLabel(tester, 'Captions on');
      expect(find.text('A circle is round.'), findsNothing);
      await tapLabel(tester, 'Captions off');
      expect(find.text('A circle is round.'), findsOneWidget);

      await tapLabel(tester, 'Speed 1×. Change to 1.25×');
      expect(v.calls, contains('speed 1.25'));
      await tapLabel(tester, 'Forward 10 seconds');
      expect(v.value.position, const Duration(seconds: 10));
      await tapLabel(tester, 'Back 10 seconds');
      expect(v.value.position, Duration.zero);

      await tapLabel(tester, 'Full screen');
      expect(find.bySemanticsLabel('Exit full screen'), findsOneWidget);
      await tester.pump(
        const Duration(seconds: 5),
      ); // controls hide while playing
      expect(find.bySemanticsLabel('Exit full screen'), findsNothing);
      await tester.tap(
        find.bySemanticsLabel(RegExp('^Video: Shapes all around')),
      );
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Exit full screen');

      await tapLabel(tester, 'Pause');
      expect(v.value.playing, isFalse);
      await tapLabel(tester, 'Play');
      v.advance(const Duration(seconds: 40));
      await tester.pumpAndSettle();
      expect(find.text('You watched it all!'), findsOneWidget);
      final done = reports('shapes-all-around').last;
      expect((done.status, done.completed), (SessionStatus.completed, true));
      expect(done.extra['positionMs'], 32000);
      expect(
        (await positions.positions('child-mia'))['shapes-all-around'],
        isNull,
      );
      expect(demo.progress['child-mia']!.starsToday, greaterThan(0));
      expect(find.bySemanticsLabel(RegExp('^Next: ')), findsOneWidget);
      await tapLabel(tester, 'Watch again');
      expect(v.value.position, Duration.zero);
      expect(v.value.playing, isTrue);
    },
  );

  testWidgets(
    'video: leaving early saves the place; Keep watching; continue or start again',
    (tester) async {
      await signIn(tester);
      await open(tester, Routes.videoPlay('rainbow-colours'));
      media.video.advance(const Duration(seconds: 12));
      await tester.pump();
      await tapLabel(tester, 'Close');
      final left = reports('rainbow-colours').last;
      expect(
        (left.status, left.extra['positionMs']),
        (SessionStatus.abandoned, 12000),
      );
      expect(media.video.disposed, isTrue);

      await tapLabel(tester, 'Watch');
      await scrollTo(tester, find.text('Keep watching'));
      expect(
        find.bySemanticsLabel(RegExp(r'^\d+ percent watched')),
        findsOneWidget,
      );

      await open(tester, Routes.video('rainbow-colours'));
      expect(find.text('Keep watching'), findsOneWidget);
      expect(find.text('You stopped at 0:12'), findsOneWidget);
      await tapLabel(tester, 'Keep watching');
      expect(media.video.openedAt, const Duration(seconds: 12));
      expect(find.text('Carrying on from 0:12'), findsOneWidget);
      await tapLabel(tester, 'Start again');
      expect(media.video.value.position, Duration.zero);
    },
  );

  testWidgets(
    'video: a network error, slow internet, and opening while offline',
    (tester) async {
      await signIn(tester);
      media.failNextOpen = true;
      await open(tester, Routes.videoPlay('shapes-all-around'));
      expect(find.text('Oops!'), findsOneWidget);
      await tapLabel(tester, 'Try again');
      expect(find.text('Oops!'), findsNothing);
      expect(media.video.value.playing, isTrue);

      media.video.advance(const Duration(seconds: 6));
      media.video.buffering(true);
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('^Loading')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('Slow internet… still loading'), findsOneWidget);
      media.video.buffering(false);
      await tester.pump();
      expect(find.text('Slow internet… still loading'), findsNothing);

      media.video.fail();
      await tester.pump();
      expect(find.text('Oops!'), findsOneWidget);
      await tapLabel(tester, 'Try again');
      expect(
        media.video.openedAt,
        const Duration(seconds: 6),
        reason: 'reopens where it stopped',
      );
      await tapLabel(tester, 'Close');

      demo.failNextLaunch = const NetworkFailure();
      await open(tester, Routes.videoPlay('rainbow-colours'));
      expect(find.text("You're offline"), findsOneWidget);
      await tapLabel(tester, 'Try again');
      expect(
        find.bySemanticsLabel(RegExp('^Video: Rainbow colours')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'video: pauses when the app goes to the background (a call, the home button)',
    (tester) async {
      await signIn(tester);
      await open(tester, Routes.videoPlay('shapes-all-around'));
      expect(media.video.value.playing, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(media.video.value.playing, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Play'),
        findsOneWidget,
        reason: 'waits for the child to press play',
      );
    },
  );

  testWidgets('video from a course island completes that step', (tester) async {
    await signIn(tester);
    await open(tester, '${Routes.videoPlay('shapes-all-around')}?step=step-x');
    media.video.advance(const Duration(seconds: 40));
    await tester.pumpAndSettle();
    final done = reports('shapes-all-around').last;
    expect(
      (done.completed, done.lessonStepId, done.source),
      (true, 'step-x', PlaySource.course),
    );
  });

  // ------------------------------------------------------------------------------------------
  // Parental controls and limits
  // ------------------------------------------------------------------------------------------

  testWidgets(
    'parent turns videos off and a category off: hidden for the child, refused if opened',
    (tester) async {
      await signIn(
        tester,
        before: (d) {
          d.progress['child-mia'] =
              (d.progress['child-mia'] ?? ChildProgress.empty).copyWith(
                sections: const SectionSwitches(watch: false),
                controls: const MediaControls(
                  blockedCategoryIds: {'category-bedtime'},
                ),
              );
        },
      );
      expect(find.bySemanticsLabel('Watch'), findsNothing);
      await open(tester, Routes.videoPlay('shapes-all-around'));
      expect(find.text('Not today'), findsOneWidget);
      await tapLabel(tester, 'Back');

      await tapLabel(tester, 'Listen');
      expect(find.text('Tidy-up tune'), findsWidgets);
      expect(find.text('Moon lullaby'), findsNothing);
      expect(find.text('The sleepy cloud'), findsNothing);
      await open(tester, Routes.song('moon-lullaby'));
      expect(find.text('Not today'), findsOneWidget);
    },
  );

  testWidgets(
    'a daily limit: watching stops with "That\'s all for today!", games stay open',
    (tester) async {
      await signIn(
        tester,
        before: (d) {
          d.progress['child-mia'] =
              (d.progress['child-mia'] ?? ChildProgress.empty).copyWith(
                controls: const MediaControls(
                  dailyLimitMinutes: 5,
                  limitedSections: {'watch', 'listen'},
                ),
              );
          d.usage['child-mia'] = {'watch': 280};
        },
      );
      await open(tester, Routes.videoPlay('shapes-all-around'));
      expect(media.video.value.playing, isTrue);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text("That's all for today!"), findsOneWidget);
      expect(media.video.value.playing, isFalse);
      expect(find.bySemanticsLabel('Grown-ups'), findsOneWidget);
      await tapLabel(tester, 'Back');
      await open(tester, Routes.story('pip-and-the-lost-seed'));
      expect(
        find.text("That's all for today!"),
        findsOneWidget,
        reason: 'stories count too',
      );
      await tapLabel(tester, 'Back');
      await open(tester, Routes.play('engine-sampler'));
      expect(
        find.text('Try everything!'),
        findsOneWidget,
        reason: 'games are never limited',
      );
    },
  );

  testWidgets(
    'parents: Media and screen time — switches, categories, limit, saved',
    (tester) async {
      await signIn(tester);
      await tapLabel(tester, 'Grown-ups');
      for (final d in ['5', '2', '8']) {
        await tapLabel(tester, d);
      }
      await tapText(tester, 'Manage children');
      await tapText(tester, 'Mia');
      await tester.dragUntilVisible(
        find.text('Media and screen time'),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      await tapText(tester, 'Media and screen time');
      expect(find.text('Mia: media and screen time'), findsOneWidget);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Videos'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.widgetWithText(SwitchListTile, 'Bedtime'),
        find.byType(ListView).last,
        const Offset(0, -150),
      );
      await tester.tap(find.widgetWithText(SwitchListTile, 'Bedtime'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('No limit'),
        find.byType(ListView).last,
        const Offset(0, -150),
      );
      await tester.tap(find.text('No limit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 minutes').last);
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Save'),
        find.byType(ListView).last,
        const Offset(0, -150),
      );
      await tapText(tester, 'Save');
      expect(find.text('Saved'), findsOneWidget);
      final p = demo.progress['child-mia']!;
      expect(p.sections.watch, isFalse);
      expect(p.controls.blockedCategoryIds, {'category-bedtime'});
      expect(p.controls.dailyLimitMinutes, 30);
    },
  );

  testWidgets('Plus stories need Plus: a Basic family sees "Ask a grown-up!"', (
    tester,
  ) async {
    await signIn(tester);
    demo.setFamilyPlus(false);
    await open(tester, Routes.story('the-sleepy-cloud'));
    expect(find.text('Ask a grown-up!'), findsOneWidget);
    await tapLabel(tester, 'Back');
    await open(tester, Routes.story('pip-and-the-lost-seed'));
    expect(
      find.text('Page 1 of 6'),
      findsOneWidget,
      reason: 'free stories open',
    );
  });

  // ------------------------------------------------------------------------------------------
  // Songs
  // ------------------------------------------------------------------------------------------

  testWidgets(
    'songs: play, pause, next, previous, repeat, shuffle; a song ending plays the next',
    (tester) async {
      await signIn(tester);
      await open(tester, Routes.song('counting-train'));
      var a = media.audio;
      expect(a.opened!.url, endsWith('songs/counting-train/en.m4a'));
      expect(a.nowPlaying!.title, 'The counting train');
      expect(a.value.playing, isTrue);
      await tapLabel(tester, 'Pause');
      expect(a.value.playing, isFalse);
      await tapLabel(tester, 'Play');
      expect(a.value.playing, isTrue);

      await tapLabel(tester, 'Next');
      expect(a.opened!.url, endsWith('ten-little-seeds/en.m4a'));
      expect(reports('counting-train').last.status, SessionStatus.abandoned);
      await tapLabel(tester, 'Previous');
      expect(
        a.opened!.url,
        endsWith('counting-train/en.m4a'),
        reason: 'under 3 s: the song before',
      );
      a.advance(const Duration(seconds: 10));
      await tapLabel(tester, 'Previous');
      expect(
        a.value.position,
        Duration.zero,
        reason: 'over 3 s: the same song restarts',
      );
      expect(a.opened!.url, endsWith('counting-train/en.m4a'));

      await tapLabel(tester, 'Repeat off');
      expect(find.bySemanticsLabel('Repeat all'), findsOneWidget);
      await tapLabel(tester, 'Repeat all');
      expect(find.bySemanticsLabel('Repeat this song'), findsOneWidget);
      a.advance(
        const Duration(minutes: 2),
      ); // ends → repeat one: the same song again
      await tester.pumpAndSettle();
      expect(a.opened!.url, endsWith('counting-train/en.m4a'));
      expect(reports('counting-train').where((r) => r.completed), hasLength(1));
      await tapLabel(tester, 'Repeat this song');
      a.advance(const Duration(minutes: 2)); // ends → the next song
      await tester.pumpAndSettle();
      expect(a.opened!.url, endsWith('ten-little-seeds/en.m4a'));

      await tapLabel(tester, 'Shuffle off');
      expect(find.bySemanticsLabel('Shuffle on'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Ten little seeds, playing now'),
        findsOneWidget,
      );
      await tapLabel(tester, 'Moon lullaby');
      expect(a.opened!.url, endsWith('moon-lullaby/en.m4a'));
      a = media.audio;
      expect(media.audios, hasLength(1), reason: 'one player for every song');
    },
  );

  testWidgets(
    'a song opened from the library plays that song, in a list of every song',
    (tester) async {
      await signIn(tester);
      await open(tester, Routes.song('moon-lullaby'));
      expect(media.audio.opened!.url, endsWith('moon-lullaby/en.m4a'));
      expect(
        find.bySemanticsLabel('Moon lullaby, playing now'),
        findsOneWidget,
      );
      for (final t in [
        'The counting train',
        'Ten little seeds',
        'How do you feel?',
        'Tidy-up tune',
      ]) {
        expect(find.bySemanticsLabel(t), findsOneWidget, reason: t);
      }
    },
  );

  testWidgets(
    'songs keep playing while browsing (mini player); stop closes it',
    (tester) async {
      await signIn(tester);
      await open(tester, Routes.song('tidy-up-tune'));
      await tapLabel(tester, 'Close player');
      expect(
        find.bySemanticsLabel('Now playing: Tidy-up tune. Open the player'),
        findsOneWidget,
      );
      await tapLabel(tester, 'Home');
      expect(
        media.audio.value.playing,
        isTrue,
        reason: 'still playing on another screen',
      );
      expect(media.audio.disposed, isFalse);
      await tapLabel(tester, 'Pause');
      expect(media.audio.value.playing, isFalse);
      await tapLabel(tester, 'Now playing: Tidy-up tune. Open the player');
      expect(find.text('Tidy-up tune'), findsWidgets);
      await tapLabel(tester, 'Close player');
      await tapLabel(tester, 'Stop the music');
      expect(find.bySemanticsLabel(RegExp('^Now playing')), findsNothing);
      expect(media.audio.disposed, isTrue);
      expect(reports('tidy-up-tune').last.status, SessionStatus.abandoned);
    },
  );

  // ------------------------------------------------------------------------------------------
  // Stories
  // ------------------------------------------------------------------------------------------

  testWidgets(
    'stories: narration sentence by sentence, pause, page turns, progress, the end',
    (tester) async {
      await signIn(tester);
      speech.holdNarration = true;
      await open(tester, Routes.story('pip-and-the-lost-seed'));
      expect(find.text('Page 1 of 6'), findsOneWidget);
      expect(find.text('Pip had one tiny seed.'), findsOneWidget);
      await tapLabel(tester, 'Read to me');
      await tapLabel(tester, 'Read this page to me');
      expect(speech.narrated.last, 'Pip had one tiny seed.');
      speech.finishNarration();
      await tester.pump();
      expect(speech.narrated.last, '"Where shall I plant you?" asked Pip.');
      await tapLabel(tester, 'Pause reading');
      expect(speech.narrating, isFalse);
      expect(find.bySemanticsLabel('Read this page to me'), findsOneWidget);

      await tapLabel(tester, 'Next page');
      expect(find.text('Page 2 of 6'), findsOneWidget);
      await tester.fling(find.text('Whoosh!'), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Page 3 of 6'), findsOneWidget);
      await tapLabel(tester, 'Previous page');
      expect(find.text('Page 2 of 6'), findsOneWidget);
      // tap a sentence to hear it
      await tapLabel(tester, 'Whoosh!');
      expect(speech.said.last, 'Whoosh!');

      // "Read to me" turns the pages by itself
      await tapLabel(tester, 'Read to me');
      speech.holdNarration = false;
      await tapLabel(tester, 'Read this page to me');
      speech.holdNarration =
          true; // page 3 waits, so the reading can be paused there
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Page 3 of 6'), findsOneWidget);
      await tapLabel(tester, 'Pause reading');

      for (var i = 0; i < 3; i++) {
        await tapLabel(tester, 'Next page');
      }
      expect(find.text('Page 6 of 6'), findsOneWidget);
      expect(find.text('The end!'), findsOneWidget);
      final done = reports('pip-and-the-lost-seed').last;
      expect(
        (done.status, done.extra['page'], done.extra['pages']),
        (SessionStatus.completed, 5, 6),
      );
      await tapLabel(tester, 'Read again');
      expect(find.text('Page 1 of 6'), findsOneWidget);
    },
  );

  testWidgets('stories: leaving saves the page; Continue reading opens there', (
    tester,
  ) async {
    await signIn(tester);
    await open(tester, Routes.story('nova-counts-the-stars'));
    await tapLabel(tester, 'Next page');
    await tapLabel(tester, 'Next page');
    await tapLabel(tester, 'Close');
    final left = reports('nova-counts-the-stars').last;
    expect((left.status, left.extra['page']), (SessionStatus.abandoned, 2));

    await tapLabel(tester, 'Listen');
    await scrollTo(tester, find.text('Keep reading and listening'));
    expect(find.bySemanticsLabel('Page 3 of 6'), findsOneWidget);
    await open(tester, Routes.story('nova-counts-the-stars'));
    expect(find.text('Page 3 of 6'), findsOneWidget);
    expect(find.text('Carrying on from page 3'), findsOneWidget);
    await tapLabel(tester, 'Start at the beginning');
    expect(find.text('Page 1 of 6'), findsOneWidget);
  });

  testWidgets('stories: the app going to the background stops the narration', (
    tester,
  ) async {
    await signIn(tester);
    speech.holdNarration = true;
    await open(tester, Routes.story('pip-and-the-lost-seed'));
    await tapLabel(tester, 'Read this page to me');
    expect(speech.narrating, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(speech.narrating, isFalse);
    // frames resume with the app; the button shows "read" again (nothing restarts on its own)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Read this page to me'), findsOneWidget);
    expect(speech.narrating, isFalse);
  });

  // ------------------------------------------------------------------------------------------
  // Layout
  // ------------------------------------------------------------------------------------------

  for (final (name, size) in [
    ('phone landscape', phoneLandscape),
    ('tablet', tablet),
    ('desktop', desktop),
  ]) {
    testWidgets('layout ($name): libraries, video, song and story players', (
      tester,
    ) async {
      await signIn(tester, size: size);
      final handle = tester.ensureSemantics();
      Future<void> check(String what, {bool contrast = true}) async {
        await expectLater(
          tester,
          meetsGuideline(iOSTapTargetGuideline),
          reason: what,
        );
        await expectLater(
          tester,
          meetsGuideline(labeledTapTargetGuideline),
          reason: what,
        );
        if (contrast) {
          await expectLater(
            tester,
            meetsGuideline(textContrastGuideline),
            reason: what,
          );
        }
        expect(tester.takeException(), isNull, reason: what);
      }

      await tapLabel(tester, 'Watch');
      await check('watch');
      await tapLabel(tester, 'Listen');
      await check('listen');
      await open(tester, Routes.video('pip-meets-a-snail'));
      await check('video details');
      await open(tester, Routes.videoPlay('pip-meets-a-snail'));
      media.video.caption("Hello! I'm Pip.");
      await tester.pump();
      await check('video player');
      await tapLabel(tester, 'Close');
      await open(tester, Routes.song('moon-lullaby'));
      await check('song player');
      await tapLabel(tester, 'Close player');
      await tapLabel(tester, 'Listen'); // a known page under the mini player
      // Contrast is skipped here only: the checker misreads text cut by the edge of the
      // scrolling page above the bar. The bar itself is ink on listen-soft (a checked token pair).
      await check('mini player', contrast: false);
      await open(tester, Routes.story('nova-counts-the-stars'));
      await check('story reader');
      handle.dispose();
    });
  }
}
