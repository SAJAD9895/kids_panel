import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/demo/demo_catalog.dart';
import 'package:kids_app/features/learning/domain/catalog.dart';
import 'package:kids_app/features/learning/domain/progress.dart';
import 'package:kids_app/features/learning/domain/progress_rules.dart';

void main() {
  final content = DemoCatalog.seed();
  final letters = content.trees['letters-a-to-h']!; // 3 islands: 3, 3, 2 steps
  final counting = content.trees['counting-to-10']!;
  const L = ProgressState.locked,
      A = ProgressState.available,
      P = ProgressState.inProgress,
      C = ProgressState.completed;

  Set<String> steps(List<String> ids) => ids.toSet();

  group('islands', () {
    test('nothing done: the first island is open, the rest wait', () {
      expect(ProgressRules.lessonStates(letters, {}), [A, L, L]);
    });

    test('island 1 done: island 2 is next', () {
      final done = steps([
        'letters-1-step-1',
        'letters-1-step-2',
        'letters-1-step-3',
      ]);
      expect(ProgressRules.lessonStates(letters, done), [C, A, L]);
    });

    test('island 2 started', () {
      final done = steps([
        'letters-1-step-1',
        'letters-1-step-2',
        'letters-1-step-3',
        'letters-2-step-1',
      ]);
      expect(ProgressRules.lessonStates(letters, done), [C, P, L]);
    });

    test('an island with no steps is never "done"', () {
      final empty = CourseTree(
        course: letters.course,
        lessons: [const Lesson(id: 'x', title: LocalizedText({}), steps: [])],
      );
      expect(ProgressRules.lessonStates(empty, {}), [A]);
      expect(ProgressRules.nextStep(empty, {}), isNull);
    });
  });

  group('steps', () {
    final island2 = letters.lessons[1];

    test('in an open island: done, now, then waiting', () {
      final s = ProgressRules.stepStates(island2, P, {
        'letters-2-step-1',
      }, hasPlus: true);
      expect(s.map((x) => x.state), [C, P, L]);
    });

    test('in a locked island everything waits', () {
      expect(
        ProgressRules.stepStates(
          island2,
          L,
          {},
          hasPlus: true,
        ).map((x) => x.state),
        [L, L, L],
      );
    });

    test(
      'Plus activities need a grown-up in a Basic family, and only then',
      () {
        // island 2 step 3 is "The sleepy cloud" (Plus)
        expect(
          ProgressRules.stepStates(
            island2,
            A,
            {},
            hasPlus: false,
          )[2].needsGrownUp,
          isTrue,
        );
        expect(
          ProgressRules.stepStates(
            island2,
            A,
            {},
            hasPlus: true,
          )[2].needsGrownUp,
          isFalse,
        );
        expect(
          ProgressRules.stepStates(
            island2,
            A,
            {},
            hasPlus: false,
          )[0].needsGrownUp,
          isFalse,
        );
      },
    );

    test('optional steps are open as soon as the island is', () {
      final lesson = Lesson(
        id: 'l',
        title: const LocalizedText({}),
        steps: [
          LessonStep(
            id: 'a',
            position: 0,
            type: 'practice',
            activity: letters.lessons[0].steps[0].activity,
          ),
          LessonStep(
            id: 'b',
            position: 1,
            type: 'practice',
            activity: letters.lessons[0].steps[1].activity,
            required: false,
          ),
          LessonStep(
            id: 'c',
            position: 2,
            type: 'practice',
            activity: letters.lessons[0].steps[2].activity,
          ),
        ],
      );
      expect(
        ProgressRules.stepStates(
          lesson,
          A,
          {},
          hasPlus: true,
        ).map((x) => x.state),
        [P, A, L],
      );
    });
  });

  group('courses and paths', () {
    final mia = DemoCatalog.miaProgress(DateTime(2026, 11, 18));

    test('course state follows enrolment and steps', () {
      expect(ProgressRules.courseState(letters, ChildProgress.empty), A);
      expect(ProgressRules.courseState(letters, mia), P);
      final all = {for (final s in letters.allSteps) s.id};
      expect(
        ProgressRules.courseState(
          letters,
          ChildProgress(completedStepIds: all),
        ),
        C,
      );
      expect(
        ProgressRules.courseState(
          letters,
          const ChildProgress(
            enrollments: [
              Enrollment(courseId: 'letters-a-to-h', status: 'completed'),
            ],
          ),
        ),
        C,
      );
    });

    test('Plus course in a Basic family needs a grown-up', () {
      expect(
        ProgressRules.courseStatus(
          counting,
          ChildProgress.empty,
          hasPlus: false,
        ),
        const NodeStatus(A, needsGrownUp: true),
      );
      expect(
        ProgressRules.courseStatus(
          counting,
          ChildProgress.empty,
          hasPlus: true,
        ),
        const NodeStatus(A),
      );
    });

    test('a path opens its courses one after the other', () {
      expect(
        ProgressRules.pathStates(
          [letters, counting],
          ChildProgress.empty,
          hasPlus: true,
        ).map((s) => s.state),
        [A, L],
      );
      expect(
        ProgressRules.pathStates(
          [letters, counting],
          mia,
          hasPlus: true,
        ).map((s) => s.state),
        [P, L],
      );
      final all = {for (final s in letters.allSteps) s.id};
      expect(
        ProgressRules.pathStates(
          [letters, counting],
          ChildProgress(completedStepIds: all),
          hasPlus: true,
        ).map((s) => s.state),
        [C, A],
      );
    });

    test('fraction and next step', () {
      expect(ProgressRules.courseFraction(letters, {}), 0);
      expect(
        ProgressRules.courseFraction(letters, mia.completedStepIds),
        closeTo(3 / 8, 1e-9),
      );
      final next = ProgressRules.nextStep(letters, mia.completedStepIds)!;
      expect(next.lessonIndex, 1);
      expect(next.step.id, 'letters-2-step-1');
      expect((next.stepsDone, next.stepsTotal), (0, 3));
      final all = {for (final s in letters.allSteps) s.id};
      expect(
        ProgressRules.nextStep(letters, all),
        isNull,
        reason: 'finished course',
      );
    });
  });

  group('recommendations', () {
    final catalog = content.catalog;

    test('only what suits the age', () {
      final picks = Recommendations.forChild(
        catalog,
        ChildProgress.empty,
        ageMonths: 30,
        hasPlus: true,
        limit: 50,
      );
      expect(picks, isNotEmpty);
      expect(picks.every((a) => a.suitsAge(30)), isTrue);
      expect(
        picks.map((a) => a.id),
        isNot(contains('trace-a-to-h')),
        reason: '42+ months',
      );
    });

    test('daily picks first; played and locked ones go to the end', () {
      final mia = DemoCatalog.miaProgress(DateTime(2026, 11, 18));
      final picks = Recommendations.forChild(
        catalog,
        mia,
        ageMonths: 56,
        hasPlus: false,
        limit: 50,
      );
      final ids = picks.map((a) => a.id).toList();
      expect(
        ids.first,
        'shape-sort',
        reason: 'the first daily pick that is open and not played yet',
      );
      expect(
        ids.indexOf('shape-sort'),
        lessThan(ids.indexOf('shape-homes')),
        reason: 'shape-homes was played',
      );
      expect(
        ids.indexOf('shape-sort'),
        lessThan(ids.indexOf('find-the-b')),
        reason: 'find-the-b is Plus',
      );
      expect(ids.toSet().length, ids.length, reason: 'no duplicates');
    });

    test('path for an age', () {
      expect(Recommendations.pathFor(catalog, 40)!.slug, 'preschool-start');
      expect(Recommendations.pathFor(catalog, 26)!.slug, 'little-steps');
      expect(
        Recommendations.pathFor(catalog, 120)!.slug,
        'preschool-start',
        reason: 'falls back to the first',
      );
      expect(Recommendations.pathFor(const Catalog(), 40), isNull);
    });

    test('age in months is month precision', () {
      expect(ageInMonths(2022, 3, DateTime(2026, 11, 18)), 56);
      expect(ageInMonths(2026, 10, DateTime(2026, 11, 1)), 1);
    });
  });
}
