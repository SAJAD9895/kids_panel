import 'rewards.dart';

/// GET /children/:id/rewards and PUT /children/:id/goals. Rewards themselves are only ever
/// given by the server when a session is synced: there is deliberately no "award" call.
abstract interface class RewardsRepository {
  Future<RewardsSummary> rewards(String childId);
  Future<GoalSettings> saveGoals(String childId, GoalSettings goals);
}
