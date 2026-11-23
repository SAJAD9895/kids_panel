import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../domain/rewards.dart';
import '../domain/rewards_repository.dart';

/// `GET /children/:id/rewards` and `PUT /children/:id/goals` (Edge Function `children`). The
/// summary is computed on the server with the household's day and week.
class SupabaseRewardsRepository implements RewardsRepository {
  SupabaseRewardsRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<RewardsSummary> rewards(String childId) async {
    try {
      final res = await _db.functions.invoke(
        'children/$childId/rewards',
        method: HttpMethod.get,
      );
      return RewardsSummary.fromJson(res.data as Map);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<GoalSettings> saveGoals(String childId, GoalSettings goals) async {
    try {
      final res = await _db.functions.invoke(
        'children/$childId/goals',
        method: HttpMethod.put,
        body: goals.toJson(),
      );
      return GoalSettings.fromJson(res.data as Map);
    } catch (e) {
      throw mapError(e);
    }
  }
}
