import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/clock/clock.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../child_profiles/presentation/child_providers.dart';
import '../domain/catalog.dart';
import '../domain/progress.dart';
import '../domain/progress_rules.dart';

/// Published content, loaded once per signed-in parent.
final catalogProvider = FutureProvider<Catalog>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.read(catalogRepositoryProvider).loadCatalog();
});

/// One course with its islands and steps.
final courseTreeProvider = FutureProvider.family<CourseTree, String>(
  (ref, courseId) => ref.read(catalogRepositoryProvider).courseTree(courseId),
);

final activitySkillsProvider = FutureProvider.family<List<SkillTag>, String>(
  (ref, activityId) =>
      ref.read(catalogRepositoryProvider).activitySkills(activityId),
);

/// Progress of one child (keyed by id, so switching child never shows the previous child's).
final childProgressProvider = FutureProvider.family<ChildProgress, String>(
  (ref, childId) => ref
      .read(progressRepositoryProvider)
      .childProgress(childId, today: ref.read(clockProvider)()),
);

final familyPlusProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return false;
  return ref.read(progressRepositoryProvider).familyHasPlus();
});

/// The selected child's age in months (null when no child is selected).
final childAgeMonthsProvider = Provider<int?>((ref) {
  final child = ref.watch(selectedChildProvider);
  if (child == null) return null;
  return ageInMonths(
    child.birthYearMonth.year,
    child.birthYearMonth.month,
    ref.watch(clockProvider)(),
  );
});

/// Everything a kid screen needs, together: content, the selected child's progress and Plus.
class KidsData {
  const KidsData({
    required this.catalog,
    required this.progress,
    required this.hasPlus,
    required this.ageMonths,
  });

  final Catalog catalog;
  final ChildProgress progress;
  final bool hasPlus;
  final int ageMonths;

  bool locked(ActivitySummary a) => a.plusOnly && !hasPlus;
}

final kidsDataProvider = FutureProvider<KidsData>((ref) async {
  final childId = ref.watch(selectedChildIdProvider);
  final age = ref.watch(childAgeMonthsProvider) ?? 48;
  final results = await Future.wait([
    ref.watch(catalogProvider.future),
    childId == null
        ? Future.value(ChildProgress.empty)
        : ref.watch(childProgressProvider(childId).future),
    ref.watch(familyPlusProvider.future),
  ]);
  return KidsData(
    catalog: results[0] as Catalog,
    progress: results[1] as ChildProgress,
    hasPlus: results[2] as bool,
    ageMonths: age,
  );
});

/// Course trees for several courses (path screen, course lists), in the given order.
final courseTreesProvider = FutureProvider.family<List<CourseTree>, String>((
  ref,
  joinedIds,
) async {
  final ids = joinedIds.isEmpty ? const <String>[] : joinedIds.split(',');
  return Future.wait([
    for (final id in ids) ref.watch(courseTreeProvider(id).future),
  ]);
});

/// Re-fetches everything a kid screen shows (pull-to-retry after an error).
void refreshKidsData(WidgetRef ref) {
  final childId = ref.read(selectedChildIdProvider);
  ref.invalidate(catalogProvider);
  ref.invalidate(familyPlusProvider);
  ref.invalidate(courseTreeProvider);
  if (childId != null) ref.invalidate(childProgressProvider(childId));
}
