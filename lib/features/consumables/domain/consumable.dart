enum InventoryUnit {
  unit('unit', 'unité'),
  box('box', 'boîte'),
  roll('roll', 'rouleau'),
  pack('pack', 'paquet'),
  pair('pair', 'paire'),
  carton('carton', 'carton'),
  bag('bag', 'sac'),
  bottle('bottle', 'bouteille'),
  other('other', 'autre');

  const InventoryUnit(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  factory InventoryUnit.fromJson(String value) => values.firstWhere(
    (unit) => unit.databaseValue == value,
    orElse: () => InventoryUnit.other,
  );
}

enum ConsumableStockStatus {
  ok('OK'),
  low('Stock faible'),
  out('Rupture');

  const ConsumableStockStatus(this.label);
  final String label;
}

enum InventoryMovementReason {
  restock('restock', 'Réassort'),
  maraude('maraude', 'Maraude'),
  inventoryCorrection('inventory_correction', 'Correction inventaire'),
  loss('loss', 'Perte'),
  other('other', 'Autre');

  const InventoryMovementReason(this.databaseValue, this.label);
  final String databaseValue;
  final String label;

  factory InventoryMovementReason.fromJson(String value) => values.firstWhere(
    (reason) => reason.databaseValue == value,
    orElse: () => InventoryMovementReason.other,
  );
}

class Consumable {
  const Consumable({
    required this.id,
    required this.name,
    required this.category,
    required this.currentQuantity,
    required this.unit,
    required this.alertThreshold,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.storageLocation,
  });

  factory Consumable.fromJson(Map<String, dynamic> json) => Consumable(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    currentQuantity: (json['current_quantity'] as num).toDouble(),
    unit: InventoryUnit.fromJson(json['unit'] as String),
    alertThreshold: (json['alert_threshold'] as num).toDouble(),
    storageLocation: json['storage_location'] as String?,
    isArchived: json['is_archived'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  final String id;
  final String name;
  final String category;
  final double currentQuantity;
  final InventoryUnit unit;
  final double alertThreshold;
  final String? storageLocation;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConsumableStockStatus get stockStatus {
    if (currentQuantity <= 0) return ConsumableStockStatus.out;
    if (currentQuantity <= alertThreshold) return ConsumableStockStatus.low;
    return ConsumableStockStatus.ok;
  }

  bool get shouldBuy => stockStatus != ConsumableStockStatus.ok;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Consumable &&
          id == other.id &&
          name == other.name &&
          category == other.category &&
          currentQuantity == other.currentQuantity &&
          unit == other.unit &&
          alertThreshold == other.alertThreshold &&
          storageLocation == other.storageLocation &&
          isArchived == other.isArchived;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    currentQuantity,
    unit,
    alertThreshold,
    storageLocation,
    isArchived,
  );
}

class ConsumableMovement {
  const ConsumableMovement({
    required this.id,
    required this.consumableId,
    required this.previousQuantity,
    required this.newQuantity,
    required this.difference,
    required this.reason,
    required this.createdAt,
    this.concertId,
    this.note,
    this.actorName,
  });

  factory ConsumableMovement.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    final firstName = (actor?['first_name'] as String?)?.trim();
    final lastName = (actor?['last_name'] as String?)?.trim();
    final name = [
      firstName,
      lastName,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
    return ConsumableMovement(
      id: json['id'] as String,
      consumableId: json['consumable_id'] as String,
      concertId: json['concert_id'] as String?,
      previousQuantity: (json['previous_quantity'] as num).toDouble(),
      newQuantity: (json['new_quantity'] as num).toDouble(),
      difference: (json['quantity_difference'] as num).toDouble(),
      reason: InventoryMovementReason.fromJson(json['reason'] as String),
      note: json['note'] as String?,
      actorName: name.isEmpty ? null : name,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String consumableId;
  final String? concertId;
  final double previousQuantity;
  final double newQuantity;
  final double difference;
  final InventoryMovementReason reason;
  final String? note;
  final String? actorName;
  final DateTime createdAt;
}
