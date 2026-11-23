import '../features/learning/domain/catalog.dart';
import '../features/learning/domain/progress.dart';
import 'demo_games.dart';
import 'demo_media_catalog.dart';

/// The content of supabase/seed.sql (sections 4–9 and 13), in memory, for demo mode and tests.
/// Ids are the slugs. Keep the two in step when the seed changes.
class DemoCatalog {
  DemoCatalog._(this.catalog, this.trees);

  final Catalog catalog;
  final Map<String, CourseTree> trees;

  static DemoCatalog empty() => DemoCatalog._(const Catalog(), const {});

  /// This content without the activities [remove] matches (tests: an empty subject).
  DemoCatalog without(bool Function(ActivitySummary) remove) => DemoCatalog._(
    Catalog(
      subjects: catalog.subjects,
      categories: catalog.categories,
      activities: catalog.activities.where((a) => !remove(a)).toList(),
      courses: catalog.courses,
      paths: catalog.paths,
      collections: catalog.collections,
    ),
    trees,
  );

  static DemoCatalog seed() {
    LocalizedText t(String en) => LocalizedText({'en': en});
    const subjectKeys = [
      ('letters', 'Letters'),
      ('numbers', 'Numbers'),
      ('shapes', 'Shapes and colours'),
      ('science', 'Science'),
      ('nature', 'Nature'),
      ('music', 'Music'),
      ('art', 'Art'),
      ('feelings', 'Feelings'),
      ('health', 'Healthy habits'),
      ('english', 'English words'),
      ('thinking', 'Thinking'),
      ('moving', 'Moving'),
    ];
    final subjects = [
      for (var i = 0; i < subjectKeys.length; i++)
        Subject(
          id: 'subject-${subjectKeys[i].$1}',
          key: subjectKeys[i].$1,
          name: t(subjectKeys[i].$2),
          sort: i + 1,
        ),
    ];
    ActivitySummary a(
      String slug,
      ActivityType type,
      String title,
      String subj,
      int min,
      int max,
      int secs,
      bool plus, {
      String descr = '',
      int players = 1,
    }) => ActivitySummary(
      id: slug,
      slug: slug,
      type: type,
      title: t(title),
      description: t(descr),
      subjectId: 'subject-$subj',
      ageMinMonths: min,
      ageMaxMonths: max,
      estimatedSeconds: secs,
      plusOnly: plus,
      players: players,
    );
    const g = ActivityType.game,
        v = ActivityType.video,
        s = ActivityType.song,
        st = ActivityType.story,
        q = ActivityType.quiz;
    final activities = [
      a(
        'shape-homes',
        g,
        'Shape homes',
        'shapes',
        36,
        72,
        180,
        false,
        descr: 'Help each shape find its home',
      ),
      a(
        'count-the-boats',
        g,
        'Count the boats',
        'numbers',
        36,
        84,
        180,
        true,
        descr: 'How many boats are on the lake?',
      ),
      a('trace-a-to-h', g, 'Trace a to h', 'letters', 42, 84, 240, true),
      a('find-the-b', g, 'Find the b', 'letters', 42, 84, 150, true),
      a('letters-check', q, 'Letters check-in', 'letters', 42, 84, 120, false),
      a(
        'race-together',
        g,
        'Race together',
        'moving',
        48,
        96,
        240,
        true,
        players: 2,
      ),
      a(
        'pip-meets-a-snail',
        v,
        'Pip meets a snail',
        'nature',
        24,
        84,
        312,
        false,
      ),
      a('counting-train', s, 'The counting train', 'music', 24, 84, 151, false),
      a(
        'the-sleepy-cloud',
        st,
        'The sleepy cloud',
        'feelings',
        24,
        84,
        300,
        true,
      ),
      a(
        'more-or-less',
        g,
        'More or less?',
        'numbers',
        36,
        84,
        180,
        true,
        descr: 'Which basket has more apples?',
      ),
      a(
        'number-trace-1-5',
        g,
        'Number trace 1 to 5',
        'numbers',
        42,
        84,
        200,
        false,
      ),
      a(
        'numbers-on-the-farm',
        v,
        'Numbers on the farm',
        'numbers',
        24,
        72,
        250,
        false,
      ),
      a(
        'ten-little-seeds',
        s,
        'Ten little seeds',
        'numbers',
        24,
        72,
        140,
        false,
      ),
      a(
        'shape-sort',
        g,
        'Shape sort',
        'shapes',
        24,
        60,
        150,
        false,
        descr: 'Put each shape in its box',
      ),
      a(
        'colour-the-garden',
        g,
        'Colour the garden',
        'shapes',
        24,
        72,
        240,
        true,
      ),
      a(
        'why-does-it-rain',
        v,
        'Why does it rain?',
        'science',
        36,
        96,
        280,
        true,
      ),
      a('feelings-song', s, 'How do you feel?', 'feelings', 24, 84, 130, false),
      a(
        'calm-breathing',
        st,
        'Bolt takes a breath',
        'feelings',
        36,
        96,
        260,
        true,
      ),
      a(
        'engine-sampler',
        g,
        'Try everything!',
        'thinking',
        36,
        96,
        420,
        false,
        descr: 'One of every kind of game',
      ),
      // Phase 10: the game collection (lib/demo/demo_games.dart).
      for (final x in demoGames)
        a(
          x.slug,
          g,
          x.title,
          x.subject,
          x.ageMin,
          x.ageMax,
          x.seconds,
          false,
          descr: x.description,
        ),
    ];
    // Phase 11: videos, songs and stories come from the media library (real files, thumbnails,
    // categories): lib/demo/demo_media_catalog.dart, the same facts as seed §16.
    final mediaSlugs = {for (final m in demoMediaItems) m.slug};
    activities
      ..removeWhere((x) => mediaSlugs.contains(x.slug))
      ..addAll([
        for (final m in demoMediaItems)
          ActivitySummary(
            id: m.slug,
            slug: m.slug,
            type: ActivityType.parse(m.type),
            title: t(m.title),
            description: t(m.description),
            subjectId: 'subject-${m.subject}',
            ageMinMonths: m.ageMin,
            ageMaxMonths: m.ageMax,
            estimatedSeconds: m.seconds,
            plusOnly: m.plus,
            categoryId: 'category-${m.category}',
            thumbnail: m.thumbnail,
          ),
      ]);
    final byId = {for (final x in activities) x.id: x};

    Lesson lesson(
      String id,
      String title,
      List<(String, String)> steps, {
      bool prize = false,
    }) => Lesson(
      id: id,
      title: t(title),
      hasPrize: prize,
      steps: [
        for (var i = 0; i < steps.length; i++)
          LessonStep(
            id: '$id-step-${i + 1}',
            position: i,
            type: steps[i].$1,
            activity: byId[steps[i].$2]!,
          ),
      ],
    );

    Course course(
      String slug,
      String title,
      String descr,
      String subj,
      Stage stage,
      bool plus,
      int sort,
      int lessons,
    ) => Course(
      id: slug,
      slug: slug,
      title: t(title),
      description: t(descr),
      subjectId: 'subject-$subj',
      stage: stage,
      plusOnly: plus,
      sort: sort,
      lessonCount: lessons,
    );
    final letters = course(
      'letters-a-to-h',
      'Letters a to h',
      'Learn your first 8 letters with Bolt',
      'letters',
      Stage.preschool,
      false,
      0,
      3,
    );
    final counting = course(
      'counting-to-10',
      'Counting to 10',
      'Count boats, seeds and farm animals',
      'numbers',
      Stage.preschool,
      true,
      2,
      2,
    );
    final shapes = course(
      'shapes-around-us',
      'Shapes around us',
      'Find circles, squares and triangles',
      'shapes',
      Stage.toddler,
      false,
      3,
      2,
    );
    final feelings = course(
      'big-feelings',
      'Big feelings',
      'Name your feelings and calm down',
      'feelings',
      Stage.kindergarten,
      true,
      4,
      1,
    );

    final trees = {
      letters.id: CourseTree(
        course: letters,
        lessons: [
          lesson('letters-1', 'Island 1: a b c', [
            ('knowledge_check', 'letters-check'),
            ('practice', 'find-the-b'),
            ('trace', 'trace-a-to-h'),
          ]),
          lesson('letters-2', 'Island 2: d e f', [
            ('intro', 'pip-meets-a-snail'),
            ('song', 'counting-train'),
            ('story', 'the-sleepy-cloud'),
          ], prize: true),
          lesson('letters-3', 'Island 3: g h', [
            ('practice', 'find-the-b'),
            ('knowledge_check', 'letters-check'),
          ]),
        ],
      ),
      counting.id: CourseTree(
        course: counting,
        lessons: [
          lesson('counting-1', 'Island 1: 1 2 3', [
            ('intro', 'numbers-on-the-farm'),
            ('practice', 'count-the-boats'),
            ('trace', 'number-trace-1-5'),
          ]),
          lesson('counting-2', 'Island 2: up to 10', [
            ('song', 'ten-little-seeds'),
            ('practice', 'more-or-less'),
          ]),
        ],
      ),
      shapes.id: CourseTree(
        course: shapes,
        lessons: [
          lesson('shapes-1', 'Island 1: circles', [
            ('practice', 'shape-sort'),
            ('practice', 'shape-homes'),
          ]),
          lesson('shapes-2', 'Island 2: squares and triangles', [
            ('practice', 'colour-the-garden'),
          ]),
        ],
      ),
      feelings.id: CourseTree(
        course: feelings,
        lessons: [
          lesson('feelings-1', 'Island 1: happy and sad', [
            ('song', 'feelings-song'),
            ('story', 'calm-breathing'),
          ]),
        ],
      ),
    };

    Collection c(
      String slug,
      String surface,
      String kind,
      String title,
      List<String> ids,
    ) => Collection(
      id: slug,
      slug: slug,
      surface: surface,
      kind: kind,
      title: t(title),
      activityIds: ids,
    );

    return DemoCatalog._(
      Catalog(
        subjects: subjects,
        categories: [
          for (final c in demoMediaCategories)
            Category(
              id: 'category-${c.key}',
              key: c.key,
              name: t(c.name),
              sort: c.sort,
            ),
        ],
        activities: activities,
        courses: [letters, counting, shapes, feelings],
        paths: [
          LearningPath(
            id: 'preschool-start',
            slug: 'preschool-start',
            title: t('Starting school'),
            description: t('Letters and numbers before school'),
            stage: Stage.preschool,
            ageMinMonths: 36,
            ageMaxMonths: 72,
            courseIds: [letters.id, counting.id],
          ),
          LearningPath(
            id: 'little-steps',
            slug: 'little-steps',
            title: t('Little steps'),
            description: t('Shapes, colours and feelings for the youngest'),
            stage: Stage.toddler,
            ageMinMonths: 24,
            ageMaxMonths: 48,
            courseIds: [shapes.id, feelings.id],
          ),
        ],
        collections: [
          c('games-for-today', 'home', 'daily_picks', 'Games for today', [
            'shape-homes',
            'count-the-boats',
            'find-the-b',
            'shape-sort',
            'more-or-less',
            'engine-sampler',
          ]),
          c('game-room', 'home', 'row', 'Game room', [
            for (final x in demoGames) x.slug,
          ]),
          c('play-together', 'home', 'row', 'Play together', ['race-together']),
          c('garden-world', 'home', 'world', "Pip's garden", [
            'shape-homes',
            'pip-meets-a-snail',
          ]),
          for (final row in demoMediaRows)
            c(row.$1, row.$2, row.$3, row.$4, row.$5),
        ],
      ),
      trees,
    );
  }

