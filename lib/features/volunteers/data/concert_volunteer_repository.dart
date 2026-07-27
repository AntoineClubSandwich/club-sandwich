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
      _isClubSandwichAdmin(userId),
    ]);

    final counts = results[0]! as ConcertVolunteerCounts;
    final isAdmin = results[1]! as bool;
    final details = await _fetchDetails(concertId);
    final ownApplication = details
        .where((application) => application.userId == userId)
        .firstOrNull;
    final applications = isAdmin
        ? details
        : const <ConcertVolunteerApplication>[];

    return ConcertVolunteerSectionData(
      ownApplication: ownApplication,
      counts: counts,
      isAdmin: isAdmin,
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

  Future<bool> _isClubSandwichAdmin(String userId) async {
    final rows = await client
        .from('memberships')
        .select('role, organizations!inner(kind)')
        .eq('profile_id', userId);

    return rows.any((row) {
      final role = row['role'] as String?;
      final organization = row['organizations'] as Map<String, dynamic>?;
      return organization?['kind'] == 'club_sandwich' &&
          (role == 'super_admin' || role == 'admin');
    });
  }

  Future<List<ConcertVolunteerApplication>> _fetchDetails(
    String concertId,
  ) async {
    final rows = await client.rpc<List<dynamic>>(
      'get_concert_volunteer_team_details',
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
