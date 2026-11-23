import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../domain/catalog.dart';
import '../domain/learning_repositories.dart';
import '../domain/progress.dart';

Future<T> _guard<T>(Future<T> Function() run) async {
  try {
    return await run();
  } catch (e) {
    throw mapError(e);
  }
}

typedef _Row = Map<String, dynamic>;

int _int(Object? v, [int fallback = 0]) => (v as num?)?.toInt() ?? fallback;

ActivitySummary activityFromRow(Map<String, dynamic> r) => ActivitySummary(
  id: r['id'] as String,
  slug: r['slug'] as String,
  type: ActivityType.parse(r['type'] as String),
  title: LocalizedText.fromJson(r['title']),
  description: LocalizedText.fromJson(r['description']),
  subjectId: r['subject_id'] as String?,
  ageMinMonths: _int(r['age_min_months'], 24),
  ageMaxMonths: _int(r['age_max_months'], 96),
  estimatedSeconds: (r['estimated_seconds'] as num?)?.toInt(),
  plusOnly: r['plus_only'] as bool? ?? false,
  players: _int(r['players'], 1),
  categoryId: r['primary_category_id'] as String?,
  thumbnail: (r['thumbnail'] as Map?)?['object_path'] as String?,
);

/// Where the child stopped in each video, song or story: newest session first, the first
/// decisive one per activity wins (finished → nothing to resume; left early with a position →
/// resume there). Rows: `activity_sessions` with `activity_results(metrics)`.
Map<String, ResumePoint> positionsFromSessions(
  List<Map<String, dynamic>> rows,
) {
  final decided = <String>{};
  final out = <String, ResumePoint>{};
  for (final r in rows) {
    final id = r['activity_id'] as String;
    if (decided.contains(id)) continue;
    final status = r['status'] as String?;
    if (status == 'completed') {
      decided.add(id);
      continue;
    }
    if (status != 'abandoned') continue;
    final res = r['activity_results'];
    final metrics =
        (res is List ? (res.isEmpty ? null : res.first) : res) as Map?;
    final at =
        DateTime.tryParse('${r['ended_at'] ?? r['started_at']}') ??
        DateTime.utc(2000);
    final p = ResumePoint.fromMetrics(metrics?['metrics'] as Map?, at);
    if (p != null) {
      out[id] = p;
      decided.add(id);
    }
  }
  return out;
}

const _activityCols =
    'id, slug, type, title, description, subject_id, age_min_months, age_max_months, estimated_seconds, plus_only, players, '
    'primary_category_id, thumbnail:media_assets!activities_thumbnail_asset_id_fkey(object_path)';

Course _course(_Row r) {
  final modules = (r['course_modules'] as List? ?? const []).cast<_Row>();
  return Course(
    id: r['id'] as String,
    slug: r['slug'] as String,
    title: LocalizedText.fromJson(r['title']),
    description: LocalizedText.fromJson(r['description']),
    subjectId: r['subject_id'] as String?,
    stage: Stage.parse(r['stage'] as String),
    plusOnly: r['plus_only'] as bool? ?? false,
    together: r['kind'] == 'learn_together',
    sort: _int(r['sort']),
    lessonCount: modules.fold(
      0,
      (n, m) => n + (m['lessons'] as List? ?? const []).length,
    ),
  );
}

