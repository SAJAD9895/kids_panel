import 'catalog.dart';
import 'progress.dart';

/// Published content. Reads through the Data API: RLS returns published rows only.
/// Throws [Failure] on error.
abstract interface class CatalogRepository {
  /// Subjects, published activities, courses (with island counts), paths and collections.
  Future<Catalog> loadCatalog();

  /// One course with its islands and steps, in order.
  Future<CourseTree> courseTree(String courseId);

  /// Skills an activity practises.
  Future<List<SkillTag>> activitySkills(String activityId);
}

/// One child's progress. RLS returns rows only for the signed-in parent's own children, so
/// another family's child id simply yields nothing.
abstract interface class ProgressRepository {
  Future<ChildProgress> childProgress(
    String childId, {
    required DateTime today,
  });

  /// Whether the family has an active Plus entitlement.
  Future<bool> familyHasPlus();
}
