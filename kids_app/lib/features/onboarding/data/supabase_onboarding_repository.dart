import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../domain/onboarding_repository.dart';

class SupabaseOnboardingRepository implements OnboardingRepository {
  SupabaseOnboardingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> hasFamilyAccount(String userId) async {
    try {
      // RLS: a parent can read only their own parent_profiles row.
      final row = await _client
          .from('parent_profiles')
          .select('account_id')
          .eq('user_id', userId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<OnboardingResult> complete(OnboardingRequest request) async {
    try {
      final res = await _client.functions.invoke(
        'onboarding/complete',
        body: request.toJson(),
      );
      final data = res.data as Map;
      return OnboardingResult(
        accountId: data['accountId'] as String,
        childId: data['childId'] as String?,
        created: data['created'] as bool? ?? true,
      );
    } catch (e) {
      throw mapError(e);
    }
  }
}
