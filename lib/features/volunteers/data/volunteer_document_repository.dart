import 'dart:typed_data';

import 'package:club_sandwich/features/volunteers/domain/volunteer_document.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VolunteerDocumentRepository {
  const VolunteerDocumentRepository(this._client);
  final SupabaseClient _client;

  static const _bucket = 'volunteer-private-documents';

  Future<List<VolunteerDocument>> fetchMyDocuments() async {
    final rows = await _client.rpc<List<dynamic>>('get_my_volunteer_documents');
    return rows
        .map((row) => VolunteerDocument.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<VolunteerDocument>> fetchDocuments(String userId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_volunteer_documents',
      params: {'requested_user_id': userId},
    );
    return rows
        .map((row) => VolunteerDocument.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<PendingVolunteerDocument>> fetchPendingDocuments() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_pending_volunteer_documents',
    );
    return rows
        .map(
          (row) =>
              PendingVolunteerDocument.fromJson(row as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<String> uploadFile({
    required String targetUserId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final path =
        '$targetUserId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  }

  Future<String> signedUrl(String storagePath) {
    return _client.storage.from(_bucket).createSignedUrl(storagePath, 300);
  }

  Future<void> submitMyDocument({
    required VolunteerDocumentType type,
    required String storagePath,
    String? documentId,
  }) async {
    await _client.rpc<void>(
      'submit_my_volunteer_document',
      params: {
        'requested_document_type': type.databaseValue,
        'requested_storage_path': storagePath,
        'requested_document_id': documentId,
      },
    );
  }

  Future<void> adminSetDocument({
    required String userId,
    required VolunteerDocumentType type,
    String? storagePath,
    String? label,
    String? documentId,
  }) async {
    await _client.rpc<void>(
      'admin_set_volunteer_document',
      params: {
        'requested_user_id': userId,
        'requested_document_type': type.databaseValue,
        'requested_storage_path': storagePath,
        'requested_label': label,
        'requested_document_id': documentId,
      },
    );
  }

  Future<void> reviewDocument({
    required String documentId,
    required VolunteerDocumentStatus status,
    String? rejectionReason,
  }) async {
    await _client.rpc<void>(
      'review_volunteer_document',
      params: {
        'requested_document_id': documentId,
        'requested_status': status.databaseValue,
        'requested_rejection_reason': rejectionReason,
      },
    );
  }

  Future<void> notifyMissingDocuments(String userId) async {
    await _client.rpc<void>(
      'notify_missing_volunteer_documents',
      params: {'requested_user_id': userId},
    );
  }
}
