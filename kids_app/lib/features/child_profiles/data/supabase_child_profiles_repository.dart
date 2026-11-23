import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/error/failure.dart';
import '../domain/child_profile.dart';
import '../domain/child_profiles_repository.dart';

/// Reads: Data API under RLS. Writes: the `children` Edge Function.
/// No account id or user id is ever sent: the server takes them from the JWT.
class SupabaseChildProfilesRepository implements ChildProfilesRepository {
  SupabaseChildProfilesRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw mapError(e);
    }
  }

  static ChildProfile _child(Map<String, dynamic> r) => ChildProfile(
    id: r['id'] as String,
    nickname: r['nickname'] as String,
    avatarId: (r['avatar_id'] ?? r['avatarId']) as String?,
    birthYearMonth:
        BirthYearMonth.tryParse(
          (r['birth_year_month'] ?? r['birthYearMonth']) as String?,
        ) ??
        (throw const ServerFailure()),
    sort: (r['sort'] as num?)?.toInt() ?? 0,
  );

  @override
  Future<List<ChildProfile>> listChildren() => _guard(() async {
    final rows = await _client
        .from('child_profiles')
        .select('id, nickname, avatar_id, birth_year_month, sort')
        .eq('status', 'active')
        .order('sort')
        .order('created_at');
    return rows.map(_child).toList();
  });

  @override
  Future<List<Avatar>> listAvatars() => _guard(() async {
    final rows = await _client
        .from('avatars')
        .select('id, key, sort')
        .eq('active', true)
        .order('sort');
    return [
      for (final r in rows)
        Avatar(
          id: r['id'] as String,
          key: r['key'] as String,
          sort: (r['sort'] as num).toInt(),
        ),
    ];
  });

  @override
  Future<String> addChild(ChildDetails details) => _guard(() async {
    final res = await _client.functions.invoke(
      'children',
      body: details.toJson(),
    );
    return (res.data as Map)['childId'] as String;
  });

  @override
  Future<ChildProfile> updateChild(String id, ChildDetails details) =>
      _guard(() async {
        final res = await _client.functions.invoke(
          'children/$id',
          method: HttpMethod.patch,
          body: details.toJson(),
        );
        return _child(Map<String, dynamic>.from(res.data as Map));
      });

  @override
  Future<void> deleteChild(String id) => _guard(
    () => _client.functions.invoke('children/$id', method: HttpMethod.delete),
  );
}
