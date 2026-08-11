import 'package:club_sandwich/features/avatar/domain/avatar_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarRepository {
  const AvatarRepository(this._client);

  final SupabaseClient _client;

  Future<AvatarConfig> fetchCurrentAvatar() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return AvatarConfig.defaultConfig;

    final row = await _client
        .from('avatar_configs')
        .select('config')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return AvatarConfig.defaultConfig;
    return AvatarConfig.fromJson(row['config'] as Map<String, dynamic>);
  }

  Future<void> saveCurrentAvatar(AvatarConfig config) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Utilisateur non connecté.');
    await _client.from('avatar_configs').upsert({
      'user_id': userId,
      'config': config.toJson(),
    });
  }
}
