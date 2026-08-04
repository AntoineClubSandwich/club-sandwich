import 'dart:typed_data';

import 'package:club_sandwich/features/organizations/domain/organization_convention.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationConventionRepository {
  const OrganizationConventionRepository(this._client);
  final SupabaseClient _client;

  static const _bucket = 'organization-private-documents';

  Future<OrganizationConvention?> fetch(String organizationId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_organization_convention',
      params: {'requested_organization_id': organizationId},
    );
    if (rows.isEmpty) return null;
    return OrganizationConvention.fromJson(rows.first as Map<String, dynamic>);
  }

  Future<String> uploadFile({
    required String organizationId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final path =
        '$organizationId/${DateTime.now().microsecondsSinceEpoch}.$extension';
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

  Future<void> submitMyConvention({
    required String organizationId,
    required String storagePath,
  }) async {
    await _client.rpc<void>(
      'submit_my_organization_convention',
      params: {
        'requested_organization_id': organizationId,
        'requested_storage_path': storagePath,
      },
    );
  }

  Future<void> adminSetConvention({
    required String organizationId,
    required String storagePath,
  }) async {
    await _client.rpc<void>(
      'admin_set_organization_convention',
      params: {
        'requested_organization_id': organizationId,
        'requested_storage_path': storagePath,
      },
    );
  }

  Future<void> reject({
    required String organizationId,
    required String rejectionReason,
  }) async {
    await _client.rpc<void>(
      'review_organization_convention',
      params: {
        'requested_organization_id': organizationId,
        'requested_status': 'rejected',
        'requested_rejection_reason': rejectionReason,
      },
    );
  }
}
