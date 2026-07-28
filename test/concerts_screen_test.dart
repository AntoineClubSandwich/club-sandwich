import 'dart:async';

import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/data/concert_repository.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_form.dart';
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
    Size size = const Size(1200, 900),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/maraudes',
      routes: [
        GoRoute(
          path: '/maraudes',
          builder: (context, state) => const ConcertsScreen(),
        ),
        GoRoute(
          path: '/maraudes/:concertId',
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

  testWidgets('affiche l’état vide et ouvre le formulaire unique', (
    tester,
  ) async {
    await pumpConcerts(tester, const []);

    expect(find.text('Aucune maraude'), findsOneWidget);
    expect(find.text('Ouvrez votre première maraude.'), findsOneWidget);

    await tester.tap(find.text('Ouvrir une maraude'));
    await tester.pumpAndSettle();

    expect(find.byType(ConcertForm), findsOneWidget);
    expect(find.text('Nouvelle maraude'), findsWidgets);
    expect(find.text('Titre'), findsNothing);
  });

  testWidgets('la liste affiche plusieurs concerts et les vrais compteurs', (
    tester,
  ) async {
    await pumpConcerts(tester, [
      buildConcert(
        id: 'first',
        artist: 'Premier artiste',
        selectedVolunteerCount: 1,
      ),
      buildConcert(
        id: 'second',
        artist: 'Deuxième artiste',
        selectedVolunteerCount: 5,
      ),
    ]);

    expect(find.text('Premier artiste'), findsOneWidget);
    expect(find.text('Deuxième artiste'), findsOneWidget);
    expect(find.text('1 bénévole'), findsOneWidget);
    expect(find.text('5 bénévoles'), findsOneWidget);
  });

  testWidgets('un clic sur une carte ouvre sa route détaillée', (tester) async {
    await pumpConcerts(tester, [
      buildConcert(id: 'first', artist: 'Premier artiste'),
    ]);

    await tester.tap(find.text('Premier artiste'));
    await tester.pumpAndSettle();

    expect(find.text('Détail first'), findsOneWidget);
  });

  testWidgets('le même ConcertForm sert à la création et à la modification', (
    tester,
  ) async {
    await pumpConcerts(tester, [
      buildConcert(id: 'concert-id', artist: 'Artiste'),
    ]);

    await tester.tap(find.text('Nouvelle maraude'));
    await tester.pumpAndSettle();
    expect(find.byType(ConcertForm), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    expect(find.byType(ConcertForm), findsOneWidget);
    expect(find.text('Modifier la maraude'), findsOneWidget);
    expect(find.text('Titre'), findsNothing);
  });

  testWidgets('préremplit les champs du formulaire simplifié en modification', (
    tester,
  ) async {
    const venue = Venue(
      id: 'venue-id',
      name: 'Olympia',
      publicAddressLine1: '28 boulevard des Capucines',
      postalCode: '75009',
      city: 'Paris',
      artistEntranceAddressLine1: 'Rue Caumartin',
      artistEntrancePostalCode: '75009',
      artistEntranceCity: 'Paris',
      accessInstructions: 'Sonner à la porte noire.',
    );
    final concert = buildConcert(
      artist: 'VICTOR',
      time: '21:30:00',
      status: ConcertStatus.confirmed,
      venue: venue,
      cateringClosesAt: '23:00:00',
      notes: 'Récupération côté scène',
      promoterOrganizationName: 'Producteur Exemple',
      promoterContactName: 'Camille',
      promoterContactPhone: '0600000000',
      promoterContactEmail: 'camille@example.com',
      cateringContactName: 'Alex',
      cateringContactPhone: '0611111111',
      cateringContactEmail: 'alex@example.com',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ConcertForm(initialConcert: concert, onSubmit: (_) async {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'concert-artist-field'), 'VICTOR');
    expect(_fieldText(tester, 'concert-venue-field'), 'Olympia');
    expect(find.byKey(const ValueKey('concert-tour-field')), findsNothing);
    expect(find.byKey(const ValueKey('concert-time-field')), findsNothing);
    expect(find.byKey(const ValueKey('concert-status-field')), findsNothing);
    expect(
      find.text(
        'Fermeture du catering '
        '(à renseigner quand transmise par le catering)',
      ),
      findsOneWidget,
    );
    expect(find.text('23:00'), findsOneWidget);
    expect(find.text('Producteur Exemple'), findsNothing);
    expect(find.text('Rue Caumartin, 75009 Paris'), findsOneWidget);
    expect(find.text('Sonner à la porte noire.'), findsOneWidget);
    expect(find.text('Récupération côté scène'), findsOneWidget);
    expect(_fieldText(tester, 'promoter-contact-name'), 'Camille');
    expect(_fieldText(tester, 'promoter-contact-phone'), '0600000000');
    expect(find.byKey(const ValueKey('promoter-contact-email')), findsNothing);
    expect(
      find.text(
        'Personne à contacter pour toute question relative à cette maraude.',
      ),
      findsOneWidget,
    );
    expect(find.text('Alex'), findsOneWidget);
  });

  testWidgets('valide uniquement les champs obligatoires du formulaire', (
    tester,
  ) async {
    await pumpConcerts(tester, const []);
    await tester.tap(find.text('Ouvrir une maraude'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ex. : Accès, code porte, consignes particulières, etc.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ouvrir la maraude'));
    await tester.pump();

    expect(find.text('Ce champ est requis.'), findsNWidgets(2));
    expect(find.text('Titre'), findsNothing);
  });

  testWidgets('refuse un e-mail invalide', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ConcertForm(
              initialConcert: buildConcert(venue: testVenue),
              onSubmit: (_) async {},
            ),
          ),
        ),
      ),
    );

    final emailField = find.widgetWithText(TextFormField, 'E-mail').first;
    await tester.enterText(emailField, 'adresse-invalide');
    await tester.ensureVisible(find.text('Enregistrer les modifications'));
    await tester.tap(find.text('Enregistrer les modifications'));
    await tester.pump();

    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
  });

  testWidgets('désactive l’enregistrement pendant la requête', (tester) async {
    final completer = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ConcertForm(
              initialConcert: buildConcert(venue: testVenue),
              onSubmit: (_) => completer.future,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Enregistrer les modifications'));
    await tester.tap(find.text('Enregistrer les modifications'));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('concert-submit-button')),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ConcertForm), findsNothing);
  });

  testWidgets('crée puis modifie avec le même brouillon métier', (
    tester,
  ) async {
    final repository = _FakeConcertRepository();
    await pumpConcerts(
      tester,
      const [],
      concertRepository: repository,
      venueRepository: _FakeVenueRepository(),
    );

    await tester.tap(find.text('Ouvrir une maraude'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('concert-artist-field')),
      'Nouvel artiste',
    );
    await tester.enterText(
      find.byKey(const ValueKey('concert-venue-field')),
      'Pl',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salle Pleyel'));
    await tester.enterText(
      find.byKey(const ValueKey('promoter-contact-name')),
      'Camille Martin',
    );
    await tester.enterText(
      find.byKey(const ValueKey('promoter-contact-phone')),
      '06 00 00 00 00',
    );
    await tester.ensureVisible(find.text('Ouvrir la maraude'));
    await tester.tap(find.text('Ouvrir la maraude'));
    await tester.pumpAndSettle();

    expect(repository.createdDraft?.artist, 'Nouvel artiste');
    expect(repository.createdDraft?.venueId, testVenue.id);
    expect(repository.createdDraft?.promoterContactName, 'Camille Martin');
    expect(repository.createdDraft?.promoterContactPhone, '06 00 00 00 00');
    expect(find.text('Concert créé.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('le parcours d’édition enregistre les champs unifiés', (
    tester,
  ) async {
    final repository = _FakeConcertRepository();
    await pumpConcerts(tester, [
      buildConcert(id: 'concert-id', venue: testVenue),
    ], concertRepository: repository);

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
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
    expect(find.text('Concert modifié.'), findsOneWidget);
  });

  testWidgets('confirme puis supprime un concert', (tester) async {
    final repository = _FakeConcertRepository();
    await pumpConcerts(tester, [
      buildConcert(id: 'concert-id'),
    ], concertRepository: repository);

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer la maraude ?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(repository.deletedConcertId, 'concert-id');
    expect(find.text('Concert supprimé.'), findsOneWidget);
  });

  testWidgets('affiche l’agenda et ouvre un concert du calendrier', (
    tester,
  ) async {
    final now = DateTime.now();
    await pumpConcerts(tester, [
      buildConcert(
        id: 'agenda-id',
        artist: 'Artiste agenda',
        date: DateTime(now.year, now.month, 15),
        time: '21:30:00',
        venue: testVenue,
        selectedVolunteerCount: 3,
      ),
    ]);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('month-agenda')), findsOneWidget);
    expect(find.text('Artiste agenda'), findsOneWidget);
    expect(find.text('3/4 bénévoles'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agenda-concert-agenda-id')));
    await tester.pumpAndSettle();
    expect(find.text('Détail agenda-id'), findsOneWidget);
  });

  testWidgets('navigue entre les mois et revient à aujourd’hui', (
    tester,
  ) async {
    await pumpConcerts(tester, [buildConcert()]);
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    final initialHeading = _agendaHeading(tester);

    await tester.tap(find.byKey(const ValueKey('agenda-next-month')));
    await tester.pumpAndSettle();
    expect(_agendaHeading(tester), isNot(initialHeading));

    await tester.tap(find.text('Aujourd’hui'));
    await tester.pumpAndSettle();
    expect(_agendaHeading(tester), initialHeading);
  });

  testWidgets('affiche une chronologie à la place du mois sur mobile', (
    tester,
  ) async {
    final now = DateTime.now();
    await pumpConcerts(tester, [
      buildConcert(
        id: 'today',
        artist: 'Concert du jour',
        date: now,
        venue: testVenue,
      ),
      buildConcert(
        id: 'tomorrow',
        artist: 'Concert de demain',
        date: now.add(const Duration(days: 1)),
        venue: testVenue,
      ),
    ], size: const Size(390, 844));

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-agenda')), findsOneWidget);
    expect(find.byKey(const ValueKey('month-agenda')), findsNothing);
    expect(find.text('Aujourd’hui'), findsOneWidget);
    expect(find.text('Demain'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mémorise la vue agenda lors d’un aller-retour navigation', (
    tester,
  ) async {
    final now = DateTime.now();
    final router = await pumpConcerts(tester, [
      buildConcert(id: 'remembered', date: DateTime(now.year, now.month)),
    ]);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agenda-concert-remembered')));
    await tester.pumpAndSettle();
    router.go('/maraudes');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('month-agenda')), findsOneWidget);
  });

  testWidgets('applique les filtres aux vues liste et agenda', (tester) async {
    final now = DateTime.now();
    await pumpConcerts(tester, [
      buildConcert(
        id: 'victor',
        artist: 'VICTOR',
        date: now,
        venue: testVenue,
        promoterOrganizationName: 'Producteur A',
      ),
      buildConcert(
        id: 'other',
        artist: 'Autre artiste',
        date: now,
        venue: const Venue(
          id: 'other-venue',
          name: 'Olympia',
          publicAddressLine1: '28 boulevard des Capucines',
          postalCode: '75009',
          city: 'Paris',
        ),
      ),
    ]);

    await tester.tap(find.text('Filtres'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('concert-filter-artist')),
      'victor',
    );
    await tester.pump();

    expect(find.text('VICTOR'), findsOneWidget);
    expect(find.text('Autre artiste'), findsNothing);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('VICTOR'), findsOneWidget);
    expect(find.text('Autre artiste'), findsNothing);
  });
}

String _fieldText(WidgetTester tester, String key) {
  final widget = tester.widget(find.byKey(ValueKey(key)));
  return switch (widget) {
    TextFormField field => field.controller?.text ?? '',
    TextField field => field.controller?.text ?? '',
    _ => throw StateError('Champ texte introuvable : $key'),
  };
}

String _agendaHeading(WidgetTester tester) {
  final heading = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('month-agenda')),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data)
      .whereType<String>()
      .firstWhere((text) => RegExp(r'^[a-zéû]+\s\d{4}$').hasMatch(text));
  return heading;
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

  ConcertDraft? createdDraft;
  String? updatedConcertId;
  ConcertDraft? updatedDraft;
  String? deletedConcertId;

  @override
  Future<Concert> createConcert(ConcertDraft draft) async {
    createdDraft = draft;
    return buildConcert(
      artist: draft.artist,
      date: draft.date,
      status: ConcertStatus.planned,
      venue: testVenue,
      cateringClosesAt: draft.cateringClosesAt,
      promoterContactName: draft.promoterContactName,
      promoterContactPhone: draft.promoterContactPhone,
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
      status: ConcertStatus.planned,
      venue: testVenue,
      cateringClosesAt: draft.cateringClosesAt,
      promoterContactName: draft.promoterContactName,
      promoterContactPhone: draft.promoterContactPhone,
    );
  }

  @override
  Future<void> deleteConcert(String concertId) async {
    deletedConcertId = concertId;
  }
}
