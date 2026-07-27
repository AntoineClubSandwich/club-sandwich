import 'dart:async';

import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/data/concert_repository.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_detail_screen.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_form.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/test_data.dart';

void main() {
  test('calcule l’arrivée recommandée quinze minutes avant', () {
    expect(recommendedArrivalFromDatabase('22:30:00'), '22:15');
    expect(recommendedArrivalFromDatabase('00:10:00'), '23:55');
  });

  test('valide légèrement les adresses e-mail non vides', () {
    expect(validateOptionalEmail(''), isNull);
    expect(validateOptionalEmail('contact@example.com'), isNull);
    expect(validateOptionalEmail('adresse-invalide'), isNotNull);
  });

  testWidgets('affiche les valeurs optionnelles absentes', (tester) async {
    final concert = Concert(
      id: 'concert-id',
      organizationId: 'organization-id',
      artist: 'Artiste',
      date: DateTime(2026, 9, 15),
      status: ConcertStatus.planned,
      createdBy: 'profile-id',
      createdAt: DateTime(2026, 7, 25),
      updatedAt: DateTime(2026, 7, 25),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertDetailsProvider.overrideWith(
            (ref, concertId) async => concert,
          ),
          concertVolunteerSectionProvider.overrideWith(
            (ref, concertId) async => const ConcertVolunteerSectionData(
              counts: ConcertVolunteerCounts.empty(),
              isAdmin: false,
              applications: [],
            ),
          ),
        ],
        child: const MaterialApp(
          home: ConcertDetailScreen(concertId: 'concert-id'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Artiste'), findsWidgets);
    expect(find.text('15 septembre 2026'), findsWidgets);
    expect(find.text('—'), findsWidgets);
    expect(find.text('0 candidatures'), findsOneWidget);
    expect(find.text('0 bénévoles sélectionnés'), findsOneWidget);
    expect(find.text('Je me propose'), findsOneWidget);
    expect(find.text('Aucun document disponible.'), findsOneWidget);
    expect(find.text('Aucun contact tourneur renseigné.'), findsOneWidget);
    expect(find.text('Aucun contact catering renseigné.'), findsOneWidget);
  });

  testWidgets('affiche les coordonnées des deux contacts', (tester) async {
    final concert = buildConcert(
      notes: 'Consignes utiles',
      cateringClosesAt: '22:30:00',
      venue: testVenue,
      promoterOrganizationName: 'Producteur',
      promoterContactName: 'Camille',
      promoterContactPhone: '+33 6 00 00 00 00',
      promoterContactEmail: 'camille@example.com',
      cateringContactName: 'Alex',
      cateringContactPhone: '+33 6 11 11 11 11',
      cateringContactEmail: 'alex@example.com',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertDetailsProvider.overrideWith(
            (ref, concertId) async => concert,
          ),
          concertVolunteerSectionProvider.overrideWith(
            (ref, concertId) async => const ConcertVolunteerSectionData(
              counts: ConcertVolunteerCounts.empty(),
              isAdmin: false,
              applications: [],
            ),
          ),
        ],
        child: const MaterialApp(
          home: ConcertDetailScreen(concertId: 'concert-id'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Camille'), findsOneWidget);
    expect(find.text('camille@example.com'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('alex@example.com'), findsOneWidget);
    expect(find.text('Salle Pleyel'), findsWidgets);
    expect(find.text('Producteur'), findsNWidgets(2));
    expect(find.text('Consignes utiles'), findsOneWidget);
    expect(find.text('22:30'), findsOneWidget);
    expect(find.text('22:15'), findsOneWidget);
  });

  testWidgets('affiche un chargement pendant la récupération', (tester) async {
    final completer = Completer<Concert?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertDetailsProvider.overrideWith(
            (ref, concertId) => completer.future,
          ),
        ],
        child: const MaterialApp(
          home: ConcertDetailScreen(concertId: 'concert-id'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('affiche une erreur de chargement', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertDetailsProvider.overrideWith(
            (ref, concertId) => Future.error(StateError('Erreur simulée')),
          ),
        ],
        child: const MaterialApp(
          home: ConcertDetailScreen(concertId: 'concert-id'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger ce concert.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('affiche un état concert introuvable', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertDetailsProvider.overrideWith((ref, concertId) async => null),
        ],
        child: const MaterialApp(
          home: ConcertDetailScreen(concertId: 'missing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Concert introuvable'), findsOneWidget);
    expect(
      find.text('Ce concert n’existe pas ou n’est pas accessible.'),
      findsOneWidget,
    );
  });

  testWidgets('ouvre le formulaire unifié depuis la fiche concert', (
    tester,
  ) async {
    final repository = _FakeEditConcertRepository();
    final concert = buildConcert(
      id: 'concert-id',
      artist: 'Artiste initial',
      venue: testVenue,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertRepositoryProvider.overrideWithValue(repository),
          concertDetailsProvider.overrideWith(
            (ref, concertId) async => concert,
          ),
          concertVolunteerSectionProvider.overrideWith(
            (ref, concertId) async => const ConcertVolunteerSectionData(
              counts: ConcertVolunteerCounts.empty(),
              isAdmin: true,
              applications: [],
            ),
          ),
        ],
        child: const MaterialApp(
          home: ConcertDetailScreen(concertId: 'concert-id'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    expect(find.byType(ConcertForm), findsOneWidget);
    expect(find.text('Titre'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('concert-artist-field')),
      'Artiste modifié',
    );
    await tester.ensureVisible(find.text('Enregistrer les modifications'));
    await tester.tap(find.text('Enregistrer les modifications'));
    await tester.pumpAndSettle();

    expect(repository.updatedConcertId, 'concert-id');
    expect(repository.updatedDraft?.artist, 'Artiste modifié');
    expect(repository.updatedDraft?.venueId, testVenue.id);
  });

  testWidgets('affiche et permet de corriger le cycle de maraude', (
    tester,
  ) async {
    final repository = _FakeLifecycleConcertRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertRepositoryProvider.overrideWithValue(repository),
          concertDetailsProvider.overrideWith(
            (ref, concertId) async => repository.concert,
          ),
          concertVolunteerSectionProvider.overrideWith(
            (ref, concertId) async => const ConcertVolunteerSectionData(
              counts: ConcertVolunteerCounts.empty(),
              isAdmin: true,
              applications: [],
            ),
          ),
        ],
        child: const MaterialApp(
          home: ConcertDetailScreen(concertId: 'concert-id'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ouverte'), findsWidgets);

    final selector = find.byKey(const ValueKey('maraude-status-selector'));
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('En cours').last);
    await tester.pumpAndSettle();

    expect(find.text('En cours'), findsWidgets);
    expect(find.text('27 juillet 2026\n21:12'), findsOneWidget);

    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminée').last);
    await tester.pumpAndSettle();

    expect(find.text('Terminée'), findsWidgets);
    expect(find.text('Maraude terminée'), findsOneWidget);
    expect(find.text('27 juillet 2026\n23:05'), findsOneWidget);
    expect(repository.startCount, 1);
    expect(repository.completeCount, 1);
  });

  testWidgets('le bénévole voit le cycle sans pouvoir le modifier', (
    tester,
  ) async {
    final concert = buildConcert(
      maraudeStatus: MaraudeStatus.inProgress,
      actualStartAt: DateTime(2026, 7, 27, 21, 12),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertDetailsProvider.overrideWith(
            (ref, concertId) async => concert,
          ),
          concertVolunteerSectionProvider.overrideWith(
            (ref, concertId) async => const ConcertVolunteerSectionData(
              counts: ConcertVolunteerCounts.empty(),
              isAdmin: false,
              applications: [],
            ),
          ),
        ],
        child: const MaterialApp(
          home: ConcertDetailScreen(concertId: 'concert-id'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('27 juillet 2026\n21:12'), findsOneWidget);
    expect(find.text('Démarrer la maraude'), findsNothing);
    expect(find.text('Terminer la maraude'), findsNothing);
  });
}

class _FakeLifecycleConcertRepository extends ConcertRepository {
  _FakeLifecycleConcertRepository()
    : concert = buildConcert(),
      super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  Concert concert;
  int startCount = 0;
  int completeCount = 0;

  @override
  Future<void> setMaraudeStatus(
    String concertId,
    MaraudeStatus status, {
    String? cancellationReason,
  }) async {
    if (status == MaraudeStatus.inProgress) {
      startCount++;
      concert = buildConcert(
        maraudeStatus: status,
        actualStartAt: DateTime(2026, 7, 27, 21, 12),
      );
    } else if (status == MaraudeStatus.completed) {
      completeCount++;
      concert = buildConcert(
        maraudeStatus: status,
        actualStartAt: DateTime(2026, 7, 27, 21, 12),
        actualEndAt: DateTime(2026, 7, 27, 23, 5),
      );
    }
  }
}

class _FakeEditConcertRepository extends ConcertRepository {
  _FakeEditConcertRepository()
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  String? updatedConcertId;
  ConcertDraft? updatedDraft;

  @override
  Future<Concert> updateConcert(String concertId, ConcertDraft draft) async {
    updatedConcertId = concertId;
    updatedDraft = draft;
    return buildConcert(id: concertId, artist: draft.artist, venue: testVenue);
  }
}
