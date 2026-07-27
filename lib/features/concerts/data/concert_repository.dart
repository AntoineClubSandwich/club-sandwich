import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConcertRepository {
  const ConcertRepository(this._client);

  final SupabaseClient _client;

  static const _concertWithDetailsSelect =
      '*, '
      'venue:venues!concerts_venue_id_fkey('
      'id, name, public_address_line1, public_address_line2, '
      'postal_code, city, '
      'access_details:venue_access_details('
      'artist_entrance_address_line1, artist_entrance_address_line2, '
      'artist_entrance_postal_code, artist_entrance_city, access_instructions'
      ')'
      '), '
      'promoter_organization:organizations!'
      'concerts_promoter_organization_id_fkey(name), '
      'volunteer_applications:concert_volunteers(status)';

  static const _concertDetailSelect =
      '$_concertWithDetailsSelect, '
      'collections:maraude_collections(*), '
      'distribution:maraude_distributions(*), '
      'operational_report:maraude_operational_reports(*)';

  Future<List<Concert>> fetchConcerts() async {
    final rows = await _client
        .from('concerts')
        .select(_concertWithDetailsSelect)
        .order('concert_date')
        .order('concert_time');

    return rows.map(Concert.fromJson).toList(growable: false);
  }

  Future<Concert?> fetchConcert(String concertId) async {
    final row = await _client
        .from('concerts')
        .select(_concertDetailSelect)
        .eq('id', concertId)
        .maybeSingle();

    return row == null ? null : Concert.fromJson(row);
  }

  Future<Concert> createConcert(ConcertDraft draft) async {
    final context = await _currentContext();
    final row = await _client
        .from('concerts')
        .insert({
          ...draft.toJson(),
          'status': ConcertStatus.planned.jsonValue,
          'organization_id': context.organizationId,
          'created_by': context.userId,
          if (context.promoterOrganizationId != null)
            'promoter_organization_id': context.promoterOrganizationId,
        })
        .select()
        .single();

    return Concert.fromJson(row);
  }

  Future<Concert> updateConcert(String concertId, ConcertDraft draft) async {
    final row = await _client
        .from('concerts')
        .update(draft.toJson())
        .eq('id', concertId)
        .select()
        .single();

    return Concert.fromJson(row);
  }

  Future<void> deleteConcert(String concertId) async {
    await _client.from('concerts').delete().eq('id', concertId);
  }

  Future<void> startMaraude(String concertId) async {
    await _client.rpc<void>(
      'start_maraude',
      params: {'requested_concert_id': concertId},
    );
  }

  Future<void> completeMaraude(String concertId) async {
    await _client.rpc<void>(
      'complete_maraude',
      params: {'requested_concert_id': concertId},
    );
  }

  Future<void> setMaraudeStatus(
    String concertId,
    MaraudeStatus status, {
    String? cancellationReason,
  }) async {
    await _client.rpc<void>(
      'set_maraude_status',
      params: {
        'requested_concert_id': concertId,
        'requested_status': status.jsonValue,
        'requested_cancellation_reason': cancellationReason,
      },
    );
  }

  Future<void> saveMaraudeReport(
    String concertId,
    MaraudeReportDraft draft, {
    bool complete = true,
  }) async {
    await _client.rpc<void>(
      'save_maraude_report',
      params: {
        'requested_concert_id': concertId,
        'requested_total_weight_kg': draft.totalWeightKg,
        'requested_estimated_meals': draft.estimatedMeals,
        'requested_comment': draft.comment,
        'requested_photo_folder_url': draft.photoFolderUrl,
        'requested_complete': complete,
      },
    );
  }

  Future<List<MaraudeOverview>> fetchMaraudeOverview({int limit = 100}) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_maraude_overview',
      params: {'requested_limit': limit},
    );
    return rows
        .map((row) => MaraudeOverview.fromJson(row! as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> updateMaraudePhotoLink(
    String concertId,
    String? photoFolderUrl,
  ) async {
    await _client.rpc<void>(
      'update_maraude_photo_link',
      params: {
        'requested_concert_id': concertId,
        'requested_photo_folder_url': photoFolderUrl,
      },
    );
  }

  Future<void> updateClosingComment(
    String concertId,
    String? closingComment,
  ) async {
    final trimmed = closingComment?.trim();
    await _client
        .from('concerts')
        .update({
          'closing_comment': trimmed == null || trimmed.isEmpty
              ? null
              : trimmed,
        })
        .eq('id', concertId);
  }

  Future<_ConcertContext> _currentContext() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Utilisateur non connecté.');

    final rows = await _client.rpc<List<dynamic>>(
      'get_concert_creation_context',
    );
    if (rows.isEmpty) {
      throw const PostgrestException(message: 'Contexte de création absent.');
    }
    final creationContext = rows.first as Map<String, dynamic>;

    return _ConcertContext(
      userId: userId,
      organizationId: creationContext['organization_id'] as String,
      promoterOrganizationId:
          creationContext['promoter_organization_id'] as String?,
    );
  }
}

class _ConcertContext {
  const _ConcertContext({
    required this.userId,
    required this.organizationId,
    this.promoterOrganizationId,
  });

  final String userId;
  final String organizationId;
  final String? promoterOrganizationId;
}
