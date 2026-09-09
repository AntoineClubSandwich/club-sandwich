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

  /// A single RPC round-trip (`get_concert_volunteer_bundle`, mirroring the
  /// "mode terrain" operation screen's one-bundle pattern) instead of the
  /// six separate calls this used to make: one blocking expiry sweep that
  /// doesn't belong on a read path, a duplicate current-account fetch
  /// (already available from [currentUserContextProvider] on screen), and
  /// counts/access/applications each as their own round-trip.
  Future<ConcertVolunteerSectionData> fetchSection(String concertId) async {
    final userId = _requireUserId();
    final result = await client.rpc<Object?>(
      'get_concert_volunteer_bundle',
      params: {'requested_concert_id': concertId},
    );
    final bundle = Map<String, dynamic>.from(result! as Map);

    final isAdmin = bundle['is_admin'] as bool;
    final isPromoter = bundle['is_promoter'] as bool;
    final canViewApplications = bundle['can_view_applications'] as bool;
    final canManageConcert = bundle['can_manage_concert'] as bool;
    final canApply = bundle['can_apply'] as bool;
    final counts = ConcertVolunteerCounts.fromJson(
      bundle['counts'] as Map<String, dynamic>,
    );

    final applicationRows = (bundle['applications'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    await _resolveApplicationAvatarRows(applicationRows);
    final details = applicationRows
        .map(ConcertVolunteerApplication.fromJson)
        .toList(growable: false);

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
      activeRole: AppUserRole.fromJson(bundle['role'] as String),
      currentUserId: userId,
      canViewApplications: canViewApplications,
      canManageConcert: canManageConcert,
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
        'Sélectionnez au moins un volontaire.',
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

  /// Locks (or unlocks) a volunteer's team role so it can't be changed, or
  /// the volunteer removed from the team, by accident — e.g. a misclick on
  /// "Retirer de l'équipe" right after a confirmed team leader was set up.
  Future<void> setRoleLock(String applicationId, bool locked) async {
    await client.rpc<void>(
      'set_volunteer_role_lock',
      params: {
        'requested_application_id': applicationId,
        'requested_locked': locked,
      },
    );
  }

  /// Re-notifies a volunteer whose role is locked but who still hasn't
  /// confirmed their participation - an explicit, admin-triggered nudge
  /// rather than a passive wait, gated server-side to only the applications
  /// actually awaiting confirmation.
  Future<void> remindVolunteerConfirmation(String applicationId) async {
    await client.rpc<void>(
      'remind_volunteer_confirmation',
      params: {'requested_application_id': applicationId},
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
