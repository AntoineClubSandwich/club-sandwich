import 'dart:async';

import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/data/concert_repository.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_operational_report_card.dart';
import 'package:club_sandwich/features/dashboard/presentation/dashboard_screen.dart';
import 'package:club_sandwich/features/invitations/data/invitation_providers.dart';
import 'package:club_sandwich/features/invitations/domain/invitation_campaign.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/features/volunteers/presentation/volunteers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/test_data.dart';

void main() {
  test('MaraudeOverview parse les actions en attente du tableau de bord', () {
    final overview = MaraudeOverview.fromJson(const {
      'concert_id': 'concert-id',
      'artist': 'Artiste',
      'concert_date': '2026-07-29',
      'concert_time': '20:00:00',
      'maraude_status': 'team_ready',
      'venue_name': 'Olympia',
      'application_count': 4,
      'pending_application_count': 2,
      'selected_count': 2,
      'pending_confirmation_count': 1,
      'own_status': 'selected',
      'own_team_role': 'logistics',
      'own_confirmation_status': 'pending',
      'is_admin': false,
    });

    expect(overview.pendingApplicationCount, 2);
    expect(overview.pendingConfirmationCount, 1);
    expect(overview.ownConfirmationStatus, VolunteerConfirmationStatus.pending);
  });

  test('MaraudeOperationalReport parse les valeurs nulles et décimales', () {
    final report = MaraudeOperationalReport.fromJson(const {
      'concert_id': 'concert-id',
      'total_weight_kg': 12.5,
      'estimated_meals': 0,
      'comment': null,
      'last_modified_by': null,
      'created_at': '2026-07-27T20:00:00.000Z',
      'updated_at': '2026-07-27T21:00:00.000Z',
    });

    expect(report.totalWeightKg, 12.5);
    expect(report.estimatedMeals, 0);
    expect(report.comment, isNull);
  });

  test('distingue une valeur non renseignée de zéro', () {
    final report = MaraudeOperationalReport.fromJson(const {
      'concert_id': 'concert-id',
      'total_weight_kg': null,
      'estimated_meals': null,
      'distance_km': null,
      'quantities_unavailable': true,
      'created_at': '2026-07-27T20:00:00.000Z',
      'updated_at': '2026-07-27T21:00:00.000Z',
    });

    expect(report.totalWeightKg, isNull);
    expect(report.estimatedMeals, isNull);
    expect(report.distanceKm, isNull);
    expect(report.quantitiesUnavailable, isTrue);
  });

  testWidgets(
    'enregistre un compte rendu avec distance et quantités absentes',
    (tester) async {
      final repository = _FakeMaraudeCycleRepository();
      await _pumpReport(tester, repository);

      await tester.enterText(find.byKey(const ValueKey('report-weight')), '0');
      await tester.enterText(
        find.byKey(const ValueKey('report-distance')),
        '4,5',
      );
      await tester.tap(
        find.byKey(const ValueKey('report-quantities-unavailable')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('report-comment')),
        'Aucune collecte',
      );
      await tester.tap(find.byKey(const ValueKey('save-report-draft')));
      await tester.pumpAndSettle();

      expect(repository.savedDraft?.totalWeightKg, isNull);
      expect(repository.savedDraft?.distanceKm, 4.5);
      expect(repository.savedDraft?.quantitiesUnavailable, isTrue);
      expect(repository.savedDraft?.comment, 'Aucune collecte');
      expect(repository.complete, isFalse);
      expect(find.text('Brouillon enregistré.'), findsOneWidget);
    },
  );

  testWidgets(
    'une collecte renseignée neutralise le placeholder de quantités absentes',
    (tester) async {
      final timestamp = DateTime.utc(2026, 7, 29, 12);
      final concert = buildConcert(
        maraudeStatus: MaraudeStatus.completed,
        operationalReport: MaraudeOperationalReport(
          concertId: 'concert-id',
          quantitiesUnavailable: true,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
        collections: [
          MaraudeCollection(
            id: 'collection-id',
            concertId: 'concert-id',
            category: CollectionCategory.preparedMeals,
            quantity: 14,
            unit: CollectionUnit.piece,
            weightKg: 4.9,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MaraudeOperationalReportCard(
                concert: concert,
                canEdit: true,
                canEditPhoto: false,
                canManagePhotoGallery: true,
                currentUserId: 'admin-id',
                isAdmin: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('report-quantities-unavailable')),
      );
      expect(checkbox.value, isFalse);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('report-weight')))
            .controller
            ?.text,
        '4,9',
      );
    },
  );

  testWidgets('conserve les valeurs après une erreur de compte rendu', (
    tester,
  ) async {
    final repository = _FakeMaraudeCycleRepository(shouldFail: true);
    await _pumpReport(tester, repository);

    await tester.enterText(find.byKey(const ValueKey('report-distance')), '18');
    await tester.tap(find.byKey(const ValueKey('save-report-draft')));
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible d’enregistrer le compte rendu.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('report-distance')))
          .controller
          ?.text,
      '18',
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
          .widget<FilledButton>(find.byKey(const ValueKey('save-report-draft')))
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
    expect(find.text('Équipe non constituée'), findsWidgets);
    expect(find.text('2 candidatures à examiner'), findsOneWidget);
    expect(find.text('Aujourd’hui'), findsOneWidget);
    expect(find.text('Maraudes passées non clôturées'), findsOneWidget);
    expect(find.text('Constituer l’équipe'), findsOneWidget);
    expect(find.text('Saisir le compte rendu'), findsOneWidget);
    expect(find.text('2 bénévoles'), findsOneWidget);
    expect(find.text('12,5 kg'), findsOneWidget);
    expect(find.text('18 repas'), findsNothing);
    expect(find.text('Catering : Maison test'), findsOneWidget);
    expect(find.text('Artiste future'), findsOneWidget);
    expect(find.text('Artiste today'), findsOneWidget);
    expect(find.text('Artiste past'), findsOneWidget);
    expect(find.text('Artiste completed'), findsOneWidget);
  });

  testWidgets(
    'le dashboard admin remonte confirmations et invitations à décider',
    (tester) async {
      final items = [
        _overview(
          id: 'confirmation',
          date: DateTime.now().add(const Duration(days: 1)),
          status: MaraudeStatus.teamReady,
          selectedCount: 2,
          pendingConfirmationCount: 1,
          isAdmin: true,
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserContextProvider.overrideWith(
              (ref) async => const CurrentUserContext(
                profileId: 'admin-id',
                role: AppUserRole.admin,
                status: UserAccountStatus.active,
              ),
            ),
            maraudeOverviewProvider.overrideWith((ref) async => items),
            invitationCampaignsProvider.overrideWith(
              (ref) async => [_invitationCampaign(pendingCount: 2)],
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirmations bénévoles en attente'), findsOneWidget);
      expect(find.text('Suivre les confirmations'), findsOneWidget);
      expect(
        find.text('Invitations nécessitant votre attention'),
        findsOneWidget,
      );
      expect(
        find.text('2 décisions restantes · 2 places restantes'),
        findsOneWidget,
      );
      expect(find.text('Décider des attributions'), findsOneWidget);
    },
  );

  testWidgets(
    'le dashboard admin remonte les invitations en attente de confirmation',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserContextProvider.overrideWith(
              (ref) async => const CurrentUserContext(
                profileId: 'admin-id',
                role: AppUserRole.admin,
                status: UserAccountStatus.active,
              ),
            ),
            maraudeOverviewProvider.overrideWith((ref) async => []),
            invitationCampaignsProvider.overrideWith(
              (ref) async => [
                _invitationCampaign(
                  status: InvitationCampaignStatus.closed,
                  awaitingConfirmationCount: 2,
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Invitations nécessitant votre attention'),
        findsOneWidget,
      );
      expect(
        find.text(
          '0 décisions restantes · 2 places restantes · 2 invitations en attente de confirmation',
        ),
        findsOneWidget,
      );
      expect(find.text('Suivre les confirmations bénévoles'), findsOneWidget);
    },
  );

  testWidgets('le dashboard admin remonte les crédits à valider', (
    tester,
  ) async {
    final items = [
      _overview(
        id: 'credit',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: MaraudeStatus.completed,
        selectedCount: 3,
        pendingCreditValidationCount: 2,
        isAdmin: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserContextProvider.overrideWith(
            (ref) async => const CurrentUserContext(
              profileId: 'admin-id',
              role: AppUserRole.admin,
              status: UserAccountStatus.active,
            ),
          ),
          maraudeOverviewProvider.overrideWith((ref) async => items),
          invitationCampaignsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Présences et crédits à valider'), findsOneWidget);
    expect(find.text('2 crédits à valider'), findsOneWidget);
    expect(find.text('Dernières maraudes clôturées'), findsNothing);
  });

  testWidgets('le dashboard tourneur ne répète pas les prochaines maraudes', (
    tester,
  ) async {
    final items = [
      _overview(
        id: 'future',
        date: DateTime.now().add(const Duration(days: 2)),
        status: MaraudeStatus.open,
      ),
      _overview(
        id: 'completed',
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: MaraudeStatus.completed,
      ),
      _overview(
        id: 'future-completed',
        date: DateTime.now().add(const Duration(days: 3)),
        status: MaraudeStatus.completed,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserContextProvider.overrideWith(
            (ref) async => const CurrentUserContext(
              profileId: 'promoter-id',
              role: AppUserRole.promoter,
              status: UserAccountStatus.active,
            ),
          ),
          maraudeOverviewProvider.overrideWith((ref) async => items),
          invitationCampaignsProvider.overrideWith(
            (ref) async => [_invitationCampaign()],
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prochaines maraudes'), findsOneWidget);
    expect(find.text('Activité récente'), findsOneWidget);
    expect(find.text('Artiste future'), findsOneWidget);
    expect(find.text('Artiste completed'), findsOneWidget);
    expect(find.text('Artiste future-completed'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Artiste future-completed')).dy,
      greaterThan(tester.getTopLeft(find.text('Activité récente')).dy),
    );
    expect(
      find.text('Invitations nécessitant votre attention'),
      findsOneWidget,
    );
    expect(find.text('Suivre la campagne'), findsOneWidget);
  });

  testWidgets('le dashboard bénévole masque les actions administratives', (
    tester,
  ) async {
    final items = [
      _overview(
        id: 'open',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: MaraudeStatus.open,
      ),
      _overview(
        id: 'selected',
        date: DateTime.now().add(const Duration(days: 1)),
        status: MaraudeStatus.teamReady,
        ownStatus: ConcertVolunteerStatus.selected,
        ownRole: MaraudeRole.logistics,
        ownConfirmation: VolunteerConfirmationStatus.confirmed,
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

    expect(find.text('Maraudes ouvertes'), findsOneWidget);
    expect(find.text('Artiste open'), findsOneWidget);
    expect(find.text('Je me propose'), findsOneWidget);
    expect(find.text('Prochaine mission'), findsOneWidget);
    expect(find.text('Disponibilités en attente'), findsOneWidget);
    expect(find.text('Rôle : Chargé.e de logistique'), findsOneWidget);
    expect(find.text('Candidatures à examiner'), findsNothing);
  });

  testWidgets(
    'le dashboard bénévole distingue confirmation et invitation obtenue',
    (tester) async {
      final items = [
        _overview(
          id: 'confirmation',
          date: DateTime.now().add(const Duration(days: 1)),
          status: MaraudeStatus.teamReady,
          ownStatus: ConcertVolunteerStatus.selected,
          ownConfirmation: VolunteerConfirmationStatus.pending,
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserContextProvider.overrideWith(
              (ref) async => const CurrentUserContext(
                profileId: 'volunteer-id',
                role: AppUserRole.volunteer,
                status: UserAccountStatus.active,
              ),
            ),
            maraudeOverviewProvider.overrideWith((ref) async => items),
            invitationCampaignsProvider.overrideWith(
              (ref) async => [
                _invitationCampaign(
                  status: InvitationCampaignStatus.closed,
                  ownStatus: InvitationApplicationStatus.selected,
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Participation à confirmer'), findsOneWidget);
      expect(find.text('Confirmer ma participation'), findsOneWidget);
      expect(find.text('Prochaine mission'), findsNothing);
      expect(find.text('Invitation attribuée'), findsOneWidget);
      expect(
        find.text('Voir les informations de l’invitation'),
        findsOneWidget,
      );
    },
  );

  testWidgets('le dashboard bénévole affiche les crédits disponibles', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserContextProvider.overrideWith(
            (ref) async => const CurrentUserContext(
              profileId: 'volunteer-id',
              role: AppUserRole.volunteer,
              status: UserAccountStatus.active,
            ),
          ),
          maraudeOverviewProvider.overrideWith((ref) async => []),
          invitationCampaignsProvider.overrideWith((ref) async => []),
          volunteerCreditSummaryProvider.overrideWith(
            (ref) async => const VolunteerCreditSummary(
              earned: 5,
              consumed: 3,
              available: 2,
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Crédits disponibles'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Progression vers les invitations'), findsOneWidget);
    expect(
      find.text('2/3 crédits pour pouvoir candidater aux invitations.'),
      findsOneWidget,
    );
  });

  testWidgets('le dashboard bénévole signale l’éligibilité aux invitations', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserContextProvider.overrideWith(
            (ref) async => const CurrentUserContext(
              profileId: 'volunteer-id',
              role: AppUserRole.volunteer,
              status: UserAccountStatus.active,
            ),
          ),
          maraudeOverviewProvider.overrideWith((ref) async => []),
          invitationCampaignsProvider.overrideWith((ref) async => []),
          volunteerCreditSummaryProvider.overrideWith(
            (ref) async => const VolunteerCreditSummary(
              earned: 4,
              consumed: 0,
              available: 4,
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vous êtes éligible aux invitations'), findsOneWidget);
    expect(
      find.text(
        '4 crédits disponibles — vous pouvez candidater aux invitations.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('la page bénévole affiche une maraude ouverte sans candidature', (
    tester,
  ) async {
    final items = [
      _overview(
        id: 'without-application',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: MaraudeStatus.open,
      ),
      _overview(
        id: 'own-pending',
        date: DateTime.now().add(const Duration(days: 1)),
        status: MaraudeStatus.open,
        ownStatus: ConcertVolunteerStatus.pending,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [maraudeOverviewProvider.overrideWith((ref) async => items)],
        child: const MaterialApp(home: VolunteersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maraudes ouvertes'), findsOneWidget);
    expect(find.text('Artiste without-application'), findsOneWidget);
    expect(find.text('Je me propose'), findsOneWidget);
    expect(find.text('Artiste own-pending'), findsOneWidget);
    expect(find.text('Disponibilité transmise'), findsOneWidget);
  });

  testWidgets(
    'une candidature refusée future apparaît dans l’historique et non à venir',
    (tester) async {
      final items = [
        _overview(
          id: 'future-refused',
          date: DateTime.now().add(const Duration(days: 3)),
          status: MaraudeStatus.open,
          ownStatus: ConcertVolunteerStatus.notSelected,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            maraudeOverviewProvider.overrideWith((ref) async => items),
          ],
          child: const MaterialApp(home: VolunteersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('À venir'), findsNothing);
      expect(find.text('Aucune maraude à venir.'), findsOneWidget);
      expect(find.text('Historique personnel'), findsOneWidget);
      expect(find.text('Artiste future-refused'), findsOneWidget);
      expect(find.text('Non sélectionné'), findsOneWidget);
    },
  );

  testWidgets('une participation passée non clôturée reste à régulariser', (
    tester,
  ) async {
    final items = [
      _overview(
        id: 'past-selected',
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: MaraudeStatus.teamReady,
        ownStatus: ConcertVolunteerStatus.selected,
        ownConfirmation: VolunteerConfirmationStatus.confirmed,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [maraudeOverviewProvider.overrideWith((ref) async => items)],
        child: const MaterialApp(home: VolunteersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('À régulariser'), findsOneWidget);
    expect(find.text('Artiste past-selected'), findsOneWidget);
  });

  testWidgets(
    'une maraude terminée future apparaît uniquement dans l’historique',
    (tester) async {
      final items = [
        _overview(
          id: 'future-completed',
          date: DateTime.now().add(const Duration(days: 3)),
          status: MaraudeStatus.completed,
          ownStatus: ConcertVolunteerStatus.selected,
          ownConfirmation: VolunteerConfirmationStatus.confirmed,
          totalWeightKg: 15.700000000000001,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            maraudeOverviewProvider.overrideWith((ref) async => items),
          ],
          child: const MaterialApp(home: VolunteersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('À venir'), findsNothing);
      expect(find.text('Historique personnel'), findsOneWidget);
      expect(find.text('Artiste future-completed'), findsOneWidget);
      expect(find.text('15,7 kg'), findsOneWidget);
    },
  );

  testWidgets(
    'le calendrier bénévole affiche et distingue open, pending et selected',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now();
      final items = [
        _overview(
          id: 'open-calendar',
          date: DateTime(now.year, now.month, 10),
          status: MaraudeStatus.open,
        ),
        _overview(
          id: 'pending-calendar',
          date: DateTime(now.year, now.month, 11),
          status: MaraudeStatus.open,
          ownStatus: ConcertVolunteerStatus.pending,
        ),
        _overview(
          id: 'selected-calendar',
          date: DateTime(now.year, now.month, 12),
          status: MaraudeStatus.teamReady,
          ownStatus: ConcertVolunteerStatus.selected,
        ),
      ];
      final router = GoRouter(
        initialLocation: '/maraudes',
        routes: [
          GoRoute(
            path: '/maraudes',
            builder: (_, _) => const VolunteersScreen(),
          ),
          GoRoute(
            path: '/maraudes/:id',
            builder: (_, state) => Text('Détail ${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            maraudeOverviewProvider.overrideWith((ref) async => items),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('volunteer-view-selector')),
        findsOneWidget,
      );
      await tester.tap(find.text('Calendrier'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('month-agenda')), findsOneWidget);
      expect(find.text('Artiste open-calendar'), findsOneWidget);
      expect(find.text('Artiste pending-calendar'), findsOneWidget);
      expect(find.text('Artiste selected-calendar'), findsOneWidget);
      expect(find.text('Ouverte'), findsOneWidget);
      expect(find.text('En attente'), findsOneWidget);
      expect(find.text('Sélectionné'), findsOneWidget);
      expect(
        _calendarItemColor(tester, 'open-calendar'),
        Colors.blue.withValues(alpha: 0.12),
      );
      expect(
        _calendarItemColor(tester, 'pending-calendar'),
        Colors.orange.withValues(alpha: 0.12),
      );
      expect(
        _calendarItemColor(tester, 'selected-calendar'),
        Colors.green.withValues(alpha: 0.12),
      );

      await tester.tap(
        find.byKey(const ValueKey('agenda-concert-selected-calendar')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Détail selected-calendar'), findsOneWidget);
    },
  );
}

Color? _calendarItemColor(WidgetTester tester, String id) {
  return tester
      .widget<Material>(find.byKey(ValueKey('calendar-item-surface-$id')))
      .color;
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
            canManagePhotoGallery: true,
            currentUserId: 'admin-id',
            isAdmin: true,
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
  int pendingConfirmationCount = 0,
  int pendingCreditValidationCount = 0,
  bool isAdmin = false,
  ConcertVolunteerStatus? ownStatus,
  MaraudeRole? ownRole,
  VolunteerConfirmationStatus? ownConfirmation,
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
    pendingApplicationCount: applicationCount,
    selectedCount:
        selectedCount ?? (ownStatus == ConcertVolunteerStatus.selected ? 1 : 0),
    pendingConfirmationCount: pendingConfirmationCount,
    pendingCreditValidationCount: pendingCreditValidationCount,
    totalWeightKg: totalWeightKg,
    estimatedMeals: estimatedMeals,
    isAdmin: isAdmin,
    ownStatus: ownStatus,
    ownTeamRole: ownRole,
    ownConfirmationStatus: ownConfirmation,
  );
}

InvitationCampaign _invitationCampaign({
  int pendingCount = 0,
  InvitationCampaignStatus status = InvitationCampaignStatus.open,
  InvitationApplicationStatus? ownStatus,
  int awaitingConfirmationCount = 0,
}) {
  return InvitationCampaign(
    id: 'campaign-id',
    organizationId: 'organization-id',
    organizationName: 'Tourneur test',
    title: 'Invitations test',
    availablePlaces: 4,
    status: status,
    createdBy: 'promoter-id',
    createdAt: DateTime.utc(2026, 7, 28),
    updatedAt: DateTime.utc(2026, 7, 28),
    applicationCount: pendingCount,
    pendingCount: pendingCount,
    selectedCount: 2,
    attributedPlacesCount: 2,
    awaitingConfirmationCount: awaitingConfirmationCount,
    ownApplication: ownStatus == null
        ? null
        : InvitationApplication(
            id: 'invitation-application-id',
            userId: 'volunteer-id',
            status: ownStatus,
            createdAt: DateTime.utc(2026, 7, 28),
          ),
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
