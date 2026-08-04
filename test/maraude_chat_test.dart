import 'package:club_sandwich/features/concerts/domain/maraude_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('affiche le rôle admin fourni par la requête sécurisée', () {
    final message = MaraudeMessage.fromJson({
      'id': 'message-id',
      'user_id': 'admin-id',
      'author_name': 'Admin',
      'message': 'Message de coordination',
      'created_at': '2026-07-28T20:38:00.000Z',
    });

    expect(message.authorName, 'Admin');
  });

  test('conserve Bénévole uniquement comme dernier secours', () {
    final message = MaraudeMessage.fromJson({
      'id': 'message-id',
      'user_id': 'volunteer-id',
      'author_name': '',
      'message': 'Présent',
      'created_at': '2026-07-28T20:38:00.000Z',
    });

    expect(message.authorName, 'Bénévole');
  });
}