  /// Mia's progress in the seed (section 12 and 13), relative to [now].
  static ChildProgress miaProgress(DateTime now) => ChildProgress(
    completedStepIds: const {
      'letters-1-step-1',
      'letters-1-step-2',
      'letters-1-step-3',
    },
    enrollments: const [
      Enrollment(
        courseId: 'letters-a-to-h',
        status: 'in_progress',
        currentStepId: 'letters-2-step-1',
      ),
    ],
    recent: [
      PlayedActivity(
        activityId: 'pip-meets-a-snail',
        at: now.subtract(const Duration(minutes: 30)),
      ),
      PlayedActivity(
        activityId: 'count-the-boats',
        at: now.subtract(const Duration(minutes: 45)),
      ),
      PlayedActivity(
        activityId: 'shape-homes',
        at: now.subtract(const Duration(minutes: 60)),
      ),
    ],
    starsToday: 3,
    starsTotal: 3,
    rewards: const [
      EarnedReward(key: 'garden-snail', type: 'sticker', title: 'Snail'),
      EarnedReward(key: 'garden-bee', type: 'sticker', title: 'Bee'),
      EarnedReward(
        key: 'badge-first-island',
        type: 'badge',
        title: 'First island',
      ),
    ],
    favoriteIds: const {'shape-homes'},
  );
}
