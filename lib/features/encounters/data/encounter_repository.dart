import 'package:club_sandwich/features/encounters/domain/maraude_encounter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EncounterRepository {
  const EncounterRepository(this.client);

  final SupabaseClient client;

  Future<MaraudeEncounter> record({
    required String maraudeId,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    final row = await client
        .rpc(
          'record_maraude_encounter',
          params: {
            'requested_maraude_id': maraudeId,
            'requested_latitude': latitude,
            'requested_longitude': longitude,
            'requested_accuracy': accuracy,
          },
        )
        .single();
    return MaraudeEncounter.fromJson(row);
  }

  Future<List<MaraudeEncounter>> fetchAdminMap(
    EncounterMapPeriod period,
  ) async {
    final rows = await client.rpc<List<dynamic>>(
      'get_admin_encounter_map',
      params: {
        'requested_from': period.from.toUtc().toIso8601String(),
        'requested_to': period.to.toUtc().toIso8601String(),
      },
    );
    return rows
        .map(
          (row) =>
              MaraudeEncounter.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }
}
