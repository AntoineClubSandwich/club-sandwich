import 'package:supabase_flutter/supabase_flutter.dart';

const profileAvatarBucket = 'profile-avatars';
const _avatarUrlLifetimeSeconds = 3600;

bool isExternalAvatarUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.hasScheme &&
      const {'http', 'https', 'data', 'blob'}.contains(uri.scheme);
}

/// Resolves private avatar object paths in one Storage request. Existing
/// external avatar URLs are deliberately left untouched.
Future<Map<String, String>> resolveAvatarUrls(
  SupabaseClient client,
  Iterable<String?> values,
) async {
  final paths = values
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty && !isExternalAvatarUrl(value))
      .toSet()
      .toList(growable: false);
  if (paths.isEmpty) return const {};

  final results = await client.storage
      .from(profileAvatarBucket)
      .createSignedUrlsResult(paths, _avatarUrlLifetimeSeconds);
  return {
    for (final result in results)
      if (result is SignedUrlSuccess) result.path: result.signedUrl,
  };
}

String? resolvedAvatarUrl(String? value, Map<String, String> signedUrls) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (isExternalAvatarUrl(normalized)) return normalized;
  return signedUrls[normalized];
}

Future<String?> resolveAvatarUrl(SupabaseClient client, String? value) async {
  final urls = await resolveAvatarUrls(client, [value]);
  return resolvedAvatarUrl(value, urls);
}
