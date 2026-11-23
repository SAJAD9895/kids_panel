import 'child_profile.dart';

/// Child profiles of the signed-in family.
///
/// Reads go through the Data API under RLS (only this family's rows come back). Writes go
/// through the `children` Edge Function: clients have no write access to child_profiles.
/// Every method throws a [Failure] on error.
abstract interface class ChildProfilesRepository {
  /// Active children, in the family's order.
  Future<List<ChildProfile>> listChildren();

  /// Buddies the parent can pick from.
  Future<List<Avatar>> listAvatars();

  /// `POST /children`. Throws [ChildLimitFailure] when the plan is full. Returns the new id.
  Future<String> addChild(ChildDetails details);

  /// `PATCH /children/:id`.
  Future<ChildProfile> updateChild(String id, ChildDetails details);

  /// `DELETE /children/:id`. Owner only. Throws [ReauthRequiredFailure] if the last sign-in
  /// is older than 10 minutes.
  Future<void> deleteChild(String id);
}
