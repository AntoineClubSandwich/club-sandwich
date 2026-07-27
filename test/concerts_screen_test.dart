import 'dart:async';

import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/data/concert_repository.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/presentation/concerts_screen.dart';
import 'package:club_sandwich/features/venues/data/venue_providers.dart';
import 'package:club_sandwich/features/venues/data/venue_repository.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/test_data.dart';

void main() {
  Future<GoRouter> pumpConcerts(
    WidgetTester tester,
    List<Concert> concerts, {
    ConcertRepository? concertRepository,
    VenueRepository? venueRepository,
  }) async {
    final router = GoRouter(
      initialLocation: '/concerts',
      routes: [
        GoRoute(
          path: '/concerts',
          builder: (context, state) => const ConcertsScreen(),
        ),
        GoRoute(
          path: '/concerts/:concertId',
          builder: (context, state) =>
              Text('Détail ${state.pathParameters['concertId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertsProvider.overrideWith((ref) async => concerts),
          if (concertRepository != null)
            concertRepositoryProvider.overrideWithValue(concertRepository),
          if (venueRepository != null)
            venueRepositoryProvider.overrideWithValue(venueRepository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('affiche l’état vide et ouvre le dialogue de création', (
    tester,
  ) async {
    await pumpConcerts(tester, const []);

    expect(find.text('Aucun concert'), findsOneWidget);
    expect(find.text('Créez votre premier concert.'), findsOneWidget);

    await tester.tap(find.text('Créer un concert'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateConcertDialog), findsOneWidget);
  });

  testWidgets('affiche plusieurs concerts', (tester) async {
    await pumpConcerts(tester, [
      buildConcert(id: 'first', artist: 'Premier artiste'),
      buildConcert(id: 'second', artist: 'Deuxième artiste'),
    ]);

    expect(find.text('Premier artiste'), findsOneWidget);
    expect(find.text('Deuxième artiste'), findsOneWidget);
    expect(find.text('0 bénévole'), findsNWidgets(2));
  });

  testWidgets('un clic sur une carte ouvre sa route détaillée', (tester) async {
    await pumpConcerts(tester, [
      buildConcert(id: 'first', artist: 'Premier artiste'),
    ]);

    await tester.tap(find.text('Premier artiste'));
    await tester.pumpAndSettle();

    expect(find.text('Détail first'), findsOneWidget);
  });

  testWidgets('le dialogue de création valide les champs obligatoires', (
    tester,
  ) async {
    await pumpConcerts(tester, const []);
    await tester.tap(find.text('Créer un concert'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(find.text('Ce champ est requis.'), findsNWidgets(3));
  });

  testWidgets('le dialogue d’édition refuse un e-mail invalide', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConcertFormDialog(
            initialConcert: buildConcert(title: 'Titre'),
            onSubmit: (draft) async {},
          ),
        ),
      ),
    );

    final emailField = find.widgetWithText(TextFormField, 'E-mail').first;
    await tester.enterText(emailField, 'adresse-invalide');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
  });

  testWidgets('désactive l’enregistrement pendant la requête', (tester) async {
    final completer = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConcertFormDialog(
            initialConcert: buildConcert(title: 'Titre'),
            onSubmit: (draft) => completer.future,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    final submitButton = tester.widget<FilledButton>(
      find.byType(FilledButton).last,
    );
    expect(submitButton.onPressed, isNull);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ConcertFormDialog), findsNothing);
  });

  testWidgets('le parcours de création transmet toujours le bon brouillon', (
    tester,
  ) async {
    final concertRepository = _FakeConcertRepository();
    await pumpConcerts(
      tester,
      const [],
      concertRepository: concertRepository,
      venueRepository: _FakeVenueRepository(),
    );

    await tester.tap(find.text('Créer un concert'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Artiste'),
      'Nouvel artiste',
    );

    await tester.tap(find.text('Date du concert'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Salle'), 'Pl');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salle Pleyel'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(concertRepository.createdDraft?.artist, 'Nouvel artiste');
    expect(concertRepository.createdDraft?.venueId, testVenue.id);
    expect(find.text('Concert créé.'), findsOneWidget);
  });

  testWidgets('le parcours d’édition enregistre toujours les modifications', (
    tester,
  ) async {
    final repository = _FakeConcertRepository();
    await pumpConcerts(tester, [
      buildConcert(id: 'concert-id', title: 'Titre'),
    ], concertRepository: repository);

    await tester.tap(find.byTooltip('Actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Artiste'),
      'Artiste modifié',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(repository.updatedConcertId, 'concert-id');
    expect(repository.updatedDraft?.artist, 'Artiste modifié');
    expect(find.text('Concert modifié.'), findsOneWidget);
  });

  testWidgets('le parcours de suppression confirme puis supprime', (
    tester,
  ) async {
    final repository = _FakeConcertRepository();
    await pumpConcerts(tester, [
      buildConcert(id: 'concert-id', title: 'Titre'),
    ], concertRepository: repository);

    await tester.tap(find.byTooltip('Actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer le concert ?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(repository.deletedConcertId, 'concert-id');
    expect(find.text('Concert supprimé.'), findsOneWidget);
  });

  testWidgets('conserve les valeurs du formulaire après une erreur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConcertFormDialog(
            initialConcert: buildConcert(title: 'Titre'),
            onSubmit: (draft) => Future.error(Exception('Erreur simulée')),
          ),
        ),
      ),
    );

    final contactNameField = find.widgetWithText(TextFormField, 'Nom').first;
    await tester.enterText(contactNameField, 'Camille');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ConcertFormDialog), findsOneWidget);
    expect(find.text('Camille'), findsOneWidget);
    expect(
      find.text('Impossible d’enregistrer les modifications.'),
      findsOneWidget,
    );
  });
}

SupabaseClient _testClient() {
  return SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    accessToken: () async => 'test-token',
  );
}

class _FakeVenueRepository extends VenueRepository {
  _FakeVenueRepository() : super(_testClient());

  @override
  Future<List<Venue>> searchActiveVenues(String query) async => [testVenue];
}

class _FakeConcertRepository extends ConcertRepository {
  _FakeConcertRepository() : super(_testClient());

  CreateConcertDraft? createdDraft;
  String? updatedConcertId;
  ConcertDraft? updatedDraft;
  String? deletedConcertId;

  @override
  Future<Concert> createConcert(CreateConcertDraft draft) async {
    createdDraft = draft;
    return buildConcert(
      artist: draft.artist,
      date: draft.date,
      venue: testVenue,
      cateringClosesAt: draft.cateringClosesAt,
    );
  }

  @override
  Future<Concert> updateConcert(String concertId, ConcertDraft draft) async {
    updatedConcertId = concertId;
    updatedDraft = draft;
    return buildConcert(
      id: concertId,
      artist: draft.artist,
      date: draft.date,
      title: draft.title,
    );
  }

  @override
  Future<void> deleteConcert(String concertId) async {
    deletedConcertId = concertId;
  }
}
