import 'package:club_sandwich/features/volunteers/domain/volunteer_profile.dart';

const _unset = Object();

enum ConcertVolunteerStatus {
  pending('pending', 'En attente'),
  selected('selected', 'Sélectionné'),
  notSelected('not_selected', 'Non sélectionné'),
  withdrawn('withdrawn', 'Désisté');

  const ConcertVolunteerStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ConcertVolunteerStatus fromDatabase(String value) {
    return values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () =>
          throw FormatException('Statut de candidature inconnu : $value'),
    );
  }
}

enum MaraudeRole {
  teamLeader('team_leader', 'Chef d’équipe'),
  driver('driver', 'Conducteur'),
  volunteer('volunteer', 'Bénévole');

  const MaraudeRole(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static MaraudeRole fromDatabase(String value) {
    return values.firstWhere(
      (role) => role.databaseValue == value,
      orElse: () => throw FormatException('Rôle de maraude inconnu : $value'),
    );
  }
}

enum VolunteerAttendanceStatus {
  pending('pending', 'En attente'),
  present('present', 'Présent'),
  absent('absent', 'Absent');

  const VolunteerAttendanceStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static VolunteerAttendanceStatus fromDatabase(String value) {
    return values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () =>
          throw FormatException('Statut de présence inconnu : $value'),
    );
  }
}

class VolunteerHistoryEntry {
  const VolunteerHistoryEntry({
    required this.concertId,
    required this.concertDate,
    required this.artist,
    required this.venueName,
    required this.status,
  });

  factory VolunteerHistoryEntry.fromJson(Map<String, dynamic> json) {
    return VolunteerHistoryEntry(
      concertId: json['concert_id'] as String,
      concertDate: DateTime.parse(json['concert_date'] as String),
      artist: json['artist'] as String,
      venueName: json['venue_name'] as String,
      status: ConcertVolunteerStatus.fromDatabase(json['status'] as String),
    );
  }

  final String concertId;
  final DateTime concertDate;
  final String artist;
  final String venueName;
  final ConcertVolunteerStatus status;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VolunteerHistoryEntry &&
            concertId == other.concertId &&
            concertDate == other.concertDate &&
            artist == other.artist &&
            venueName == other.venueName &&
            status == other.status;
  }

  @override
  int get hashCode =>
      Object.hash(concertId, concertDate, artist, venueName, status);
}

class VolunteerStatistics {
  const VolunteerStatistics({
    required this.totalApplications,
    required this.selectedApplications,
    required this.notSelectedApplications,
    required this.withdrawnApplications,
    required this.history,
    this.lastSelectedDate,
  });

  const VolunteerStatistics.empty()
    : totalApplications = 0,
      selectedApplications = 0,
      notSelectedApplications = 0,
      withdrawnApplications = 0,
      lastSelectedDate = null,
      history = const [];

  factory VolunteerStatistics.fromJson(Map<String, dynamic> json) {
    final lastSelectedDateValue = json['last_selected_date'] as String?;
    final historyRows = json['history'] as List<dynamic>? ?? const [];
    final history =
        historyRows
            .map(
              (row) =>
                  VolunteerHistoryEntry.fromJson(row as Map<String, dynamic>),
            )
            .toList()
          ..sort((first, second) {
            return second.concertDate.compareTo(first.concertDate);
          });
    return VolunteerStatistics(
      totalApplications: (json['total_applications'] as num?)?.toInt() ?? 0,
      selectedApplications:
          (json['selected_applications'] as num?)?.toInt() ?? 0,
      notSelectedApplications:
          (json['not_selected_applications'] as num?)?.toInt() ?? 0,
      withdrawnApplications:
          (json['withdrawn_applications'] as num?)?.toInt() ?? 0,
      lastSelectedDate: lastSelectedDateValue == null
          ? null
          : DateTime.parse(lastSelectedDateValue),
      history: List.unmodifiable(history.take(20)),
    );
  }

  final int totalApplications;
  final int selectedApplications;
  final int notSelectedApplications;
  final int withdrawnApplications;
  final DateTime? lastSelectedDate;
  final List<VolunteerHistoryEntry> history;

  int? get selectionRate {
    if (totalApplications == 0) return null;
    return (selectedApplications * 100 / totalApplications).round();
  }

  int? get withdrawalRate {
    if (totalApplications == 0) return null;
    return (withdrawnApplications * 100 / totalApplications).round();
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VolunteerStatistics &&
            totalApplications == other.totalApplications &&
            selectedApplications == other.selectedApplications &&
            notSelectedApplications == other.notSelectedApplications &&
            withdrawnApplications == other.withdrawnApplications &&
            lastSelectedDate == other.lastSelectedDate &&
            _listEquals(history, other.history);
  }

  @override
  int get hashCode => Object.hash(
    totalApplications,
    selectedApplications,
    notSelectedApplications,
    withdrawnApplications,
    lastSelectedDate,
    Object.hashAll(history),
  );
}

class ConcertVolunteerApplication {
  const ConcertVolunteerApplication({
    required this.id,
    required this.concertId,
    required this.userId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.profile,
    this.statistics = const VolunteerStatistics.empty(),
    this.teamRole,
    this.attendanceStatus,
  });

