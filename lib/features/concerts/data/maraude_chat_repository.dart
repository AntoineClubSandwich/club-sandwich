import 'package:club_sandwich/features/concerts/domain/maraude_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaraudeChatRepository {
  const MaraudeChatRepository(this._client);
  final SupabaseClient _client;

  Future<List<MaraudeMessage>> fetch(String concertId) async {
    final rows = await _client.rpc(
      'get_maraude_messages',
      params: {'requested_concert_id': concertId},
    );
    return rows.map(MaraudeMessage.fromJson).toList(growable: false);
  }

  Future<void> send(String concertId, String message) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Utilisateur non connecté.');
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    await _client.from('maraude_messages').insert({
      'concert_id': concertId,
      'user_id': userId,
      'message': normalized,
    });
  }
}
