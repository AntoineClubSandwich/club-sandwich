class MaraudeDistribution {
  const MaraudeDistribution({
    required this.id,
    required this.concertId,
    required this.createdAt,
    required this.updatedAt,
    this.distributionLocation,
    this.estimatedBeneficiaries,
    this.distributedMeals,
    this.remainingWeightKg,
    this.distributionStartedAt,
    this.distributionCompletedAt,
    this.incidentComment,
  });

  factory MaraudeDistribution.fromJson(Map<String, dynamic> json) {
    return MaraudeDistribution(
      id: json['id'] as String,
      concertId: json['concert_id'] as String,
      distributionLocation: json['distribution_location'] as String?,
      estimatedBeneficiaries: (json['estimated_beneficiaries'] as num?)
          ?.toInt(),
      distributedMeals: (json['distributed_meals'] as num?)?.toInt(),
      remainingWeightKg: (json['remaining_weight_kg'] as num?)?.toDouble(),
      distributionStartedAt: _optionalDateTime(json['distribution_started_at']),
      distributionCompletedAt: _optionalDateTime(
        json['distribution_completed_at'],
      ),
      incidentComment: json['incident_comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String concertId;
  final String? distributionLocation;
  final int? estimatedBeneficiaries;
  final int? distributedMeals;
  final double? remainingWeightKg;
  final DateTime? distributionStartedAt;
  final DateTime? distributionCompletedAt;
  final String? incidentComment;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'concert_id': concertId,
    'distribution_location': distributionLocation,
    'estimated_beneficiaries': estimatedBeneficiaries,
    'distributed_meals': distributedMeals,
    'remaining_weight_kg': remainingWeightKg,
    'distribution_started_at': distributionStartedAt?.toIso8601String(),
    'distribution_completed_at': distributionCompletedAt?.toIso8601String(),
    'incident_comment': incidentComment,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MaraudeDistribution &&
            id == other.id &&
            concertId == other.concertId &&
            distributionLocation == other.distributionLocation &&
            estimatedBeneficiaries == other.estimatedBeneficiaries &&
            distributedMeals == other.distributedMeals &&
            remainingWeightKg == other.remainingWeightKg &&
            distributionStartedAt == other.distributionStartedAt &&
            distributionCompletedAt == other.distributionCompletedAt &&
            incidentComment == other.incidentComment &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    concertId,
    distributionLocation,
    estimatedBeneficiaries,
    distributedMeals,
    remainingWeightKg,
    distributionStartedAt,
    distributionCompletedAt,
    incidentComment,
    createdAt,
    updatedAt,
  );
}

class MaraudeDistributionDraft {
  const MaraudeDistributionDraft({
    this.distributionLocation,
    this.estimatedBeneficiaries,
    this.distributedMeals,
    this.remainingWeightKg,
    this.distributionStartedAt,
    this.distributionCompletedAt,
    this.incidentComment,
  });

  final String? distributionLocation;
  final int? estimatedBeneficiaries;
  final int? distributedMeals;
  final double? remainingWeightKg;
  final DateTime? distributionStartedAt;
  final DateTime? distributionCompletedAt;
  final String? incidentComment;

  Map<String, dynamic> toJson() => {
    'distribution_location': _nullIfBlank(distributionLocation),
    'estimated_beneficiaries': estimatedBeneficiaries,
    'distributed_meals': distributedMeals,
    'remaining_weight_kg': remainingWeightKg,
    'distribution_started_at': distributionStartedAt?.toIso8601String(),
    'distribution_completed_at': distributionCompletedAt?.toIso8601String(),
    'incident_comment': _nullIfBlank(incidentComment),
  };
}

DateTime? _optionalDateTime(Object? value) {
  return value == null ? null : DateTime.parse(value as String);
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
