import 'package:club_sandwich/features/volunteers/domain/volunteer_document.dart'
    show VolunteerDocumentStatus;

class OrganizationConvention {
  const OrganizationConvention({
    required this.status,
    this.storagePath,
    this.rejectionReason,
    this.uploadedAt,
    this.reviewedAt,
  });

  factory OrganizationConvention.fromJson(Map<String, dynamic> json) {
    return OrganizationConvention(
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

  final VolunteerDocumentStatus status;
  final String? storagePath;
  final String? rejectionReason;
  final DateTime? uploadedAt;
  final DateTime? reviewedAt;

  bool get hasFile => storagePath != null;
}