/// Reads published content through the Data API (RLS: published rows only, for anyone).
class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<Catalog> loadCatalog() => _guard(() async {
    final results = await Future.wait([
      _db.from('subjects').select('id, key, name, sort').order('sort'),
      _db
          .from('activities')
          .select(_activityCols)
          .eq('status', 'published')
          .order('slug'),
      _db
          .from('courses')
          .select(
            'id, slug, kind, title, description, subject_id, stage, plus_only, sort, course_modules(lessons(id))',
          )
          .eq('status', 'published')
          .order('sort'),
      _db
          .from('learning_paths')
          .select(
            'id, slug, title, description, stage, age_min_months, age_max_months, learning_path_courses(course_id, position)',
          )
          .eq('status', 'published'),
      _db
          .from('collections')
          .select(
            'id, slug, surface, kind, title, age_min_months, age_max_months, sort, starts_at, ends_at, collection_items(activity_id, position)',
          )
          .eq('status', 'published')
          .order('sort'),
      _db
          .from('categories')
          .select('id, key, name, sort')
          .eq('status', 'published')
          .order('sort'),
    ]);
    final now = DateTime.now().toUtc();
    bool live(_Row r) {
      final s = DateTime.tryParse('${r['starts_at']}'),
          e = DateTime.tryParse('${r['ends_at']}');
      return (s == null || !s.isAfter(now)) && (e == null || e.isAfter(now));
    }

    return Catalog(
      subjects: [
        for (final r in results[0])
          Subject(
            id: r['id'] as String,
            key: r['key'] as String,
            name: LocalizedText.fromJson(r['name']),
            sort: _int(r['sort']),
          ),
      ],
      activities: results[1].map(activityFromRow).toList(),
      categories: [
        for (final r in results[5])
          Category(
            id: r['id'] as String,
            key: r['key'] as String,
            name: LocalizedText.fromJson(r['name']),
            sort: _int(r['sort']),
          ),
      ],
      courses: results[2].map(_course).toList(),
      paths: [
        for (final r in results[3])
          LearningPath(
            id: r['id'] as String,
            slug: r['slug'] as String,
            title: LocalizedText.fromJson(r['title']),
            description: LocalizedText.fromJson(r['description']),
            stage: Stage.parse(r['stage'] as String),
            ageMinMonths: _int(r['age_min_months']),
            ageMaxMonths: _int(r['age_max_months'], 144),
            courseIds:
                ((r['learning_path_courses'] as List).cast<_Row>()..sort(
                      (a, b) =>
                          _int(a['position']).compareTo(_int(b['position'])),
                    ))
                    .map((x) => x['course_id'] as String)
                    .toList(),
          ),
      ],
      collections: [
        for (final r in results[4])
          if (live(r))
            Collection(
              id: r['id'] as String,
              slug: r['slug'] as String,
              surface: r['surface'] as String,
              kind: r['kind'] as String,
              title: LocalizedText.fromJson(r['title']),
              ageMinMonths: _int(r['age_min_months']),
              ageMaxMonths: _int(r['age_max_months'], 144),
              activityIds:
                  ((r['collection_items'] as List).cast<_Row>()..sort(
                        (a, b) =>
                            _int(a['position']).compareTo(_int(b['position'])),
                      ))
                      .map((x) => x['activity_id'] as String)
                      .toList(),
            ),
      ],
    );
  });

  @override
  Future<CourseTree> courseTree(String courseId) => _guard(() async {
    final r = await _db
        .from('courses')
        .select(
          'id, slug, kind, title, description, subject_id, stage, plus_only, sort, '
          'course_modules(position, lessons(id, position, title, prize_reward_id, prerequisite_lesson_ids, '
          'lesson_steps(id, position, step_type, required, activities($_activityCols))))',
        )
        .eq('id', courseId)
        .single();
    final modules = (r['course_modules'] as List).cast<_Row>()
      ..sort((a, b) => _int(a['position']).compareTo(_int(b['position'])));
    final lessons = <Lesson>[];
    for (final m in modules) {
      final ls = (m['lessons'] as List).cast<_Row>()
        ..sort((a, b) => _int(a['position']).compareTo(_int(b['position'])));
      for (final l in ls) {
        final steps = (l['lesson_steps'] as List).cast<_Row>()
          ..sort((a, b) => _int(a['position']).compareTo(_int(b['position'])));
        lessons.add(
          Lesson(
            id: l['id'] as String,
            title: LocalizedText.fromJson(l['title']),
            hasPrize: l['prize_reward_id'] != null,
            prerequisiteIds: {
              for (final p
                  in (l['prerequisite_lesson_ids'] as List?) ?? const [])
                '$p',
            },
            steps: [
              for (final s in steps)
                if (s['activities'] != null)
                  LessonStep(
                    id: s['id'] as String,
                    position: _int(s['position']),
                    type: s['step_type'] as String,
                    required: s['required'] as bool? ?? true,
                    activity: activityFromRow(s['activities'] as _Row),
                  ),
            ],
          ),
        );
      }
    }
    final course = _course({
      ...r,
      'course_modules': modules.map((m) => {'lessons': m['lessons']}).toList(),
    });
    return CourseTree(course: course, lessons: lessons);
  });

  @override
  Future<List<SkillTag>> activitySkills(String activityId) => _guard(() async {
    final rows = await _db
        .from('activity_skills')
        .select('weight, skills(key, name)')
        .eq('activity_id', activityId);
    return [
      for (final r in rows)
        if (r['skills'] != null)
          SkillTag(
            key: (r['skills'] as _Row)['key'] as String,
            name: LocalizedText.fromJson((r['skills'] as _Row)['name']),
          ),
    ];
  });
}

