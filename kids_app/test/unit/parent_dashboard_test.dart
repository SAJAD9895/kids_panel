import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/core/error/failure.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/demo/demo_reports.dart';
import 'package:kids_app/features/parents/domain/account.dart';
import 'package:kids_app/features/parents/domain/parent_reports.dart';
import 'package:kids_app/features/rewards/domain/rewards.dart';

import '../helpers/test_app.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

Future<DemoBackend> alice({DateTime Function()? clock}) async {
  final b = DemoBackend(latency: Duration.zero, clock: clock ?? () => testNow);
  await b.signInWithPassword(
    email: 'alice@example.test',
    password: DemoBackend.alicePassword,
  );
  return b;
}

/// A report as GET /progress/report returns it (shape checked against the SQL test D1).
Map<String, Object?> serverReport({
  int scoredA = 3,
  double avgA = 85,
  int evidence = 4,
}) => {
  'childId': 'c1',
  'period': 'week',
  'from': '2026-11-16',
  'to': '2026-11-22',
  'today': '2026-11-18',
  'daysElapsed': 3,
  'totals': {
    'seconds': 1500,
    'sessions': 5,
    'completed': 4,
    'activities': 3,
    'learningDays': 2,
    'stars': 7,
  },
  'previous': {
    'from': '2026-11-09',
    'to': '2026-11-15',
    'seconds': 300,
    'completed': 1,
  },
  'daily': [
    for (var i = 0; i < 7; i++)
      {
        'date': '2026-11-${16 + i}',
        'seconds': i == 0 ? 1500 : 0,
        'completed': i == 0 ? 4 : 0,
      },
  ],
  'byType': [
    {'type': 'game', 'started': 3, 'completed': 2},
  ],
  'bySubject': [
    {
      'key': 'numbers',
      'name': 'Numbers',
      'completed': 3,
      'seconds': 900,
      'scored': scoredA,
      'avgScore': avgA,
    },
    {
      'key': 'letters',
      'name': 'Letters',
      'completed': 3,
      'seconds': 600,
      'scored': 3,
      'avgScore': 50.0,
    },
  ],
  'games': [
    {
      'slug': 'memory-match',
      'title': 'Memory match',
      'plays': 2,
      'completed': 2,
      'avgScore': 90.0,
      'bestScore': 100.0,
      'accuracy': 90.0,
      'levels': ['easy', 'medium'],
    },
  ],
  'quizzes': [
    {
      'slug': 'letters-check',
      'title': 'Letters check-in',
      'attempts': 1,
      'lastScore': 50,
      'bestScore': 50,
      'avgScore': 50.0,
      'firstTryCorrect': null,
    },
  ],
  'lessons': {'stepsCompleted': 3, 'completedInPeriod': 1, 'completedTotal': 2},
  'skills': [
    {
      'key': 'counting',
      'name': 'Counting to 20',
      'group': 'literacy_numeracy',
      'mastery': 0.8,
      'evidence': evidence,
      'practisedInPeriod': true,
    },
    {
      'key': 'listening',
      'name': 'Listening',
      'group': 'language',
      'mastery': 0.2,
      'evidence': 2,
      'practisedInPeriod': false,
    },
  ],
  'goals': {
    'enabled': true,
    'dailyTarget': 3,
    'weeklyTarget': 4,
    'daysReached': 1,
    'daysElapsed': 3,
    'weeks': [
      {'weekStart': '2026-11-16', 'reached': false},
    ],
  },
  'consistency': [
    for (var i = 0; i < 8; i++)
      {'weekStart': '2026-09-${28 + i}', 'learningDays': i},
  ],
  'scoredSessions': 3,
  'recent': [
    {
      'activityId': 'memory-match',
      'title': 'Memory match',
      'type': 'game',
      'status': 'completed',
      'startedAt': '2026-11-16T09:00:00Z',
      'seconds': 600,
      'score': 80,
      'level': 'easy',
    },
  ],
};

