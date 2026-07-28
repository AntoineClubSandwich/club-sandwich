import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/distributions/domain/maraude_distribution.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';

enum ConcertStatus {
  planned('planned'),
  confirmed('confirmed'),
  completed('completed'),
  cancelled('cancelled');

  const ConcertStatus(this.jsonValue);

  final String jsonValue;

  factory ConcertStatus.fromJson(String value) {
    return ConcertStatus.values.firstWhere(
      (status) => status.jsonValue == value,
      orElse: () => throw FormatException('Statut de concert inconnu : $value'),
    );
  }
}

enum MaraudeStatus {
  draft('draft', 'Brouillon'),
  open('open', 'Ouverte'),
  teamReady('team_ready', 'Équipe validée'),
  inProgress('in_progress', 'En cours'),
  completed('completed', 'Terminée'),
  cancelled('cancelled', 'Annulée');

  const MaraudeStatus(this.jsonValue, this.label);

  final String jsonValue;
  final String label;

  factory MaraudeStatus.fromJson(String value) {
    return MaraudeStatus.values.firstWhere(
      (status) => status.jsonValue == value,
      orElse: () => throw FormatException('État de maraude inconnu : $value'),
    );
  }
}

class Concert {
  const Concert({
    required this.id,
    required this.organizationId,
    required this.artist,
    required this.date,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.maraudeStatus = MaraudeStatus.open,
    this.actualStartAt,
    this.actualEndAt,
    this.closingComment,
    this.cancellationReason,
    this.operationalReport,
    this.collections = const [],
    this.distribution,
    this.time,
    this.notes,
    this.venueId,
    this.cateringClosesAt,
    this.promoterOrganizationId,
    this.venue,
    this.promoterOrganizationName,
    this.promoterContactName,
    this.promoterContactPhone,
    this.promoterContactEmail,
    this.cateringContactName,
    this.cateringContactPhone,
    this.cateringContactEmail,
    this.selectedVolunteerCount = 0,
  });

