import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/consumables/domain/consumable.dart';
import 'package:club_sandwich/features/distributions/domain/maraude_distribution.dart';
import 'package:club_sandwich/features/equipment/domain/equipment_asset.dart';

enum MaraudeOperationalStep {
  preparation('preparation', 'Préparation'),
  collection('collection', 'Collecte'),
  distribution('distribution', 'Distribution'),
  equipmentReturn('equipment_return', 'Retour matériel'),
  summary('summary', 'Bilan');

  const MaraudeOperationalStep(this.databaseValue, this.label);
  final String databaseValue;
  final String label;

  factory MaraudeOperationalStep.fromJson(String value) => values.firstWhere(
    (step) => step.databaseValue == value,
    orElse: () => MaraudeOperationalStep.preparation,
  );
}

enum EquipmentIncidentType {
  missing('missing', 'Manquant'),
  damaged('damaged', 'Endommagé'),
  needsCleaning('needs_cleaning', 'À nettoyer'),
  needsCheck('needs_check', 'À vérifier'),
  lost('lost', 'Perdu'),
  other('other', 'Autre');

  const EquipmentIncidentType(this.databaseValue, this.label);
  final String databaseValue;
  final String label;

  factory EquipmentIncidentType.fromJson(String value) => values.firstWhere(
    (incident) => incident.databaseValue == value,
    orElse: () => EquipmentIncidentType.other,
  );
}

class MaraudeOperation {
  const MaraudeOperation({
    required this.concertId,
    required this.currentStep,
    required this.createdAt,
    required this.updatedAt,
    this.preparationCompletedAt,
    this.collectionCompletedAt,
    this.distributionCompletedAt,
    this.equipmentReturnCompletedAt,
    this.summaryCompletedAt,
    this.lastModifiedBy,
  });

