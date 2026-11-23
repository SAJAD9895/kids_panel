import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/child_profile.dart';

/// The family's children. Refetched when the signed-in parent changes.
final childrenProvider =
    AsyncNotifierProvider<ChildrenController, List<ChildProfile>>(
      ChildrenController.new,
    );

class ChildrenController extends AsyncNotifier<List<ChildProfile>> {
  @override
  Future<List<ChildProfile>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.read(childProfilesRepositoryProvider).listChildren();
  }

  /// Fetches again; the previous list stays visible while loading. Errors end up in [state].
  Future<void> reload() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {}
  }

  /// Returns the new child's id. Throws a Failure (e.g. ChildLimitFailure); the list is unchanged then.
  Future<String> add(ChildDetails details) async {
    final id = await ref
        .read(childProfilesRepositoryProvider)
        .addChild(details);
    await reload();
    return id;
  }

  Future<void> edit(String id, ChildDetails details) async {
    final updated = await ref
        .read(childProfilesRepositoryProvider)
        .updateChild(id, details);
    final current = state.value;
    if (current != null) {
      state = AsyncData([for (final c in current) c.id == id ? updated : c]);
    }
  }

  Future<void> remove(String id) async {
    await ref.read(childProfilesRepositoryProvider).deleteChild(id);
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final c in current)
          if (c.id != id) c,
      ]);
    }
    if (ref.read(selectedChildIdProvider) == id) {
      ref.read(selectedChildIdProvider.notifier).clear();
    }
  }
}

final avatarsProvider = FutureProvider<List<Avatar>>(
  (ref) => ref.read(childProfilesRepositoryProvider).listAvatars(),
);

/// Art index for an avatar id (falls back to the first buddy while avatars load).
final buddyArtIndexProvider = Provider.family<int, String?>((ref, avatarId) {
  if (avatarId == null) return 0;
  final avatars = ref.watch(avatarsProvider).value ?? const [];
  for (final a in avatars) {
    if (a.id == avatarId) return a.artIndex;
  }
  return 0;
});

/// The child using the Kids Area on this device ("Who's playing?", K35). Session state:
/// cleared on sign-out so one child's screens never show another's data.
final selectedChildIdProvider =
    NotifierProvider<SelectedChildController, String?>(
      SelectedChildController.new,
    );

class SelectedChildController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;

  void clear() => state = null;
}

final selectedChildProvider = Provider<ChildProfile?>((ref) {
  final id = ref.watch(selectedChildIdProvider);
  final children = ref.watch(childrenProvider).value;
  if (id == null || children == null) return null;
  for (final c in children) {
    if (c.id == id) return c;
  }
  return null;
});
