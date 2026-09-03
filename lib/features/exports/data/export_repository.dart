import 'dart:convert';
import 'dart:typed_data';

import 'package:club_sandwich/features/exports/domain/maraude_export_row.dart';
import 'package:csv/csv.dart' as csv_lib;
import 'package:file_saver/file_saver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExportRepository {
  const ExportRepository(this._client);
  final SupabaseClient _client;

  Future<List<MaraudeExportRow>> fetchMaraudeExportRows({
    DateTime? startDate,
    DateTime? endDate,
    String? organizationId,
  }) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_maraude_export_rows',
      params: {
        'requested_start_date': startDate == null ? null : _dateOnly(startDate),
        'requested_end_date': endDate == null ? null : _dateOnly(endDate),
        'requested_organization_id': organizationId,
      },
    );
    return rows
        .map((row) => MaraudeExportRow.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Uint8List buildCsv(List<MaraudeExportRow> rows) {
    final table = <List<dynamic>>[
      [
        'Maraude',
        'Date',
        'Organisation',
        'Salle',
        'Durée (h)',
        'Distance (km)',
        'Poids collecté (kg)',
        'Repas distribués',
        'Bénéficiaires estimés',
        'Bénévoles mobilisés',
        'Heures de bénévolat',
        'Détail des collectes',
      ],
      for (final row in rows)
        [
          row.artist,
          _formatDate(row.concertDate),
          row.organizationName ?? '',
          row.venueName ?? '',
          row.durationHours ?? '',
          row.distanceKm ?? '',
          row.totalWeightKg ?? '',
          row.distributedMeals ?? '',
          row.estimatedBeneficiaries ?? '',
          row.volunteerCount,
          row.volunteerHours ?? '',
          row.collectionSummary ?? '',
        ],
    ];
    final content = csv_lib.excel.encode(table);
    return Uint8List.fromList(utf8.encode(content));
  }

  Future<void> saveCsv(Uint8List bytes, String filename) async {
    await FileSaver.instance.saveFile(
      name: filename,
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';
}
