import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/shared/data/avatar_url_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaraudeTeamMemberDraft {
  const MaraudeTeamMemberDraft({
    required this.applicationId,
    required this.role,
  });

  final String applicationId;
  final MaraudeRole role;

  Map<String, dynamic> toJson() => {
    'application_id': applicationId,
    'team_role': role.databaseValue,
  };
}

class ConcertVolunteerRepository {
  const ConcertVolunteerRepository(this.client);

  final SupabaseClient client;

  Future<ConcertVolunteerSectionData> fetchSection(String concertId) async {
    final userId = _requireUserId();
    await client.rpc<int>('expire_volunteer_confirmations');
    final results = await Future.wait<Object?>([
      _fetchCounts(concertId),
      _fetchAccess(concertId),
      _fetchCurrentAccount(),
    ]);

    final counts = results[0]! as ConcertVolunteerCounts;
    final access = results[1]! as _ConcertAccess;
    final account = results[2]! as _CurrentAccount;
    if (account.profileId != userId ||
        account.status != UserAccountStatus.active) {
      throw const AuthException('Compte utilisateur inactif.');
    }

    final isAdmin = account.role == AppUserRole.admin;
    final isPromoter = account.role == AppUserRole.promoter;
    final isVolunteer = account.role == AppUserRole.volunteer;
    final canViewApplications =
        isAdmin || (isPromoter && access.canViewApplications);
    final canApply = isVolunteer && access.canApply;
    final details = canViewApplications || canApply
        ? await _fetchDetails(concertId, isPromoter: isPromoter)
        : const <ConcertVolunteerApplication>[];
    final ownApplication = canApply
        ? details
              .where((application) => application.userId == userId)
              .firstOrNull
        : null;
    final applications = canViewApplications
        ? details
        : const <ConcertVolunteerApplication>[];

    return ConcertVolunteerSectionData(
      ownApplication: ownApplication,
      counts: counts,
      isAdmin: isAdmin,
      isPromoter: isPromoter,
      activeRole: account.role,
      currentUserId: userId,
      canViewApplications: canViewApplications,
      canManageConcert: isAdmin || (isPromoter && access.canManageConcert),
      canApply: canApply,
      applications: applications,
    );
  }

  Future<void> apply(String concertId) async {
    final userId = _requireUserId();
    await client.from('concert_volunteers').insert({
      'concert_id': concertId,
      'user_id': userId,
      'status': ConcertVolunteerStatus.pending.databaseValue,
    });
  }

  Future<Map<String, dynamic>?> fetchPrivateVolunteerInformation(
    String userId,
  ) async {
    final rows = await client.rpc<List<dynamic>>(
      'get_volunteer_private_information',
      params: {'requested_user_id': userId},
    );
    if (rows.isEmpty) return null;
    final result = Map<String, dynamic>.from(rows.first as Map);
    for (final field in [
      'identity_document_path',
      'social_security_document_path',
    ]) {
      final path = result[field] as String?;
      if (path != null) {
        result['${field}_url'] = await client.storage
            .from('volunteer-private-documents')
            .createSignedUrl(path, 300);
      }
    }
    return result;
  }

  Future<void> reapply(String concertId) async {
    await client.rpc<void>(
      'reapply_to_concert',
      params: {'requested_concert_id': concertId},
    );
  }

  Future<void> withdraw(String applicationId) async {
    final userId = _requireUserId();
    await client
        .from('concert_volunteers')
        .update({'status': ConcertVolunteerStatus.withdrawn.databaseValue})
        .eq('id', applicationId)
        .eq('user_id', userId);
  }

  Future<void> confirmParticipation(
    String concertId, {
    required bool roleAcknowledged,
  }) async {
    await client.rpc<void>(
      'confirm_concert_participation',
      params: {
        'requested_concert_id': concertId,
        'requested_role_acknowledged': roleAcknowledged,
      },
    );
  }

  Future<void> setStatus(
    String applicationId,
    ConcertVolunteerStatus status,
  ) async {
    if (status != ConcertVolunteerStatus.selected &&
        status != ConcertVolunteerStatus.notSelected) {
      throw ArgumentError.value(
        status,
        'status',
        'Le statut administrateur doit être selected ou not_selected.',
      );
    }

    await client
        .from('concert_volunteers')
        .update({'status': status.databaseValue})
        .eq('id', applicationId);
  }

  Future<void> selectVolunteers(
    String concertId,
    Iterable<String> applicationIds,
  ) async {
    final ids = applicationIds.toSet().toList(growable: false);
    if (ids.isEmpty) {
      throw ArgumentError.value(
        ids,
        'applicationIds',
        'Sélectionnez au moins une candidature.',
      );
    }

    await client.rpc<void>(
      'select_concert_volunteers',
      params: {
        'requested_concert_id': concertId,
        'requested_application_ids': ids,
      },
    );
  }

