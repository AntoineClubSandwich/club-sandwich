enum InvitationCampaignStatus {
  draft('draft', 'Brouillon'),
  open('open', 'Ouverte'),
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
    required this.selectedCount,
    this.organizationName,
    this.concertId,
    this.description,
    this.applicationDeadline,
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
      title: json['title'] as String,
      description: json['description'] as String?,
      availablePlaces: (json['available_places'] as num).toInt(),
      applicationDeadline: json['application_deadline'] == null
          ? null
          : DateTime.parse(json['application_deadline'] as String),
      status: InvitationCampaignStatus.fromJson(json['status'] as String),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      applicationCount:
          (json['application_count'] as num?)?.toInt() ?? applications.length,
      selectedCount: (json['selected_count'] as num?)?.toInt() ?? 0,
      ownApplication: ownApplication,
    );
  }

  final String id;
  final String organizationId;
  final String? organizationName;
  final String? concertId;
  final String title;
  final String? description;
  final int availablePlaces;
  final DateTime? applicationDeadline;
  final InvitationCampaignStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int applicationCount;
  final int selectedCount;
  final InvitationApplication? ownApplication;
}

class InvitationApplication {
  const InvitationApplication({
    required this.id,
    required this.userId,
    required this.status,
    required this.createdAt,
  });

  factory InvitationApplication.fromJson(Map<String, dynamic> json) {
    return InvitationApplication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      status: InvitationApplicationStatus.fromJson(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String userId;
  final InvitationApplicationStatus status;
  final DateTime createdAt;
}

class InvitationCampaignDraft {
  const InvitationCampaignDraft({
    required this.organizationId,
    required this.title,
    required this.availablePlaces,
    required this.status,
    this.concertId,
    this.description,
    this.applicationDeadline,
  });

  final String organizationId;
  final String? concertId;
  final String title;
  final String? description;
  final int availablePlaces;
  final DateTime? applicationDeadline;
  final InvitationCampaignStatus status;

  Map<String, dynamic> toJson() => {
    'organization_id': organizationId,
    'concert_id': concertId,
    'title': title.trim(),
    'description': _blank(description),
    'available_places': availablePlaces,
    'application_deadline': applicationDeadline?.toUtc().toIso8601String(),
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

  String get displayName => '$firstName $lastName'.trim();
}

String? _relatedName(Object? relation) {
  return relation is Map<String, dynamic> ? relation['name'] as String? : null;
}

String? _blank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
