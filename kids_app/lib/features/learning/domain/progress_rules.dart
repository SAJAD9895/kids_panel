import 'catalog.dart';
import 'progress.dart';

/// How a course, island or step is shown to the child (docs/design/states.md).
///
/// These rules only decide what to DISPLAY. The server stays the authority: when play exists
/// (M2), `play/launch` re-checks unlocks and entitlement, so a tampered client unlocks nothing.
/// Pure Dart, unit-tested (test/unit/progress_rules_test.dart).
enum ProgressState {
  /// Not reachable yet: finish what comes before.
  locked,

  /// Open, not started.
  available,

  /// Started (or the next thing to do).
  inProgress,
  completed,
}

class NodeStatus {
  const NodeStatus(this.state, {this.needsGrownUp = false});

  final ProgressState state;

  /// Plus content in a family without Plus: the child sees "Ask a grown-up", never a price.
  final bool needsGrownUp;

  bool get isOpen => state != ProgressState.locked && !needsGrownUp;

  @override
  bool operator ==(Object other) =>
      other is NodeStatus &&
      other.state == state &&
      other.needsGrownUp == needsGrownUp;

  @override
  int get hashCode => Object.hash(state, needsGrownUp);

  @override
  String toString() => needsGrownUp ? '$state+grownUp' : '$state';
}

abstract final class ProgressRules {
  static bool lessonDone(Lesson l, Set<String> done) =>
      l.steps.isNotEmpty && l.requiredSteps.every((s) => done.contains(s.id));

  /// Islands open one after the other: the first is open, each next one opens when the one
  /// before is done and every prerequisite island (set in the CMS) is done too.
  static List<ProgressState> lessonStates(CourseTree tree, Set<String> done) {
    final out = <ProgressState>[];
    final finished = {
      for (final l in tree.lessons)
        if (lessonDone(l, done)) l.id,
    };
    var previousDone = true;
    for (final l in tree.lessons) {
      if (lessonDone(l, done)) {
        out.add(ProgressState.completed);
        previousDone = true;
      } else if (previousDone && finished.containsAll(l.prerequisiteIds)) {
        out.add(
          l.steps.any((s) => done.contains(s.id))
              ? ProgressState.inProgress
              : ProgressState.available,
        );
        previousDone = false;
      } else {
        out.add(ProgressState.locked);
      }
    }
    return out;
  }

  /// Steps of one island: done steps stay open for replay; the first required step not done
  /// yet is "now"; required steps after it wait. Optional steps are open once the island is.
  static List<NodeStatus> stepStates(
    Lesson lesson,
    ProgressState lessonState,
    Set<String> done, {
    required bool hasPlus,
  }) {
    var currentFound = false;
    return [
      for (final s in lesson.steps)
        NodeStatus(() {
          if (lessonState == ProgressState.locked) return ProgressState.locked;
          if (done.contains(s.id)) return ProgressState.completed;
          if (!s.required) return ProgressState.available;
          if (!currentFound) {
            currentFound = true;
            return ProgressState.inProgress;
          }
          return ProgressState.locked;
        }(), needsGrownUp: s.activity.plusOnly && !hasPlus),
    ];
  }

  static ProgressState courseState(CourseTree tree, ChildProgress p) {
    final e = p.enrollment(tree.course.id);
    final states = lessonStates(tree, p.completedStepIds);
    if ((e?.completed ?? false) ||
        (states.isNotEmpty &&
            states.every((s) => s == ProgressState.completed))) {
      return ProgressState.completed;
    }
    if (e != null ||
        tree.allSteps.any((s) => p.completedStepIds.contains(s.id))) {
      return ProgressState.inProgress;
    }
    return ProgressState.available;
  }

  static NodeStatus courseStatus(
    CourseTree tree,
    ChildProgress p, {
    required bool hasPlus,
  }) => NodeStatus(
    courseState(tree, p),
    needsGrownUp: tree.course.plusOnly && !hasPlus,
  );

