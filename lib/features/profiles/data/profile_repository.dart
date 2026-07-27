import 'package:club_sandwich/features/profiles/domain/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  const ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile?> fetchCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  Future<void> updateCurrentProfile({
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Utilisateur non connecté.');
    final normalizedPhone = phone?.trim();
    await _client
        .from('profiles')
        .update({
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'phone': normalizedPhone == null || normalizedPhone.isEmpty
              ? null
              : normalizedPhone,
        })
        .eq('id', userId);
  }
}