void main() {
  group('formatting and periods', () {
    test('durations', () {
      expect(formatDuration(0), '0 min');
      expect(formatDuration(45), '45 s');
      expect(formatDuration(600), '10 min');
      expect(formatDuration(3900), '1 h 05 min');
    });

    test(
      'periods: start and shift (weeks on Monday, months roll over years)',
      () {
        expect(ReportPeriod.week.startOf(d(2026, 11, 22)), d(2026, 11, 16));
        expect(ReportPeriod.month.startOf(d(2026, 11, 22)), d(2026, 11, 1));
        expect(ReportPeriod.month.shift(d(2026, 12, 1), 1), d(2027, 1, 1));
        expect(ReportPeriod.month.shift(d(2026, 1, 1), -1), d(2025, 12, 1));
        expect(ReportPeriod.week.shift(d(2026, 11, 16), -1), d(2026, 11, 9));
        expect(ReportPeriod.parse('month'), ReportPeriod.month);
        expect(ReportPeriod.parse('nonsense'), ReportPeriod.week);
      },
    );

    test('mastery bands (09 §9.3: < 0.4, 0.4–0.75, > 0.75)', () {
      expect(MasteryBand.of(0.39), MasteryBand.gettingStarted);
      expect(MasteryBand.of(0.4), MasteryBand.practising);
      expect(MasteryBand.of(0.75), MasteryBand.practising);
      expect(MasteryBand.of(0.751), MasteryBand.confident);
    });
  });

  group('reports', () {
    test('the server report parses with every block', () {
      final r = ProgressReport.fromJson(serverReport());
      expect(
        (r.from, r.to, r.period),
        (d(2026, 11, 16), d(2026, 11, 22), ReportPeriod.week),
      );
      expect(
        (
          r.seconds,
          r.sessions,
          r.completed,
          r.activities,
          r.learningDays,
          r.stars,
        ),
        (1500, 5, 4, 3, 2, 7),
      );
      expect((r.previousSeconds, r.previousCompleted), (300, 1));
      expect(r.daily, hasLength(7));
      expect(r.byType.single.rate, closeTo(2 / 3, 1e-9));
      expect(r.games.single.levels, ['easy', 'medium']);
      expect(r.quizzes.single.firstTryCorrect, isNull);
      expect((r.stepsCompleted, r.lessonsInPeriod, r.lessonsTotal), (3, 1, 2));
      expect(r.skills.first.band, MasteryBand.confident);
      expect(r.goals.dayRate, closeTo(1 / 3, 1e-9));
      expect(r.consistency.last.learningDays, 7);
      expect(r.inProgress, isTrue); // today (18th) is inside the week
      expect(r.isEmpty, isFalse);
    });

    test('a period that has not started yet has no goal rate (not 0 %)', () {
      expect(const GoalReport(daysElapsed: 0).dayRate, isNull);
    });

    test('strengths and practice: a fixed rule with an evidence bar', () {
      final ins = ReportInsights.of(ProgressReport.fromJson(serverReport()));
      expect(ins.enoughData, isTrue);
      expect(ins.strengths, [
        'Numbers: 85 % on average in 3 scored activities',
        'Counting to 20: confident (4 activities)',
      ]);
      expect(ins.practise, ['Letters: 50 % on average in 3 scored activities']);
      // Listening (2 activities) is below the evidence bar: not mentioned
      expect(ins.practise.any((s) => s.contains('Listening')), isFalse);
    });

    test('too little evidence: nothing is claimed', () {
      final j = serverReport(scoredA: 2, evidence: 2);
      (j['bySubject'] as List).removeLast();
      final ins = ReportInsights.of(ProgressReport.fromJson(j));
      expect(ins.enoughData, isFalse);
      expect(ins.strengths, isEmpty);
      expect(ins.practise, isEmpty);
    });

    test('the overview parses and adds up the family', () {
      final o = FamilyOverview.fromJson({
        'today': '2026-11-18',
        'unread': 2,
        'plusUntil': '2027-11-08T00:00:00Z',
        'children': [
          for (final (id, s, b) in [('a', 600, 5), ('b', 300, 9)])
            {
              'childId': id,
              'secondsWeek': s,
              'rewards': {'today': '2026-11-18', 'balance': b},
              'recent': [],
            },
        ],
      });
      expect((o.secondsWeek, o.starsTotal, o.unread), (900, 14, 2));
      expect(o.child('b')!.rewards.balance, 9);
      expect(o.plusUntil, isNotNull);
    });
  });

  group('the demo server computes reports by the same rules', () {
    test("Mia's week adds up from her sessions (the seed's numbers)", () async {
      final b = await alice();
      final r = await b.report(
        'child-mia',
        period: ReportPeriod.week,
        date: testNow,
      );
      final mine = b.history.where((s) => s.childId == 'child-mia');
      expect(r.seconds, mine.fold(0, (n, s) => n + s.seconds));
      expect(r.seconds, 6 * 180); // six 3-minute sessions, as seed §12 / §18
      expect((r.sessions, r.completed), (6, 6));
      expect(r.learningDays, 2);
      expect(r.stars, b.ledgerOf('child-mia').balance);
      expect(r.daily.fold(0, (n, x) => n + x.seconds), r.seconds);
      expect(r.lessonsInPeriod, 1);
      expect(r.goals.daysReached, 2);
      expect(r.consistency, hasLength(8));
      expect(r.skills.map((k) => k.key), contains('listening'));
    });

    test(
      'a day report holds only that day; an empty period is empty',
      () async {
        final b = await alice();
        final day = await b.report(
          'child-mia',
          period: ReportPeriod.day,
          date: testNow,
        );
        expect((day.seconds, day.completed), (540, 3));
        final before = await b.report(
          'child-mia',
          period: ReportPeriod.week,
          date: testNow.subtract(const Duration(days: 14)),
        );
        expect(before.isEmpty, isTrue);
        expect(before.inProgress, isFalse);
      },
    );

    test("another family's child: not found", () async {
      final b = await alice();
      expect(
        () => b.report('child-sam', period: ReportPeriod.week),
        throwsA(isA<NotFoundFailure>()),
      );
      expect(
        () => b.requestExport(childId: 'child-sam'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('the overview matches the history and the ledger', () async {
      final b = await alice();
      final o = await b.overview();
      final mia = o.child('child-mia')!;
      expect(mia.secondsTotal, 1080);
      expect(mia.secondsToday, 540);
      expect(mia.lessonsCompleted, 1);
      expect(mia.rewards.balance, b.ledgerOf('child-mia').balance);
      expect(mia.badgesEarned, 3);
      expect(o.child('child-leo')!.recent, isEmpty);
      expect(o.unread, 2); // Mia's two daily goals
    });

    test('skill mastery follows §9.3: halfway on first evidence, half again on a same-day repeat', () {
      final m = DemoMastery('k', 'K', 'thinking')..update(0.6, again: false);
      expect(m.mastery, closeTo(0.3, 1e-9));
      m.update(1, again: true); // α = 1/3, halved
      expect(m.mastery, closeTo(0.3 + (1 / 6) * 0.7, 1e-9));
      expect(m.evidence, 2);
      expect(
        evidenceOf(
          DemoSession(
            childId: 'c',
            activityId: 'a',
            status: 'completed',
            startedAt: testNow,
            correct: 3,
            total: 4,
          ),
        ),
        0.75,
      );
      expect(
        evidenceOf(
          DemoSession(
            childId: 'c',
            activityId: 'a',
            status: 'completed',
            startedAt: testNow,
          ),
        ),
        0.7,
      );
    });
  });

  group(
    'account (demo server, the same rules as the account Edge Function)',
    () {
      test(
        'export: one child only, needs a recent sign-in, five a day',
        () async {
          var now = testNow;
          final b = await alice(clock: () => now);
          final link = await b.requestExport(childId: 'child-leo');
          final data = jsonDecode(link.preview!) as Map;
          expect(data['scope'], 'child');
          expect(
            (data['children'] as List).single['profile']['nickname'],
            'Leo',
          );
          expect(link.preview!.contains('Mia'), isFalse);
          final all = jsonDecode((await b.requestExport()).preview!) as Map;
          expect((all['children'] as List), hasLength(2));
          expect((all['account'] as Map)['consents'], isNotEmpty);
          for (var i = 0; i < 3; i++) {
            await b.requestExport();
          }
          await expectLater(
            b.requestExport(),
            throwsA(isA<RateLimitedFailure>()),
          );
          now = now.add(const Duration(minutes: 15));
          final c = await alice(clock: () => now);
          now = now.add(const Duration(minutes: 11));
          await expectLater(
            c.requestExport(),
            throwsA(isA<ReauthRequiredFailure>()),
          );
          expect(
            (await b.notifications()).where((n) => n.type == 'export_ready'),
            hasLength(5),
          );
        },
      );

      test(
        'account deletion: scheduled for 7 days with a notice; cancelled',
        () async {
          final b = await alice();
          final d = await b.scheduleAccountDeletion();
          expect(d.scheduledFor, testNow.add(const Duration(days: 7)));
          expect(
            (await b.scheduleAccountDeletion()).id,
            d.id,
          ); // asking twice changes nothing
          expect((await b.notifications()).first.type, 'deletion_scheduled');
          await b.cancelAccountDeletion(d.id);
          expect((await b.deletionRequests()).single.status, 'cancelled');
        },
      );

      test('preferences: a type switched off sends nothing', () async {
        final b = await alice();
        await b.savePreferences({
          for (final t in NoticeType.values) t: t != NoticeType.exportReady,
        });
        await b.requestExport();
        expect(
          (await b.notifications()).where((n) => n.type == 'export_ready'),
          isEmpty,
        );
        expect((await b.preferences())[NoticeType.exportReady], isFalse);
      });

      test('mark read: one, then all', () async {
        final b = await alice();
        final list = await b.notifications();
        await b.markRead([list.first.id]);
        expect((await b.notifications()).where((n) => n.unread), hasLength(1));
        await b.markRead();
        expect((await b.notifications()).where((n) => n.unread), isEmpty);
      });

      test('subscription: Plus (code) and Basic', () async {
        final b = await alice();
        final s = await b.subscription();
        expect((s.hasPlus, s.provider, s.manageUrl), (true, 'promo', null));
        b.setFamilyPlus(false);
        expect((await b.subscription()).hasPlus, isFalse);
        expect(await b.plans(), hasLength(2));
      });
    },
  );

  group('words and links', () {
    String name(String? id) => id == 'c1' ? 'Mia' : 'Your child';

    test(
      'notices are written from their type; nicknames come from the device',
      () {
        final w = ParentNotification(
          id: '1',
          type: 'weekly_progress',
          createdAt: testNow,
          params: {
            'weekStart': '2026-11-09',
            'children': [
              {
                'childId': 'c1',
                'learningDays': 3,
                'activities': 7,
                'seconds': 1500,
              },
            ],
          },
        ).text(name);
        expect(w.title, 'Last week’s learning');
        expect(w.body, 'Mia: 3 learning days, 7 activities, 25 min');
        final g = ParentNotification(
          id: '2',
          type: 'goal_reached',
          createdAt: testNow,
          params: {'childId': 'c1', 'period': 'week'},
        ).text(name);
        expect(g.title, 'Mia reached this week’s goal');
        for (final t in NoticeType.values) {
          expect(
            ParentNotification(
              id: 'x',
              type: t.key,
              createdAt: testNow,
              params: const {},
            ).text(name).title,
            isNot('Notice'),
            reason: t.key,
          );
        }
      },
    );

    test('store links for managing a subscription', () {
      expect(
        const SubscriptionInfo(provider: 'apple').manageUrl.toString(),
        'https://apps.apple.com/account/subscriptions',
      );
      expect(
        const SubscriptionInfo(provider: 'google').manageUrl!.host,
        'play.google.com',
      );
      expect(const SubscriptionInfo(provider: 'stripe').manageUrl, isNull);
      expect(
        SubscriptionInfo(
          plusUntil: DateTime.now().subtract(const Duration(days: 1)),
        ).hasPlus,
        isFalse,
      );
    });

    test('an export can be downloaded until it expires', () {
      final e = ExportRequest(
        id: 'e',
        status: 'ready',
        createdAt: testNow,
        expiresAt: testNow.add(const Duration(days: 7)),
      );
      expect(e.available(testNow), isTrue);
      expect(e.available(testNow.add(const Duration(days: 8))), isFalse);
      expect(
        ExportRequest(
          id: 'f',
          status: 'failed',
          createdAt: testNow,
        ).available(testNow),
        isFalse,
      );
    });

    test('server days stay calendar days', () {
      expect(dayKey(d(2026, 11, 16)), '2026-11-16');
    });
  });
}
