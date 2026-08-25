import 'package:club_sandwich/features/consumables/domain/consumable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConsumableRepository {
  const ConsumableRepository(this._client);

  final SupabaseClient _client;

  Future<List<Consumable>> fetchAll() async {
    final rows = await _client
        .from('consumables')
        .select()
        .eq('is_archived', false)
        .order('name');
    return rows.map(Consumable.fromJson).toList(growable: false);
  }

  Future<List<ConsumableMovement>> fetchMovements(String consumableId) async {
    final rows = await _client
        .from('consumable_movements')
        .select('*, actor:profiles(first_name, last_name)')
        .eq('consumable_id', consumableId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map(ConsumableMovement.fromJson).toList(growable: false);
  }

  Future<Consumable> create({
    required String name,
    required String category,
    required InventoryUnit unit,
    required double initialQuantity,
    required double alertThreshold,
    String? storageLocation,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_consumable',
      params: {
        'requested_name': name,
        'requested_category': category,
        'requested_unit': unit.databaseValue,
        'requested_initial_quantity': initialQuantity,
        'requested_alert_threshold': alertThreshold,
        'requested_storage_location': storageLocation,
      },
    );
    return Consumable.fromJson(row);
  }

  Future<void> updateMetadata(
    String id, {
    required String name,
    required String category,
    required InventoryUnit unit,
    required double alertThreshold,
    String? storageLocation,
  }) async {
    await _client
        .from('consumables')
        .update({
          'name': name.trim(),
          'category': category.trim(),
          'unit': unit.databaseValue,
          'alert_threshold': alertThreshold,
          'storage_location': _nullIfBlank(storageLocation),
        })
        .eq('id', id);
  }

  Future<void> archive(String id) async {
    await _client
        .from('consumables')
        .update({'is_archived': true})
        .eq('id', id);
  }

  Future<Consumable> moveStock({
    required String id,
    required double newQuantity,
    required InventoryMovementReason reason,
    String? note,
    String? concertId,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'apply_consumable_movement',
      params: {
        'requested_consumable_id': id,
        'requested_new_quantity': newQuantity,
        'requested_reason': reason.databaseValue,
        'requested_note': note,
        'requested_concert_id': concertId,
      },
    );
    return Consumable.fromJson(row);
  }
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
