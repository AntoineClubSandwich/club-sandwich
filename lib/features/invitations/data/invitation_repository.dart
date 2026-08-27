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
          'venue:venues!invitation_campaigns_venue_id_fkey('
          'id, name, public_address_line1, public_address_line2, '
          'postal_code, city), '
          'applications:invitation_applications('
          'id, user_id, status, created_at, confirmation_status, '
          'confirmation_due_at, confirmation_responded_at, plus_one, '
          'plus_one_name)',
        )
        .order('created_at', ascending: false);

    // The `applications` join above is RLS-filtered per caller — a
    // volunteer only ever sees their own row there, so counts derived
    // from it (below, for `ownApplication`) must not be reused for the
    // campaign-wide totals. Fetch those separately from a function that
    // sees every application, so "places restantes" matches for every
    // role looking at the same campaign.
    final campaignIds = rows
        .map((row) => row['id'] as String)
        .toList(growable: false);
    final countsById = <String, Map<String, dynamic>>{};
    if (campaignIds.isNotEmpty) {
      final countRows = await _client.rpc<List<dynamic>>(
        'get_invitation_campaign_counts',
        params: {'requested_campaign_ids': campaignIds},
      );
      for (final row in countRows) {
        final map = Map<String, dynamic>.from(row as Map);
        countsById[map['campaign_id'] as String] = map;
      }
    }

    return rows
        .map((row) {
          final value = Map<String, dynamic>.from(row);
          final applications =
              value['applications'] as List<dynamic>? ?? const <dynamic>[];
          final counts = countsById[value['id']];
          value['application_count'] = counts?['application_count'] ?? 0;
          value['selected_count'] = counts?['selected_count'] ?? 0;
          value['attributed_places_count'] =
              counts?['attributed_places_count'] ?? 0;
          value['awaiting_confirmation_count'] =
              counts?['awaiting_confirmation_count'] ?? 0;
          value['pending_count'] = counts?['pending_count'] ?? 0;
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

  Future<void> deleteCampaign(String campaignId) async {
    final deleted = await _client
        .from('invitation_campaigns')
        .delete()
        .eq('id', campaignId)
        .select('id')
        .maybeSingle();
    if (deleted == null) {
      throw const PostgrestException(
        message: 'Campagne introuvable ou suppression non autorisée.',
      );
    }
  }

  Future<void> setCampaignStatus(
    String campaignId,
    InvitationCampaignStatus status,
  ) async {
    await _client.rpc<void>(
      'set_invitation_campaign_status',
      params: {
        'requested_campaign_id': campaignId,
        'requested_status': status.jsonValue,
      },
    );
  }

  Future<void> apply(
    String campaignId, {
    bool plusOne = false,
    String? plusOneName,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Utilisateur non connecté.');
    await _client.from('invitation_applications').insert({
      'campaign_id': campaignId,
      'user_id': userId,
      'status': InvitationApplicationStatus.pending.jsonValue,
      'plus_one': plusOne,
      'plus_one_name': plusOne ? plusOneName?.trim() : null,
    });
  }

  Future<void> setPlusOne(
    String applicationId, {
    required bool plusOne,
    String? plusOneName,
  }) async {
    await _client
        .from('invitation_applications')
        .update({
          'plus_one': plusOne,
          'plus_one_name': plusOne ? plusOneName?.trim() : null,
        })
        .eq('id', applicationId);
  }

  Future<void> confirm(String applicationId) async {
    await _client.rpc<void>(
      'confirm_invitation_application',
      params: {'requested_application_id': applicationId},
    );
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