  factory MaraudeOperation.fromJson(Map<String, dynamic> json) =>
      MaraudeOperation(
        concertId: json['concert_id'] as String,
        currentStep: MaraudeOperationalStep.fromJson(
          json['current_step'] as String,
        ),
        preparationCompletedAt: _date(json['preparation_completed_at']),
        collectionCompletedAt: _date(json['collection_completed_at']),
        distributionCompletedAt: _date(json['distribution_completed_at']),
        equipmentReturnCompletedAt: _date(
          json['equipment_return_completed_at'],
        ),
        summaryCompletedAt: _date(json['summary_completed_at']),
        lastModifiedBy: json['last_modified_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  final String concertId;
  final MaraudeOperationalStep currentStep;
  final DateTime? preparationCompletedAt;
  final DateTime? collectionCompletedAt;
  final DateTime? distributionCompletedAt;
  final DateTime? equipmentReturnCompletedAt;
  final DateTime? summaryCompletedAt;
  final String? lastModifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MaraudeConsumableAllocation {
  const MaraudeConsumableAllocation({
    required this.id,
    required this.concertId,
    required this.consumableId,
    required this.name,
    required this.unit,
    required this.plannedQuantity,
    required this.availableQuantity,
    this.actualQuantity,
    this.validatedAt,
  });

  factory MaraudeConsumableAllocation.fromJson(Map<String, dynamic> json) =>
      MaraudeConsumableAllocation(
        id: json['id'] as String,
        concertId: json['concert_id'] as String,
        consumableId: json['consumable_id'] as String,
        name: json['name'] as String,
        unit: InventoryUnit.fromJson(json['unit'] as String),
        plannedQuantity: (json['planned_quantity'] as num).toDouble(),
        actualQuantity: (json['actual_quantity'] as num?)?.toDouble(),
        availableQuantity: (json['available_quantity'] as num).toDouble(),
        validatedAt: _date(json['validated_at']),
      );

  final String id;
  final String concertId;
  final String consumableId;
  final String name;
  final InventoryUnit unit;
  final double plannedQuantity;
  final double? actualQuantity;
  final double availableQuantity;
  final DateTime? validatedAt;
}

class MaraudeEquipmentAllocation {
  const MaraudeEquipmentAllocation({
    required this.id,
    required this.concertId,
    required this.equipmentId,
    required this.name,
    required this.status,
    required this.quantityTotal,
    required this.plannedQuantity,
    this.locationName,
    this.takenQuantity,
    this.returnedQuantity,
    this.incidentType,
    this.incidentNote,
  });

  factory MaraudeEquipmentAllocation.fromJson(Map<String, dynamic> json) =>
      MaraudeEquipmentAllocation(
        id: json['id'] as String,
        concertId: json['concert_id'] as String,
        equipmentId: json['equipment_id'] as String,
        name: json['name'] as String,
        status: EquipmentStatus.fromJson(json['status'] as String),
        quantityTotal: (json['quantity_total'] as num).toInt(),
        locationName: json['location_name'] as String?,
        plannedQuantity: (json['planned_quantity'] as num).toInt(),
        takenQuantity: (json['taken_quantity'] as num?)?.toInt(),
        returnedQuantity: (json['returned_quantity'] as num?)?.toInt(),
        incidentType: json['incident_type'] == null
            ? null
            : EquipmentIncidentType.fromJson(json['incident_type'] as String),
        incidentNote: json['incident_note'] as String?,
      );

  final String id;
  final String concertId;
  final String equipmentId;
  final String name;
  final EquipmentStatus status;
  final int quantityTotal;
  final String? locationName;
  final int plannedQuantity;
  final int? takenQuantity;
  final int? returnedQuantity;
  final EquipmentIncidentType? incidentType;
  final String? incidentNote;
}

class MaraudeStepEvent {
  const MaraudeStepEvent({
    required this.id,
    required this.step,
    required this.eventType,
    required this.createdAt,
    this.actorId,
  });

  factory MaraudeStepEvent.fromJson(Map<String, dynamic> json) =>
      MaraudeStepEvent(
        id: json['id'] as String,
        step: MaraudeOperationalStep.fromJson(json['step'] as String),
        eventType: json['event_type'] as String,
        actorId: json['actor_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final MaraudeOperationalStep step;
  final String eventType;
  final String? actorId;
  final DateTime createdAt;
}

class MaraudeOperationBundle {
  const MaraudeOperationBundle({
    required this.consumables,
    required this.equipment,
    required this.collections,
    required this.history,
    this.encounterCount = 0,
    this.operation,
    this.distribution,
  });

  factory MaraudeOperationBundle.fromJson(Map<String, dynamic> json) =>
      MaraudeOperationBundle(
        operation: json['operation'] == null
            ? null
            : MaraudeOperation.fromJson(
                Map<String, dynamic>.from(json['operation'] as Map),
              ),
        consumables: _maps(
          json['consumables'],
        ).map(MaraudeConsumableAllocation.fromJson).toList(growable: false),
        equipment: _maps(
          json['equipment'],
        ).map(MaraudeEquipmentAllocation.fromJson).toList(growable: false),
        collections: _maps(
          json['collections'],
        ).map(MaraudeCollection.fromJson).toList(growable: false),
        distribution: json['distribution'] == null
            ? null
            : MaraudeDistribution.fromJson(
                Map<String, dynamic>.from(json['distribution'] as Map),
              ),
        encounterCount: (json['encounter_count'] as num?)?.toInt() ?? 0,
        history: _maps(
          json['history'],
        ).map(MaraudeStepEvent.fromJson).toList(growable: false),
      );

  final MaraudeOperation? operation;
  final List<MaraudeConsumableAllocation> consumables;
  final List<MaraudeEquipmentAllocation> equipment;
  final List<MaraudeCollection> collections;
  final MaraudeDistribution? distribution;
  final int encounterCount;
  final List<MaraudeStepEvent> history;

  int get totalCollectedBoxes => collections
      .where((line) => line.unit == CollectionUnit.box)
      .fold(0, (total, line) => total + line.quantity.round());

  int get totalPreparedBoxes => consumables
      .where((item) => item.unit == InventoryUnit.box)
      .fold(0, (total, item) => total + (item.actualQuantity ?? 0).round());

  double get totalCollectedWeight =>
      collections.fold(0, (total, line) => total + (line.weightKg ?? 0));
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

Iterable<Map<String, dynamic>> _maps(Object? value) =>
    (value as List? ?? const []).map(
      (item) => Map<String, dynamic>.from(item as Map),
    );
