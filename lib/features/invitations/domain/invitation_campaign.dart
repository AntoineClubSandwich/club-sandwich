import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart'
    show VolunteerConfirmationStatus;

enum InvitationCampaignStatus {
  draft('draft', 'Brouillon'),
  open('open', 'Candidatures ouvertes'),
  closed('closed', 'Terminée'),
  cancelled('cancelled', 'Annulée');

  const InvitationCampaignStatus(this.jsonValue, this.label);
  final String jsonValue;
  final String label;

  factory InvitationCampaignStatus.fromJson(String value) {
    return InvitationCampaignStatus.values.firstWhere(
      (status) => status.jsonValue == value,
      orElse: () =>
          throw FormatException('Statut de campagne inconnu : $value'),
    );
  }
}

enum InvitationApplicationStatus {
  pending('pending', 'En attente'),
  selected('selected', 'Invitation attribuée'),
  notSelected('not_selected', 'Non sélectionné'),
  withdrawn('withdrawn', 'Désisté');

  const InvitationApplicationStatus(this.jsonValue, this.label);
  final String jsonValue;
  final String label;

  factory InvitationApplicationStatus.fromJson(String value) {
    return InvitationApplicationStatus.values.firstWhere(
      (status) => status.jsonValue == value,
      orElse: () =>
          throw FormatException('Statut de candidature inconnu : $value'),
    );
  }
}

class InvitationCampaign {
  const InvitationCampaign({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.availablePlaces,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.applicationCount,
    this.pendingCount = 0,
    required this.selectedCount,
    this.attributedPlacesCount = 0,
    this.awaitingConfirmationCount = 0,
    this.organizationName,
    this.concertId,
    this.venueId,
    this.venue,
    this.description,
    this.applicationDeadline,
    this.eventDate,
    this.ownApplication,
  });

  factory InvitationCampaign.fromJson(Map<String, dynamic> json) {
    final applications =
        json['applications'] as List<dynamic>? ?? const <dynamic>[];
    final ownApplication = applications.isEmpty
        ? null
        : InvitationApplication.fromJson(
            applications.first as Map<String, dynamic>,
          );
    return InvitationCampaign(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      organizationName: _relatedName(json['organization']),
      concertId: json['concert_id'] as String?,
      venueId: json['venue_id'] as String?,
      venue: _relatedVenue(json['venue']),
      title: json['title'] as String,
      description: json['description'] as String?,
      availablePlaces: (json['available_places'] as num).toInt(),
      applicationDeadline: json['application_deadline'] == null
          ? null
          : DateTime.parse(json['application_deadline'] as String),
      eventDate: json['event_date'] == null
          ? null
          : DateTime.parse(json['event_date'] as String),
      status: InvitationCampaignStatus.fromJson(json['status'] as String),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      applicationCount:
          (json['application_count'] as num?)?.toInt() ?? applications.length,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      selectedCount: (json['selected_count'] as num?)?.toInt() ?? 0,
      attributedPlacesCount:
          (json['attributed_places_count'] as num?)?.toInt() ??
          (json['selected_count'] as num?)?.toInt() ??
          0,
      awaitingConfirmationCount:
          (json['awaiting_confirmation_count'] as num?)?.toInt() ?? 0,
      ownApplication: ownApplication,
    );
  }

  final String id;
  final String organizationId;
  final String? organizationName;
  final String? concertId;
  final String? venueId;
  final Venue? venue;
  final String title;
  final String? description;
  final int availablePlaces;
  final DateTime? applicationDeadline;
  final DateTime? eventDate;
  final InvitationCampaignStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int applicationCount;
  final int pendingCount;
  final int selectedCount;
  final int attributedPlacesCount;
  final int awaitingConfirmationCount;
  final InvitationApplication? ownApplication;

  int get remainingPlaces {
    final remaining = availablePlaces - attributedPlacesCount;
    return remaining < 0 ? 0 : remaining;
  }
}

class InvitationApplication {
  const InvitationApplication({
    required this.id,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.confirmationStatus,
    this.confirmationDueAt,
    this.confirmationRespondedAt,
    this.plusOne = false,
    this.plusOneName,
    this.invitationFilePath,
    this.onGuestList = false,
    this.invitationSentAt,
  });

  factory InvitationApplication.fromJson(Map<String, dynamic> json) {
    return InvitationApplication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      status: InvitationApplicationStatus.fromJson(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      confirmationStatus: json['confirmation_status'] == null
          ? null
          : VolunteerConfirmationStatus.fromDatabase(
              json['confirmation_status'] as String,
            ),
      confirmationDueAt: json['confirmation_due_at'] == null
          ? null
          : DateTime.parse(json['confirmation_due_at'] as String),
      confirmationRespondedAt: json['confirmation_responded_at'] == null
          ? null
          : DateTime.parse(json['confirmation_responded_at'] as String),
      plusOne: json['plus_one'] as bool? ?? false,
      plusOneName: json['plus_one_name'] as String?,
      invitationFilePath: json['invitation_file_path'] as String?,
      onGuestList: json['on_guest_list'] as bool? ?? false,
      invitationSentAt: json['invitation_sent_at'] == null
          ? null
          : DateTime.parse(json['invitation_sent_at'] as String),
    );
  }