  Future<void> saveTeam(
    String concertId,
    Iterable<MaraudeTeamMemberDraft> members,
  ) async {
    final team = members.toList(growable: false);
    await client.rpc<void>(
      'save_maraude_team',
      params: {
        'requested_concert_id': concertId,
        'requested_team': team.map((member) => member.toJson()).toList(),
      },
    );
  }

  Future<void> setTeamRole(String applicationId, MaraudeRole role) async {
    await client
        .from('concert_volunteers')
        .update({'team_role': role.databaseValue})
        .eq('id', applicationId);
  }

  /// Immediately persists a team role assignment (admin/organization-member
  /// only, validated server-side: application must be selected, the
  /// maraude's team must still be editable, and only one team leader is
  /// allowed at a time). Unlike [setTeamRole] this goes through
  /// `set_volunteer_team_role`, which also resets the volunteer's
  /// confirmation to pending if they had already confirmed under a
  /// different role.
  Future<void> assignTeamRole(String applicationId, MaraudeRole role) async {
    await client.rpc<void>(
      'set_volunteer_team_role',
      params: {
        'requested_application_id': applicationId,
        'requested_role': role.databaseValue,
      },
    );
  }

  Future<void> setAttendanceStatus(
    String applicationId,
    VolunteerAttendanceStatus status,
  ) async {
    await client.rpc<void>(
      'set_volunteer_attendance',
      params: {
        'requested_application_id': applicationId,
        'requested_status': status.databaseValue,
      },
    );
  }

  Future<MaraudeAttendanceData> fetchAttendance(String concertId) async {
    final rows = await client.rpc<List<dynamic>>(
      'get_maraude_attendance',
      params: {'requested_concert_id': concertId},
    );
    final jsonRows = rows
        .map((row) => Map<String, dynamic>.from(row! as Map))
        .toList(growable: false);
    await _resolveFlatAvatarRows(jsonRows);
    return MaraudeAttendanceData(
      jsonRows.map(MaraudeAttendanceMember.fromJson).toList(growable: false),
    );
  }

  Future<int> validateAttendance(String concertId) async {
    return client.rpc<int>(
      'validate_maraude_attendance',
      params: {'requested_concert_id': concertId},
    );
  }

  Future<int> fetchCreditCount() async {
    return client.rpc<int>('get_my_volunteer_credit_count');
  }

  Future<VolunteerCreditSummary> fetchCreditSummary() async {
    final rows = await client.rpc<List<dynamic>>(
      'get_my_volunteer_credit_summary',
    );
    if (rows.isEmpty) return VolunteerCreditSummary.empty;
    return VolunteerCreditSummary.fromJson(rows.first as Map<String, dynamic>);
  }

  Future<List<ConcertVolunteerRosterEntry>> fetchRoster(
    String concertId,
  ) async {
    final rows = await client.rpc<List<dynamic>>(
      'get_concert_volunteer_roster',
      params: {'requested_concert_id': concertId},
    );
    final jsonRows = rows
        .map((row) => Map<String, dynamic>.from(row! as Map))
        .toList(growable: false);
    await _resolveFlatAvatarRows(jsonRows);
    return jsonRows
        .map(ConcertVolunteerRosterEntry.fromJson)
        .toList(growable: false);
  }

  String _requireUserId() {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Utilisateur non connecté.');
    return userId;
  }

  Future<ConcertVolunteerCounts> _fetchCounts(String concertId) async {
    final rows = await client.rpc<List<dynamic>>(
      'get_concert_volunteer_counts',
      params: {'requested_concert_id': concertId},
    );
    if (rows.isEmpty) return const ConcertVolunteerCounts.empty();
    return ConcertVolunteerCounts.fromJson(rows.first! as Map<String, dynamic>);
  }

  Future<_ConcertAccess> _fetchAccess(String concertId) async {
    final rows = await client.rpc<List<dynamic>>(
      'get_concert_access',
      params: {'requested_concert_id': concertId},
    );
    if (rows.isEmpty) return const _ConcertAccess();
    return _ConcertAccess.fromJson(rows.first! as Map<String, dynamic>);
  }

  Future<_CurrentAccount> _fetchCurrentAccount() async {
    final rows = await client.rpc<List<dynamic>>('get_current_user_context');
    if (rows.isEmpty) {
      throw const AuthException('Compte utilisateur introuvable.');
    }
    return _CurrentAccount.fromJson(rows.first! as Map<String, dynamic>);
  }

