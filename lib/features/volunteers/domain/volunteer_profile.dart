class VolunteerProfile {
  const VolunteerProfile({
    required this.userId,
    this.firstName,
    this.lastName,
    this.phone,
    this.avatarUrl,
    this.birthDate,
    this.hasDrivingLicense,
    this.canLiftHeavyLoads,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  factory VolunteerProfile.fromJson(Map<String, dynamic> json) {
    final birthDateValue = json['birth_date'] as String?;
    return VolunteerProfile(
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      birthDate: birthDateValue == null ? null : DateTime.parse(birthDateValue),
      hasDrivingLicense: json['has_driving_license'] as bool?,
      canLiftHeavyLoads: json['can_lift_heavy_loads'] as bool?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
    );
  }

  final String userId;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? avatarUrl;
  final DateTime? birthDate;
  final bool? hasDrivingLicense;
  final bool? canLiftHeavyLoads;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  String get displayName {
    final parts = [
      firstName?.trim(),
      lastName?.trim(),
    ].whereType<String>().where((part) => part.isNotEmpty);
    final name = parts.join(' ');
    return name.isEmpty ? 'Bénévole' : name;
  }

  bool get hasEmergencyContact {
    return emergencyContactName?.trim().isNotEmpty == true ||
        emergencyContactPhone?.trim().isNotEmpty == true;
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'first_name': firstName,
    'last_name': lastName,
    'phone': phone,
    'avatar_url': avatarUrl,
    'birth_date': _formatDate(birthDate),
    'has_driving_license': hasDrivingLicense,
    'can_lift_heavy_loads': canLiftHeavyLoads,
    'emergency_contact_name': emergencyContactName,
    'emergency_contact_phone': emergencyContactPhone,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VolunteerProfile &&
            userId == other.userId &&
            firstName == other.firstName &&
            lastName == other.lastName &&
            phone == other.phone &&
            avatarUrl == other.avatarUrl &&
            birthDate == other.birthDate &&
            hasDrivingLicense == other.hasDrivingLicense &&
            canLiftHeavyLoads == other.canLiftHeavyLoads &&
            emergencyContactName == other.emergencyContactName &&
            emergencyContactPhone == other.emergencyContactPhone;
  }

  @override
  int get hashCode => Object.hash(
    userId,
    firstName,
    lastName,
    phone,
    avatarUrl,
    birthDate,
    hasDrivingLicense,
    canLiftHeavyLoads,
    emergencyContactName,
    emergencyContactPhone,
  );
}

String? _formatDate(DateTime? value) {
  if (value == null) return null;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