/// Reads one child's progress. RLS (can_access_child) limits every query to the parent's
/// own children; nothing is written from the app.
class SupabaseProgressRepository implements ProgressRepository {
  SupabaseProgressRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<ChildProgress> childProgress(
    String childId, {
    required DateTime today,
  }) => _guard(() async {
    final r = await Future.wait([
      _db
          .from('lesson_step_completions')
          .select('step_id')
          .eq('child_id', childId),
      _db
          .from('course_enrollments')
          .select('course_id, status, current_step_id')
          .eq('child_id', childId),
      _db
          .from('activity_sessions')
          .select(
            'activity_id, started_at, ended_at, status, activity_results(metrics)',
          )
          .eq('child_id', childId)
          .order('started_at', ascending: false)
          .limit(60),
      _db
          .from('daily_progress')
          .select('local_date, stars')
          .eq('child_id', childId),
      _db
          .from('child_rewards')
          .select('quantity, rewards(key, type, title)')
          .eq('child_id', childId),
      _db.from('favorites').select('activity_id').eq('child_id', childId),
      _db
          .from('screen_time_rules')
          .select(
            'learn_enabled, watch_enabled, listen_enabled, together_enabled, '
            'daily_limit_minutes, limited_sections, blocked_category_ids',
          )
          .eq('child_id', childId),
      _db.from('child_star_totals').select('stars').eq('child_id', childId),
      _db
          .from('learning_goals')
          .select('enabled, daily_activities, weekly_days')
          .eq('child_id', childId),
    ]);
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final seen = <String>{};
    final rules = r[6].isEmpty ? null : r[6].first;
    return ChildProgress(
      completedStepIds: {for (final x in r[0]) x['step_id'] as String},
      enrollments: [
        for (final x in r[1])
          Enrollment(
            courseId: x['course_id'] as String,
            status: x['status'] as String,
            currentStepId: x['current_step_id'] as String?,
          ),
      ],
      recent: [
        for (final x in r[2])
          if (seen.add(x['activity_id'] as String))
            PlayedActivity(
              activityId: x['activity_id'] as String,
              at: DateTime.parse(x['started_at'] as String),
            ),
      ],
      starsToday: r[3]
          .where((x) => x['local_date'] == todayKey)
          .fold(0, (n, x) => n + _int(x['stars'])),
      starsTotal: r[7].isEmpty
          ? r[3].fold(0, (n, x) => n + _int(x['stars']))
          : _int(r[7].first['stars']),
      goals: r[8].isEmpty
          ? const GoalSettings()
          : GoalSettings(
              enabled: r[8].first['enabled'] as bool? ?? true,
              dailyActivities: _int(r[8].first['daily_activities'], 3),
              weeklyDays: _int(r[8].first['weekly_days'], 4),
            ),
      rewards: [
        for (final x in r[4])
          if (x['rewards'] != null)
            EarnedReward(
              key: (x['rewards'] as _Row)['key'] as String,
              type: (x['rewards'] as _Row)['type'] as String,
              title: LocalizedText.fromJson((x['rewards'] as _Row)['title'])
                  .of(),
              quantity: _int(x['quantity'], 1),
            ),
      ],
      favoriteIds: {for (final x in r[5]) x['activity_id'] as String},
      positions: positionsFromSessions(r[2]),
      controls: rules == null
          ? const MediaControls()
          : MediaControls(
              blockedCategoryIds: {
                for (final c
                    in (rules['blocked_category_ids'] as List?) ?? const [])
                  '$c',
              },
              dailyLimitMinutes: (rules['daily_limit_minutes'] as num?)
                  ?.toInt(),
              limitedSections: {
                for (final c
                    in (rules['limited_sections'] as List?) ??
                        const ['learn', 'watch', 'listen', 'together'])
                  '$c',
              },
            ),
      sections: rules == null
          ? const SectionSwitches()
          : SectionSwitches(
              learn: rules['learn_enabled'] as bool? ?? true,
              watch: rules['watch_enabled'] as bool? ?? true,
              listen: rules['listen_enabled'] as bool? ?? true,
              together: rules['together_enabled'] as bool? ?? true,
            ),
    );
  });

  @override
  Future<bool> familyHasPlus() => _guard(() async {
    final rows = await _db
        .from('entitlements')
        .select('active_until')
        .eq('entitlement', 'plus');
    final now = DateTime.now().toUtc();
    return rows.any(
      (x) => DateTime.tryParse('${x['active_until']}')?.isAfter(now) ?? false,
    );
  });
}
