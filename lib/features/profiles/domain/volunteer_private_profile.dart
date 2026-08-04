class VolunteerPrivateProfile {
  const VolunteerPrivateProfile({
    this.additionalInformation,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.certifications = const [],
  });

  factory VolunteerPrivateProfile.fromJson(Map<String, dynamic> json) {
    return VolunteerPrivateProfile(
      additionalInformation: json['additional_information'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      certifications:
          (json['certifications'] as List<dynamic>?)
              ?.map((item) => item as String)
              .toList(growable: false) ??
          const [],
    );
  }

  final String? additionalInformation;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final List<String> certifications;
}