  final String id;
  final String organizationId;
  final String artist;
  final DateTime date;
  final String? time;
  final ConcertStatus status;
  final MaraudeStatus maraudeStatus;
  final DateTime? actualStartAt;
  final DateTime? actualEndAt;
  final String? closingComment;
  final String? cancellationReason;
  final MaraudeOperationalReport? operationalReport;
  final List<MaraudeCollection> collections;
  final MaraudeDistribution? distribution;
  final String? notes;
  final String? venueId;
  final String? cateringClosesAt;
  final String? promoterOrganizationId;
  final Venue? venue;
  String? get venueName => venue?.name;
  final String? promoterOrganizationName;
  final String? promoterContactName;
  final String? promoterContactPhone;
  final String? promoterContactEmail;
  final String? cateringContactName;
  final String? cateringContactPhone;
  final String? cateringContactEmail;
  final int selectedVolunteerCount;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Concert.fromJson(Map<String, dynamic> json) {
    return Concert(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      artist: json['artist'] as String,
      date: DateTime.parse(json['concert_date'] as String),
      time: json['concert_time'] as String?,
      status: ConcertStatus.fromJson(json['status'] as String),
      maraudeStatus: json['maraude_status'] == null
          ? MaraudeStatus.open
          : MaraudeStatus.fromJson(json['maraude_status'] as String),
      actualStartAt: _optionalDateTime(json['actual_start_at']),
      actualEndAt: _optionalDateTime(json['actual_end_at']),
      closingComment: _nullIfBlank(json['closing_comment'] as String?),
      cancellationReason: _nullIfBlank(json['cancellation_reason'] as String?),
      operationalReport: _relatedOperationalReport(json['operational_report']),
      collections: List<MaraudeCollection>.unmodifiable(
        (json['collections'] as List<dynamic>? ?? const []).map(
          (row) => MaraudeCollection.fromJson(row as Map<String, dynamic>),
        ),
      ),
      distribution: _relatedDistribution(json['distribution']),
      notes: json['notes'] as String?,
      venueId: json['venue_id'] as String?,
      cateringClosesAt: json['catering_closes_at'] as String?,
      promoterOrganizationId: json['promoter_organization_id'] as String?,
      venue: _relatedVenue(json['venue']),
      promoterOrganizationName: _relatedName(json['promoter_organization']),
      promoterContactName: _nullIfBlank(
        json['promoter_contact_name'] as String?,
      ),
      promoterContactPhone: _nullIfBlank(
        json['promoter_contact_phone'] as String?,
      ),
      promoterContactEmail: _nullIfBlank(
        json['promoter_contact_email'] as String?,
      ),
      cateringContactName: _nullIfBlank(
        json['catering_contact_name'] as String?,
      ),
      cateringContactPhone: _nullIfBlank(
        json['catering_contact_phone'] as String?,
      ),
      cateringContactEmail: _nullIfBlank(
        json['catering_contact_email'] as String?,
      ),
      selectedVolunteerCount: _selectedVolunteerCount(
        json['volunteer_applications'],
      ),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'artist': artist,
      'concert_date': _dateToJson(date),
      'concert_time': time,
      'status': status.jsonValue,
      'maraude_status': maraudeStatus.jsonValue,
      'actual_start_at': actualStartAt?.toIso8601String(),
      'actual_end_at': actualEndAt?.toIso8601String(),
      'closing_comment': closingComment,
      'cancellation_reason': cancellationReason,
      'operational_report': operationalReport == null
          ? null
          : {
              'concert_id': operationalReport!.concertId,
              'total_weight_kg': operationalReport!.totalWeightKg,
              'estimated_meals': operationalReport!.estimatedMeals,
              'comment': operationalReport!.comment,
              'photo_folder_url': operationalReport!.photoFolderUrl,
              'last_modified_by': operationalReport!.lastModifiedBy,
              'created_at': operationalReport!.createdAt.toIso8601String(),
              'updated_at': operationalReport!.updatedAt.toIso8601String(),
            },
      'collections': collections
          .map((collection) => collection.toJson())
          .toList(),
      'distribution': distribution?.toJson(),
      'notes': notes,
      'venue_id': venueId,
      'catering_closes_at': cateringClosesAt,
      'promoter_organization_id': promoterOrganizationId,
      'promoter_contact_name': promoterContactName,
      'promoter_contact_phone': promoterContactPhone,
      'promoter_contact_email': promoterContactEmail,
      'catering_contact_name': cateringContactName,
      'catering_contact_phone': cateringContactPhone,
      'catering_contact_email': cateringContactEmail,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

MaraudeOperationalReport? _relatedOperationalReport(Object? relation) {
  if (relation is Map<String, dynamic>) {
    return MaraudeOperationalReport.fromJson(relation);
  }
  if (relation is List<dynamic> && relation.isNotEmpty) {
    return MaraudeOperationalReport.fromJson(
      relation.first as Map<String, dynamic>,
    );
  }
  return null;
}

DateTime? _optionalDateTime(Object? value) {
  return value == null ? null : DateTime.parse(value as String);
}

MaraudeDistribution? _relatedDistribution(Object? relation) {
  if (relation is Map<String, dynamic>) {
    return MaraudeDistribution.fromJson(relation);
  }
  if (relation is List<dynamic> && relation.isNotEmpty) {
    return MaraudeDistribution.fromJson(relation.first as Map<String, dynamic>);
  }
  return null;
}

String? _relatedName(Object? relation) {
  if (relation is Map<String, dynamic>) return relation['name'] as String?;
  return null;
}

Venue? _relatedVenue(Object? relation) {
  if (relation is Map<String, dynamic>) return Venue.fromJson(relation);
  return null;
}

class ConcertDraft {
  const ConcertDraft({
    required this.artist,
    required this.date,
    required this.venueId,
    this.promoterOrganizationId,
    this.cateringClosesAt,
    this.notes,
    this.promoterContactName,
    this.promoterContactPhone,
  });

  final String artist;
  final DateTime date;
  final String venueId;
  final String? promoterOrganizationId;
  final String? cateringClosesAt;
  final String? notes;
  final String? promoterContactName;
  final String? promoterContactPhone;

  Map<String, dynamic> toJson() {
    return {
      'artist': artist,
      'concert_date': _dateToJson(date),
      'venue_id': venueId,
      'catering_closes_at': cateringClosesAt,
      'notes': notes,
      'promoter_contact_name': _nullIfBlank(promoterContactName),
      'promoter_contact_phone': _nullIfBlank(promoterContactPhone),
    };
  }
}

int _selectedVolunteerCount(Object? relation) {
  if (relation is! List<dynamic>) return 0;
  return relation.where((row) {
    return row is Map<String, dynamic> && row['status'] == 'selected';
  }).length;
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _dateToJson(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
