import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaraudeCollectionRepository {
  const MaraudeCollectionRepository(this._client);

  final SupabaseClient _client;

  Future<MaraudeCollection> create(
    String concertId,
    MaraudeCollectionDraft draft,
  ) async {
    final row = await _client
        .from('maraude_collections')
        .insert({...draft.toJson(), 'concert_id': concertId})
        .select()
        .single();
    return MaraudeCollection.fromJson(row);
  }

  Future<MaraudeCollection> update(
    String collectionId,
    MaraudeCollectionDraft draft,
  ) async {
    final row = await _client
        .from('maraude_collections')
        .update(draft.toJson())
        .eq('id', collectionId)
        .select()
        .single();
    return MaraudeCollection.fromJson(row);
  }

  Future<void> delete(String collectionId) async {
    await _client.from('maraude_collections').delete().eq('id', collectionId);
  }
}