  factory ConcertVolunteerApplication.fromJson(Map<String, dynamic> json) {
    final nestedProfile = json['profile'] as Map<String, dynamic>?;
    final hasFlatProfile = json.containsKey('first_name');
    final profileJson = nestedProfile == null
        ? hasFlatProfile
              ? json
              : null
        : {...nestedProfile, 'user_id': json['user_id']};
    return ConcertVolunteerApplication(
      id: json['id'] as String,
      concertId: json['concert_id'] as String,
      userId: json['user_id'] as String,
      status: ConcertVolunteerStatus.fromDatabase(json['status'] as String),
      teamRole: json['team_role'] == null
          ? null
          : MaraudeRole.fromDatabase(json['team_role'] as String),
      attendanceStatus: json['attendance_status'] == null
          ? null
          : VolunteerAttendanceStatus.fromDatabase(
              json['attendance_status'] as String,
            ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      profile: profileJson == null
          ? null
          : VolunteerProfile.fromJson(profileJson),
      statistics: VolunteerStatistics.fromJson(json),
    );
  }

  final String id;
  final String concertId;
  final String userId;
  final ConcertVolunteerStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final VolunteerProfile? profile;
  final VolunteerStatistics statistics;
  final MaraudeRole? teamRole;
  final VolunteerAttendanceStatus? attendanceStatus;

  String get displayName => profile?.displayName ?? 'Bénévole';

  VolunteerAttendanceStatus? get effectiveAttendanceStatus {
    if (status != ConcertVolunteerStatus.selected) return null;
    return attendanceStatus ?? VolunteerAttendanceStatus.pending;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'concert_id': concertId,
    'user_id': userId,
    'status': status.databaseValue,
    'team_role': teamRole?.databaseValue,
    'attendance_status': attendanceStatus?.databaseValue,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  ConcertVolunteerApplication copyWith({
    String? id,
    String? concertId,
    String? userId,
    ConcertVolunteerStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    VolunteerProfile? profile,
    VolunteerStatistics? statistics,
    Object? teamRole = _unset,
    Object? attendanceStatus = _unset,
  }) {
    return ConcertVolunteerApplication(
      id: id ?? this.id,
      concertId: concertId ?? this.concertId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profile: profile ?? this.profile,
      statistics: statistics ?? this.statistics,
      teamRole: identical(teamRole, _unset)
          ? this.teamRole
          : teamRole as MaraudeRole?,
      attendanceStatus: identical(attendanceStatus, _unset)
          ? this.attendanceStatus
          : attendanceStatus as VolunteerAttendanceStatus?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ConcertVolunteerApplication &&
            id == other.id &&
            concertId == other.concertId &&
            userId == other.userId &&
            status == other.status &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt &&
            profile == other.profile &&
            statistics == other.statistics &&
            teamRole == other.teamRole &&
            attendanceStatus == other.attendanceStatus;
  }

  @override
  int get hashCode => Object.hash(
    id,
    concertId,
    userId,
    status,
    createdAt,
    updatedAt,
    profile,
    statistics,
    teamRole,
    attendanceStatus,
  );
}

class TeamAttendanceCounts {
  const TeamAttendanceCounts({
    required this.selectedCount,
    required this.presentCount,
    required this.absentCount,
    required this.pendingCount,
  });

  factory TeamAttendanceCounts.fromApplications(
    Iterable<ConcertVolunteerApplication> applications,
  ) {
    var selectedCount = 0;
    var presentCount = 0;
    var absentCount = 0;
    var pendingCount = 0;

    for (final application in applications) {
      if (application.status != ConcertVolunteerStatus.selected) continue;
      selectedCount++;
      switch (application.effectiveAttendanceStatus!) {
        case VolunteerAttendanceStatus.pending:
          pendingCount++;
          break;
        case VolunteerAttendanceStatus.present:
          presentCount++;
          break;
        case VolunteerAttendanceStatus.absent:
          absentCount++;
          break;
      }
    }

    return TeamAttendanceCounts(
      selectedCount: selectedCount,
      presentCount: presentCount,
      absentCount: absentCount,
      pendingCount: pendingCount,
    );
  }

  final int selectedCount;
  final int presentCount;
  final int absentCount;
  final int pendingCount;
}

class ConcertVolunteerCounts {
  const ConcertVolunteerCounts({
    required this.applicationCount,
    required this.selectedCount,
    required this.presentCount,
    required this.absentCount,
  });

  const ConcertVolunteerCounts.empty()
    : applicationCount = 0,
      selectedCount = 0,
      presentCount = 0,
      absentCount = 0;

  factory ConcertVolunteerCounts.fromJson(Map<String, dynamic> json) {
    return ConcertVolunteerCounts(
      applicationCount: (json['application_count'] as num?)?.toInt() ?? 0,
      selectedCount: (json['selected_count'] as num?)?.toInt() ?? 0,
      presentCount: (json['present_count'] as num?)?.toInt() ?? 0,
      absentCount: (json['absent_count'] as num?)?.toInt() ?? 0,
    );
  }

  final int applicationCount;
  final int selectedCount;
  final int presentCount;
  final int absentCount;
}

class ConcertVolunteerSectionData {
  const ConcertVolunteerSectionData({
    required this.counts,
    required this.isAdmin,
    required this.applications,
    this.ownApplication,
  });

  final ConcertVolunteerApplication? ownApplication;
  final ConcertVolunteerCounts counts;
  final bool isAdmin;
  final List<ConcertVolunteerApplication> applications;

  TeamAttendanceCounts get attendanceCounts =>
      TeamAttendanceCounts.fromApplications(applications);
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