  final String id;
  final String userId;
  final InvitationApplicationStatus status;
  final DateTime createdAt;
  final VolunteerConfirmationStatus? confirmationStatus;
  final DateTime? confirmationDueAt;
  final DateTime? confirmationRespondedAt;
  final bool plusOne;
  final String? plusOneName;
  final String? invitationFilePath;
  final bool onGuestList;
  final DateTime? invitationSentAt;

  bool get hasInvitationDelivery => invitationFilePath != null || onGuestList;

  bool get isValidated =>
      status == InvitationApplicationStatus.selected &&
      confirmationStatus == VolunteerConfirmationStatus.confirmed;

  bool get awaitsConfirmation =>
      status == InvitationApplicationStatus.selected &&
      confirmationStatus == VolunteerConfirmationStatus.pending;
}

class InvitationCampaignDraft {
  const InvitationCampaignDraft({
    required this.organizationId,
    required this.venueId,
    required this.title,
    required this.availablePlaces,
    required this.status,
    this.concertId,
    this.description,
    this.applicationDeadline,
    this.eventDate,
  });

  final String organizationId;
  final String venueId;
  final String? concertId;
  final String title;
  final String? description;
  final int availablePlaces;
  final DateTime? applicationDeadline;
  final DateTime? eventDate;
  final InvitationCampaignStatus status;

  Map<String, dynamic> toJson() => {
    'organization_id': organizationId,
    'venue_id': venueId,
    'concert_id': concertId,
    'title': title.trim(),
    'description': _blank(description),
    'available_places': availablePlaces,
    'application_deadline': applicationDeadline?.toUtc().toIso8601String(),
    'event_date': eventDate == null
        ? null
        : '${eventDate!.year.toString().padLeft(4, '0')}-'
              '${eventDate!.month.toString().padLeft(2, '0')}-'
              '${eventDate!.day.toString().padLeft(2, '0')}',
    'status': status.jsonValue,
  };
}

class InvitationCandidate {
  const InvitationCandidate({
    required this.applicationId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.memberSince,
    required this.maraudeCount,
    required this.withdrawalCount,
    required this.invitationCount,
    required this.canManage,
    this.lastInvitationAt,
    this.confirmationStatus,
    this.confirmationDueAt,
    this.plusOne = false,
    this.plusOneName,
    this.invitationFilePath,
    this.onGuestList = false,
    this.invitationSentAt,
  });

  factory InvitationCandidate.fromJson(Map<String, dynamic> json) {
    return InvitationCandidate(
      applicationId: json['application_id'] as String,
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      status: InvitationApplicationStatus.fromJson(json['status'] as String),
      memberSince: DateTime.parse(json['member_since'] as String),
      maraudeCount: (json['maraude_count'] as num).toInt(),
      withdrawalCount: (json['withdrawal_count'] as num).toInt(),
      invitationCount: (json['invitation_count'] as num).toInt(),
      lastInvitationAt: json['last_invitation_at'] == null
          ? null
          : DateTime.parse(json['last_invitation_at'] as String),
      canManage: json['can_manage'] as bool? ?? false,
      confirmationStatus: json['confirmation_status'] == null
          ? null
          : VolunteerConfirmationStatus.fromDatabase(
              json['confirmation_status'] as String,
            ),
      confirmationDueAt: json['confirmation_due_at'] == null
          ? null
          : DateTime.parse(json['confirmation_due_at'] as String),
      plusOne: json['plus_one'] as bool? ?? false,
      plusOneName: json['plus_one_name'] as String?,
      invitationFilePath: json['invitation_file_path'] as String?,
      onGuestList: json['on_guest_list'] as bool? ?? false,
      invitationSentAt: json['invitation_sent_at'] == null
          ? null
          : DateTime.parse(json['invitation_sent_at'] as String),
    );
  }

  final String applicationId;
  final String userId;
  final String firstName;
  final String lastName;
  final InvitationApplicationStatus status;
  final DateTime memberSince;
  final int maraudeCount;
  final int withdrawalCount;
  final int invitationCount;
  final DateTime? lastInvitationAt;
  final bool canManage;
  final VolunteerConfirmationStatus? confirmationStatus;
  final DateTime? confirmationDueAt;
  final bool plusOne;
  final String? plusOneName;
  final String? invitationFilePath;
  final bool onGuestList;
  final DateTime? invitationSentAt;

  bool get hasInvitationDelivery => invitationFilePath != null || onGuestList;

  String get displayName => '$firstName $lastName'.trim();
}

String? _relatedName(Object? relation) {
  return relation is Map<String, dynamic> ? relation['name'] as String? : null;
}

Venue? _relatedVenue(Object? relation) {
  if (relation is Map<String, dynamic>) return Venue.fromJson(relation);
  if (relation is List<dynamic> && relation.isNotEmpty) {
    return Venue.fromJson(relation.first as Map<String, dynamic>);
  }
  return null;
}

String? _blank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
