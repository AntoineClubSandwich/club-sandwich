import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/distributions/domain/maraude_distribution.dart';
import 'package:club_sandwich/features/operations/domain/maraude_workflow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaraudeOperationRepository {
  const MaraudeOperationRepository(this.client);

  final SupabaseClient client;

  Future<MaraudeOperationBundle> fetchBundle(String concertId) async {
    final result = await client.rpc<Object?>(
      'get_maraude_operation_bundle',
      params: {'requested_concert_id': concertId},
    );
    return MaraudeOperationBundle.fromJson(
      Map<String, dynamic>.from(result! as Map),
    );
  }

  Future<void> planResources({
    required String concertId,
    required Map<String, double> consumables,
    required Map<String, int> equipment,
  }) async {
    await client.rpc<void>(
      'plan_maraude_resources',
      params: {
        'requested_concert_id': concertId,
        'requested_consumables': [
          for (final entry in consumables.entries)
            {'consumable_id': entry.key, 'planned_quantity': entry.value},
        ],
        'requested_equipment': [
          for (final entry in equipment.entries)
            {'equipment_id': entry.key, 'planned_quantity': entry.value},
        ],
      },
    );
  }

  Future<List<MaraudeResourceCatalogConsumable>> fetchConsumableCatalog(
    String concertId,
  ) async {
    final rows = await client.rpc<List<dynamic>>(
      'get_maraude_consumable_catalog',
      params: {'requested_concert_id': concertId},
    );
    return rows
        .map(
          (row) => MaraudeResourceCatalogConsumable.fromJson(
            row as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  Future<List<MaraudeResourceCatalogEquipment>> fetchEquipmentCatalog(
    String concertId,
  ) async {
    final rows = await client.rpc<List<dynamic>>(
      'get_maraude_equipment_catalog',
      params: {'requested_concert_id': concertId},
    );
    return rows
        .map(
          (row) => MaraudeResourceCatalogEquipment.fromJson(
            row as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  Future<void> addResourceAllocation({
    required String concertId,
    String? consumableId,
    String? equipmentId,
    required num quantity,
  }) => client.rpc<void>(
    'add_maraude_resource_allocation',
    params: {
      'requested_concert_id': concertId,
      'requested_consumable_id': consumableId,
      'requested_equipment_id': equipmentId,
      'requested_quantity': quantity,
    },
  );

  Future<void> validatePreparation({
    required String concertId,
    required Map<String, double> consumableQuantities,
    required Map<String, int> equipmentQuantities,
  }) async {
    await client.rpc<void>(
      'validate_maraude_preparation',
      params: {
        'requested_concert_id': concertId,
        'requested_consumables': [
          for (final entry in consumableQuantities.entries)
            {'allocation_id': entry.key, 'actual_quantity': entry.value},
        ],
        'requested_equipment': [
          for (final entry in equipmentQuantities.entries)
            {'allocation_id': entry.key, 'taken_quantity': entry.value},
        ],
      },
    );
  }

  Future<MaraudeCollection> saveCollection({
    required String concertId,
    required String description,
    required int boxCount,
    required double weightKg,
    String? collectionId,
    String? comment,
  }) async {
    final row = await client
        .rpc(
          'save_maraude_collection_v2',
          params: {
            'requested_concert_id': concertId,
            'requested_collection_id': collectionId,
            'requested_description': description,
            'requested_box_count': boxCount,
            'requested_weight_kg': weightKg,
            'requested_comment': comment,
          },
        )
        .single();
    return MaraudeCollection.fromJson(row);
  }

  Future<void> deleteCollection(String id) =>
      client.from('maraude_collections').delete().eq('id', id);

  Future<MaraudeDistribution> saveDistribution({
    required String concertId,
    required Map<String, int> distributedBoxesByAllocation,
    required int beneficiaries,
    String? comment,
  }) async {
    final row = await client
        .rpc(
          'save_maraude_distribution_v4',
          params: {
            'requested_concert_id': concertId,
            'requested_box_distributions': [
              for (final entry in distributedBoxesByAllocation.entries)
                {
                  'allocation_id': entry.key,
                  'distributed_quantity': entry.value,
                },
            ],
            'requested_beneficiaries': beneficiaries,
            'requested_comment': comment,
          },
        )
        .single();
    return MaraudeDistribution.fromJson(row);
  }

  Future<void> recordEquipmentReturn({
    required String concertId,
    required List<EquipmentReturnDraft> returns,
  }) => client.rpc<void>(
    'record_maraude_equipment_return',
    params: {
      'requested_concert_id': concertId,
      'requested_returns': [for (final item in returns) item.toJson()],
    },
  );

  Future<void> validateStep(String concertId, MaraudeOperationalStep step) =>
      client.rpc<void>(
        'validate_maraude_step',
        params: {
          'requested_concert_id': concertId,
          'requested_step': step.databaseValue,
        },
      );

  Future<void> complete(String concertId) => client.rpc<void>(
    'complete_guided_maraude',
    params: {'requested_concert_id': concertId},
  );
}

class EquipmentReturnDraft {
  const EquipmentReturnDraft({
    required this.allocationId,
    required this.returnedQuantity,
    this.incidentType,
    this.incidentNote,
  });

  final String allocationId;
  final int returnedQuantity;
  final EquipmentIncidentType? incidentType;
  final String? incidentNote;

  Map<String, dynamic> toJson() => {
    'allocation_id': allocationId,
    'returned_quantity': returnedQuantity,
    'incident_type': incidentType?.databaseValue,
    'incident_note': incidentNote,
  };
}
