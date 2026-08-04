import 'dart:convert';

import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/exports/data/export_providers.dart';
import 'package:club_sandwich/features/exports/data/export_repository.dart';
import 'package:club_sandwich/features/exports/domain/maraude_export_row.dart';
import 'package:club_sandwich/features/exports/presentation/maraude_export_dialog.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('MaraudeExportRow parse les valeurs nulles et calculées', () {
    final row = MaraudeExportRow.fromJson({
      'concert_id': 'concert-id',
      'artist': 'Artiste',
      'concert_date': '2026-02-10',
      'organization_name': 'Tourneur A',
      'venue_name': 'Salle',
      'actual_start_at': '2026-02-10T19:00:00Z',
      'actual_end_at': '2026-02-10T22:00:00Z',
      'duration_hours': 3.0,
      'distance_km': 12.3,
      'total_weight_kg': 42.5,
      'estimated_meals': 30,
      'distributed_meals': null,
      'estimated_beneficiaries': null,
      'volunteer_count': 4,
      'volunteer_hours': 12.0,
      'collection_summary': 'Plats préparés: 30 pièce(s)',
    });

    expect(row.artist, 'Artiste');
    expect(row.durationHours, 3.0);
    expect(row.distributedMeals, isNull);
    expect(row.volunteerCount, 4);
    expect(row.collectionSummary, 'Plats préparés: 30 pièce(s)');
  });

  test('génère un CSV avec en-têtes et une ligne par maraude', () {
    const repository = ExportRepository(_UnusedClient());
    final bytes = repository.buildCsv([
      MaraudeExportRow.fromJson({
        'concert_id': 'concert-id',
        'artist': 'Maraude test',
        'concert_date': '2026-02-10',
        'organization_name': 'Tourneur A',
        'venue_name': 'Salle',
        'duration_hours': 3.0,
        'distance_km': 12.3,
        'total_weight_kg': 42.5,
        'estimated_meals': 30,
        'distributed_meals': 28,
        'estimated_beneficiaries': 25,
        'volunteer_count': 4,
        'volunteer_hours': 12.0,
        'collection_summary': 'Plats préparés: 30 pièce(s)',
      }),
    ]);
    final content = utf8.decode(bytes, allowMalformed: true);

    expect(content, contains('Maraude'));
    expect(content, contains('Poids collecté (kg)'));
    expect(content, contains('Maraude test'));
    expect(content, contains('10/02/2026'));
    expect(content, contains('Tourneur A'));
  });

  testWidgets(
    'le dialogue d’export déclenche la récupération et le téléchargement',
    (tester) async {
      final repository = _FakeExportRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exportRepositoryProvider.overrideWithValue(repository),
            organizationsProvider.overrideWith(
              (ref) async => [
                Organization(
                  id: 'org-a',
                  name: 'Tourneur A',
                  slug: 'tourneur-a',
                  kind: OrganizationKind.promoter,
                  createdAt: DateTime.utc(2026, 1, 1),
                ),
              ],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      showMaraudeExportDialog(context, AppUserRole.admin),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('export-organization-field')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('export-submit-button')));
      await tester.pumpAndSettle();

      expect(repository.fetchCalls, 1);
      expect(repository.savedFilenames, hasLength(1));
    },
  );

  testWidgets('le dialogue signale l’absence de résultat sans télécharger', (
    tester,
  ) async {
    final repository = _FakeExportRepository(rows: const []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [exportRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showMaraudeExportDialog(context, AppUserRole.promoter),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('export-submit-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Aucune maraude terminée ne correspond à ces critères.'),
      findsOneWidget,
    );
    expect(repository.savedFilenames, isEmpty);
  });
}

class _UnusedClient implements SupabaseClient {
  const _UnusedClient();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Not used in this test');
}

class _FakeExportRepository extends ExportRepository {
  _FakeExportRepository({this.rows})
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final List<MaraudeExportRow>? rows;
  int fetchCalls = 0;
  final savedFilenames = <String>[];

  @override
  Future<List<MaraudeExportRow>> fetchMaraudeExportRows({
    DateTime? startDate,
    DateTime? endDate,
    String? organizationId,
  }) async {
    fetchCalls++;
    return rows ??
        [
          MaraudeExportRow.fromJson({
            'concert_id': 'concert-id',
            'artist': 'Maraude test',
            'concert_date': '2026-02-10',
            'volunteer_count': 2,
          }),
        ];
  }

  @override
  Future<void> saveCsv(dynamic bytes, String filename) async {
    savedFilenames.add(filename);
  }
}
