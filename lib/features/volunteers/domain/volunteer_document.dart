enum VolunteerDocumentType {
  identity('identity', 'Pièce d’identité'),
  socialSecurity('social_security', 'Carte de sécurité sociale'),
  contract('contract', 'Contrat de bénévolat'),
  other('other', 'Autre document');

  const VolunteerDocumentType(this.databaseValue, this.label);
  final String databaseValue;
  final String label;

  factory VolunteerDocumentType.fromDatabase(String value) {
    return VolunteerDocumentType.values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => throw FormatException('Type de document inconnu : $value'),
    );
  }
}

enum VolunteerDocumentStatus {
  pending('pending', 'En attente'),
  approved('approved', 'Validé'),
  rejected('rejected', 'Refusé');

  const VolunteerDocumentStatus(this.databaseValue, this.label);
  final String databaseValue;
  final String label;

  factory VolunteerDocumentStatus.fromDatabase(String value) {
    return VolunteerDocumentStatus.values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () =>
          throw FormatException('Statut de document inconnu : $value'),
    );
  }
}

class VolunteerDocument {
  const VolunteerDocument({
    required this.id,
    required this.type,
    required this.status,
    this.label,
    this.storagePath,
    this.rejectionReason,
    this.uploadedAt,
    this.reviewedAt,
  });

  factory VolunteerDocument.fromJson(Map<String, dynamic> json) {
    return VolunteerDocument(
      id: json['id'] as String,
      type: VolunteerDocumentType.fromDatabase(json['document_type'] as String),
      label: json['label'] as String?,
      status: VolunteerDocumentStatus.fromDatabase(json['status'] as String),
      storagePath: json['storage_path'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      uploadedAt: json['uploaded_at'] == null
          ? null
          : DateTime.parse(json['uploaded_at'] as String),
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
    );
  }

  final String id;
  final VolunteerDocumentType type;
  final String? label;
  final VolunteerDocumentStatus status;
  final String? storagePath;
  final String? rejectionReason;
  final DateTime? uploadedAt;
  final DateTime? reviewedAt;

  bool get hasFile => storagePath != null;

  String get displayLabel =>
      type == VolunteerDocumentType.other ? (label ?? type.label) : type.label;
}

class PendingVolunteerDocument {
  const PendingVolunteerDocument({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.type,
    required this.storagePath,
    this.label,
    this.uploadedAt,
  });

  factory PendingVolunteerDocument.fromJson(Map<String, dynamic> json) {
    return PendingVolunteerDocument(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      type: VolunteerDocumentType.fromDatabase(json['document_type'] as String),
      label: json['label'] as String?,
      storagePath: json['storage_path'] as String,
      uploadedAt: json['uploaded_at'] == null
          ? null
          : DateTime.parse(json['uploaded_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final VolunteerDocumentType type;
  final String? label;
  final String storagePath;
  final DateTime? uploadedAt;

  String get displayName => '$firstName $lastName'.trim();

  String get displayLabel =>
      type == VolunteerDocumentType.other ? (label ?? type.label) : type.label;
}
