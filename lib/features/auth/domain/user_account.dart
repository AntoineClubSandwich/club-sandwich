enum AppUserRole {
  admin('admin', 'Administrateur'),
  promoter('promoter', 'Tourneur'),
  volunteer('volunteer', 'Bénévole');

  const AppUserRole(this.jsonValue, this.label);

  final String jsonValue;
  final String label;

  factory AppUserRole.fromJson(String value) {
    return AppUserRole.values.firstWhere(
      (role) => role.jsonValue == value,
      orElse: () => throw FormatException('Rôle utilisateur inconnu : $value'),
    );
  }
}

enum UserAccountStatus {
  invited('invited', 'Invitation envoyée'),
  active('active', 'Actif'),
  disabled('disabled', 'Désactivé');

  const UserAccountStatus(this.jsonValue, this.label);

  final String jsonValue;
  final String label;

  factory UserAccountStatus.fromJson(String value) {
    return UserAccountStatus.values.firstWhere(
      (status) => status.jsonValue == value,
      orElse: () =>
          throw FormatException('Statut utilisateur inconnu : $value'),
    );
  }
}

class CurrentUserContext {
  const CurrentUserContext({
    required this.profileId,
    required this.role,
    required this.status,
    this.organizationId,
    this.organizationName,
  });

  factory CurrentUserContext.fromJson(Map<String, dynamic> json) {
    return CurrentUserContext(
      profileId: json['profile_id'] as String,
      role: AppUserRole.fromJson(json['role'] as String),
      organizationId: json['organization_id'] as String?,
      organizationName: json['organization_name'] as String?,
      status: UserAccountStatus.fromJson(json['status'] as String),
    );
  }

  final String profileId;
  final AppUserRole role;
  final String? organizationId;
  final String? organizationName;
  final UserAccountStatus status;
}

class ManagedUser {
  const ManagedUser({
    required this.profileId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.status,
    required this.invitedAt,
    this.organizationId,
    this.organizationName,
    this.lastSignInAt,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      profileId: json['profile_id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String,
      role: AppUserRole.fromJson(json['role'] as String),
      organizationId: json['organization_id'] as String?,
      organizationName: json['organization_name'] as String?,
      status: UserAccountStatus.fromJson(json['status'] as String),
      invitedAt: DateTime.parse(json['invited_at'] as String),
      lastSignInAt: json['last_sign_in_at'] == null
          ? null
          : DateTime.parse(json['last_sign_in_at'] as String),
    );
  }

  final String profileId;
  final String firstName;
  final String lastName;
  final String email;
  final AppUserRole role;
  final String? organizationId;
  final String? organizationName;
  final UserAccountStatus status;
  final DateTime invitedAt;
  final DateTime? lastSignInAt;

  String get displayName {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? email : value;
  }
}

class UserInvitationDraft {
  const UserInvitationDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.organizationId,
  });

  final String firstName;
  final String lastName;
  final String email;
  final AppUserRole role;
  final String? organizationId;
}
