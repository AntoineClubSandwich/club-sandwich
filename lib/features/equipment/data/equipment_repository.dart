import 'package:club_sandwich/features/equipment/domain/equipment_asset.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _equipmentSelect = '*, location:equipment_locations(id, name, is_active)';

class EquipmentRepository {
  const EquipmentRepository(this._client);

  final SupabaseClient _client;

  Future<List<EquipmentAsset>> fetchAll() async {
    final rows = await _client
        .from('equipment_assets')
        .select(_equipmentSelect)
        .eq('is_archived', false)
        .order('name');
    return rows.map(EquipmentAsset.fromJson).toList(growable: false);
  }

  Future<List<EquipmentLocation>> fetchLocations() async {
    final rows = await _client
        .from('equipment_locations')
        .select()
        .eq('is_active', true)
        .order('name');
    return rows.map(EquipmentLocation.fromJson).toList(growable: false);
  }

  Future<List<EquipmentEvent>> fetchEvents(String equipmentId) async {
    final rows = await _client
        .from('equipment_events')
        .select('*, actor:profiles(first_name, last_name)')
        .eq('equipment_id', equipmentId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map(EquipmentEvent.fromJson).toList(growable: false);
  }

  Future<void> create({
    required String name,
    required String category,
    required int quantityTotal,
    required EquipmentStatus status,
    String? internalCode,
    String? locationId,
    String? condition,
    String? notes,
  }) async {
    await _client.from('equipment_assets').insert({
      'name': name.trim(),
      'category': category.trim(),
      'quantity_total': quantityTotal,
      'status': status.databaseValue,
      'internal_code': _nullIfBlank(internalCode),
      'location_id': locationId,
      'condition': _nullIfBlank(condition),
      'notes': _nullIfBlank(notes),
    });
  }

  Future<void> update(
    String id, {
    required String name,
    required String category,
    required int quantityTotal,
    required EquipmentStatus status,
    String? internalCode,
    String? locationId,
    String? condition,
    String? notes,
  }) async {
    await _client
        .from('equipment_assets')
        .update({
          'name': name.trim(),
          'category': category.trim(),
          'quantity_total': quantityTotal,
          'status': status.databaseValue,
          'internal_code': _nullIfBlank(internalCode),
          'location_id': locationId,
          'condition': _nullIfBlank(condition),
          'notes': _nullIfBlank(notes),
        })
        .eq('id', id);
  }

  Future<void> archive(String id) async {
    await _client
        .from('equipment_assets')
        .update({'is_archived': true})
        .eq('id', id);
  }

  Future<EquipmentLocation> createLocation(String name) async {
    final row = await _client
        .from('equipment_locations')
        .insert({'name': name.trim()})
        .select()
        .single();
    return EquipmentLocation.fromJson(row);
  }
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
