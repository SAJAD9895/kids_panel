import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/app/providers.dart';
import 'package:kids_app/core/error/failure.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/demo/demo_media.g.dart';
import 'package:kids_app/demo/demo_rewards.dart';
import 'package:kids_app/features/play/data/play_data.dart';
import 'package:kids_app/features/play/domain/session_report.dart';
import 'package:kids_app/features/play/presentation/play_providers.dart';
import 'package:kids_app/features/rewards/domain/rewards.dart';
import 'package:kids_app/features/rewards/presentation/rewards_providers.dart';
import 'package:kids_app/features/rewards/presentation/widgets/celebration_host.dart';
import 'package:kids_app/features/rewards/presentation/widgets/reward_widgets.dart'
    show CelebrationStyle;

import '../helpers/test_app.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

void main() {
  group('streak rule (the same as private.streak_of)', () {
    final today = d(2026, 11, 18); // a Wednesday

    test('consecutive learning days count; the same day twice counts once', () {
      final s = StreakRules.of([
        d(2026, 11, 16),
        d(2026, 11, 17),
        d(2026, 11, 17), // a second activity that day: still one learning day
        d(2026, 11, 18),
      ], today);
      expect((s.current, s.longest, s.lastDay), (3, 3, d(2026, 11, 18)));
    });

    test('one rest day keeps the streak; rest days are not counted', () {
      final s = StreakRules.of([
        d(2026, 11, 13),
        d(2026, 11, 14),
        d(2026, 11, 16), // the 15th was a rest day
        d(2026, 11, 17),
      ], today);
      expect((s.current, s.longest), (4, 4));
    });

    test('two rest days in a row start a new streak; the best is kept', () {
      final s = StreakRules.of([
        d(2026, 11, 8),
        d(2026, 11, 9),
        d(2026, 11, 10),
        d(2026, 11, 13), // 11th and 12th off
        d(2026, 11, 14),
      ], today);
      expect((s.current, s.longest), (0, 3)); // last day the 14th: 4 days ago
      final back = StreakRules.of([
        d(2026, 11, 8),
        d(2026, 11, 9),
        d(2026, 11, 10),
        d(2026, 11, 13),
        d(2026, 11, 14),
        d(2026, 11, 16),
      ], today);
      expect((back.current, back.longest), (3, 3)); // 13, 14, (15 off), 16
    });

    test('a streak is still current today after yesterday or a rest day, not after two', () {
      expect(StreakRules.of([d(2026, 11, 17)], today).current, 1);
      expect(StreakRules.of([d(2026, 11, 16)], today).current, 1);
      expect(StreakRules.of([d(2026, 11, 15)], today).current, 0);
    });

    test('days after today (a wrong device clock) are ignored', () {
      final s = StreakRules.of([d(2026, 11, 18), d(2026, 11, 25)], today);
      expect((s.current, s.longest, s.lastDay), (1, 1, d(2026, 11, 18)));
    });

    test('no learning yet', () {
      final s = StreakRules.of(const [], today);
      expect((s.current, s.longest, s.lastDay), (0, 0, null));
    });
  });

  group('dates', () {
    test('weeks start on Monday (like date_trunc(week))', () {
      expect(weekStartOf(d(2026, 11, 18)), d(2026, 11, 16));
      expect(weekStartOf(d(2026, 11, 16)), d(2026, 11, 16));
      expect(weekStartOf(d(2026, 11, 22)), d(2026, 11, 16)); // Sunday
      expect(weekStartOf(d(2026, 11, 23)), d(2026, 11, 23));
    });

    test('server days are calendar days, never shifted by a zone', () {
      expect(parseDay('2026-11-18'), d(2026, 11, 18));
      expect(parseDay('2026-11-18T23:30:00+04:00'), d(2026, 11, 18));
      expect(parseDay(null), isNull);
      expect(dayKey(d(2026, 1, 5)), '2026-01-05');
      // across a daylight-saving change the day count stays whole
      expect(daysBetween(d(2026, 3, 28), d(2026, 3, 30)), 2);
    });
  });

  group('server JSON', () {
    test('the summary (GET /children/:id/rewards)', () {
      final s = RewardsSummary.fromJson({
        'today': '2026-11-18',
        'weekStart': '2026-11-16',
        'balance': 14,
        'streak': {'current': 2, 'longest': 5, 'lastDay': '2026-11-18'},
        'goals': {'enabled': true, 'dailyActivities': 4, 'weeklyDays': 3},
        'day': {
          'target': 4,
          'progress': 4,
          'completedAt': '2026-11-18T09:00:00Z',
        },
        'week': {'target': 3, 'progress': 1, 'completedAt': null},
        'learningDays': ['2026-11-16', '2026-11-18'],
        'transactions': [
          {
            'amount': 2,
            'reason': 'badge',
            'refKey': 'badge:x',
            'localDate': '2026-11-18',
            'at': '2026-11-18T09:00:00Z',
            'badgeKey': 'badge-week-1',
            'badgeTitle': {'en': 'Great week'},
          },
        ],
        'badges': [
          {
            'key': 'badge-first-game',
            'title': {'en': 'First game'},
            'description': {'en': 'You finished your very first game.'},
            'howToEarn': {'en': 'Finish any game.'},
            'rule': 'first_game',
            'params': <String, Object?>{},
            'bonusStars': 1,
            'sort': 1,
            'art': 'badges/first-game/1/512.webp',
            'earnedAt': '2026-11-17T08:00:00Z',
          },
          {
            'key': 'badge-streak-7',
            'title': {'en': 'Seven learning days'},
            'rule': 'streak',
            'params': {'days': 7},
            'art': 'badges/streak-7/1/512.webp',
            'earnedAt': null,
          },
        ],
        'counts': {
          'islands': 1,
          'courses': 0,
          'dailyGoals': 2,
          'weeklyGoals': 0,
          'learningDays': 2,
        },
        'rules': [
          {
            'key': 'activity_completed',
            'stars': 1,
            'description': {'en': 'One star'},
          },
        ],
      });
      expect(s.today, d(2026, 11, 18));
      expect(s.weekStart, d(2026, 11, 16));
      expect((s.balance, s.streak.current, s.streak.longest), (14, 2, 5));
      expect(s.goals, const GoalSettings(dailyActivities: 4, weeklyDays: 3));
      expect((s.day.done, s.week.done, s.week.left), (true, false, 2));
      expect(s.learningDays, {d(2026, 11, 16), d(2026, 11, 18)});
      expect(s.transactions.single.reason, StarReason.badge);
      expect(s.transactions.single.badgeTitle, 'Great week');
      expect(s.badges.map((b) => (b.earned, b.target)), [
        (true, 1),
        (false, 7),
      ]);
      expect(s.earnedBadges.single.key, 'badge-first-game');
      expect(s.counts.dailyGoals, 2);
      expect(s.rules.single.description, 'One star');
    });

    test('new rewards from a sync, round trip; replays are empty', () {
      final e = RewardEvents.fromJson('child-leo', {
        'stars': 4,
        'transactions': [
          {'reason': 'activity_completed', 'amount': 1},
          {'reason': 'daily_goal_met', 'amount': 1},
          {'reason': 'badge', 'amount': 2},
        ],
        'badges': [
          {
            'key': 'badge-week-1',
            'title': {'en': 'Great week'},
            'bonusStars': 2,
            'art': 'badges/week-1/1/512.webp',
          },
        ],
        'goals': [
          {'period': 'day', 'justCompleted': true},
          {'period': 'week', 'justCompleted': false},
        ],
        'lessonCompleted': false,
        'courseCompleted': false,
        'streak': {'current': 7, 'longest': 7, 'grew': true},
        'balance': 30,
      })!;
      expect((e.stars, e.dailyGoalDone, e.weeklyGoalDone), (4, true, false));
      expect(e.badges.single.title, 'Great week');
      expect(e.streakMilestone, 7);
      expect(e.isEmpty, isFalse);
      final again = RewardEvents.fromJson('child-leo', e.toJson())!;
      expect(
        (
          again.stars,
          again.badges.single.art,
          again.streakMilestone,
          again.balance,
        ),
        (4, 'badges/week-1/1/512.webp', 7, 30),
      );
      expect(RewardEvents.fromJson('x', null), isNull);
      expect(
        RewardEvents.fromJson('x', {
          'stars': 0,
          'streak': {'current': 4, 'grew': false},
        })!.isEmpty,
        isTrue,
      );
    });

    test('goal status', () {
      const g = GoalStatus(target: 3, progress: 1);
      expect((g.done, g.left), (false, 2));
      expect(g.fraction, closeTo(1 / 3, 1e-9));
      expect(const GoalStatus(target: 3, progress: 5).fraction, 1);
      // a goal reached earlier stays reached after a parent raises the target
      expect(
        GoalStatus(target: 5, progress: 3, completedAt: DateTime(2026)).done,
        isTrue,
      );
    });
  });

  group('demo ledger (the same rules as private.apply_rewards)', () {
    final demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
    final catalog = demo.content.catalog;
    final today = dayOf(testNow);

    RewardEvents finish(
      DemoRewardLedger l,
      String activity,
      DateTime day, {
      RewardFacts facts = const RewardFacts(),
      List<RewardRule> rules = defaultRewardRules,
    }) {
      final star = l.awardStar(activity, day);
      return l.apply(
        activityId: activity,
        day: day,
        now: testNow,
        today: today,
        starNew: star,
        catalog: catalog,
        badges: demoBadges,
        facts: facts,
        rules: rules,
      );
    }

    test('one star per activity per day; replay pays nothing; first game badge once', () {
      final l = DemoRewardLedger('c');
      final first = finish(l, 'shape-homes', today);
      expect(first.stars, 2); // 1 + the first-game badge's bonus
      expect(first.badges.single.key, 'badge-first-game');
      final again = finish(l, 'shape-homes', today);
      expect(again.stars, 0);
      expect(again.badges, isEmpty);
      expect(l.balance, 2);
      final tomorrow = finish(
        l,
        'shape-homes',
        today.add(const Duration(days: 1)),
      );
      expect(tomorrow.stars, 1); // a new day: a new star for the same game
    });

    test(
      'daily goal once, with a bonus star and a badge; progress keeps counting',
      () {
        final l = DemoRewardLedger('c');
        finish(l, 'shape-homes', today);
        finish(l, 'memory-match', today);
        final third = finish(l, 'puzzle-time', today);
        expect(third.dailyGoalDone, isTrue);
        expect(third.badges.map((b) => b.key), contains('badge-goal-1'));
        final fourth = finish(l, 'word-builder', today);
        expect(fourth.dailyGoalDone, isFalse);
        expect(
          l.transactions.where((t) => t.reason == StarReason.dailyGoal),
          hasLength(1),
        );
        final s = l.summary(today: today, badges: demoBadges);
        expect((s.day.progress, s.day.done, s.counts.dailyGoals), (4, true, 1));
      },
    );

    test('goals switched off: nothing tracked, nothing paid', () {
      final l = DemoRewardLedger('c')
        ..setGoals(const GoalSettings(enabled: false), today);
      for (final a in ['shape-homes', 'memory-match', 'puzzle-time']) {
        expect(finish(l, a, today).dailyGoalDone, isFalse);
      }
      expect(l.goalsDone, isEmpty);
    });

    test(
      'a parent raising today\'s target after it was reached keeps it reached',
      () {
        final l = DemoRewardLedger('c');
        for (final a in ['shape-homes', 'memory-match', 'puzzle-time']) {
          finish(l, a, today);
        }
        l.setGoals(const GoalSettings(dailyActivities: 6), today);
        final s = l.summary(today: today, badges: demoBadges);
        expect(s.day.done, isTrue);
        expect(s.day.target, 3); // the day it was reached keeps its target
      },
    );

    test('configurable rules: amounts follow the rules; a 0-star rule pays nothing', () {
      final l = DemoRewardLedger('c');
      const rules = [
        RewardRule(key: 'activity_completed', stars: 3, description: ''),
        RewardRule(key: 'daily_goal_met', stars: 0, description: ''),
      ];
      expect(
        finish(l, 'shape-sort', today, rules: rules).transactions.first.amount,
        3,
      );
    });

    test('streak with a late (offline) day, and the three-day badge', () {
      final l = DemoRewardLedger('c');
      for (final back in [4, 3, 0]) {
        finish(l, 'number-fun', today.subtract(Duration(days: back)));
      }
      // 2 and 1 days ago were both rest days, so today started a new streak (the best is 2)…
      expect((l.streak(today).current, l.streak(today).longest), (1, 2));
      // …until a late (offline) upload for 2 days ago arrives: -4 -3 -2 . 0 is one streak.
      final late = finish(
        l,
        'quiz-time',
        today.subtract(const Duration(days: 2)),
      );
      expect(late.streak.current, 4);
      expect(l.earned, contains('badge-streak-3'));
    });

    test('islands and courses: bonus once each', () {
      final l = DemoRewardLedger('c');
      final e = finish(
        l,
        'letters-check',
        today,
        facts: const RewardFacts(lessonsDone: 1, lessonJustDone: 'L1'),
      );
      expect(e.lessonCompleted, isTrue);
      expect(e.badges.map((b) => b.key), contains('badge-first-island'));
      final again = finish(
        l,
        'letters-check',
        today,
        facts: const RewardFacts(lessonsDone: 1, lessonJustDone: 'L1'),
      );
      expect(again.lessonCompleted, isFalse);
      final course = finish(
        l,
        'shape-sort',
        today,
        facts: const RewardFacts(
          lessonsDone: 3,
          coursesDone: 1,
          courseJustDone: 'C1',
        ),
      );
      expect(course.courseCompleted, isTrue);
      expect(
        l.transactions
            .where((t) => t.reason == StarReason.course)
            .single
            .amount,
        5,
      );
    });

    test('stars only ever go up', () {
      final l = DemoRewardLedger('c');
      var last = 0;
      for (final a in [
        'shape-homes',
        'shape-homes',
        'memory-match',
        'puzzle-time',
        'sort-it-out',
      ]) {
        finish(l, a, today);
        expect(l.balance, greaterThanOrEqualTo(last));
        last = l.balance;
      }
      expect(l.transactions.every((t) => t.amount > 0), isTrue);
    });

    test("another family's child: not found; bad goals: refused", () async {
      final b = DemoBackend(latency: Duration.zero, clock: () => testNow);
      await b.signInWithPassword(
        email: 'alice@example.test',
        password: DemoBackend.alicePassword,
      );
      expect(() => b.rewards('child-sam'), throwsA(isA<NotFoundFailure>()));
      expect(
        () => b.saveGoals('child-mia', const GoalSettings(dailyActivities: 11)),
        throwsA(isA<ValidationFailure>()),
      );
      final s = await b.rewards('child-mia');
      expect(s.earnedBadges.map((x) => x.key).toSet(), {
        'badge-first-game',
        'badge-first-island',
        'badge-goal-1',
      });
      expect(s.balance, b.ledgerOf('child-mia').balance);
    });
  });

  group('celebrations', () {
    RewardEvents ev({
      int stars = 1,
      bool day = false,
      bool week = false,
      bool lesson = false,
      bool course = false,
      int streak = 0,
      bool grew = false,
      List<({String key, String title, int bonusStars, String art})> badges =
          const [],
    }) => RewardEvents(
      childId: 'c',
      stars: stars,
      dailyGoalDone: day,
      weeklyGoalDone: week,
      lessonCompleted: lesson,
      courseCompleted: course,
      streak: Streak(current: streak, longest: streak),
      streakGrew: grew,
      badges: badges,
    );

    test('stars only → the small banner (no card)', () {
      expect(CelebrationContent.of(ev()), isNull);
      expect(
        CelebrationContent.of(ev(streak: 4, grew: true)),
        isNull,
      ); // 4 isn't a milestone
    });

    test('the most special thing leads; the rest are listed; a goal suggests a break', () {
      final c = CelebrationContent.of(
        ev(
          stars: 5,
          day: true,
          badges: const [
            (
              key: 'badge-goal-1',
              title: 'Goal getter',
              bonusStars: 1,
              art: 'a',
            ),
          ],
        ),
      )!;
      expect(c.style, CelebrationStyle.badge);
      expect(c.title, 'New badge: Goal getter!');
      expect(c.lines, [
        "Today's goal reached",
        '+5 stars',
        'Great learning today. Maybe time for a break?',
      ]);
      expect(
        CelebrationContent.of(ev(course: true, lesson: true))!.title,
        'You finished a whole course!',
      );
      expect(
        CelebrationContent.of(ev(streak: 7, grew: true))!.style,
        CelebrationStyle.milestone,
      );
      expect(
        CelebrationContent.of(ev(week: true))!.title,
        "You reached this week's goal!",
      );
      expect(
        CelebrationContent.of(ev(lesson: true))!.title,
        'Island finished!',
      );
    });

    test('the sync service queues what the server confirmed, once; offline queues nothing', () async {
      final demo = DemoBackend(latency: Duration.zero, clock: () => testNow);
      await demo.signInWithPassword(
        email: 'alice@example.test',
        password: DemoBackend.alicePassword,
      );
      final store = MemorySessionStore();
      final c = ProviderContainer(
        overrides: [
          playRepositoryProvider.overrideWithValue(demo),
          progressRepositoryProvider.overrideWithValue(demo),
          rewardsRepositoryProvider.overrideWithValue(demo),
          sessionStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(c.dispose);
      SessionReport report(String id) => SessionReport(
        sessionId: id,
        childId: 'child-leo',
        activityId: 'shape-homes',
        status: SessionStatus.completed,
        startedAt: testNow.subtract(const Duration(minutes: 3)),
        endedAt: testNow.subtract(const Duration(minutes: 1)),
        platform: 'web',
        appVersion: '1.0.0',
        contentVersion: 1,
        source: PlaySource.feed,
        completed: true,
      );

      demo.failNextSync = const NetworkFailure();
      expect(await c.read(syncServiceProvider).submit(report('s-1')), isNull);
      expect(
        c.read(celebrationQueueProvider),
        isEmpty,
      ); // not confirmed yet: nothing to celebrate

      await c
          .read(syncServiceProvider)
          .flush(); // back online: sent, confirmed, queued once
      final q = c.read(celebrationQueueProvider);
      expect(q.single.badges.single.key, 'badge-first-game');
      expect(q.single.childId, 'child-leo');

      await c
          .read(syncServiceProvider)
          .submit(report('s-1')); // the same upload again
      expect(c.read(celebrationQueueProvider), hasLength(1));
      c.read(celebrationQueueProvider.notifier).done(q.single);
      expect(
        c.read(celebrationQueueProvider.notifier).nextFor('child-leo'),
        isNull,
      );
    });
  });

  group('content', () {
    test('every badge has original artwork (256 + 512) in the dev media', () {
      final paths = {for (final f in devMediaFiles) f.path};
      for (final b in demoBadges) {
        expect(paths, contains(b.art), reason: b.key);
        expect(
          paths,
          contains(b.art.replaceFirst('/512.webp', '/256.webp')),
          reason: b.key,
        );
        expect(
          File('assets/dev_media/public-assets/${b.art}').existsSync(),
          isTrue,
          reason: b.key,
        );
      }
      expect({for (final b in demoBadges) b.key}, hasLength(demoBadges.length));
      expect(
        demoBadges.every((b) => b.rule != null && b.howToEarn.isNotEmpty),
        isTrue,
      );
    });

    test('every dev media folder (badges included) is bundled with the app', () {
      // Found by the Phase 12 screenshots: badge art missing from pubspec showed a fallback.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final f in devMediaFiles) {
        final dir =
            'assets/dev_media/${f.bucket}/${f.path.substring(0, f.path.lastIndexOf('/') + 1)}';
        expect(pubspec, contains('- $dir'), reason: f.path);
      }
    });

    test('the brief\'s achievements all exist', () {
      final rules = {for (final b in demoBadges) b.rule};
      expect(
        rules,
        containsAll([
          BadgeRule.firstLesson,
          BadgeRule.firstGame,
          BadgeRule.dailyGoals,
          BadgeRule.streak,
          BadgeRule.subjectExplorer,
          BadgeRule.firstCourse,
          BadgeRule.weeklyGoals, // consistent progress: goals reached in several weeks
        ]),
      );
    });

    test('seed §17 registers every badge (generated from this catalogue)', () {
      final seed = File('../supabase/seed.sql').readAsStringSync();
      expect(seed, contains('-- 17. Badges (Phase 12'));
      for (final b in demoBadges) {
        expect(seed, contains("('badge', '${b.key}', "), reason: b.key);
        expect(seed, contains("object_path = '${b.art}'"), reason: b.key);
      }
      expect(seed, contains('select private.apply_rewards(s.id)'));
    });
  });
}
