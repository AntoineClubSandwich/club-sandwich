import 'package:club_sandwich/features/distributions/domain/maraude_distribution.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaraudeDistributionRepository {
  const MaraudeDistributionRepository(this._client);

  final SupabaseClient _client;

  Future<MaraudeDistribution> create(
    String concertId,
    MaraudeDistributionDraft draft,
  ) async {
    final row = await _client
        .from('maraude_distributions')
        .insert({...draft.toJson(), 'concert_id': concertId})
        .select()
        .single();
    return MaraudeDistribution.fromJson(row);
  }

  Future<MaraudeDistribution> update(
    String distributionId,
    MaraudeDistributionDraft draft,
  ) async {
    final row = await _client
        .from('maraude_distributions')
        .update(draft.toJson())
        .eq('id', distributionId)
        .select()
        .single();
    return MaraudeDistribution.fromJson(row);
  }
}
