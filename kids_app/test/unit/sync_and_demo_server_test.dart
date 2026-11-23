import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/app/providers.dart';
import 'package:kids_app/core/error/failure.dart';
import 'package:kids_app/demo/demo_backend.dart';
import 'package:kids_app/features/play/data/play_data.dart';
import 'package:kids_app/features/play/domain/session_report.dart';
import 'package:kids_app/features/play/presentation/play_providers.dart';

void main() {
  final now = DateTime.utc(2026, 11, 18, 10);
  late DemoBackend demo;
  late MemorySessionStore store;
  late ProviderContainer c;

  setUp(() async {
    demo = DemoBackend(latency: Duration.zero, clock: () => now);
    store = MemorySessionStore();
    c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(demo),
        progressRepositoryProvider.overrideWithValue(demo),
        catalogRepositoryProvider.overrideWithValue(demo),
        childProfilesRepositoryProvider.overrideWithValue(demo),
        playRepositoryProvider.overrideWithValue(demo),
        sessionStoreProvider.overrideWithValue(store),
      ],
    );
    await demo.signInWithPassword(
      email: 'alice@example.test',
      password: DemoBackend.alicePassword,
    );
  });
  tearDown(() {
    c.dispose();
    demo.dispose();
  });

  SessionReport report(
    String id,
    String activity, {
    String child = 'child-leo',
    String? step,
    SessionStatus status = SessionStatus.completed,
  }) => SessionReport(
    sessionId: id,
    childId: child,
    activityId: activity,
    lessonStepId: step,
    status: status,
    startedAt: now.subtract(const Duration(minutes: 2)),
    endedAt: status == SessionStatus.started ? null : now,
    source: step == null ? PlaySource.feed : PlaySource.course,
    platform: 'ios',
    appVersion: '1.0.0',
    completed: status == SessionStatus.completed,
    score: 100,
    durationMs: 120000,
  );

  test('demo server: one star per activity per day, replays are duplicates, steps unlock', () async {
    final a = await demo.sync([
      report('s1', 'shape-sort', step: 'shapes-1-step-1'),
    ]);
    expect(
      (
        a.single.status,
        a.single.starAwarded,
        a.single.stepCompleted,
        a.single.nextStepId,
      ),
      ('accepted', true, true, 'shapes-1-step-2'),
    );
    final again = await demo.sync([report('s1', 'shape-sort')]);
    expect(again.single.status, 'duplicate');
    final second = await demo.sync([report('s2', 'shape-sort')]);
    expect(second.single.starAwarded, isFalse);
    expect(demo.progress['child-leo']!.starsToday, 1);
    expect(demo.progress['child-leo']!.recent.first.activityId, 'shape-sort');
  });

  test('demo server: a start after the end is a duplicate; another family is rejected', () async {
    await demo.sync([report('s3', 'shape-sort')]);
    expect(
      (await demo.sync([
        report('s3', 'shape-sort', status: SessionStatus.started),
      ])).single.status,
      'duplicate',
    );
    expect(
      (await demo.sync([report('s4', 'shape-sort', child: 'someone-else')]))
          .single
          .status,
      'rejected',
    );
  });

  test('sync service: a report waits in the outbox while offline and goes on the next flush', () async {
    final sync = c.read(syncServiceProvider);
    demo.failNextSync = const NetworkFailure();
    final first = await sync.submit(report('s5', 'shape-sort'));
    expect(first, isNull);
    expect(store.outbox, hasLength(1));
    final later = await sync.flush();
    expect(later.single.status, 'accepted');
    expect(store.outbox, isEmpty);
  });

  test('sync service: starts go before ends, oldest first; rejected items are dropped', () async {
    final sync = c.read(syncServiceProvider);
    demo.failNextSync = const NetworkFailure();
    await sync.submit(report('s6', 'shape-sort')); // end queued first …
    demo.failNextSync = const NetworkFailure();
    await sync.submit(
      report('s6', 'shape-sort', status: SessionStatus.started),
    ); // … then its start
    await store.enqueue(report('s7', 'shape-sort', child: 'someone-else'));
    await sync.flush();
    final s6 = demo.received
        .where((r) => r.sessionId == 's6')
        .map((r) => r.status)
        .toList();
    expect(s6, [SessionStatus.started, SessionStatus.completed]);
    expect(
      store.outbox,
      isEmpty,
      reason: 'the rejected one is dropped, not retried forever',
    );
  });

  test('two flushes at once do not send twice', () async {
    final sync = c.read(syncServiceProvider);
    await store.enqueue(report('s8', 'shape-sort'));
    await Future.wait([sync.flush(), sync.flush()]);
    expect(demo.received.where((r) => r.sessionId == 's8'), hasLength(1));
  });
}
