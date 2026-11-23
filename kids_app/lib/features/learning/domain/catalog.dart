/// Published learning content (read-only for the app). Pure Dart.
///
/// Titles are stored per locale (`{"en": …, "es": …}`); [LocalizedText] picks one.
library;

class LocalizedText {
  const LocalizedText(this.values);

  /// `{"en": "Cat", "es": "Gato"}`, or a plain string (taken as English).
  factory LocalizedText.fromJson(Object? json) => LocalizedText(
    json is Map
        ? json.map((k, v) => MapEntry('$k', '$v'))
        : json is String
        ? {'en': json}
        : const {},
  );

  bool get isEmpty => values.values.every((v) => v.trim().isEmpty);

  final Map<String, String> values;

  /// The text in [locale], else English, else any, else ''.
  String of([String locale = 'en']) =>
      values[locale] ??
      values['en'] ??
      (values.isEmpty ? '' : values.values.first);

  @override
  String toString() => of();
}

enum ActivityType {
  game,
  video,
  song,
  story,
  audiobook,
  quiz,
  printable,
  offlineActivity;

  static ActivityType parse(String v) => switch (v) {
    'video' => video,
    'song' => song,
    'story' => story,
    'audiobook' => audiobook,
    'quiz' => quiz,
    'printable' => printable,
    'offline_activity' => offlineActivity,
    _ => game,
  };

  /// The rail section the type belongs to (docs/design/README.md §2.1).
  KidsSection get section => switch (this) {
    video => KidsSection.watch,
    song || story || audiobook => KidsSection.listen,
    _ => KidsSection.play,
  };
}

/// Rail sections. `play` (games) can't be switched off by parents.
enum KidsSection { play, learn, watch, listen, together }

class Subject {
  const Subject({
    required this.id,
    required this.key,
    required this.name,
    required this.sort,
  });

  final String id;
  final String key;
  final LocalizedText name;
  final int sort;
}

/// A content category (Bedtime, Weather, Music time…). Parents can switch categories off.
class Category {
  const Category({
    required this.id,
    required this.key,
    required this.name,
    this.sort = 0,
  });

  final String id;
  final String key;
  final LocalizedText name;
  final int sort;
}

class ActivitySummary {
  const ActivitySummary({
    required this.id,
    required this.slug,
    required this.type,
    required this.title,
    this.description = const LocalizedText({}),
    this.subjectId,
    this.ageMinMonths = 24,
    this.ageMaxMonths = 96,
    this.estimatedSeconds,
    this.plusOnly = false,
    this.players = 1,
    this.categoryId,
    this.thumbnail,
  });

  final String id;
  final String slug;
  final ActivityType type;
  final LocalizedText title;
  final LocalizedText description;
  final String? subjectId;
  final int ageMinMonths;
  final int ageMaxMonths;
  final int? estimatedSeconds;
  final bool plusOnly;
  final int players;

  /// `activities.primary_category_id`.
  final String? categoryId;

  /// The thumbnail's path in the public `public-assets` bucket (`thumbs/<id>/1/512.webp`), or
  /// null (the card draws our own art instead).
  final String? thumbnail;

  bool get isMedia =>
      type == ActivityType.video ||
      type == ActivityType.song ||
      type == ActivityType.story ||
      type == ActivityType.audiobook;

  bool suitsAge(int months) => months >= ageMinMonths && months <= ageMaxMonths;

  /// Rounded up to whole minutes, at least 1.
  int? get minutes => estimatedSeconds == null
      ? null
      : ((estimatedSeconds! + 59) ~/ 60).clamp(1, 999);
}

enum Stage {
  toddler,
  preschool,
  kindergarten,
  grade1,
  grade2;

  static Stage parse(String v) => Stage.values.firstWhere(
    (s) => s.name == v,
    orElse: () => Stage.preschool,
  );
}

class Course {
  const Course({
    required this.id,
    required this.slug,
    required this.title,
    required this.stage,
    this.description = const LocalizedText({}),
    this.subjectId,
    this.plusOnly = false,
    this.together = false,
    this.sort = 0,
    this.lessonCount = 0,
  });

