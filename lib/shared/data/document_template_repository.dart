import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

enum DocumentTemplateKey {
  volunteerContract(
    'volunteer_contract',
    'Contrat de bénévolat (modèle vierge)',
  ),
  organizationConvention(
    'organization_convention',
    'Convention de partenariat (modèle vierge)',
  );

  const DocumentTemplateKey(this.databaseValue, this.label);
  final String databaseValue;
  final String label;
}

class DocumentTemplate {
  const DocumentTemplate({required this.key, required this.storagePath});

  factory DocumentTemplate.fromJson(Map<String, dynamic> json) {
    return DocumentTemplate(
      key: json['key'] as String,
      storagePath: json['storage_path'] as String,
    );
  }

  final String key;
  final String storagePath;
}

class DocumentTemplateRepository {
  const DocumentTemplateRepository(this._client);
  final SupabaseClient _client;

  static const _bucket = 'document-templates';

  Future<DocumentTemplate?> fetch(DocumentTemplateKey key) async {
    final row = await _client
        .from('document_templates')
        .select()
        .eq('key', key.databaseValue)
        .maybeSingle();
    if (row == null) return null;
    return DocumentTemplate.fromJson(row);
  }

  Future<String> signedUrl(String storagePath) {
    return _client.storage.from(_bucket).createSignedUrl(storagePath, 300);
  }

  Future<String> uploadFile({
    required DocumentTemplateKey key,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final path =
        '${key.databaseValue}-${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  }

  Future<void> setTemplate({
    required DocumentTemplateKey key,
    required String storagePath,
  }) async {
    await _client.rpc<void>(
      'admin_set_document_template',
      params: {
        'requested_key': key.databaseValue,
        'requested_storage_path': storagePath,
      },
    );
  }
}
