import 'dart:typed_data';

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
      'postal_code, city, photo_url, '
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
    final promoterOrganizationId =
        context.promoterOrganizationId ?? draft.promoterOrganizationId;
    final row = await _client
        .from('concerts')
        .insert({
          ...draft.toJson(),
          'status': ConcertStatus.planned.jsonValue,
          'organization_id': context.organizationId,
          'created_by': context.userId,
          'promoter_organization_id': ?promoterOrganizationId,
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
    await _client.rpc<void>(
      'delete_concert',
      params: {'requested_concert_id': concertId},
    );
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
    if (status == MaraudeStatus.completed) {
      await _client.rpc<void>(
        'complete_maraude_flexible',
        params: {'requested_concert_id': concertId},
      );
      return;
    }
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
      'save_maraude_operational_report_v2',
      params: {
        'requested_concert_id': concertId,
        'requested_total_weight_kg': draft.totalWeightKg,
        'requested_distance_km': draft.distanceKm,
        'requested_quantities_unavailable': draft.quantitiesUnavailable,
        'requested_comment': draft.comment,
      },
    );
    if (complete) await completeMaraude(concertId);
  }

  Future<void> correctMaraudeTiming(
    String concertId, {
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    await _client.rpc<void>(
      'correct_maraude_timing',
      params: {
        'requested_concert_id': concertId,
        'requested_start_at': startAt?.toUtc().toIso8601String(),
        'requested_end_at': endAt?.toUtc().toIso8601String(),
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

  Future<List<MaraudePhoto>> fetchMaraudePhotos(String concertId) async {
    final rows = await _client
        .from('maraude_photos')
        .select()
        .eq('concert_id', concertId)
        .order('created_at');
    return rows
        .map((row) => MaraudePhoto.fromJson(row))
        .toList(growable: false);
  }

  Future<String> maraudePhotoUrl(String storagePath) {
    return _client.storage
        .from('maraude-photos')
        .createSignedUrl(storagePath, 300);
  }

  Future<void> uploadMaraudePhoto({
    required String concertId,
    required String extension,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Utilisateur non connecté.');
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final path = '$concertId/$userId/$timestamp.$extension';
    await _client.storage
        .from('maraude-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    await _client.rpc<void>(
      'add_maraude_photo',
      params: {
        'requested_concert_id': concertId,
        'requested_storage_path': path,
      },
    );
  }

  Future<void> deleteMaraudePhoto(String photoId, String storagePath) async {
    await _client.rpc<void>(
      'delete_maraude_photo',
      params: {'requested_photo_id': photoId},
    );
    await _client.storage.from('maraude-photos').remove([storagePath]);
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
