import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/features/learning/domain/catalog.dart';
import 'package:kids_app/features/learning/domain/progress_rules.dart';

/// Phase 14: lesson prerequisites set in the admin CMS are enforced by the app.
void main() {
  ActivitySummary a(String id) => ActivitySummary(
    id: id,
    slug: id,
    type: ActivityType.game,
    title: LocalizedText({'en': id}),
  );
  Lesson lesson(String id, {Set<String> pre = const {}}) => Lesson(
    id: id,
    title: LocalizedText({'en': id}),
    prerequisiteIds: pre,
    steps: [
      LessonStep(
        id: '$id-s',
        position: 0,
        type: 'practice',
        activity: a('$id-a'),
      ),
    ],
  );
  const course = Course(
    id: 'c',
    slug: 'c',
    title: LocalizedText({'en': 'C'}),
    stage: Stage.preschool,
  );

  test('a lesson with an unfinished prerequisite stays locked', () {
    final tree = CourseTree(
      course: course,
      lessons: [
        lesson('l1'),
        lesson('l2'),
        lesson('l3', pre: {'l1', 'l2'}),
      ],
    );
    expect(ProgressRules.lessonStates(tree, {}), [
      ProgressState.available,
      ProgressState.locked,
      ProgressState.locked,
    ]);
    expect(
      ProgressRules.lessonStates(tree, {'l1-s', 'l2-s'})[2],
      ProgressState.available,
    );
  });

  test('prerequisites can lock a lesson even when the one before is done', () {
    final tree = CourseTree(
      course: course,
      lessons: [
        lesson('l1'),
        lesson('l2', pre: {'l3'}),
        lesson('l3'),
      ],
    );
    final s = ProgressRules.lessonStates(tree, {'l1-s'});
    expect(s[1], ProgressState.locked);
  });

  test('no prerequisites: unchanged (one after the other)', () {
    final tree = CourseTree(
      course: course,
      lessons: [lesson('l1'), lesson('l2')],
    );
    expect(ProgressRules.lessonStates(tree, {'l1-s'}), [
      ProgressState.completed,
      ProgressState.available,
    ]);
  });
}
