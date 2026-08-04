enum CollectionCategory {
  preparedMeals('prepared_meals', 'Repas préparés'),
  fruitsVegetables('fruits_vegetables', 'Fruits et légumes'),
  bakery('bakery', 'Boulangerie'),
  dairy('dairy', 'Produits laitiers'),
  groceries('groceries', 'Épicerie'),
  drinks('drinks', 'Boissons'),
  other('other', 'Autre');

  const CollectionCategory(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  factory CollectionCategory.fromJson(String value) {
    return values.firstWhere(
      (category) => category.databaseValue == value,
      orElse: () =>
          throw FormatException('Catégorie de collecte inconnue : $value'),
    );
  }
}

enum CollectionUnit {
  kg('kg', 'kg'),
  crate('crate', 'caisses'),
  box('box', 'boîtes'),
  bag('bag', 'sacs'),
  piece('piece', 'pièces'),
  other('other', 'autres');

  const CollectionUnit(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  factory CollectionUnit.fromJson(String value) {
    return values.firstWhere(
      (unit) => unit.databaseValue == value,
      orElse: () =>
          throw FormatException('Unité de collecte inconnue : $value'),
    );
  }
}

class MaraudeCollection {
  const MaraudeCollection({
    required this.id,
    required this.concertId,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.weightKg,
    this.averageWeightKg,
    this.comment,
  });

  factory MaraudeCollection.fromJson(Map<String, dynamic> json) {
    return MaraudeCollection(
      id: json['id'] as String,
      concertId: json['concert_id'] as String,
      category: CollectionCategory.fromJson(json['category'] as String),
      description: json['description'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      unit: CollectionUnit.fromJson(json['unit'] as String),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      averageWeightKg: (json['average_weight_kg'] as num?)?.toDouble(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String concertId;
  final CollectionCategory category;
  final String? description;
  final double quantity;
  final CollectionUnit unit;
  final double? weightKg;
  final double? averageWeightKg;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'concert_id': concertId,
    'category': category.databaseValue,
    'description': description,
    'quantity': quantity,
    'unit': unit.databaseValue,
    'weight_kg': weightKg,
    'average_weight_kg': averageWeightKg,
    'comment': comment,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MaraudeCollection &&
            id == other.id &&
            concertId == other.concertId &&
            category == other.category &&
            description == other.description &&
            quantity == other.quantity &&
            unit == other.unit &&
            weightKg == other.weightKg &&
            averageWeightKg == other.averageWeightKg &&
            comment == other.comment &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    concertId,
    category,
    description,
    quantity,
    unit,
    weightKg,
    averageWeightKg,
    comment,
    createdAt,
    updatedAt,
  );
}

class MaraudeCollectionDraft {
  const MaraudeCollectionDraft({
    required this.category,
    required this.quantity,
    required this.unit,
    this.description,
    this.weightKg,
    this.averageWeightKg,
    this.comment,
  });

  final CollectionCategory category;
  final String? description;
  final double quantity;
  final CollectionUnit unit;
  final double? weightKg;
  final double? averageWeightKg;
  final String? comment;

  Map<String, dynamic> toJson() => {
    'category': category.databaseValue,
    'description': _nullIfBlank(description),
    'quantity': quantity,
    'unit': unit.databaseValue,
    'weight_kg': weightKg,
    'average_weight_kg': averageWeightKg,
    'comment': _nullIfBlank(comment),
  };
}

class MaraudeCollectionSummary {
  const MaraudeCollectionSummary({
    required this.lotCount,
    required this.totalWeightKg,
    required this.totalPieces,
  });

  factory MaraudeCollectionSummary.fromCollections(
    Iterable<MaraudeCollection> collections,
  ) {
    var lotCount = 0;
    var totalWeightKg = 0.0;
    var totalPieces = 0.0;
    for (final collection in collections) {
      lotCount++;
      totalWeightKg += collection.weightKg ?? 0;
      if (collection.unit == CollectionUnit.piece) {
        totalPieces += collection.quantity;
      }
    }
    return MaraudeCollectionSummary(
      lotCount: lotCount,
      totalWeightKg: totalWeightKg,
      totalPieces: totalPieces,
    );
  }

  final int lotCount;
  final double totalWeightKg;
  final double totalPieces;
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
