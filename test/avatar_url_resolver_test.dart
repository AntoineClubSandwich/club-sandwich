import 'package:club_sandwich/shared/data/avatar_url_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conserve une URL externe existante', () {
    const url = 'https://example.test/avatar.jpg';
    expect(isExternalAvatarUrl(url), isTrue);
    expect(resolvedAvatarUrl(url, const {}), url);
  });

  test('ne révèle jamais directement un chemin Storage privé', () {
    const path = 'user-id/avatar';
    expect(isExternalAvatarUrl(path), isFalse);
    expect(resolvedAvatarUrl(path, const {}), isNull);
    expect(
      resolvedAvatarUrl(path, const {path: 'https://signed.test/avatar'}),
      'https://signed.test/avatar',
    );
  });
}
