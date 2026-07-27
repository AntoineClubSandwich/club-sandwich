enum MemberRole {
  admin('admin'),
  promoter('promoter'),
  volunteer('volunteer');

  const MemberRole(this.jsonValue);

  final String jsonValue;

  factory MemberRole.fromJson(String value) {
    return MemberRole.values.firstWhere(
      (role) => role.jsonValue == value,
      orElse: () => throw FormatException('Rôle inconnu : $value'),
    );
  }
}

class Membership {
  const Membership({
    required this.id,
    required this.organizationId,
    required this.profileId,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String organizationId;
  final String profileId;
  final MemberRole role;
  final DateTime createdAt;

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      profileId: json['profile_id'] as String,
      role: MemberRole.fromJson(json['role'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'profile_id': profileId,
      'role': role.jsonValue,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