  Future<List<ConcertVolunteerApplication>> _fetchDetails(
    String concertId, {
    required bool isPromoter,
  }) async {
    final rows = await client.rpc<List<dynamic>>(
      isPromoter
          ? 'get_promoter_concert_applications'
          : 'get_concert_volunteer_team_details',
      params: {'requested_concert_id': concertId},
    );

    final jsonRows = rows
        .map((row) => Map<String, dynamic>.from(row! as Map))
        .toList(growable: false);
    await _resolveApplicationAvatarRows(jsonRows);
    final applications = jsonRows
        .map(ConcertVolunteerApplication.fromJson)
        .toList(growable: false);
    if (isPromoter || applications.isEmpty) return applications;

    final confirmationRows = await client
        .from('concert_volunteers')
        .select(
          'id, confirmation_status, confirmation_requested_at, '
          'confirmation_due_at, confirmation_responded_at, '
          'role_acknowledged_at, attendance_validated_at, '
          'attendance_validated_by, last_modified_by',
        )
        .eq('concert_id', concertId);
    final confirmations = {
      for (final row in confirmationRows) row['id'] as String: row,
    };

    return applications
        .map((application) {
          final confirmation = confirmations[application.id];
          if (confirmation == null) return application;
          return application.copyWith(
            confirmationStatus: confirmation['confirmation_status'] == null
                ? null
                : VolunteerConfirmationStatus.fromDatabase(
                    confirmation['confirmation_status'] as String,
                  ),
            confirmationRequestedAt:
                confirmation['confirmation_requested_at'] == null
                ? null
                : DateTime.parse(
                    confirmation['confirmation_requested_at'] as String,
                  ),
            confirmationDueAt: confirmation['confirmation_due_at'] == null
                ? null
                : DateTime.parse(confirmation['confirmation_due_at'] as String),
            confirmationRespondedAt:
                confirmation['confirmation_responded_at'] == null
                ? null
                : DateTime.parse(
                    confirmation['confirmation_responded_at'] as String,
                  ),
            roleAcknowledgedAt: confirmation['role_acknowledged_at'] == null
                ? null
                : DateTime.parse(
                    confirmation['role_acknowledged_at'] as String,
                  ),
            attendanceValidatedAt:
                confirmation['attendance_validated_at'] == null
                ? null
                : DateTime.parse(
                    confirmation['attendance_validated_at'] as String,
                  ),
            attendanceValidatedBy:
                confirmation['attendance_validated_by'] as String?,
            lastModifiedBy: confirmation['last_modified_by'] as String?,
          );
        })
        .toList(growable: false);
  }

  Future<void> _resolveFlatAvatarRows(List<Map<String, dynamic>> rows) async {
    final signedUrls = await resolveAvatarUrls(
      client,
      rows.map((row) => row['avatar_url'] as String?),
    );
    for (final row in rows) {
      row['avatar_url'] = resolvedAvatarUrl(
        row['avatar_url'] as String?,
        signedUrls,
      );
    }
  }

  Future<void> _resolveApplicationAvatarRows(
    List<Map<String, dynamic>> rows,
  ) async {
    String? avatarValue(Map<String, dynamic> row) {
      final nested = row['profile'];
      if (nested is Map) return nested['avatar_url'] as String?;
      return row['avatar_url'] as String?;
    }

    final signedUrls = await resolveAvatarUrls(client, rows.map(avatarValue));
    for (final row in rows) {
      final nested = row['profile'];
      if (nested is Map) {
        final profile = Map<String, dynamic>.from(nested);
        profile['avatar_url'] = resolvedAvatarUrl(
          profile['avatar_url'] as String?,
          signedUrls,
        );
        row['profile'] = profile;
      } else {
        row['avatar_url'] = resolvedAvatarUrl(
          row['avatar_url'] as String?,
          signedUrls,
        );
      }
    }
  }
}

class _ConcertAccess {
  const _ConcertAccess({
    this.canViewApplications = false,
    this.canManageConcert = false,
    this.canApply = false,
  });

  factory _ConcertAccess.fromJson(Map<String, dynamic> json) {
    return _ConcertAccess(
      canViewApplications: json['can_view_applications'] as bool? ?? false,
      canManageConcert: json['can_manage_concert'] as bool? ?? false,
      canApply: json['can_apply'] as bool? ?? false,
    );
  }

  final bool canViewApplications;
  final bool canManageConcert;
  final bool canApply;
}

class _CurrentAccount {
  const _CurrentAccount({
    required this.profileId,
    required this.role,
    required this.status,
  });

  factory _CurrentAccount.fromJson(Map<String, dynamic> json) {
    return _CurrentAccount(
      profileId: json['profile_id'] as String,
      role: AppUserRole.fromJson(json['role'] as String),
      status: UserAccountStatus.fromJson(json['status'] as String),
    );
  }

  final String profileId;
  final AppUserRole role;
  final UserAccountStatus status;
}
