import 'package:flutter/painting.dart';

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/app/bootstrap.dart';
import 'package:kids_app/app/config/app_config.dart';
import 'package:kids_app/app/providers.dart';
import 'package:kids_app/core/error/error_mapper.dart';
import 'package:kids_app/core/error/failure.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/demo/demo_media.g.dart';
import 'package:kids_app/demo/demo_media_catalog.dart';
import 'package:kids_app/features/learning/data/supabase_learning_repositories.dart';
import 'package:kids_app/features/learning/domain/catalog.dart';
import 'package:kids_app/features/learning/domain/progress.dart';
import 'package:kids_app/features/media/data/media_data.dart';
import 'package:kids_app/features/media/domain/media.dart';
import 'package:kids_app/features/media/domain/media_repositories.dart';
import 'package:kids_app/features/media/presentation/media_providers.dart';
import 'package:kids_app/features/media/presentation/media_urls.dart';
import 'package:kids_app/features/play/data/play_data.dart';
import 'package:kids_app/features/play/domain/session_report.dart';
import 'package:kids_app/features/play/presentation/play_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 20, 9);

  ActivitySummary act(
    String id, {
    ActivityType type = ActivityType.video,
    String? cat,
    String? subject,
    int min = 24,
    int max = 96,
    int? secs,
    String title = 'Title',
    String descr = '',
  }) => ActivitySummary(
    id: id,
    slug: id,
    type: type,
    title: LocalizedText({'en': title}),
    description: LocalizedText({'en': descr}),
    categoryId: cat,
    subjectId: subject,
    ageMinMonths: min,
    ageMaxMonths: max,
    estimatedSeconds: secs,
  );

  group('launch', () {
    final json = {
      'activityId': 'a1',
      'type': 'story',
      'section': 'listen',
      'contentVersion': 2,
      'remainingSeconds': 120,
      'resume': {'page': 2, 'pages': 6, 'at': '2026-11-20T08:00:00Z'},
      'assets': [
        {
          'role': 'page_image',
          'position': 1,
          'url': 'https://x/2.webp',
          'kind': 'image',
          'text': {'en': 'Two.'},
        },
        {
          'role': 'page_image',
          'position': 0,
          'url': 'https://x/1.webp',
          'kind': 'image',
          'text': {'en': 'One.'},
        },
        {
          'role': 'page_audio',
          'position': 1,
          'url': 'https://x/2.m4a',
          'kind': 'audio',
        },
        {
          'role': 'subtitle',
          'locale': 'es',
          'url': 'https://x/es.vtt',
          'kind': 'subtitle',
        },
        {
          'role': 'subtitle',
          'locale': 'en',
          'url': 'https://x/en.vtt',
          'kind': 'subtitle',
        },
      ],
    };

    test('pages in order with their words and recorded narration', () {
      final l = MediaLaunch.fromJson(json);
      expect(l.type, ActivityType.story);
      expect(l.pages.map((p) => p.text.of()), ['One.', 'Two.']);
      expect(l.pages[0].narration, isNull);
      expect(l.pages[1].narration!.url, 'https://x/2.m4a');
      expect(
        (l.resume!.page, l.resume!.pages, l.remainingSeconds),
        (2, 6, 120),
      );
      expect(l.playable, isTrue);
      expect(l.captions('es')!.url, 'https://x/es.vtt');
      expect(l.captions('fr')!.locale, 'en', reason: 'falls back to English');
    });

    test(
      'a video needs an MP4 (HLS-only is not playable until media/hls exists)',
      () {
        MediaLaunch video(String kind) => MediaLaunch.fromJson({
          'activityId': 'v',
          'type': 'video',
          'assets': [
            {'role': 'video_main', 'url': 'u', 'kind': kind},
          ],
        });
        expect(video('video_mp4').playable, isTrue);
        expect(video('video_hls').playable, isFalse);
        expect(
          MediaLaunch.fromJson({
            'activityId': 's',
            'type': 'song',
            'assets': [],
          }).playable,
          isFalse,
        );
      },
    );

    test(
      'the server\'s refusals become locked states, never generic errors',
      () {
        Failure f(String type, int status) => mapError(
          FunctionException(status: status, details: {'type': type}),
        );
        expect(
          (f('NEEDS_PLUS', 402) as ContentLockedFailure).reason,
          LockReason.needsPlus,
        );
        expect(
          (f('SCREEN_TIME_OVER', 423) as ContentLockedFailure).reason,
          LockReason.screenTimeOver,
        );
        expect(
          (f('CATEGORY_BLOCKED', 423) as ContentLockedFailure).reason,
          LockReason.categoryBlocked,
        );
        expect(
          (f('SECTION_DISABLED', 423) as ContentLockedFailure).reason,
          LockReason.sectionDisabled,
        );
        // Phase 14: a family restricted by support (admin CMS)
        expect(f('ACCOUNT_SUSPENDED', 403), isA<AccountSuspendedFailure>());
        expect(
          (f('AGE_NOT_SUITABLE', 403) as ContentLockedFailure).reason,
          LockReason.ageNotSuitable,
        );
        expect(
          f('CHILD_LIMIT', 402),
          isA<ChildLimitFailure>(),
          reason: 'the old 402 is unchanged',
        );
      },
    );
  });

  group('rules', () {
    ResumePoint at(int ms, {int dur = 36000}) =>
        ResumePoint(positionMs: ms, durationMs: dur, at: t0);

    test('resume: not in the first 5 s, not in the last 5 %', () {
      expect(MediaRules.resumeAt(null), isNull);
      expect(MediaRules.resumeAt(at(4000)), isNull);
      expect(MediaRules.resumeAt(at(12000)), const Duration(seconds: 12));
      expect(MediaRules.resumeAt(at(35000)), isNull);
      expect(at(18000).fraction, 0.5);
    });

    test('finished from 95 % or the last 2 s', () {
      const d = Duration(seconds: 100);
      expect(MediaRules.finished(const Duration(seconds: 94), d), isFalse);
      expect(MediaRules.finished(const Duration(seconds: 95), d), isTrue);
      expect(
        MediaRules.finished(
          const Duration(seconds: 9),
          const Duration(seconds: 10),
        ),
        isTrue,
      );
      expect(MediaRules.finished(Duration.zero, Duration.zero), isFalse);
    });

    test(
      'what a child may see: age, the parent\'s sections and categories',
      () {
        final video = act('v', cat: 'c-bed');
        final song = act('s', type: ActivityType.song, cat: 'c-music');
        bool see(
          ActivitySummary a, {
          SectionSwitches s = const SectionSwitches(),
          Set<String> blocked = const {},
          int age = 50,
        }) => MediaRules.visible(
          a,
          ageMonths: age,
          sections: s,
          controls: MediaControls(blockedCategoryIds: blocked),
        );
        expect(see(video), isTrue);
        expect(see(video, age: 120), isFalse);
        expect(see(video, s: const SectionSwitches(watch: false)), isFalse);
        expect(see(song, s: const SectionSwitches(watch: false)), isTrue);
        expect(see(song, s: const SectionSwitches(listen: false)), isFalse);
        expect(see(video, blocked: {'c-bed'}), isFalse);
        expect(see(song, blocked: {'c-bed'}), isTrue);
      },
    );

    test('continue list: unfinished only, newest first', () {
      final a = act('a'),
          b = act('b'),
          c = act('c'),
          s = act('s', type: ActivityType.story);
      final list = MediaRules.continueList(
        [a, b, c, s],
        {
          'a': ResumePoint(positionMs: 10000, durationMs: 36000, at: t0),
          'b': ResumePoint(
            positionMs: 2000,
            durationMs: 36000,
            at: t0,
          ), // barely started
          'c': ResumePoint(
            positionMs: 20000,
            durationMs: 36000,
            at: t0.add(const Duration(hours: 1)),
          ),
          's': ResumePoint(
            page: 0,
            pages: 6,
            at: t0.subtract(const Duration(hours: 1)),
          ),
        },
      );
      expect(list.map((x) => x.$1.id), ['c', 'a', 's']);
    });

    test(
      'recommended: not played lately first, then nearest the child\'s age',
      () {
        final items = [
          act('old', min: 72, max: 108),
          act('mine', min: 36, max: 72),
          act('seen', min: 36, max: 72),
        ];
        expect(
          MediaRules.recommended(
            items,
            ageMonths: 54,
            recentlyPlayed: {'seen'},
          ).map((a) => a.id),
          ['mine', 'old', 'seen'],
        );
      },
    );

    test(
      'search: every word starts a word, any order, any case; filters combine',
      () {
        final rain = act(
          'r',
          title: 'Why does it rain?',
          descr: 'Nova follows a raindrop',
          subject: 'sci',
          cat: 'weather',
          secs: 36,
        );
        const f = MediaFilter();
        expect(f.copyWith(query: 'RAIN why').matches(rain), isTrue);
        expect(
          f.copyWith(query: 'drop').matches(rain),
          isFalse,
          reason: 'word starts only',
        );
        expect(
          f
              .copyWith(
                query: 'rain',
                subjectId: 'sci',
                categoryId: 'weather',
                maxMinutes: 1,
              )
              .matches(rain),
          isTrue,
        );
        expect(f.copyWith(subjectId: 'art').matches(rain), isFalse);
        expect(
          f.copyWith(query: 'weather').matches(rain, categoryName: 'Weather'),
          isTrue,
        );
        expect(act('long', secs: 200).minutes, 4);
        expect(
          f.copyWith(maxMinutes: 1).matches(act('long', secs: 200)),
          isFalse,
        );
        expect(
          f.copyWith(query: 'x').copyWith(clearSubject: true).isEmpty,
          isFalse,
        );
      },
    );

    test('stories: open on the saved page unless finished; finished on the last page', () {
      ResumePoint page(int p) => ResumePoint(page: p, pages: 6, at: t0);
      expect(StoryRules.startPage(null, 6), 0);
      expect(StoryRules.startPage(page(3), 6), 3);
      expect(StoryRules.startPage(page(5), 6), 0);
      expect(StoryRules.finished(5, 6), isTrue);
      expect(StoryRules.finished(4, 6), isFalse);
    });

    test('sentences: stops, quotes and exclamations stay together', () {
      expect(
        splitSentences(
          'Bird flew past. "Goodnight, little cloud!" she sang. The end!',
        ),
        ['Bird flew past.', '"Goodnight, little cloud!" she sang.', 'The end!'],
      );
      expect(splitSentences('Breathe in... like smelling a flower.'), [
        'Breathe in...',
        'like smelling a flower.',
      ]);
      expect(splitSentences('No stop at the end'), ['No stop at the end']);
    });
  });

  group('song queue', () {
    final ids = ['a', 'b', 'c', 'd'];

    test('next, the end of the list, repeat all wraps, repeat one replays', () {
      var q = SongQueue(ids, start: 'c');
      expect(q.current, 'c');
      q = q.next()!;
      expect(q.current, 'd');
      expect(q.next(), isNull, reason: 'end of the list, no repeat');
      expect(q.afterCompletion(), isNull);
      q = q.cycleRepeat();
      expect(q.repeat, SongRepeat.all);
      expect(q.next()!.current, 'a');
      q = q.cycleRepeat();
      expect(q.repeat, SongRepeat.one);
      expect(q.afterCompletion()!.current, 'd');
      expect(q.next()!.current, 'a', reason: 'the child can still skip');
      expect(q.cycleRepeat().repeat, SongRepeat.off);
    });

    test('previous restarts after 3 s, else goes back', () {
      final q = SongQueue(ids, start: 'b');
      expect(q.previous(const Duration(seconds: 10)).$2, isTrue);
      final (back, restart) = q.previous(const Duration(seconds: 1));
      expect((back.current, restart), ('a', false));
      expect(
        back.previous(Duration.zero).$2,
        isTrue,
        reason: 'first song: restart',
      );
    });

    test('shuffle keeps the current song, plays each once, is repeatable; off restores the order', () {
      final q = SongQueue(
        [for (var i = 0; i < 10; i++) 's$i'],
        start: 's3',
        seed: 7,
      );
      final s = q.toggleShuffle();
      expect(s.shuffle, isTrue);
      expect(s.current, 's3');
      expect(s.order.toSet().length, 10);
      expect(s.order, isNot([for (var i = 0; i < 10; i++) i]));
      expect(q.toggleShuffle().order, s.order, reason: 'same seed, same order');
      final off = s.next()!.toggleShuffle();
      expect(off.shuffle, isFalse);
      expect(off.current, s.next()!.current);
      expect(off.order, [for (var i = 0; i < 10; i++) i]);
      expect(SongQueue(ids).select('c').current, 'c');
      expect(SongQueue(ids).select('zz').current, 'a');
    });
  });

  group('progress', () {
    test(
      'positions from sessions: the newest decisive session per item wins',
      () {
        final rows = [
          {
            'activity_id': 'v1',
            'status': 'started',
            'started_at': '2026-11-20T09:00:00Z',
          },
          {
            'activity_id': 'v1',
            'status': 'abandoned',
            'ended_at': '2026-11-20T08:00:00Z',
            'activity_results': [
              {
                'metrics': {'positionMs': 12000, 'durationMs': 36000},
              },
            ],
          },
          {
            'activity_id': 'v2',
            'status': 'completed',
            'ended_at': '2026-11-20T08:30:00Z',
            'activity_results': {'metrics': {}},
          },
          {
            'activity_id': 'v2',
            'status': 'abandoned',
            'ended_at': '2026-11-20T07:00:00Z',
            'activity_results': {
              'metrics': {'positionMs': 5000},
            },
          },
          {
            'activity_id': 'st',
            'status': 'abandoned',
            'ended_at': '2026-11-20T06:00:00Z',
            'activity_results': {
              'metrics': {'page': 2, 'pages': 6},
            },
          },
          {
            'activity_id': 'game',
            'status': 'abandoned',
            'ended_at': '2026-11-20T06:00:00Z',
            'activity_results': {
              'metrics': {'items': []},
            },
          },
        ];
        final p = positionsFromSessions(rows);
        expect(p.keys.toSet(), {'v1', 'st'});
        expect(p['v1']!.positionMs, 12000);
        expect(p['st']!.page, 2);
      },
    );

    test('reports carry where it stopped, and read it back', () {
      final r = SessionReport(
        sessionId: 's',
        childId: 'c',
        activityId: 'a',
        status: SessionStatus.abandoned,
        startedAt: t0,
        endedAt: t0,
        source: PlaySource.feed,
        platform: 'web',
        appVersion: '1',
        extra: const {'positionMs': 12000, 'durationMs': 36000},
      );
      final json = r.toJson();
      expect(((json['result']! as Map)['metrics'] as Map)['positionMs'], 12000);
      final back = SessionReport.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(back.extra, {'positionMs': 12000, 'durationMs': 36000});
    });

    test('positions on the device: saved, read, cleared; unreadable data is forgotten', () async {
      SharedPreferences.setMockInitialValues({'kl.media.pos.c': 'not json'});
      final store = PrefsMediaPositionStore(
        await SharedPreferences.getInstance(),
      );
      expect(await store.positions('c'), isEmpty);
      await store.save(
        'c',
        'v',
        ResumePoint(positionMs: 9000, durationMs: 36000, at: t0),
      );
      expect((await store.positions('c'))['v']!.positionMs, 9000);
      await store.clear('c', 'v');
      expect(await store.positions('c'), isEmpty);
    });

    test('the parent\'s controls body', () {
      final body = SupabaseMediaRepository.controlsBody(
        const SectionSwitches(watch: false),
        const MediaControls(
          blockedCategoryIds: {'b', 'a'},
          dailyLimitMinutes: 30,
          limitedSections: {'watch', 'listen'},
        ),
      );
      expect(body, {
        'learnEnabled': true,
        'watchEnabled': false,
        'listenEnabled': true,
        'togetherEnabled': true,
        'dailyLimitMinutes': 30,
        'limitedSections': ['listen', 'watch'],
        'blockedCategoryIds': ['a', 'b'],
      });
    });
  });

  group('session tracker', () {
    late DemoBackend demo;
    late ProviderContainer c;
    late MemorySessionStore store;
    late MemoryMediaPositionStore positions;

    setUp(() async {
      demo = DemoBackend(latency: Duration.zero, clock: () => t0);
      await demo.signInWithPassword(
        email: 'alice@example.test',
        password: DemoBackend.alicePassword,
      );
      store = MemorySessionStore();
      positions = MemoryMediaPositionStore();
      c = ProviderContainer(
        overrides: [
          playRepositoryProvider.overrideWithValue(demo),
          mediaRepositoryProvider.overrideWithValue(demo),
          sessionStoreProvider.overrideWithValue(store),
          mediaPositionStoreProvider.overrideWithValue(positions),
          progressRepositoryProvider.overrideWithValue(demo),
        ],
      );
      addTearDown(c.dispose);
    });

    MediaSessionTracker tracker({void Function()? onLocked}) =>
        MediaSessionTracker(
          sync: c.read(syncServiceProvider),
          media: demo,
          positions: positions,
          newId: () => 'sess-1',
          now: () => t0,
          childId: 'child-mia',
          activityId: 'shapes-all-around',
          section: 'watch',
          contentVersion: 1,
          onLocked: onLocked,
        );

    test(
      'start, heartbeats every 30 s, an early end saves where it stopped',
      () async {
        final t = tracker()..start();
        await pumpEventQueue();
        expect(demo.received.single.status, SessionStatus.started);
        for (var i = 0; i < 31; i++) {
          t.tick();
        }
        await pumpEventQueue();
        expect(demo.usage['child-mia']!['watch'], 30);
        await t.end(
          completed: false,
          extra: {'positionMs': 31000, 'durationMs': 32000},
        );
        expect(
          demo.usage['child-mia']!['watch'],
          31,
          reason: 'the last second is sent at the end',
        );
        final end = demo.received.last;
        expect(
          (end.status, end.durationMs, end.extra['positionMs']),
          (SessionStatus.abandoned, 31000, 31000),
        );
        expect(
          (await positions.positions(
            'child-mia',
          ))['shapes-all-around']!.positionMs,
          31000,
        );
        expect(
          (await demo.childProgress(
            'child-mia',
            today: t0,
          )).positions['shapes-all-around']!.positionMs,
          31000,
        );
        await t.end(completed: true);
        expect(demo.received.length, 2, reason: 'ends once');
      },
    );

    test(
      'finishing clears the position; a used-up limit calls back once',
      () async {
        await demo.saveControls(
          'child-mia',
          sections: const SectionSwitches(),
          controls: const MediaControls(
            dailyLimitMinutes: 5,
            limitedSections: {'watch'},
          ),
        );
        var locked = 0;
        final t = tracker(onLocked: () => locked++)..start();
        for (var i = 0; i < 330; i++) {
          t.tick();
        }
        await pumpEventQueue();
        expect(locked, 1);
        await positions.save(
          'child-mia',
          'shapes-all-around',
          ResumePoint(positionMs: 1, at: t0),
        );
        await t.end(
          completed: true,
          extra: {'positionMs': 32000, 'durationMs': 32000},
        );
        expect(await positions.positions('child-mia'), isEmpty);
        expect(demo.received.last.completed, isTrue);
      },
    );

    test('offline heartbeats keep the time for later', () async {
      final t = tracker()..start();
      await pumpEventQueue();
      final media = _FailingMedia();
      final offline = MediaSessionTracker(
        sync: c.read(syncServiceProvider),
        media: media,
        positions: positions,
        newId: () => 'x',
        now: () => t0,
        childId: 'child-mia',
        activityId: 'a',
        section: 'watch',
        contentVersion: 1,
      )..start();
      for (var i = 0; i < 30; i++) {
        offline.tick();
      }
      await pumpEventQueue();
      expect(media.calls, 1);
      media.fail = false;
      await offline.beat();
      expect(media.lastSeconds, 30);
      expect(t.started, isTrue);
    });
  });

  group('development media library', () {
    test(
      'every file is on disk with the size and checksum the seed registers',
      () {
        for (final f in devMediaFiles) {
          final file = File('assets/dev_media/${f.bucket}/${f.path}');
          expect(file.existsSync(), isTrue, reason: f.path);
          final bytes = file.readAsBytesSync();
          expect(bytes.length, f.bytes, reason: f.path);
          expect(sha256.convert(bytes).toString(), f.sha256, reason: f.path);
        }
      },
    );

    test('every item has its files: video + captions, song audio, story pages = words', () {
      for (final m in demoMediaItems) {
        final roles = m.files.map((f) => f.$1).toList();
        expect(roles, contains('thumb'), reason: m.slug);
        switch (m.type) {
          case 'video':
            expect(
              roles,
              containsAll(['video_main', 'subtitle']),
              reason: m.slug,
            );
          case 'song':
            expect(roles, contains('audio_main'), reason: m.slug);
          case 'story':
            expect(
              roles.where((r) => r == 'page_image').length,
              devStoryText[m.slug]!.length,
              reason: m.slug,
            );
        }
        expect(m.seconds, greaterThan(10));
      }
      // captions are real WebVTT with timed cues
      for (final f in devMediaFiles.where((f) => f.kind == 'subtitle')) {
        final vtt = File('assets/dev_media/${f.bucket}/${f.path}')
            .readAsStringSync();
        expect(vtt, startsWith('WEBVTT'));
        expect(
          RegExp(r'\d\d:\d\d:\d\d\.\d\d\d --> ').allMatches(vtt).length,
          greaterThan(3),
        );
      }
    });

    test('the seed registers every file and links every item (seed §16 is generated)', () {
      final seed = File('../supabase/seed.sql').readAsStringSync();
      for (final f in devMediaFiles) {
        expect(seed, contains("'${f.path}', '${f.kind}'"), reason: f.path);
      }
      for (final m in demoMediaItems) {
        expect(seed, contains("slug = '${m.slug}'"), reason: m.slug);
      }
    });

    test('thumbnails: the 256 px file when that is sharp enough, decoded at the size shown', () {
      const urls = PublicBucketUrls('https://p.supabase.co');
      expect(
        urls.publicPath('thumbs/x/1/512.webp'),
        'https://p.supabase.co/storage/v1/object/public/public-assets/thumbs/x/1/512.webp',
      );
      final small = urls.thumbnail('thumbs/x/1/512.webp', width: 100, dpr: 2);
      expect(
        ((small as ResizeImage).imageProvider as NetworkImage).url,
        endsWith('/256.webp'),
      );
      expect(small.width, 200);
      final big = urls.thumbnail('thumbs/x/1/512.webp', width: 240, dpr: 2);
      expect(
        ((big as ResizeImage).imageProvider as NetworkImage).url,
        endsWith('/512.webp'),
      );
      expect(
        const AssetMediaUrls().publicPath('thumbs/x/1/512.webp'),
        'assets/dev_media/public-assets/thumbs/x/1/512.webp',
      );
    });
  });

  group('startup wiring', () {
    test('every repository is wired in demo mode and with Supabase', () {
      final client = SupabaseClient(
        'http://127.0.0.1:54321',
        'publishable-test-key',
      );
      for (final (mode, overrides) in [
        (
          'demo',
          backendOverrides(
            const AppConfig(environment: AppEnvironment.dev),
            null,
          ),
        ),
        (
          'supabase',
          backendOverrides(
            const AppConfig(
              environment: AppEnvironment.dev,
              supabaseUrl: 'http://127.0.0.1:54321',
            ),
            client,
          ),
        ),
      ]) {
        final c = ProviderContainer(overrides: overrides);
        addTearDown(c.dispose);
        for (final read in <Object Function()>[
          () => c.read(authRepositoryProvider),
          () => c.read(onboardingRepositoryProvider),
          () => c.read(childProfilesRepositoryProvider),
          () => c.read(catalogRepositoryProvider),
          () => c.read(progressRepositoryProvider),
          () => c.read(activityContentRepositoryProvider),
          () => c.read(playRepositoryProvider),
          () => c.read(mediaRepositoryProvider),
          () => c.read(mediaControlsRepositoryProvider),
        ]) {
          expect(read, returnsNormally, reason: mode);
        }
        expect(
          c.read(playRepositoryProvider),
          mode == 'demo' ? isA<DemoBackend>() : isA<SupabasePlayRepository>(),
        );
      }
      client.dispose();
    });
  });
}

class _FailingMedia implements MediaRepository {
  bool fail = true;
  int calls = 0;
  int? lastSeconds;

  @override
  Future<MediaLaunch> launch({
    required String childId,
    required String activityId,
  }) => throw UnimplementedError();

  @override
  Future<HeartbeatResult> heartbeat({
    required String childId,
    required String section,
    required int seconds,
  }) async {
    calls++;
    if (fail) throw const NetworkFailure();
    lastSeconds = seconds;
    return const HeartbeatResult();
  }
}
