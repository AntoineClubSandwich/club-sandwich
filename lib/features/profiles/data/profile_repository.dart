import 'dart:typed_data';

import 'package:club_sandwich/features/profiles/domain/profile.dart';
import 'package:club_sandwich/features/profiles/domain/volunteer_private_profile.dart';
import 'package:club_sandwich/shared/data/avatar_url_resolver.dart';
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
    if (row == null) return null;
    final json = Map<String, dynamic>.from(row);
    json['avatar_url'] = await resolveAvatarUrl(
      _client,
      json['avatar_url'] as String?,
    );
    return Profile.fromJson(json);
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

  Future<String> uploadCurrentAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Utilisateur non connecté.');

    final path = '$userId/avatar';
    await _client.storage
        .from('profile-avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _client
        .from('profiles')
        .update({'avatar_url': path})
        .eq('id', userId);
    return '${await _client.storage.from(profileAvatarBucket).createSignedUrl(path, 3600)}&v=$timestamp';
  }

  Future<VolunteerPrivateProfile?> fetchCurrentVolunteerProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('volunteer_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null
        ? const VolunteerPrivateProfile()
        : VolunteerPrivateProfile.fromJson(row);
  }

  Future<void> updateCurrentVolunteerProfile({
    required String additionalInformation,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required List<String> certifications,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Utilisateur non connecté.');
    await _client.from('volunteer_profiles').upsert({
      'user_id': userId,
      'additional_information': _nullable(additionalInformation),
      'emergency_contact_name': _nullable(emergencyContactName),
      'emergency_contact_phone': _nullable(emergencyContactPhone),
      'certifications': certifications,
    });
  }
}

String? _nullable(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
