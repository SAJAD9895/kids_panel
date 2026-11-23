import 'dart:async';
import 'dart:convert';

import '../core/error/failure.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/child_profiles/domain/child_profile.dart';
import '../features/child_profiles/domain/child_profiles_repository.dart';
import '../features/learning/domain/catalog.dart';
import '../features/learning/domain/learning_repositories.dart';
import '../features/learning/domain/progress.dart';
import '../features/onboarding/domain/onboarding_repository.dart';
import '../features/play/data/quiz_mapping.dart';
import '../features/learning/domain/progress_rules.dart';
import '../features/media/domain/media.dart';
import '../features/media/domain/media_repositories.dart';
import '../features/play/domain/play_repositories.dart';
import '../features/parents/domain/account.dart';
import '../features/parents/domain/parent_reports.dart';
import '../features/parents/domain/parent_repositories.dart';
import '../features/play/domain/session_report.dart';
import '../features/rewards/domain/rewards.dart';
import '../features/rewards/domain/rewards_repository.dart';
import 'demo_activity_content.dart';
import 'demo_catalog.dart';
import 'demo_games.dart';
import 'demo_media.g.dart';
import 'demo_media_catalog.dart';
import 'demo_reports.dart';
import 'demo_rewards.dart';

/// In-memory stand-in for Supabase, used when a dev build has no SUPABASE_URL ("demo mode")
/// and by the widget tests. Same interfaces and the same rules as the real backend
/// (plan limit, ownership, consents), with the data from supabase/seed.sql. Nothing persists.
///
///   sign in or up with any email, code 123456
///   alice@example.test has two children (Plus); password Demo-pass-123
class DemoBackend
    implements
        AuthRepository,
        OnboardingRepository,
        ChildProfilesRepository,
        CatalogRepository,
        ProgressRepository,
        ActivityContentRepository,
        PlayRepository,
        MediaRepository,
        MediaControlsRepository,
        RewardsRepository,
        ParentReportsRepository,
        AccountRepository {
  DemoBackend({
    this.latency = const Duration(milliseconds: 350),
    DateTime Function()? clock,
    DemoCatalog? content,
  }) : _clock = clock ?? DateTime.now,
       content = content ?? DemoCatalog.seed() {
    _seed();
  }

  /// Published content (the seed's, or [DemoCatalog.empty] to try empty states).
  DemoCatalog content;

  /// Progress per child id. Children not listed have none yet.
  final progress = <String, ChildProgress>{};

  /// Make the next catalogue load fail (error states).
  Failure? failNextCatalog;

  static const code = '123456';
  static const alicePassword = 'Demo-pass-123';

  /// Delay of every call (0 in tests; can be raised mid-test to see loading states).
  Duration latency;
  final DateTime Function() _clock;

  final _users = <String, _User>{}; // by email
  final _families = <String, _Family>{}; // by owner user id
  final _changes = StreamController<AuthUser?>.broadcast();
  _User? _current;
  final _avatars = [
    for (var i = 1; i <= 6; i++)
      Avatar(id: 'avatar-0$i', key: 'buddy-0$i', sort: i),
  ];
  var _ids = 0;

  /// Make the next call of each kind fail (for trying error states by hand and in tests).
  Failure? failNextRead;
  Failure? failNextWrite;

  void _seed() {
    progress['child-mia'] = DemoCatalog.miaProgress(_clock());
    _seedMiaRewards();
    final alice = _User(
      '00000000-0000-4000-a000-0000000000a1',
      'alice@example.test',
    );
    _users[alice.email] = alice;
    _families[alice.id] = _Family(childLimit: 5)
      ..children.addAll([
        const ChildProfile(
          id: 'child-mia',
          nickname: 'Mia',
          birthYearMonth: BirthYearMonth(2022, 3),
          avatarId: 'avatar-04',
        ),
        const ChildProfile(
          id: 'child-leo',
          nickname: 'Leo',
          birthYearMonth: BirthYearMonth(2020, 9),
          avatarId: 'avatar-02',
          sort: 1,
        ),
      ]);
    _consents[alice.id] = _defaultConsents(
      _clock().subtract(const Duration(days: 30)),
    );
    _seedMiaHistory();
  }

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Future<void> _read() async {
    await _wait();
    final f = failNextRead;
    failNextRead = null;
    if (f != null) throw f;
  }

  Future<void> _write() async {
    await _wait();
    final f = failNextWrite;
    failNextWrite = null;
    if (f != null) throw f;
  }

  _User get _me => _current ?? (throw const UnauthorizedFailure());

  _Family get _family => _families[_me.id] ?? (throw const ForbiddenFailure());

  // --- AuthRepository ---------------------------------------------------------------------

  @override
  AuthUser? get currentUser => _current?.toAuthUser();

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield currentUser;
    yield* _changes.stream;
  }

  void _signIn(_User u) {
    _current = u..lastSignInAt = _clock();
    _changes.add(u.toAuthUser());
  }

  @override
  Future<void> sendEmailCode({
    required String email,
    required bool createUser,
  }) async {
    await _write();
    final key = email.trim().toLowerCase();
    if (!isValidEmail(key)) throw const ValidationFailure();
    if (!createUser && !_users.containsKey(key)) {
      throw const AccountNotFoundFailure();
    }
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    await _write();
    if (code != DemoBackend.code) throw const InvalidCodeFailure();
    final key = email.trim().toLowerCase();
    _signIn(_users.putIfAbsent(key, () => _User('user-${++_ids}', key)));
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _write();
    final u = _users[email.trim().toLowerCase()];
    if (u == null ||
        u.email != 'alice@example.test' ||
        password != alicePassword) {
      throw const InvalidCredentialsFailure();
    }
    _signIn(u);
  }

  @override
  Future<void> signInWithProvider(SocialProvider provider) async =>
      throw const ForbiddenFailure();

  @override
  Future<void> signOut() async {
    _current = null;
    _changes.add(null);
  }

  // --- OnboardingRepository ---------------------------------------------------------------

  @override
  Future<bool> hasFamilyAccount(String userId) async {
    await _read();
    return _families.containsKey(userId);
  }

  @override
  Future<OnboardingResult> complete(OnboardingRequest request) async {
    await _write();
    final me = _me;
    final existing = _families[me.id];
    if (existing != null) {
      return OnboardingResult(
        accountId: 'account-${me.id}',
        childId: existing.children.firstOrNull?.id,
        created: false,
      );
    }
    final given = request.consents.map((c) => c.type).toSet();
    if (!given.containsAll(const {
      ConsentType.terms,
      ConsentType.privacyPolicy,
      ConsentType.childDataCollection,
    })) {
      throw const ValidationFailure(
        'terms, privacy_policy and child_data_collection consents are required',
      );
    }
    _checkChild(request.child);
    final child = ChildProfile(
      id: 'child-${++_ids}',
      nickname: request.child.nickname.trim(),
      birthYearMonth: request.child.birthYearMonth,
      avatarId: request.child.avatarId,
    );
    _families[me.id] = _Family(childLimit: 1)..children.add(child);
    _consents[me.id] = [
      for (final c in request.consents)
        ConsentRecord(
          type: c.toJson()['type']! as String,
          version: c.policyVersion,
          method: 'checkbox',
          grantedAt: _clock(),
        ),
    ];
    return OnboardingResult(
      accountId: 'account-${me.id}',
      childId: child.id,
      created: true,
    );
  }

  // --- ChildProfilesRepository ------------------------------------------------------------

  void _checkChild(ChildDetails d) {
    if (validateNickname(d.nickname) != null ||
        d.birthYearMonth.validate(_clock()) != null) {
      throw const ValidationFailure();
    }
    if (d.avatarId != null && !_avatars.any((a) => a.id == d.avatarId)) {
      throw const ValidationFailure('unknown avatar');
    }
  }

  @override
  Future<List<ChildProfile>> listChildren() async {
    await _read();
    return List.unmodifiable(_family.children);
  }

  @override
  Future<List<Avatar>> listAvatars() async {
    await _read();
    return List.unmodifiable(_avatars);
  }

  @override
  Future<String> addChild(ChildDetails details) async {
    await _write();
    final f = _family;
    if (f.children.length >= f.childLimit) throw const ChildLimitFailure();
    _checkChild(details);
    final child = ChildProfile(
      id: 'child-${++_ids}',
      nickname: details.nickname.trim(),
      birthYearMonth: details.birthYearMonth,
      avatarId: details.avatarId,
      sort: f.children.length,
    );
    f.children.add(child);
    return child.id;
  }

  @override
  Future<ChildProfile> updateChild(String id, ChildDetails details) async {
    await _write();
    final f = _family;
    final i = f.children.indexWhere((c) => c.id == id);
    if (i < 0) throw const NotFoundFailure();
    _checkChild(details);
    return f.children[i] = f.children[i].withDetails(details);
  }

  @override
  Future<void> deleteChild(String id) async {
    await _write();
    final f = _family;
    if (_clock().difference(_me.lastSignInAt ?? DateTime(0)) >
        const Duration(minutes: 10)) {
      throw const ReauthRequiredFailure();
    }
    final before = f.children.length;
    f.children.removeWhere((c) => c.id == id);
    if (f.children.length < before) {
      _notify(_me.id, 'account_security', {'event': 'child_deleted'});
    }
    if (f.children.length == before) throw const NotFoundFailure();
  }

  // --- CatalogRepository ------------------------------------------------------------------

  @override
  Future<Catalog> loadCatalog() async {
    await _wait();
    final f = failNextCatalog;
    failNextCatalog = null;
    if (f != null) throw f;
    return content.catalog;
  }

  @override
  Future<CourseTree> courseTree(String courseId) async {
    await _read();
    return content.trees[courseId] ?? (throw const NotFoundFailure());
  }

  @override
  Future<List<SkillTag>> activitySkills(String activityId) async {
    await _wait();
    return switch (content.catalog.activity(activityId)?.subjectId) {
      'subject-numbers' => const [
        SkillTag(
          key: 'counting',
          name: LocalizedText({'en': 'Counting to 20'}),
        ),
      ],
      'subject-letters' => const [
        SkillTag(
          key: 'letter_recognition',
          name: LocalizedText({'en': 'Recognising letters'}),
        ),
      ],
      'subject-shapes' => const [
        SkillTag(
          key: 'shape_names',
          name: LocalizedText({'en': 'Naming shapes'}),
        ),
      ],
      'subject-feelings' => const [
        SkillTag(
          key: 'naming_feelings',
          name: LocalizedText({'en': 'Naming feelings'}),
        ),
      ],
      _ => const [],
    };
  }

  // --- ProgressRepository -----------------------------------------------------------------

  @override
  Future<ChildProgress> childProgress(
    String childId, {
    required DateTime today,
  }) async {
    await _read();
    // Like RLS: another family's child simply has no rows.
    final mine =
        _families[_me.id]?.children.any((c) => c.id == childId) ?? false;
    return mine
        ? progress[childId] ?? ChildProgress.empty
        : ChildProgress.empty;
  }

  @override
  Future<bool> familyHasPlus() async {
    await _wait();
    return (_families[_me.id]?.childLimit ?? 1) > 1;
  }

  // --- ActivityContentRepository ----------------------------------------------------------

  /// Every report the demo server accepted, in order (tests read it).
  final received = <SessionReport>[];

  /// Make the next sync fail as if offline.
  Failure? failNextSync;
  final _seen = <String>{};

  @override
  Future<ActivitySource> load(String activityId) async {
    await _read();
    final a =
        content.catalog.activity(activityId) ?? (throw const NotFoundFailure());
    final cfg = demoActivityContent[a.slug] ?? demoGameContent[a.slug];
    return ActivitySource.fromConfig(
      activity: a,
      config: (cfg ?? const {}).cast<String, dynamic>(),
      extraItems: [
        if (a.slug == 'letters-check' && content.catalog.activities.isNotEmpty)
          ..._lettersCheck(),
      ],
    );
  }

  /// The seed's quiz (questions + answers rows), through the same mapping as Supabase.
  static List<Map<String, dynamic>> _lettersCheck() => [
    for (final (i, l) in ['a', 'b', 'c'].indexed)
      itemFromQuestion({
        'id': 'q-letters-$i',
        'position': i,
        'type': 'single_choice',
        'prompt': {'en': 'Which one is $l?'},
        'answers': [
          for (final (j, x) in ['a', 'b', 'c'].indexed)
            {
              'id': 'ans-$i-$j',
              'position': j,
              'content': {'en': x},
              'is_correct': x == l,
            },
        ],
      })!,
  ];

  // --- PlayRepository ---------------------------------------------------------------------

  @override
  Future<List<SyncOutcome>> sync(List<SessionReport> reports) async {
    await _wait();
    final f = failNextSync;
    failNextSync = null;
    if (f != null) throw f;
    return [for (final r in reports) _apply(r)];
  }

  /// The same rules as private.apply_session, in memory.
  SyncOutcome _apply(SessionReport r) {
    final family = _families[_me.id];
    if (family == null || !family.children.any((c) => c.id == r.childId)) {
      return SyncOutcome(
        sessionId: r.sessionId,
        status: 'rejected',
        reason: 'NOT_FOUND',
      );
    }
    final key = '${r.sessionId}:${r.status.name}';
    final finished =
        _seen.contains('${r.sessionId}:completed') ||
        _seen.contains('${r.sessionId}:abandoned');
    if (_seen.contains(key) ||
        (r.status == SessionStatus.started && finished)) {
      return SyncOutcome(sessionId: r.sessionId, status: 'duplicate');
    }
    _seen.add(key);
    received.add(r);
    if (r.status != SessionStatus.started) {
      history.add(
        DemoSession(
          childId: r.childId,
          activityId: r.activityId,
          status: r.status.name,
          startedAt: r.startedAt,
          endedAt: r.endedAt ?? r.startedAt,
          score: r.score?.toDouble(),
          correct: r.correctCount,
          total: r.totalCount,
          level: r.level,
          lessonStepId: r.lessonStepId,
        ),
      );
    }
    if (r.status != SessionStatus.completed) {
      // A media session that stopped early saves where (resume, "continue watching").
      final point = r.status == SessionStatus.abandoned
          ? ResumePoint.fromMetrics(r.extra, r.endedAt ?? _clock())
          : null;
      if (point != null) {
        final p = progress[r.childId] ?? ChildProgress.empty;
        progress[r.childId] = p.copyWith(
          positions: {...p.positions, r.activityId: point},
          recent: [
            PlayedActivity(activityId: r.activityId, at: point.at),
            ...p.recent.where((x) => x.activityId != r.activityId),
          ],
        );
      }
      return SyncOutcome(sessionId: r.sessionId, status: 'accepted');
    }

    final activity = content.catalog.activity(r.activityId);
    final allowed = !(activity?.plusOnly ?? false) || family.childLimit > 1;
    final p = progress[r.childId] ?? ChildProgress.empty;
    final ledger = ledgerOf(r.childId);
    // The household day of the start (demo: the device's zone is the household's).
    final day = dayOf(r.startedAt.toLocal());
    final star = allowed && ledger.awardStar(r.activityId, day);
    String? lessonJustDone;
    var done = p.completedStepIds;
    var enrollments = p.enrollments;
    String? nextStep;
    var courseDone = false;
    if (allowed && r.lessonStepId != null) {
      done = {...done, r.lessonStepId!};
      final tree = content.trees.values
          .where((t) => t.allSteps.any((s) => s.id == r.lessonStepId))
          .firstOrNull;
      if (tree != null) {
        nextStep = tree.lessons
            .expand((l) => l.requiredSteps)
            .where((s) => !done.contains(s.id))
            .firstOrNull
            ?.id;
        courseDone = nextStep == null;
        final lesson = tree.lessons
            .where((l) => l.steps.any((s) => s.id == r.lessonStepId))
            .first;
        if (lesson.requiredSteps.every((s) => done.contains(s.id))) {
          lessonJustDone = lesson.id;
        }
        enrollments = [
          for (final e in enrollments)
            if (e.courseId != tree.course.id) e,
          Enrollment(
            courseId: tree.course.id,
            status: courseDone ? 'completed' : 'in_progress',
            currentStepId: nextStep,
          ),
        ];
      }
    }
    final events = allowed
        ? ledger.apply(
            activityId: r.activityId,
            day: day,
            now: _clock(),
            today: dayOf(_clock()),
            starNew: star,
            catalog: content.catalog,
            badges: demoBadges,
            facts: _facts(
              done,
              enrollments,
              lessonJustDone: lessonJustDone,
              courseJustDone: courseDone
                  ? enrollments.lastOrNull?.courseId
                  : null,
            ),
          )
        : null;
    if (allowed) {
      _updateMastery(r.childId, history.last);
      for (final (hit, period) in [
        (events?.dailyGoalDone ?? false, 'day'),
        (events?.weeklyGoalDone ?? false, 'week'),
      ]) {
        if (hit) {
          _notify(_me.id, 'goal_reached', {
            'childId': r.childId,
            'period': period,
          });
        }
      }
    }
    progress[r.childId] = ChildProgress(
      completedStepIds: done,
      enrollments: enrollments,
      recent: [
        PlayedActivity(activityId: r.activityId, at: r.endedAt ?? _clock()),
        ...p.recent.where((x) => x.activityId != r.activityId),
      ],
      starsToday: ledger.starsOn(dayOf(_clock())),
      starsTotal: ledger.balance,
      rewards: [
        ...p.rewards,
        for (final b
            in events?.badges ??
                const <
                  ({String key, String title, int bonusStars, String art})
                >[])
          EarnedReward(key: b.key, type: 'badge', title: b.title),
      ],
      favoriteIds: p.favoriteIds,
      sections: p.sections,
      controls: p.controls,
      positions: {...p.positions}..remove(r.activityId),
      goals: ledger.settings,
    );
    return SyncOutcome(
      sessionId: r.sessionId,
      status: 'accepted',
      starAwarded: star,
      starsToday: progress[r.childId]!.starsToday,
      stepCompleted: allowed && r.lessonStepId != null,
      nextStepId: nextStep,
      courseCompleted: courseDone,
      rewards: events?.toJson(),
    );
  }

  // --- RewardsRepository (private.apply_rewards / rewards_summary / set_learning_goals) ---

  /// Rewards per child id.
  final rewardLedgers = <String, DemoRewardLedger>{};

  DemoRewardLedger ledgerOf(String childId) =>
      rewardLedgers.putIfAbsent(childId, () => DemoRewardLedger(childId));

  RewardFacts _facts(
    Set<String> done,
    List<Enrollment> enrollments, {
    String? lessonJustDone,
    String? courseJustDone,
  }) => RewardFacts(
    lessonsDone: [
      for (final t in content.trees.values)
        for (final l in t.lessons)
          if (l.requiredSteps.isNotEmpty &&
              l.requiredSteps.every((s) => done.contains(s.id)))
            l.id,
    ].length,
    coursesDone: enrollments.where((e) => e.completed).length,
    lessonJustDone: lessonJustDone,
    courseJustDone: courseJustDone,
  );

  /// Mia's seeded history, through the same rules: island 1 of "Letters" two days ago, then
  /// three activities today (supabase/seed.sql §18 does the same with apply_rewards).
  void _seedMiaRewards() {
    final ledger = ledgerOf('child-mia');
    final now = _clock();
    final today = dayOf(now);
    final tree = content.trees['letters-a-to-h'];
    final lesson = tree?.lessons.firstOrNull;
    if (lesson != null) {
      final earlier = today.subtract(const Duration(days: 2));
      final done = <String>{};
      for (final s in lesson.steps) {
        done.add(s.id);
        final star = ledger.awardStar(s.activity.id, earlier);
        final all = lesson.requiredSteps.every((x) => done.contains(x.id));
        ledger.apply(
          activityId: s.activity.id,
          day: earlier,
          now: now.subtract(const Duration(days: 2)),
          today: today,
          starNew: star,
          catalog: content.catalog,
          badges: demoBadges,
          facts: RewardFacts(
            lessonsDone: all ? 1 : 0,
            lessonJustDone: all ? lesson.id : null,
          ),
        );
      }
    }
    for (final (i, slug) in [
      'shape-homes',
      'count-the-boats',
      'pip-meets-a-snail',
    ].indexed) {
      final a = content.catalog.activities
          .where((x) => x.slug == slug || x.id == slug)
          .firstOrNull;
      if (a == null) continue;
      final star = ledger.awardStar(a.id, today);
      ledger.apply(
        activityId: a.id,
        day: today,
        now: now.subtract(Duration(minutes: 60 - i * 15)),
        today: today,
        starNew: star,
        catalog: content.catalog,
        badges: demoBadges,
        facts: RewardFacts(lessonsDone: lesson == null ? 0 : 1),
      );
    }
    final p = progress['child-mia']!;
    progress['child-mia'] = p.copyWith(
      starsToday: ledger.starsOn(today),
      starsTotal: ledger.balance,
      rewards: [
        ...p.rewards.where((r) => r.type != 'badge'),
        for (final b in demoBadges)
          if (ledger.earned.containsKey(b.key))
            EarnedReward(key: b.key, type: 'badge', title: b.title),
      ],
    );
  }

  bool _mine(String childId) =>
      _families[_me.id]?.children.any((c) => c.id == childId) ?? false;

  @override
  Future<RewardsSummary> rewards(String childId) async {
    await _read();
    // Like private.household_of_child: another family's child is "not found".
    if (!_mine(childId)) throw const NotFoundFailure();
    final p = progress[childId] ?? ChildProgress.empty;
    return ledgerOf(childId).summary(
      today: dayOf(_clock()),
      badges: demoBadges,
      courses: p.enrollments.where((e) => e.completed).length,
    );
  }

  @override
  Future<GoalSettings> saveGoals(String childId, GoalSettings goals) async {
    await _write();
    if (!_mine(childId)) throw const NotFoundFailure();
    if (goals.dailyActivities < GoalSettings.dailyRange.min ||
        goals.dailyActivities > GoalSettings.dailyRange.max ||
        goals.weeklyDays < GoalSettings.weeklyRange.min ||
        goals.weeklyDays > GoalSettings.weeklyRange.max) {
      throw const ValidationFailure();
    }
    ledgerOf(childId).setGoals(goals, dayOf(_clock()));
    progress[childId] = (progress[childId] ?? ChildProgress.empty).copyWith(
      goals: goals,
    );
    return goals;
  }

  // --- Parent dashboard: reports and account (private.progress_report, family_overview, ----
  // --- notify, request_export, schedule_account_deletion) ---------------------------------

  /// Every finished or stopped session the demo server recorded (plus Mia's seeded history).
  final history = <DemoSession>[];

  /// Skill mastery per child id → skill key.
  final mastery = <String, Map<String, DemoMastery>>{};

  final _notices = <String, List<ParentNotification>>{}; // by user id
  final _prefs = <String, NoticePreferences>{};
  final _consents = <String, List<ConsentRecord>>{};
  final _exports = <String, List<ExportRequest>>{};
  final _exportData = <String, String>{};
  final _deletions = <String, List<DeletionRequest>>{};

  static const _skillGroups = {
    'counting': ('Counting to 20', 'literacy_numeracy'),
    'letter_recognition': ('Recognising letters', 'literacy_numeracy'),
    'shape_names': ('Naming shapes', 'thinking'),
    'naming_feelings': ('Naming feelings', 'social_life'),
    'listening': ('Listening', 'language'),
  };

  /// The demo's skill tags per activity (by subject, weight 1).
  List<String> skillsOf(String activityId) =>
      switch (content.catalog.activity(activityId)?.subjectId) {
        'subject-numbers' => const ['counting'],
        'subject-letters' => const ['letter_recognition'],
        'subject-shapes' => const ['shape_names'],
        'subject-feelings' => const ['naming_feelings'],
        _ => const [],
      };

  void _updateMastery(String childId, DemoSession s) {
    if (s.status != 'completed') return;
    final again = history.any(
      (o) =>
          !identical(o, s) &&
          o.childId == childId &&
          o.activityId == s.activityId &&
          o.status == 'completed' &&
          o.day == s.day &&
          o.startedAt.isBefore(s.startedAt),
    );
    for (final k in skillsOf(s.activityId)) {
      final info = _skillGroups[k]!;
      (mastery[childId] ??= {})
          .putIfAbsent(k, () => DemoMastery(k, info.$1, info.$2))
          .update(evidenceOf(s), again: again);
    }
  }

  List<ConsentRecord> _defaultConsents(DateTime at) => [
    for (final t in ['terms', 'privacy_policy', 'child_data_collection'])
      ConsentRecord(
        type: t,
        version: '2026-11',
        method: 'checkbox',
        grantedAt: at,
      ),
  ];

  /// Mia's seeded sessions (supabase/seed.sql §12, §18): island 1's three steps two days ago and
  /// three activities today, 3 minutes each; and her seeded skill estimates.
  void _seedMiaHistory() {
    final now = _clock();
    final lesson = content.trees['letters-a-to-h']?.lessons.firstOrNull;
    final earlier = now.subtract(const Duration(days: 2));
    for (final (i, st) in (lesson?.steps ?? const <LessonStep>[]).indexed) {
      final at = earlier.add(Duration(minutes: 5 * i));
      history.add(
        DemoSession(
          childId: 'child-mia',
          activityId: st.activity.id,
          status: 'completed',
          startedAt: at,
          endedAt: at.add(const Duration(minutes: 3)),
          lessonStepId: st.id,
        ),
      );
    }
    for (final (slug, mins) in [
      ('shape-homes', 60),
      ('count-the-boats', 45),
      ('pip-meets-a-snail', 30),
    ]) {
      final a = content.catalog.activities
          .where((x) => x.slug == slug || x.id == slug)
          .firstOrNull;
      if (a == null) continue;
      final at = now.subtract(Duration(minutes: mins));
      history.add(
        DemoSession(
          childId: 'child-mia',
          activityId: a.id,
          status: 'completed',
          startedAt: at,
          endedAt: at.add(const Duration(minutes: 3)),
          score: 100,
        ),
      );
    }
    mastery['child-mia'] = {
      for (final (k, m, n) in [
        ('shape_names', 0.55, 3),
        ('counting', 0.30, 2),
        ('listening', 0.80, 4),
      ])
        k: DemoMastery(k, _skillGroups[k]!.$1, _skillGroups[k]!.$2, m, n),
    };
    // the goals Mia reached sent their notices (as apply_session does)
    for (final k in ledgerOf('child-mia').goalsDone.keys) {
      final alice = '00000000-0000-4000-a000-0000000000a1';
      _notices
          .putIfAbsent(alice, () => [])
          .add(
            ParentNotification(
              id: 'n-${++_ids}',
              type: 'goal_reached',
              params: {
                'childId': 'child-mia',
                'period': k.startsWith('day:') ? 'day' : 'week',
              },
              createdAt: ledgerOf('child-mia').goalsDone[k]!,
            ),
          );
    }
  }

  /// private.notify: one in-app notice, unless this parent switched the type off.
  void _notify(String userId, String type, Map<String, Object?> params) {
    final t = NoticeType.of(type);
    if (t != null && _prefs[userId]?[t] == false) return;
    _notices
        .putIfAbsent(userId, () => [])
        .add(
          ParentNotification(
            id: 'n-${++_ids}',
            type: type,
            params: params,
            createdAt: _clock(),
          ),
        );
  }

  bool _recentSignIn() =>
      _clock().difference(_me.lastSignInAt ?? DateTime(0)) <=
      const Duration(minutes: 10);

  ({int lessonsTotal, int lessonsInPeriod, int steps}) _lessonStats(
    String childId,
    DateTime from,
    DateTime to,
  ) {
    final first = <String, DateTime>{};
    for (final s in history) {
      if (s.childId != childId ||
          s.status != 'completed' ||
          s.lessonStepId == null) {
        continue;
      }
      final d = first[s.lessonStepId!];
      if (d == null || s.day.isBefore(d)) first[s.lessonStepId!] = s.day;
    }
    final done = (progress[childId] ?? ChildProgress.empty).completedStepIds;
    var total = 0, inPeriod = 0;
    for (final t in content.trees.values) {
      for (final l in t.lessons) {
        final req = l.requiredSteps.toList();
        if (req.isEmpty || !req.every((x) => done.contains(x.id))) continue;
        total++;
        final last = req
            .map((x) => first[x.id])
            .whereType<DateTime>()
            .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
        if (last != null && !last.isBefore(from) && !last.isAfter(to)) {
          inPeriod++;
        }
      }
    }
    final steps = first.values
        .where((d) => !d.isBefore(from) && !d.isAfter(to))
        .length;
    return (lessonsTotal: total, lessonsInPeriod: inPeriod, steps: steps);
  }

  @override
  Future<FamilyOverview> overview() async {
    await _read();
    final today = dayOf(_clock());
    final wk = weekStartOf(today);
    final kids = _family.children;
    return FamilyOverview(
      today: today,
      unread: (_notices[_me.id] ?? const []).where((n) => n.unread).length,
      plusUntil: _family.childLimit > 1
          ? _clock().add(const Duration(days: 355))
          : null,
      children: [
        for (final c in kids)
          () {
            final mine = history.where((s) => s.childId == c.id).toList();
            int secs(bool Function(DateTime d) keep) =>
                mine.where((s) => keep(s.day)).fold(0, (n, s) => n + s.seconds);
            final ledger = ledgerOf(c.id);
            final p = progress[c.id] ?? ChildProgress.empty;
            final recent = mine.toList()
              ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
            return ChildOverview(
              childId: c.id,
              secondsToday: secs((d) => d == today),
              secondsWeek: secs((d) => !d.isBefore(wk) && !d.isAfter(today)),
              secondsTotal: secs((_) => true),
              lessonsCompleted: _lessonStats(c.id, today, today).lessonsTotal,
              gamesCompleted: mine
                  .where(
                    (s) =>
                        s.status == 'completed' &&
                        content.catalog.activity(s.activityId)?.type ==
                            ActivityType.game,
                  )
                  .length,
              badgesEarned: ledger.earned.length,
              rewards: ledger.summary(
                today: today,
                badges: demoBadges,
                courses: p.enrollments.where((e) => e.completed).length,
              ),
              recent: [
                for (final s in recent.take(5))
                  RecentActivity(
                    activityId: s.activityId,
                    title:
                        content.catalog.activity(s.activityId)?.title.of() ??
                        s.activityId,
                    type:
                        content.catalog.activity(s.activityId)?.type.name ?? '',
                    status: s.status,
                    startedAt: s.startedAt,
                  ),
              ],
            );
          }(),
      ],
    );
  }

  @override
  Future<ProgressReport> report(
    String childId, {
    required ReportPeriod period,
    DateTime? date,
  }) async {
    await _read();
    if (!_mine(childId)) throw const NotFoundFailure();
    final today = dayOf(_clock());
    final from = period.startOf(date ?? today);
    final to = switch (period) {
      ReportPeriod.day => from,
      ReportPeriod.week => from.add(const Duration(days: 6)),
      ReportPeriod.month => DateTime.utc(from.year, from.month + 1, 0),
    };
    final lessons = _lessonStats(childId, from, to);
    return buildReport(
      childId: childId,
      period: period,
      anchor: date ?? today,
      today: today,
      sessions: history,
      ledger: ledgerOf(childId),
      catalog: content.catalog,
      mastery: mastery[childId] ?? const {},
      skillsOfActivity: {
        for (final a in content.catalog.activities) a.id: skillsOf(a.id),
      },
      lessonsInPeriod: lessons.lessonsInPeriod,
      lessonsTotal: lessons.lessonsTotal,
      stepsInPeriod: lessons.steps,
    );
  }

  @override
  Future<List<ParentNotification>> notifications() async {
    await _read();
    return [...(_notices[_me.id] ?? const <ParentNotification>[])]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> markRead([List<String>? ids]) async {
    await _write();
    final list = _notices[_me.id] ?? [];
    for (var i = 0; i < list.length; i++) {
      final n = list[i];
      if (n.unread && (ids == null || ids.contains(n.id))) {
        list[i] = ParentNotification(
          id: n.id,
          type: n.type,
          params: n.params,
          createdAt: n.createdAt,
          readAt: _clock(),
        );
      }
    }
  }

  @override
  Future<NoticePreferences> preferences() async {
    await _read();
    return {for (final t in NoticeType.values) t: _prefs[_me.id]?[t] ?? true};
  }

  @override
  Future<void> savePreferences(NoticePreferences prefs) async {
    await _write();
    _prefs[_me.id] = {...prefs};
  }

  @override
  Future<List<ConsentRecord>> consents() async {
    await _read();
    return [...(_consents[_me.id] ?? const <ConsentRecord>[])];
  }

  @override
  Future<SubscriptionInfo> subscription() async {
    await _read();
    if (_family.childLimit <= 1) return SubscriptionInfo.basic;
    final now = _clock();
    return SubscriptionInfo(
      plan: const PlanOption(
        key: 'plus_annual',
        interval: 'year',
        trialDays: 7,
        maxChildren: 4,
      ),
      status: 'active',
      provider: 'promo',
      environment: 'sandbox',
      startedAt: now.subtract(const Duration(days: 10)),
      periodEnd: now.add(const Duration(days: 355)),
      plusUntil: now.add(const Duration(days: 355)),
    );
  }

  @override
  Future<List<PlanOption>> plans() async {
    await _read();
    return const [
      PlanOption(
        key: 'plus_monthly',
        interval: 'month',
        trialDays: 7,
        maxChildren: 4,
      ),
      PlanOption(
        key: 'plus_annual',
        interval: 'year',
        trialDays: 7,
        maxChildren: 4,
      ),
    ];
  }

  @override
  Future<List<ExportRequest>> exports() async {
    await _read();
    return [...(_exports[_me.id] ?? const <ExportRequest>[])]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// private.export_child, in memory.
  Map<String, Object?> _exportChild(ChildProfile c) {
    final ledger = ledgerOf(c.id);
    return {
      'profile': {
        'nickname': c.nickname,
        'birthYearMonth': c.birthYearMonth.iso,
        'avatar': c.avatarId,
      },
      'sessions': [
        for (final s in history.where((s) => s.childId == c.id))
          {
            'activity': s.activityId,
            'status': s.status,
            'startedAt': s.startedAt.toUtc().toIso8601String(),
            'endedAt': s.endedAt?.toUtc().toIso8601String(),
            'score': s.score,
          },
      ],
      'stars': [
        for (final t in ledger.transactions)
          {
            'amount': t.amount,
            'reason': t.reason.key,
            'localDate': dayKey(t.day),
          },
      ],
      'rewards': [for (final k in ledger.earned.keys) k],
      'goals': ledger.settings.toJson(),
      'skills': [
        for (final m in (mastery[c.id] ?? const <String, DemoMastery>{}).values)
          {'skill': m.key, 'mastery': m.mastery, 'evidence': m.evidence},
      ],
    };
  }

  @override
  Future<ExportLink> requestExport({String? childId}) async {
    await _write();
    if (childId != null && !_mine(childId)) throw const NotFoundFailure();
    if (!_recentSignIn()) throw const ReauthRequiredFailure();
    final list = _exports.putIfAbsent(_me.id, () => []);
    if (list
            .where(
              (e) => _clock().difference(e.createdAt) < const Duration(days: 1),
            )
            .length >=
        5) {
      throw const RateLimitedFailure();
    }
    final kids = _family.children.where(
      (c) => childId == null || c.id == childId,
    );
    final data = const JsonEncoder.withIndent(' ').convert({
      'format': 'kids-learning-export/1',
      'scope': childId == null ? 'account' : 'child',
      if (childId == null)
        'account': {
          'parents': [_me.email],
          'consents': [
            for (final c in _consents[_me.id] ?? const <ConsentRecord>[])
              {
                'type': c.type,
                'version': c.version,
                'grantedAt': c.grantedAt.toUtc().toIso8601String(),
              },
          ],
        },
      'children': [for (final c in kids) _exportChild(c)],
    });
    final req = ExportRequest(
      id: 'export-${++_ids}',
      status: 'ready',
      childId: childId,
      createdAt: _clock(),
      expiresAt: _clock().add(const Duration(days: 7)),
    );
    list.add(req);
    _exportData[req.id] = data;
    _notify(_me.id, 'export_ready', {'requestId': req.id, 'childId': childId});
    return ExportLink(
      requestId: req.id,
      expiresAt: req.expiresAt,
      preview: data,
    );
  }

  @override
  Future<ExportLink> exportLink(String requestId) async {
    await _read();
    final req = (_exports[_me.id] ?? const <ExportRequest>[])
        .where((e) => e.id == requestId)
        .firstOrNull;
    if (req == null) throw const NotFoundFailure();
    if (!req.available(_clock())) {
      throw const ValidationFailure('This export has expired. Make a new one.');
    }
    return ExportLink(
      requestId: req.id,
      expiresAt: req.expiresAt,
      preview: _exportData[req.id],
    );
  }

  @override
  Future<List<DeletionRequest>> deletionRequests() async {
    await _read();
    return [...(_deletions[_me.id] ?? const <DeletionRequest>[])];
  }

  @override
  Future<DeletionRequest> scheduleAccountDeletion() async {
    await _write();
    _family; // must have a family (owner)
    if (!_recentSignIn()) throw const ReauthRequiredFailure();
    final list = _deletions.putIfAbsent(_me.id, () => []);
    final pending = list.where((d) => d.pendingAccount).firstOrNull;
    if (pending != null) return pending;
    final d = DeletionRequest(
      id: 'deletion-${++_ids}',
      scope: 'account',
      status: 'scheduled',
      scheduledFor: _clock().add(const Duration(days: 7)),
    );
    list.add(d);
    _notify(_me.id, 'deletion_scheduled', {'requestId': d.id});
    return d;
  }

  @override
  Future<void> cancelAccountDeletion(String requestId) async {
    await _write();
    final list = _deletions[_me.id] ?? [];
    final i = list.indexWhere((d) => d.id == requestId && d.pendingAccount);
    if (i < 0) throw const NotFoundFailure();
    final d = list[i];
    list[i] = DeletionRequest(
      id: d.id,
      scope: d.scope,
      status: 'cancelled',
      scheduledFor: d.scheduledFor,
    );
  }

  /// Test helper: a notice as the weekly job / billing service would send it.
  void addNotice(String type, Map<String, Object?> params) =>
      _notify(_me.id, type, params);

  // --- MediaRepository / MediaControlsRepository (the rules of private.launch) ------------

  /// Switches Plus on or off for the signed-in family (tests: a Basic family).
  void setFamilyPlus(bool on) {
    final f = _families[_me.id];
    if (f == null) return;
    _families[_me.id] = _Family(childLimit: on ? 5 : 1)
      ..children.addAll(f.children);
  }

  /// Make the next launch fail (e.g. `NetworkFailure()` for the offline state).
  Failure? failNextLaunch;

  /// Seconds watched / listened today, per child and section.
  final usage = <String, Map<String, int>>{};

  int? _left(String childId, String section) {
    final c = (progress[childId] ?? ChildProgress.empty).controls;
    final limit = c.dailyLimitMinutes;
    if (limit == null || !c.limitedSections.contains(section)) return null;
    final used = (usage[childId] ?? const {}).entries
        .where((e) => c.limitedSections.contains(e.key))
        .fold(0, (n, e) => n + e.value);
    return (limit * 60 - used).clamp(0, 1 << 30);
  }

  @override
  Future<MediaLaunch> launch({
    required String childId,
    required String activityId,
  }) async {
    await _wait();
    final f = failNextLaunch;
    failNextLaunch = null;
    if (f != null) throw f;
    final family = _families[_me.id];
    final child = family?.children.where((c) => c.id == childId).firstOrNull;
    if (family == null || child == null) throw const NotFoundFailure();
    final a =
        content.catalog.activity(activityId) ?? (throw const NotFoundFailure());
    final now = _clock();
    final age = ageInMonths(
      child.birthYearMonth.year,
      child.birthYearMonth.month,
      now,
    );
    if (!a.suitsAge(age)) {
      throw const ContentLockedFailure(LockReason.ageNotSuitable);
    }
    final p = progress[childId] ?? ChildProgress.empty;
    final section = MediaRules.sectionOf(a.type);
    if ((section == 'watch' && !p.sections.watch) ||
        (section == 'listen' && !p.sections.listen)) {
      throw const ContentLockedFailure(LockReason.sectionDisabled);
    }
    if (a.categoryId != null &&
        p.controls.blockedCategoryIds.contains(a.categoryId)) {
      throw const ContentLockedFailure(LockReason.categoryBlocked);
    }
    if (a.plusOnly && family.childLimit <= 1) {
      throw const ContentLockedFailure(LockReason.needsPlus);
    }
    final left = _left(childId, section);
    if (left != null && left <= 0) {
      throw const ContentLockedFailure(LockReason.screenTimeOver);
    }
    final item = demoMediaItems.where((m) => m.slug == a.slug).firstOrNull;
    final pages = devStoryText[a.slug];
    return MediaLaunch(
      activityId: a.id,
      type: a.type,
      section: section,
      resume: p.positions[a.id],
      remainingSeconds: left,
      files: [
        for (final (role, f) in item?.files ?? const <(String, DevMediaFile)>[])
          if (role != 'thumb')
            MediaFile(
              role: role,
              url: 'asset:assets/dev_media/${f.bucket}/${f.path}',
              kind: f.kind,
              mime: f.mime,
              locale: role == 'subtitle' || role == 'audio_main' ? 'en' : 'und',
              position: f.position ?? 0,
              durationMs: f.durationMs,
              width: f.width,
              height: f.height,
              text: role == 'page_image' && pages != null
                  ? LocalizedText({'en': pages[f.position ?? 0]})
                  : const LocalizedText({}),
            ),
      ],
    );
  }

  @override
  Future<HeartbeatResult> heartbeat({
    required String childId,
    required String section,
    required int seconds,
  }) async {
    await _wait();
    final day = usage.putIfAbsent(childId, () => {});
    day[section] = (day[section] ?? 0) + seconds.clamp(1, 120);
    final left = _left(childId, section);
    return HeartbeatResult(
      remainingSeconds: left,
      locked: left != null && left <= 0,
    );
  }

  @override
  Future<void> saveControls(
    String childId, {
    required SectionSwitches sections,
    required MediaControls controls,
  }) async {
    await _wait();
    final f = failNextWrite;
    failNextWrite = null;
    if (f != null) throw f;
    if (!(_families[_me.id]?.children.any((c) => c.id == childId) ?? false)) {
      throw const NotFoundFailure();
    }
    final l = controls.dailyLimitMinutes;
    if (l != null && (l < 5 || l > 600)) {
      throw const ValidationFailure('daily limit must be 5..600 minutes');
    }
    progress[childId] = (progress[childId] ?? ChildProgress.empty).copyWith(
      sections: sections,
      controls: controls,
    );
  }

  void dispose() => _changes.close();
}

class _User {
  _User(this.id, this.email);

  final String id;
  final String email;
  DateTime? lastSignInAt;

  AuthUser toAuthUser() => AuthUser(id: id, email: email);
}

class _Family {
  _Family({required this.childLimit});

  final int childLimit;
  final children = <ChildProfile>[];
}
