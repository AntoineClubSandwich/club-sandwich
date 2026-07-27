import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';

class MaraudeOperationalReport {
  const MaraudeOperationalReport({
    required this.concertId,
    required this.totalWeightKg,
    required this.estimatedMeals,
    required this.createdAt,
    required this.updatedAt,
    this.comment,
    this.photoFolderUrl,
    this.lastModifiedBy,
  });

  factory MaraudeOperationalReport.fromJson(Map<String, dynamic> json) {
    return MaraudeOperationalReport(
      concertId: json['concert_id'] as String,
      totalWeightKg: (json['total_weight_kg'] as num).toDouble(),
      estimatedMeals: (json['estimated_meals'] as num).toInt(),
      comment: _nullIfBlank(json['comment'] as String?),
      photoFolderUrl: _nullIfBlank(json['photo_folder_url'] as String?),
      lastModifiedBy: json['last_modified_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String concertId;
  final double totalWeightKg;
  final int estimatedMeals;
  final String? comment;
  final String? photoFolderUrl;
  final String? lastModifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MaraudeReportDraft {
  const MaraudeReportDraft({
    required this.totalWeightKg,
    required this.estimatedMeals,
    this.comment,
    this.photoFolderUrl,
  });

  final double totalWeightKg;
  final int estimatedMeals;
  final String? comment;
  final String? photoFolderUrl;
}

class MaraudeOverview {
  const MaraudeOverview({
    required this.concertId,
    required this.artist,
    required this.date,
    required this.maraudeStatus,
    required this.venueName,
    required this.applicationCount,
    required this.selectedCount,
    required this.isAdmin,
    this.time,
    this.venueAddress,
    this.cateringName,
    this.cateringClosesAt,
    this.totalWeightKg,
    this.estimatedMeals,
    this.ownStatus,
    this.ownTeamRole,
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
      selectedCount: (json['selected_count'] as num?)?.toInt() ?? 0,
      totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble(),
      estimatedMeals: (json['estimated_meals'] as num?)?.toInt(),
      ownStatus: json['own_status'] == null
          ? null
          : ConcertVolunteerStatus.fromDatabase(json['own_status'] as String),
      ownTeamRole: json['own_team_role'] == null
          ? null
          : MaraudeRole.fromDatabase(json['own_team_role'] as String),
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
  final int selectedCount;
  final double? totalWeightKg;
  final int? estimatedMeals;
  final ConcertVolunteerStatus? ownStatus;
  final MaraudeRole? ownTeamRole;
  final bool isAdmin;

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
