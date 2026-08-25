enum EquipmentStatus {
  available('available', 'Disponible'),
  assigned('assigned', 'Affecté'),
  inUse('in_use', 'En utilisation'),
  needsCheck('needs_check', 'À vérifier'),
  needsCleaning('needs_cleaning', 'À nettoyer'),
  damaged('damaged', 'Endommagé'),
  lost('lost', 'Perdu'),
  outOfService('out_of_service', 'Hors service');

  const EquipmentStatus(this.databaseValue, this.label);
  final String databaseValue;
  final String label;

  factory EquipmentStatus.fromJson(String value) => values.firstWhere(
    (status) => status.databaseValue == value,
    orElse: () => EquipmentStatus.needsCheck,
  );
}

class EquipmentLocation {
  const EquipmentLocation({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory EquipmentLocation.fromJson(Map<String, dynamic> json) =>
      EquipmentLocation(
        id: json['id'] as String,
        name: json['name'] as String,
        isActive: json['is_active'] as bool? ?? true,
      );

  final String id;
  final String name;
  final bool isActive;
}

class EquipmentAsset {
  const EquipmentAsset({
    required this.id,
    required this.name,
    required this.category,
    required this.quantityTotal,
    required this.status,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.internalCode,
    this.locationId,
    this.locationName,
    this.condition,
    this.notes,
  });

  factory EquipmentAsset.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    return EquipmentAsset(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      internalCode: json['internal_code'] as String?,
      quantityTotal: (json['quantity_total'] as num).toInt(),
      locationId: json['location_id'] as String?,
      locationName: location?['name'] as String?,
      status: EquipmentStatus.fromJson(json['status'] as String),
      condition: json['condition'] as String?,
      notes: json['notes'] as String?,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String name;
  final String category;
  final String? internalCode;
  final int quantityTotal;
  final String? locationId;
  final String? locationName;
  final EquipmentStatus status;
  final String? condition;
  final String? notes;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class EquipmentEvent {
  const EquipmentEvent({
    required this.id,
    required this.equipmentId,
    required this.eventType,
    required this.createdAt,
    this.concertId,
    this.quantity,
    this.previousStatus,
    this.newStatus,
    this.note,
    this.actorName,
  });

  factory EquipmentEvent.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    final actorName = [
      actor?['first_name'],
      actor?['last_name'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return EquipmentEvent(
      id: json['id'] as String,
      equipmentId: json['equipment_id'] as String,
      concertId: json['concert_id'] as String?,
      eventType: json['event_type'] as String,
      quantity: (json['quantity'] as num?)?.toInt(),
      previousStatus: json['previous_status'] == null
          ? null
          : EquipmentStatus.fromJson(json['previous_status'] as String),
      newStatus: json['new_status'] == null
          ? null
          : EquipmentStatus.fromJson(json['new_status'] as String),
      note: json['note'] as String?,
      actorName: actorName.isEmpty ? null : actorName,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String equipmentId;
  final String? concertId;
  final String eventType;
  final int? quantity;
  final EquipmentStatus? previousStatus;
  final EquipmentStatus? newStatus;
  final String? note;
  final String? actorName;
  final DateTime createdAt;
}
