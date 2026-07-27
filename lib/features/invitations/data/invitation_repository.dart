import 'package:club_sandwich/features/invitations/domain/invitation_campaign.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvitationRepository {
  const InvitationRepository(this._client);
  final SupabaseClient _client;

  Future<List<InvitationCampaign>> fetchCampaigns() async {
    final userId = _client.auth.currentUser?.id;
    final rows = await _client
        .from('invitation_campaigns')
        .select(
          '*, organization:organizations(name), '
          'applications:invitation_applications('
          'id, user_id, status, created_at)',
        )
        .order('created_at', ascending: false);
    return rows
        .map((row) {
          final value = Map<String, dynamic>.from(row);
          final applications =
              value['applications'] as List<dynamic>? ?? const <dynamic>[];
          value['application_count'] = applications
              .where(
                (item) =>
                    (item as Map<String, dynamic>)['status'] != 'withdrawn',
              )
              .length;
          value['selected_count'] = applications
              .where(
                (item) =>
                    (item as Map<String, dynamic>)['status'] == 'selected',
              )
              .length;
          value['applications'] = applications
              .where(
                (item) => (item as Map<String, dynamic>)['user_id'] == userId,
              )
              .toList(growable: false);
          return InvitationCampaign.fromJson(value);
        })
        .toList(growable: false);
  }

  Future<InvitationCampaign> create(InvitationCampaignDraft draft) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Utilisateur non connecté.');
    final row = await _client
        .from('invitation_campaigns')
        .insert({...draft.toJson(), 'created_by': userId})
        .select()
        .single();
    return InvitationCampaign.fromJson({
      ...row,
      'application_count': 0,
      'selected_count': 0,
    });
  }

  Future<void> apply(String campaignId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Utilisateur non connecté.');
    await _client.from('invitation_applications').insert({
      'campaign_id': campaignId,
      'user_id': userId,
      'status': InvitationApplicationStatus.pending.jsonValue,
    });
  }

  Future<void> withdraw(String applicationId) async {
    await _client
        .from('invitation_applications')
        .update({
          'status': InvitationApplicationStatus.withdrawn.jsonValue,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', applicationId);
  }

  Future<List<InvitationCandidate>> fetchCandidates(String campaignId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_invitation_candidates',
      params: {'requested_campaign_id': campaignId},
    );
    return rows
        .map((row) => InvitationCandidate.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> setCandidateStatus(
    String applicationId,
    InvitationApplicationStatus status,
  ) async {
    await _client.rpc<void>(
      'set_invitation_application_status',
      params: {
        'requested_application_id': applicationId,
        'requested_status': status.jsonValue,
      },
    );
  }
}
