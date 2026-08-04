class MaraudeExportRow {
  const MaraudeExportRow({
    required this.concertId,
    required this.artist,
    required this.concertDate,
    this.organizationName,
    this.venueName,
    this.actualStartAt,
    this.actualEndAt,
    this.durationHours,
    this.distanceKm,
    this.totalWeightKg,
    this.estimatedMeals,
    this.distributedMeals,
    this.estimatedBeneficiaries,
    required this.volunteerCount,
    this.volunteerHours,
    this.collectionSummary,
  });

  factory MaraudeExportRow.fromJson(Map<String, dynamic> json) {
    return MaraudeExportRow(
      concertId: json['concert_id'] as String,
      artist: json['artist'] as String,
      concertDate: DateTime.parse(json['concert_date'] as String),
      organizationName: json['organization_name'] as String?,
      venueName: json['venue_name'] as String?,
      actualStartAt: json['actual_start_at'] == null
          ? null
          : DateTime.parse(json['actual_start_at'] as String),
      actualEndAt: json['actual_end_at'] == null
          ? null
          : DateTime.parse(json['actual_end_at'] as String),
      durationHours: (json['duration_hours'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble(),
      estimatedMeals: (json['estimated_meals'] as num?)?.toInt(),
      distributedMeals: (json['distributed_meals'] as num?)?.toInt(),
      estimatedBeneficiaries: (json['estimated_beneficiaries'] as num?)
          ?.toInt(),
      volunteerCount: (json['volunteer_count'] as num).toInt(),
      volunteerHours: (json['volunteer_hours'] as num?)?.toDouble(),
      collectionSummary: json['collection_summary'] as String?,
    );
  }

  final String concertId;
  final String artist;
  final DateTime concertDate;
  final String? organizationName;
  final String? venueName;
  final DateTime? actualStartAt;
  final DateTime? actualEndAt;
  final double? durationHours;
  final double? distanceKm;
  final double? totalWeightKg;
  final int? estimatedMeals;
  final int? distributedMeals;
  final int? estimatedBeneficiaries;
  final int volunteerCount;
  final double? volunteerHours;
  final String? collectionSummary;
}
