import 'dart:async';

import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/data/concert_repository.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_operational_report_card.dart';
import 'package:club_sandwich/features/dashboard/presentation/dashboard_screen.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/test_data.dart';

void main() {
  test('MaraudeOperationalReport parse les valeurs nulles et décimales', () {
    final report = MaraudeOperationalReport.fromJson(const {
      'concert_id': 'concert-id',
      'total_weight_kg': 12.5,
      'estimated_meals': 0,
      'comment': null,
      'photo_folder_url': '',
      'last_modified_by': null,
      'created_at': '2026-07-27T20:00:00.000Z',
      'updated_at': '2026-07-27T21:00:00.000Z',
    });

    expect(report.totalWeightKg, 12.5);
    expect(report.estimatedMeals, 0);
    expect(report.comment, isNull);
    expect(report.photoFolderUrl, isNull);
  });

  testWidgets('enregistre et clôture un compte rendu avec des zéros', (
    tester,
  ) async {
    final repository = _FakeMaraudeCycleRepository();
    await _pumpReport(tester, repository);

    await tester.enterText(find.byKey(const ValueKey('report-weight')), '0');
    await tester.enterText(find.byKey(const ValueKey('report-meals')), '0');
    await tester.enterText(
      find.byKey(const ValueKey('report-comment')),
      'Aucune collecte',
    );
    await tester.tap(find.byKey(const ValueKey('complete-with-report')));
    await tester.pumpAndSettle();

    expect(repository.savedDraft?.totalWeightKg, 0);
    expect(repository.savedDraft?.estimatedMeals, 0);
    expect(repository.savedDraft?.comment, 'Aucune collecte');
    expect(repository.complete, isTrue);
    expect(find.text('Compte rendu enregistré.'), findsOneWidget);
  });

  testWidgets('conserve les valeurs après une erreur de compte rendu', (
    tester,
  ) async {
    final repository = _FakeMaraudeCycleRepository(shouldFail: true);
    await _pumpReport(tester, repository);

    await tester.enterText(find.byKey(const ValueKey('report-weight')), '12,5');
    await tester.enterText(find.byKey(const ValueKey('report-meals')), '18');
    await tester.tap(find.byKey(const ValueKey('save-report-draft')));
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible d’enregistrer le compte rendu.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('report-weight')))
          .controller
          ?.text,
      '12,5',
    );
  });

  testWidgets('désactive les actions pendant la sauvegarde du compte rendu', (
    tester,
  ) async {
    final pendingSave = Completer<void>();
    final repository = _FakeMaraudeCycleRepository(pendingSave: pendingSave);
    await _pumpReport(tester, repository);

    await tester.tap(find.byKey(const ValueKey('save-report-draft')));
    await tester.pump();

    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('save-report-draft')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pendingSave.complete();
    await tester.pumpAndSettle();

    expect(find.text('Brouillon enregistré.'), findsOneWidget);
  });

  testWidgets('le dashboard administrateur affiche les actions utiles', (
    tester,
  ) async {
    final now = DateTime.now();
    final items = [
      _overview(
        id: 'future',
        date: now.add(const Duration(days: 2)),
        status: MaraudeStatus.open,
        applicationCount: 2,
        isAdmin: true,
      ),
      _overview(
        id: 'today',
        date: now,
        status: MaraudeStatus.inProgress,
        isAdmin: true,
      ),
      _overview(
        id: 'past',
        date: now.subtract(const Duration(days: 2)),
        status: MaraudeStatus.open,
        isAdmin: true,
      ),
      _overview(
        id: 'completed',
        date: now.subtract(const Duration(days: 3)),
        status: MaraudeStatus.completed,
        selectedCount: 2,
        totalWeightKg: 12.5,
        estimatedMeals: 18,
        cateringName: 'Maison test',
        isAdmin: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [maraudeOverviewProvider.overrideWith((ref) async => items)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Candidatures à examiner'), findsOneWidget);
    expect(find.text('Aujourd’hui'), findsOneWidget);
    expect(find.text('Maraudes passées non clôturées'), findsOneWidget);
    expect(find.text('Constituer l’équipe'), findsOneWidget);
    expect(find.text('Saisir le compte rendu'), findsOneWidget);
    expect(find.text('2 bénévoles'), findsOneWidget);
    expect(find.text('12,5 kg'), findsOneWidget);
    expect(find.text('18 repas'), findsOneWidget);
    expect(find.text('Catering : Maison test'), findsOneWidget);
  });

  testWidgets('le dashboard bénévole masque les actions administratives', (
    tester,
  ) async {
    final items = [
      _overview(
        id: 'selected',
        date: DateTime.now().add(const Duration(days: 1)),
        status: MaraudeStatus.teamReady,
        ownStatus: ConcertVolunteerStatus.selected,
        ownRole: MaraudeRole.logistics,
      ),
      _overview(
        id: 'pending',
        date: DateTime.now().add(const Duration(days: 2)),
        status: MaraudeStatus.open,
        ownStatus: ConcertVolunteerStatus.pending,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [maraudeOverviewProvider.overrideWith((ref) async => items)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prochaine mission'), findsOneWidget);
    expect(find.text('Disponibilités en attente'), findsOneWidget);
    expect(find.text('Rôle : Chargé.e de logistique'), findsOneWidget);
    expect(find.text('Candidatures à examiner'), findsNothing);
  });
}

Future<void> _pumpReport(
  WidgetTester tester,
  _FakeMaraudeCycleRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [concertRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: Scaffold(
          body: MaraudeOperationalReportCard(
            concert: buildConcert(maraudeStatus: MaraudeStatus.inProgress),
            canEdit: true,
            canEditPhoto: false,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MaraudeOverview _overview({
  required String id,
  required DateTime date,
  required MaraudeStatus status,
  int applicationCount = 0,
  int? selectedCount,
  bool isAdmin = false,
  ConcertVolunteerStatus? ownStatus,
  MaraudeRole? ownRole,
  double? totalWeightKg,
  int? estimatedMeals,
  String? cateringName,
}) {
  return MaraudeOverview(
    concertId: id,
    artist: 'Artiste $id',
    date: DateTime(date.year, date.month, date.day),
    maraudeStatus: status,
    venueName: 'Olympia',
    cateringName: cateringName,
    applicationCount: applicationCount,
    selectedCount:
        selectedCount ?? (ownStatus == ConcertVolunteerStatus.selected ? 1 : 0),
    totalWeightKg: totalWeightKg,
    estimatedMeals: estimatedMeals,
    isAdmin: isAdmin,
    ownStatus: ownStatus,
    ownTeamRole: ownRole,
  );
}

class _FakeMaraudeCycleRepository extends ConcertRepository {
  _FakeMaraudeCycleRepository({this.shouldFail = false, this.pendingSave})
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final bool shouldFail;
  final Completer<void>? pendingSave;
  MaraudeReportDraft? savedDraft;
  bool? complete;

  @override
  Future<void> saveMaraudeReport(
    String concertId,
    MaraudeReportDraft draft, {
    bool complete = true,
  }) async {
    if (shouldFail) throw StateError('Erreur simulée');
    await pendingSave?.future;
    savedDraft = draft;
    this.complete = complete;
  }
}