  final String id;
  final String slug;
  final LocalizedText title;
  final LocalizedText description;
  final String? subjectId;
  final Stage stage;
  final bool plusOnly;

  /// A "learn together" course (child + grown-up).
  final bool together;
  final int sort;
  final int lessonCount;
}

class LessonStep {
  const LessonStep({
    required this.id,
    required this.position,
    required this.type,
    required this.activity,
    this.required = true,
  });

  final String id;
  final int position;

  /// `knowledge_check`, `intro`, `practice`, `trace`, `song`, `story`, …
  final String type;
  final bool required;
  final ActivitySummary activity;
}

/// An "island": a lesson inside a course.
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.steps,
    this.hasPrize = false,
    this.prerequisiteIds = const {},
  });

  final String id;
  final LocalizedText title;
  final List<LessonStep> steps;
  final bool hasPrize;

  /// Lessons of the same course that must be finished first (set in the CMS).
  final Set<String> prerequisiteIds;

  Iterable<LessonStep> get requiredSteps => steps.where((s) => s.required);
}

/// A course with its islands and steps, in order (modules flattened).
class CourseTree {
  const CourseTree({required this.course, required this.lessons});

  final Course course;
  final List<Lesson> lessons;

  Iterable<LessonStep> get allSteps => lessons.expand((l) => l.steps);
}

class LearningPath {
  const LearningPath({
    required this.id,
    required this.slug,
    required this.title,
    required this.stage,
    required this.ageMinMonths,
    required this.ageMaxMonths,
    required this.courseIds,
    this.description = const LocalizedText({}),
  });

  final String id;
  final String slug;
  final LocalizedText title;
  final LocalizedText description;
  final Stage stage;
  final int ageMinMonths;
  final int ageMaxMonths;

  /// In path order.
  final List<String> courseIds;

  bool suitsAge(int months) => months >= ageMinMonths && months <= ageMaxMonths;
}

class Collection {
  const Collection({
    required this.id,
    required this.slug,
    required this.surface,
    required this.kind,
    required this.title,
    required this.activityIds,
    this.ageMinMonths = 0,
    this.ageMaxMonths = 144,
  });

  final String id;
  final String slug;

  /// `home`, `learn`, `watch`, `listen`, `explore`.
  final String surface;

  /// `daily_picks`, `world`, `row`, …
  final String kind;
  final LocalizedText title;
  final List<String> activityIds;
  final int ageMinMonths;
  final int ageMaxMonths;
}

/// Everything published, loaded once per session (small: tens to hundreds of rows).
class Catalog {
  const Catalog({
    this.subjects = const [],
    this.activities = const [],
    this.courses = const [],
    this.paths = const [],
    this.collections = const [],
    this.categories = const [],
  });

  final List<Subject> subjects;
  final List<Category> categories;
  final List<ActivitySummary> activities;
  final List<Course> courses;
  final List<LearningPath> paths;
  final List<Collection> collections;

  bool get isEmpty => activities.isEmpty && courses.isEmpty;

  ActivitySummary? activity(String id) => _byId(activities, id, (a) => a.id);
  Course? course(String id) => _byId(courses, id, (c) => c.id);
  LearningPath? path(String id) => _byId(paths, id, (p) => p.id);
  Category? category(String? id) =>
      id == null ? null : _byId(categories, id, (c) => c.id);
  Subject? subjectByKey(String key) => _byId(subjects, key, (s) => s.key);
  Subject? subject(String? id) =>
      id == null ? null : _byId(subjects, id, (s) => s.id);

  static T? _byId<T>(List<T> list, String id, String Function(T) key) {
    for (final x in list) {
      if (key(x) == id) return x;
    }
    return null;
  }
}

/// A skill an activity practises (shown on the activity screen).
class SkillTag {
  const SkillTag({required this.key, required this.name});

  final String key;
  final LocalizedText name;
}
