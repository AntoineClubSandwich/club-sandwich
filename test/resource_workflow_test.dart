import 'package:club_sandwich/features/consumables/domain/consumable.dart';
import 'package:club_sandwich/features/distributions/domain/maraude_distribution.dart';
import 'package:club_sandwich/features/equipment/domain/equipment_asset.dart';
import 'package:club_sandwich/features/operations/data/maraude_operation_repository.dart';
import 'package:club_sandwich/features/operations/domain/maraude_workflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Consommable', () {
    Consumable item(double quantity, double threshold) => Consumable(
      id: 'item-1',
      name: 'Gants',
      category: 'Hygiène',
      currentQuantity: quantity,
      unit: InventoryUnit.box,
      alertThreshold: threshold,
      isArchived: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('calcule les trois états de stock', () {
      expect(item(8, 2).stockStatus, ConsumableStockStatus.ok);
      expect(item(2, 2).stockStatus, ConsumableStockStatus.low);
      expect(item(0, 2).stockStatus, ConsumableStockStatus.out);
    });

    test('la liste à acheter contient stock faible et rupture', () {
      expect(item(8, 2).shouldBuy, isFalse);
      expect(item(2, 2).shouldBuy, isTrue);
      expect(item(0, 2).shouldBuy, isTrue);
    });

    test('parse les champs Supabase', () {
      final parsed = Consumable.fromJson({
        'id': 'item-1',
        'name': 'Sacs',
        'category': 'Distribution',
        'current_quantity': 12,
        'unit': 'pack',
        'alert_threshold': 3,
        'storage_location': null,
        'is_archived': false,
        'created_at': '2026-08-25T10:00:00Z',
        'updated_at': '2026-08-25T11:00:00Z',
      });
      expect(parsed.unit, InventoryUnit.pack);
      expect(parsed.storageLocation, isNull);
      expect(parsed.currentQuantity, 12);
    });
  });

  group('Parc matériel', () {
    test('parse un équipement et son emplacement', () {
      final asset = EquipmentAsset.fromJson({
        'id': 'asset-1',
        'name': 'Balance',
        'category': 'Pesée',
        'quantity_total': 1,
        'status': 'needs_check',
        'is_archived': false,
        'location_id': 'location-1',
        'location': {'id': 'location-1', 'name': 'Local', 'is_active': true},
        'created_at': '2026-08-25T10:00:00Z',
        'updated_at': '2026-08-25T11:00:00Z',
      });
      expect(asset.status, EquipmentStatus.needsCheck);
      expect(asset.locationName, 'Local');
      expect(asset.internalCode, isNull);
    });

    test('un statut inconnu reste exploitable', () {
      expect(
        EquipmentStatus.fromJson('future_status'),
        EquipmentStatus.needsCheck,
      );
    });
  });

  group('Workflow terrain', () {
    final bundleJson = {
      'operation': {
        'concert_id': 'concert-1',
        'current_step': 'distribution',
        'created_at': '2026-08-25T10:00:00Z',
        'updated_at': '2026-08-25T11:00:00Z',
      },
      'consumables': [
        {
          'id': 'allocation-1',
          'concert_id': 'concert-1',
          'consumable_id': 'item-1',
          'name': 'Gants',
          'unit': 'box',
          'planned_quantity': 2,
          'actual_quantity': 1,
          'available_quantity': 8,
        },
      ],
      'equipment': [
        {
          'id': 'equipment-allocation-1',
          'concert_id': 'concert-1',
          'equipment_id': 'asset-1',
          'name': 'Balance',
          'status': 'in_use',
          'quantity_total': 1,
          'planned_quantity': 1,
          'taken_quantity': 1,
          'location_name': 'Local',
        },
      ],
      'collections': [
        {
          'id': 'collection-1',
          'concert_id': 'concert-1',
          'category': 'prepared_meals',
          'description': 'Curry',
          'quantity': 8,
          'unit': 'box',
          'weight_kg': 6.2,
          'average_weight_kg': 0.775,
          'created_at': '2026-08-25T10:00:00Z',
          'updated_at': '2026-08-25T10:00:00Z',
        },
        {
          'id': 'collection-2',
          'concert_id': 'concert-1',
          'category': 'prepared_meals',
          'description': 'Desserts',
          'quantity': 9,
          'unit': 'box',
          'weight_kg': 3.1,
          'average_weight_kg': 0.344,
          'created_at': '2026-08-25T10:05:00Z',
          'updated_at': '2026-08-25T10:05:00Z',
        },
      ],
      'distribution': {
        'id': 'distribution-1',
        'concert_id': 'concert-1',
        'collected_boxes': 17,
        'distributed_boxes': 15,
        'remaining_boxes': 2,
        'estimated_beneficiaries': 12,
        'created_at': '2026-08-25T11:00:00Z',
        'updated_at': '2026-08-25T11:00:00Z',
      },
      'history': [
        {
          'id': 'event-1',
          'step': 'preparation',
          'event_type': 'completed',
          'created_at': '2026-08-25T10:10:00Z',
        },
      ],
    };

    test('parse le bundle groupé sans N+1', () {
      final bundle = MaraudeOperationBundle.fromJson(bundleJson);
      expect(
        bundle.operation?.currentStep,
        MaraudeOperationalStep.distribution,
      );
      expect(bundle.consumables.single.actualQuantity, 1);
      expect(bundle.equipment.single.status, EquipmentStatus.inUse);
      expect(bundle.history.single.eventType, 'completed');
    });

    test('calcule les totaux de collecte à partir des lignes', () {
      final bundle = MaraudeOperationBundle.fromJson(bundleJson);
      expect(bundle.totalCollectedBoxes, 17);
      expect(bundle.totalCollectedWeight, closeTo(9.3, 0.0001));
    });

    test(
      'parse les boîtes de distribution sans les confondre avec les repas',
      () {
        final distribution = MaraudeOperationBundle.fromJson(
          bundleJson,
        ).distribution;
        expect(distribution?.distributedBoxes, 15);
        expect(distribution?.remainingBoxes, 2);
        expect(distribution?.distributedMeals, isNull);
      },
    );

    test('sérialise un retour matériel avec incident', () {
      const draft = EquipmentReturnDraft(
        allocationId: 'allocation-1',
        returnedQuantity: 0,
        incidentType: EquipmentIncidentType.lost,
        incidentNote: 'Non retrouvé',
      );
      expect(draft.toJson(), {
        'allocation_id': 'allocation-1',
        'returned_quantity': 0,
        'incident_type': 'lost',
        'incident_note': 'Non retrouvé',
      });
    });
  });

  test('MaraudeDistribution conserve les nouvelles colonnes optionnelles', () {
    final distribution = MaraudeDistribution.fromJson({
      'id': 'distribution-1',
      'concert_id': 'concert-1',
      'collected_boxes': null,
      'distributed_boxes': null,
      'remaining_boxes': null,
      'last_modified_by': null,
      'created_at': '2026-08-25T10:00:00Z',
      'updated_at': '2026-08-25T11:00:00Z',
    });
    expect(distribution.collectedBoxes, isNull);
    expect(distribution.toJson()['remaining_boxes'], isNull);
  });
}
