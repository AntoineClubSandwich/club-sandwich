import 'dart:async';
import 'dart:convert';

import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/data/concert_repository.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_report.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_detail_screen.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_report_pdf_service.dart';
import 'package:club_sandwich/features/distributions/domain/maraude_distribution.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:pdf/pdf.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/test_data.dart';

void main() {
  test('calcule la durée, le poids, les lots et les pièces', () {
    final report = MaraudeReport.fromConcert(_completedConcert(), _counts);

    expect(report.actualDuration, const Duration(hours: 1, minutes: 53));
    expect(formatMaraudeDuration(report.actualDuration), '1 h 53');
    expect(report.collectionSummary.lotCount, 2);
    expect(report.collectionSummary.totalWeightKg, 30.5);
    expect(report.collectionSummary.totalPieces, 25);
    expect(report.selectedCount, 4);
    expect(report.presentCount, 3);
    expect(report.absentCount, 1);
  });

  test('génère un document PDF non vide', () async {
    final bytes = await const MaraudeReportPdfService().buildPdf(
      MaraudeReport.fromConcert(_completedConcert(), _counts),
    );

    expect(bytes.length, greaterThan(1000));
    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
  });

  test(
    'embarque Noto Sans et couvre les caractères Unicode attendus',
    () async {
      const unicodeText = 'Élodie Maël Anaïs Point Éphémère œ €';
      final loadedAssets = <String>[];
      final messages = <String>[];
      final report = MaraudeReport.fromConcert(
        buildConcert(
          artist: 'Élodie Maël Anaïs',
          venue: const Venue(
            id: 'unicode-venue',
            name: 'Point Éphémère',
            publicAddressLine1: '200 quai de Valmy',
            postalCode: '75010',
            city: 'Paris',
          ),
          maraudeStatus: MaraudeStatus.completed,
          actualStartAt: DateTime(2026, 7, 27, 21),
          actualEndAt: DateTime(2026, 7, 27, 23),
          closingComment: 'Collecte solidaire : œ et €.',
        ),
        _counts,
      );
      final service = MaraudeReportPdfService.withAssetLoader((assetPath) {
        loadedAssets.add(assetPath);
        return rootBundle.load(assetPath);
      });

      final bytes = await runZoned(
        () => service.buildPdf(report),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) => messages.add(message),
        ),
      );

      expect(bytes.length, greaterThan(1000));
      expect(loadedAssets, [
        MaraudeReportPdfService.regularFontAsset,
        MaraudeReportPdfService.boldFontAsset,
      ]);
      expect(
        messages.where(
          (message) =>
              message.contains('has no Unicode support') ||
              message.contains('Unable to find a font to draw'),
        ),
        isEmpty,
      );

      for (final assetPath in loadedAssets) {
        final data = await rootBundle.load(assetPath);
        final font = TtfParser(data);
        for (final rune in unicodeText.runes) {
          if (rune == 0x20) continue;
          expect(
            font.charToGlyphIndexMap[rune],
            isNotNull,
            reason:
                '$assetPath doit contenir '
                '${String.fromCharCode(rune)} (U+${rune.toRadixString(16)})',
          );
        }
      }
    },
  );

  test('le repository normalise et enregistre le commentaire', () async {
    Request? capturedRequest;
    final client = SupabaseClient(
      'http://localhost',
      'test-key',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return Response('', 204, request: request);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      accessToken: () async => 'test-token',
    );
    addTearDown(client.dispose);

    await ConcertRepository(
      client,
    ).updateClosingComment('concert-id', '  Belle maraude.  ');

    expect(capturedRequest?.method, 'PATCH');
    expect(capturedRequest?.url.queryParameters['id'], 'eq.concert-id');
    expect(jsonDecode(capturedRequest!.body), {
      'closing_comment': 'Belle maraude.',
    });
  });

  testWidgets('affiche le bilan complet après la clôture', (tester) async {
    final store = _ReportStore(_completedConcert());
    await _pumpReport(tester, store, isAdmin: true);

    expect(find.text('Bilan'), findsOneWidget);
    expect(find.text('Durée réelle'), findsOneWidget);
    expect(find.text('1 h 53'), findsOneWidget);
    expect(find.text('Nombre de lots'), findsNWidgets(2));
    expect(find.text('30.5 kg'), findsOneWidget);
    expect(find.text('Quantité totale de pièces'), findsOneWidget);
    expect(find.text('Place de la République'), findsNWidgets(2));
    expect(find.text('Belle maraude.'), findsOneWidget);
    expect(find.text('Exporter le bilan'), findsOneWidget);
  });

  testWidgets('permet à l’administrateur de modifier le commentaire', (
    tester,
  ) async {
    final store = _ReportStore(_completedConcert());
    await _pumpReport(tester, store, isAdmin: true);

    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-closing-comment')),
    );
    await tester.tap(find.byKey(const ValueKey('edit-closing-comment')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Commentaire'),
      'Commentaire mis à jour',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(store.concert.closingComment, 'Commentaire mis à jour');
    expect(find.text('Commentaire mis à jour'), findsOneWidget);
  });

  testWidgets('le bénévole présent consulte un bilan entièrement en lecture', (
    tester,
  ) async {
    final store = _ReportStore(_completedConcert());
    await _pumpReport(
      tester,
      store,
      isAdmin: false,
      ownApplication: _application(VolunteerAttendanceStatus.present),
    );

    expect(find.text('Bilan'), findsOneWidget);
    expect(find.text('Exporter le bilan'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-closing-comment')), findsNothing);
  });

  testWidgets('le bilan reste inaccessible avant clôture ou sans présence', (
    tester,
  ) async {
    final startedStore = _ReportStore(
      buildConcert(
        maraudeStatus: MaraudeStatus.started,
        actualStartAt: DateTime(2026, 7, 27, 21, 12),
      ),
    );
    await _pumpReport(tester, startedStore, isAdmin: true);
    expect(find.text('Bilan'), findsNothing);

    final completedStore = _ReportStore(_completedConcert());
    await _pumpReport(
      tester,
      completedStore,
      isAdmin: false,
      ownApplication: _application(VolunteerAttendanceStatus.absent),
    );
    expect(find.text('Bilan'), findsNothing);
  });
}

const _counts = ConcertVolunteerCounts(
  applicationCount: 7,
  selectedCount: 4,
  presentCount: 3,
  absentCount: 1,
);

Concert _completedConcert() {
  return buildConcert(
    artist: 'The Blaze',
    venue: testVenue,
    maraudeStatus: MaraudeStatus.completed,
    actualStartAt: DateTime(2026, 7, 27, 21, 12),
    actualEndAt: DateTime(2026, 7, 27, 23, 5),
    closingComment: 'Belle maraude.',
    collections: [
      _collection(
        id: 'meals',
        quantity: 25,
        unit: CollectionUnit.piece,
        weightKg: 12.5,
      ),
      _collection(
        id: 'crates',
        quantity: 3,
        unit: CollectionUnit.crate,
        weightKg: 18,
      ),
    ],
    distribution: MaraudeDistribution(
      id: 'distribution-id',
      concertId: 'concert-id',
      distributionLocation: 'Place de la République',
      estimatedBeneficiaries: 42,
      distributedMeals: 35,
      remainingWeightKg: 7.5,
      distributionStartedAt: DateTime(2026, 7, 27, 22),
      distributionCompletedAt: DateTime(2026, 7, 27, 23),
      incidentComment: 'RAS',
      createdAt: DateTime(2026, 7, 27, 22),
      updatedAt: DateTime(2026, 7, 27, 23),
    ),
  );
}

MaraudeCollection _collection({
  required String id,
  required double quantity,
  required CollectionUnit unit,
  required double weightKg,
}) {
  return MaraudeCollection(
    id: id,
    concertId: 'concert-id',
    category: CollectionCategory.preparedMeals,
    quantity: quantity,
    unit: unit,
    weightKg: weightKg,
    createdAt: DateTime(2026, 7, 27),
    updatedAt: DateTime(2026, 7, 27),
  );
}

ConcertVolunteerApplication _application(
  VolunteerAttendanceStatus attendanceStatus,
) {
  return ConcertVolunteerApplication(
    id: 'application-id',
    concertId: 'concert-id',
    userId: 'user-id',
    status: ConcertVolunteerStatus.selected,
    attendanceStatus: attendanceStatus,
    createdAt: DateTime(2026, 7, 27),
    updatedAt: DateTime(2026, 7, 27),
  );
}

Future<void> _pumpReport(
  WidgetTester tester,
  _ReportStore store, {
  required bool isAdmin,
  ConcertVolunteerApplication? ownApplication,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        concertRepositoryProvider.overrideWithValue(store.repository),
        concertDetailsProvider.overrideWith(
          (ref, concertId) async => store.concert,
        ),
        concertVolunteerSectionProvider.overrideWith(
          (ref, concertId) async => ConcertVolunteerSectionData(
            ownApplication: ownApplication,
            counts: _counts,
            isAdmin: isAdmin,
            applications: const [],
          ),
        ),
      ],
      child: const MaterialApp(
        home: ConcertDetailScreen(concertId: 'concert-id'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ReportStore {
  _ReportStore(this.concert) {
    repository = _FakeReportConcertRepository(this);
  }

  Concert concert;
  late final _FakeReportConcertRepository repository;
}

class _FakeReportConcertRepository extends ConcertRepository {
  _FakeReportConcertRepository(this.store)
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final _ReportStore store;

  @override
  Future<void> updateClosingComment(
    String concertId,
    String? closingComment,
  ) async {
    final previous = store.concert;
    store.concert = Concert(
      id: previous.id,
      organizationId: previous.organizationId,
      artist: previous.artist,
      date: previous.date,
      status: previous.status,
      createdBy: previous.createdBy,
      createdAt: previous.createdAt,
      updatedAt: previous.updatedAt,
      maraudeStatus: previous.maraudeStatus,
      actualStartAt: previous.actualStartAt,
      actualEndAt: previous.actualEndAt,
      closingComment: closingComment?.trim(),
      collections: previous.collections,
      distribution: previous.distribution,
      venue: previous.venue,
    );
  }
}