  /// Courses of a path, in order: each opens when the one before is done (or already started).
  static List<NodeStatus> pathStates(
    List<CourseTree> trees,
    ChildProgress p, {
    required bool hasPlus,
  }) {
    final out = <NodeStatus>[];
    var previousDone = true;
    for (final t in trees) {
      final s = courseState(t, p);
      final state = switch (s) {
        ProgressState.completed => ProgressState.completed,
        ProgressState.inProgress => ProgressState.inProgress,
        _ => previousDone ? ProgressState.available : ProgressState.locked,
      };
      out.add(NodeStatus(state, needsGrownUp: t.course.plusOnly && !hasPlus));
      previousDone = s == ProgressState.completed;
    }
    return out;
  }

  /// Share of required steps done, 0..1.
  static double courseFraction(CourseTree tree, Set<String> done) {
    final req = tree.lessons.expand((l) => l.requiredSteps).toList();
    if (req.isEmpty) return 0;
    return req.where((s) => done.contains(s.id)).length / req.length;
  }

  /// What "Keep going" opens: the current island and its next step, or null when the course
  /// is finished (or has no steps).
  static NextStep? nextStep(CourseTree tree, Set<String> done) {
    final states = lessonStates(tree, done);
    for (var i = 0; i < tree.lessons.length; i++) {
      if (states[i] == ProgressState.available ||
          states[i] == ProgressState.inProgress) {
        final lesson = tree.lessons[i];
        final step =
            lesson.requiredSteps
                .where((s) => !done.contains(s.id))
                .firstOrNull ??
            lesson.steps.firstOrNull;
        if (step == null) return null;
        return NextStep(
          lesson: lesson,
          lessonIndex: i,
          step: step,
          stepsDone: lesson.requiredSteps
              .where((s) => done.contains(s.id))
              .length,
          stepsTotal: lesson.requiredSteps.length,
        );
      }
    }
    return null;
  }
}

class NextStep {
  const NextStep({
    required this.lesson,
    required this.lessonIndex,
    required this.step,
    required this.stepsDone,
    required this.stepsTotal,
  });

  final Lesson lesson;
  final int lessonIndex;
  final LessonStep step;
  final int stepsDone;
  final int stepsTotal;
}

/// Age in whole months, from a birth year and month (month precision, like the server).
int ageInMonths(int birthYear, int birthMonth, DateTime now) =>
    (now.year * 12 + now.month - 1) - (birthYear * 12 + birthMonth - 1);

abstract final class Recommendations {
  /// Today's suggestions: the home "daily picks" row first, then anything else that suits the
  /// child's age, with things not played recently before things played, open before locked.
  static List<ActivitySummary> forChild(
    Catalog catalog,
    ChildProgress p, {
    required int ageMonths,
    required bool hasPlus,
    int limit = 8,
  }) {
    final picks = catalog.collections
        .where((c) => c.surface == 'home' && c.kind == 'daily_picks')
        .expand((c) => c.activityIds)
        .map(catalog.activity)
        .whereType<ActivitySummary>();
    final rest = catalog.activities.where(
      (a) => a.type == ActivityType.game || a.type == ActivityType.quiz,
    );
    final played = {for (final r in p.recent) r.activityId};
    final seen = <String>{};
    final candidates = [
      for (final a in [...picks, ...rest])
        if (a.suitsAge(ageMonths) && seen.add(a.id)) a,
    ];
    int rank(ActivitySummary a) =>
        (played.contains(a.id) ? 2 : 0) + (a.plusOnly && !hasPlus ? 1 : 0);
    final ordered = [...candidates]..sort((a, b) => rank(a).compareTo(rank(b)));
    return ordered.take(limit).toList();
  }

  /// The path that suits the child's age best (first match), else the first path.
  static LearningPath? pathFor(Catalog catalog, int ageMonths) =>
      catalog.paths.where((p) => p.suitsAge(ageMonths)).firstOrNull ??
      catalog.paths.firstOrNull;
}
