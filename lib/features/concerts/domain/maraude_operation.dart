import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';

class MaraudeOperationalReport {
  const MaraudeOperationalReport({
    required this.concertId,
    required this.createdAt,
    required this.updatedAt,
    this.totalWeightKg,
    this.estimatedMeals,
    this.distanceKm,
    this.quantitiesUnavailable = false,
    this.comment,
    this.lastModifiedBy,
  });

  factory MaraudeOperationalReport.fromJson(Map<String, dynamic> json) {
    return MaraudeOperationalReport(
      concertId: json['concert_id'] as String,
      totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble(),
      estimatedMeals: (json['estimated_meals'] as num?)?.toInt(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      quantitiesUnavailable: json['quantities_unavailable'] as bool? ?? false,
      comment: _nullIfBlank(json['comment'] as String?),
      lastModifiedBy: json['last_modified_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String concertId;
  final double? totalWeightKg;
  final int? estimatedMeals;
  final double? distanceKm;
  final bool quantitiesUnavailable;
  final String? comment;
  final String? lastModifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MaraudeReportDraft {
  const MaraudeReportDraft({
    this.totalWeightKg,
    this.estimatedMeals,
    this.distanceKm,
    this.quantitiesUnavailable = false,
    this.comment,
  });

  final double? totalWeightKg;
  final int? estimatedMeals;
  final double? distanceKm;
  final bool quantitiesUnavailable;
  final String? comment;
}

class MaraudePhoto {
  const MaraudePhoto({
    required this.id,
    required this.concertId,
    required this.uploadedBy,
    required this.storagePath,
    required this.createdAt,
  });

  factory MaraudePhoto.fromJson(Map<String, dynamic> json) {
    return MaraudePhoto(
      id: json['id'] as String,
      concertId: json['concert_id'] as String,
      uploadedBy: json['uploaded_by'] as String,
      storagePath: json['storage_path'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String concertId;
  final String uploadedBy;
  final String storagePath;
  final DateTime createdAt;
}

class MaraudeOverview {
  const MaraudeOverview({
    required this.concertId,
    required this.artist,
    required this.date,
    required this.maraudeStatus,
    required this.venueName,
    required this.applicationCount,
    this.pendingApplicationCount = 0,
    required this.selectedCount,
    this.pendingConfirmationCount = 0,
    this.confirmedCount = 0,
    this.confirmedLeaderCount = 0,
    this.pendingCreditValidationCount = 0,
    required this.isAdmin,
    this.time,
    this.venueAddress,
    this.cateringName,
    this.cateringClosesAt,
    this.totalWeightKg,
    this.estimatedMeals,
    this.ownStatus,
    this.ownTeamRole,
    this.ownConfirmationStatus,
  });

  factory MaraudeOverview.fromJson(Map<String, dynamic> json) {
    return MaraudeOverview(
      concertId: json['concert_id'] as String,
      artist: json['artist'] as String,
      date: DateTime.parse(json['concert_date'] as String),
      time: json['concert_time'] as String?,
      maraudeStatus: MaraudeStatus.fromJson(json['maraude_status'] as String),
      venueName: json['venue_name'] as String,
      venueAddress: _nullIfBlank(json['venue_address'] as String?),
      cateringName: _nullIfBlank(json['catering_name'] as String?),
      cateringClosesAt: json['catering_closes_at'] as String?,
      applicationCount: (json['application_count'] as num?)?.toInt() ?? 0,
      pendingApplicationCount:
          (json['pending_application_count'] as num?)?.toInt() ?? 0,
      selectedCount: (json['selected_count'] as num?)?.toInt() ?? 0,
      pendingConfirmationCount:
          (json['pending_confirmation_count'] as num?)?.toInt() ?? 0,
      confirmedCount: (json['confirmed_count'] as num?)?.toInt() ?? 0,
      confirmedLeaderCount:
          (json['confirmed_leader_count'] as num?)?.toInt() ?? 0,
      pendingCreditValidationCount:
          (json['pending_credit_validation_count'] as num?)?.toInt() ?? 0,
      totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble(),
      estimatedMeals: (json['estimated_meals'] as num?)?.toInt(),
      ownStatus: json['own_status'] == null
          ? null
          : ConcertVolunteerStatus.fromDatabase(json['own_status'] as String),
      ownTeamRole: json['own_team_role'] == null
          ? null
          : MaraudeRole.fromDatabase(json['own_team_role'] as String),
      ownConfirmationStatus: json['own_confirmation_status'] == null
          ? null
          : VolunteerConfirmationStatus.fromDatabase(
              json['own_confirmation_status'] as String,
            ),
      isAdmin: json['is_admin'] as bool? ?? false,
    );
  }

  final String concertId;
  final String artist;
  final DateTime date;
  final String? time;
  final MaraudeStatus maraudeStatus;
  final String venueName;
  final String? venueAddress;
  final String? cateringName;
  final String? cateringClosesAt;
  final int applicationCount;
  final int pendingApplicationCount;
  final int selectedCount;
  final int pendingConfirmationCount;
  final int confirmedCount;
  final int confirmedLeaderCount;
  final int pendingCreditValidationCount;
  final double? totalWeightKg;
  final int? estimatedMeals;
  final ConcertVolunteerStatus? ownStatus;
  final MaraudeRole? ownTeamRole;
  final VolunteerConfirmationStatus? ownConfirmationStatus;
  final bool isAdmin;

  /// Whether this maraude is open for applications and the current
  /// volunteer hasn't applied to it yet.
  bool get isOpenForApplication =>
      maraudeStatus == MaraudeStatus.open && ownStatus == null;

  /// Whether the team has confirmed enough members (3+, exactly one
  /// confirmed team leader) for an admin to validate it — see
  /// `set_maraude_status`'s `team_ready` gate, which enforces the same
  /// rule server-side.
  bool get isReadyForTeamValidation =>
      maraudeStatus == MaraudeStatus.open &&
      confirmedCount >= 3 &&
      confirmedLeaderCount == 1;

  DateTime get recommendedArrival {
    final value = cateringClosesAt;
    if (value == null) return date;
    final parts = value.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    ).subtract(const Duration(minutes: 15));
  }
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
