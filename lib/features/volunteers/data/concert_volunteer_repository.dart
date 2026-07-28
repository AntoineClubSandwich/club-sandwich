import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
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
    final results = await Future.wait<Object?>([
      _fetchCounts(concertId),
      _fetchAccess(concertId),
    ]);

    final counts = results[0]! as ConcertVolunteerCounts;
    final access = results[1]! as _ConcertAccess;
    final details = access.canViewApplications || access.canApply
        ? await _fetchDetails(concertId, isPromoter: access.isPromoter)
        : const <ConcertVolunteerApplication>[];
    final ownApplication = access.canApply && !access.canViewApplications
        ? details
              .where((application) => application.userId == userId)
              .firstOrNull
        : null;
    final applications = access.canViewApplications
        ? details
        : const <ConcertVolunteerApplication>[];

    return ConcertVolunteerSectionData(
      ownApplication: ownApplication,
      counts: counts,
      isAdmin: access.isAdmin,
      isPromoter: access.isPromoter,
      canViewApplications: access.canViewApplications,
      canManageConcert: access.canManageConcert,
      canApply: access.canApply,
      applications: applications,
    );
  }

  Future<ConcertVolunteerApplication> apply(String concertId) async {
    final userId = _requireUserId();
    final row = await client
        .from('concert_volunteers')
        .insert({
          'concert_id': concertId,
          'user_id': userId,
          'status': ConcertVolunteerStatus.pending.databaseValue,
        })
        .select()
        .single();

    return ConcertVolunteerApplication.fromJson(row);
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

  Future<void> setAttendanceStatus(
    String applicationId,
    VolunteerAttendanceStatus status,
  ) async {
    await client
        .from('concert_volunteers')
        .update({'attendance_status': status.databaseValue})
        .eq('id', applicationId);
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

    return rows
        .map(
          (row) => ConcertVolunteerApplication.fromJson(
            row! as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }
}

class _ConcertAccess {
  const _ConcertAccess({
    this.isAdmin = false,
    this.isPromoter = false,
    this.canViewApplications = false,
    this.canManageConcert = false,
    this.canApply = false,
  });

  factory _ConcertAccess.fromJson(Map<String, dynamic> json) {
    return _ConcertAccess(
      isAdmin: json['is_admin'] as bool? ?? false,
      isPromoter: json['is_promoter'] as bool? ?? false,
      canViewApplications: json['can_view_applications'] as bool? ?? false,
      canManageConcert: json['can_manage_concert'] as bool? ?? false,
      canApply: json['can_apply'] as bool? ?? false,
    );
  }

  final bool isAdmin;
  final bool isPromoter;
  final bool canViewApplications;
  final bool canManageConcert;
  final bool canApply;
}
