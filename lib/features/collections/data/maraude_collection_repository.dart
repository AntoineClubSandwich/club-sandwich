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
        .rpc(
          'save_maraude_collection',
          params: {
            'requested_concert_id': concertId,
            'requested_collection_id': null,
            ..._rpcDraft(draft),
          },
        )
        .single();
    return MaraudeCollection.fromJson(row);
  }

  Future<MaraudeCollection> update(
    String collectionId,
    MaraudeCollectionDraft draft,
  ) async {
    final row = await _client
        .rpc(
          'save_maraude_collection',
          params: {
            'requested_concert_id': null,
            'requested_collection_id': collectionId,
            ..._rpcDraft(draft),
          },
        )
        .single();
    return MaraudeCollection.fromJson(row);
  }

  Future<void> delete(String collectionId) async {
    await _client.from('maraude_collections').delete().eq('id', collectionId);
  }
}

Map<String, dynamic> _rpcDraft(MaraudeCollectionDraft draft) => {
  'requested_category': draft.category.databaseValue,
  'requested_description': draft.description,
  'requested_quantity': draft.quantity,
  'requested_unit': draft.unit.databaseValue,
  'requested_average_weight_kg': draft.averageWeightKg,
  'requested_comment': draft.comment,
};
