enum OrganizationKind {
  clubSandwich('club_sandwich'),
  promoter('producer');

  const OrganizationKind(this.jsonValue);
  final String jsonValue;

  factory OrganizationKind.fromJson(String value) {
    return OrganizationKind.values.firstWhere(
      (kind) => kind.jsonValue == value,
      orElse: () =>
          throw FormatException('Type d’organisation inconnu : $value'),
    );
  }
}

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.slug,
    required this.createdAt,
    this.kind = OrganizationKind.promoter,
    this.emailDomain,
    this.contactEmail,
    this.phone,
    this.address,
    this.websiteUrl,
    this.notes,
  });

  final String id;
  final String name;
  final String slug;
  final DateTime createdAt;
  final OrganizationKind kind;
  final String? emailDomain;
  final String? contactEmail;
  final String? phone;
  final String? address;
  final String? websiteUrl;
  final String? notes;

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      kind: json['kind'] == null
          ? OrganizationKind.promoter
          : OrganizationKind.fromJson(json['kind'] as String),
      emailDomain: json['email_domain'] as String?,
      contactEmail: json['contact_email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      websiteUrl: json['website_url'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'created_at': createdAt.toIso8601String(),
      'kind': kind.jsonValue,
      'email_domain': emailDomain,
      'contact_email': contactEmail,
      'phone': phone,
      'address': address,
      'website_url': websiteUrl,
      'notes': notes,
    };
  }

  /// Whether [email]'s domain matches this organization's configured
  /// [emailDomain] (case-insensitive). Used to pre-select the
  /// organization when an admin invites a Tourneur account.
  bool matchesEmailDomain(String email) {
    final domain = emailDomain;
    if (domain == null || domain.isEmpty) return false;
    final separator = email.lastIndexOf('@');
    if (separator == -1 || separator == email.length - 1) return false;
    return email.substring(separator + 1).toLowerCase() == domain;
  }
}

class OrganizationDraft {
  const OrganizationDraft({
    required this.name,
    required this.slug,
    this.emailDomain,
    this.contactEmail,
    this.phone,
    this.address,
    this.websiteUrl,
    this.notes,
  });

  final String name;
  final String slug;
  final String? emailDomain;
  final String? contactEmail;
  final String? phone;
  final String? address;
  final String? websiteUrl;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'slug': slug.trim().toLowerCase(),
    'kind': OrganizationKind.promoter.jsonValue,
    'email_domain': _nullIfBlank(emailDomain)?.toLowerCase(),
    'contact_email': _nullIfBlank(contactEmail),
    'phone': _nullIfBlank(phone),
    'address': _nullIfBlank(address),
    'website_url': _nullIfBlank(websiteUrl),
    'notes': _nullIfBlank(notes),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

class OrganizationContact {
  const OrganizationContact({
    required this.id,
    required this.organizationId,
    required this.firstName,
    required this.lastName,
    this.jobTitle,
    this.email,
    this.phone,
  });

  factory OrganizationContact.fromJson(Map<String, dynamic> json) {
    return OrganizationContact(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      jobTitle: json['job_title'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  final String id;
  final String organizationId;
  final String firstName;
  final String lastName;
  final String? jobTitle;
  final String? email;
  final String? phone;

  String get displayName => '$firstName $lastName'.trim();
}

class OrganizationDocument {
  const OrganizationDocument({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.url,
    required this.createdAt,
  });

  factory OrganizationDocument.fromJson(Map<String, dynamic> json) {
    return OrganizationDocument(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String organizationId;
  final String name;
  final String url;
  final DateTime createdAt;
}

class OrganizationDetails {
  const OrganizationDetails({
    required this.organization,
    required this.contacts,
    required this.documents,
    required this.concertCount,
    required this.completedMaraudeCount,
    required this.totalWeightKg,
  });

  final Organization organization;
  final List<OrganizationContact> contacts;
  final List<OrganizationDocument> documents;
  final int concertCount;
  final int completedMaraudeCount;
  final double totalWeightKg;
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
