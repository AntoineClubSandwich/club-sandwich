import 'package:club_sandwich/features/administration/presentation/administration_screen.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/auth/presentation/activation_screen.dart';
import 'package:club_sandwich/features/auth/presentation/reset_password_screen.dart';
import 'package:club_sandwich/features/invitations/data/invitation_providers.dart';
import 'package:club_sandwich/features/invitations/data/invitation_repository.dart';
import 'package:club_sandwich/features/invitations/domain/invitation_campaign.dart';
import 'package:club_sandwich/features/invitations/presentation/invitations_screen.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/features/profiles/domain/volunteer_statistics.dart'
    as profile_stats;
import 'package:club_sandwich/features/venues/data/venue_providers.dart';
import 'package:club_sandwich/features/venues/data/venue_repository.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:club_sandwich/features/venues/presentation/venue_search_field.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/shared/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Identité V2', () {
    test('ne connaît que les trois rôles applicatifs', () {
      expect(AppUserRole.values.map((role) => role.jsonValue), [
        'admin',
        'promoter',
        'volunteer',
      ]);
      expect(() => AppUserRole.fromJson('catering'), throwsFormatException);
      expect(() => AppUserRole.fromJson('super_admin'), throwsFormatException);
    });

    test('parse le contexte tourneur et son organisation', () {
      final context = CurrentUserContext.fromJson({
        'profile_id': 'profile-id',
        'role': 'promoter',
        'organization_id': 'organization-id',
        'organization_name': 'Auguri',
        'status': 'active',
      });

      expect(context.role, AppUserRole.promoter);
      expect(context.organizationId, 'organization-id');
      expect(context.organizationName, 'Auguri');
      expect(context.status, UserAccountStatus.active);
    });

    test('un +1 consomme deux places dans le quota de la campagne', () {
      final campaign = InvitationCampaign.fromJson({
        'id': 'campaign-id',
        'organization_id': 'organization-id',
        'venue_id': 'venue-id',
        'title': 'Places concert',
        'available_places': 3,
        'status': 'open',
        'created_by': 'promoter-id',
        'created_at': '2026-07-27T10:00:00Z',
        'updated_at': '2026-07-27T10:00:00Z',
        'application_count': 1,
        'selected_count': 1,
        'attributed_places_count': 2,
        'applications': [
          {
            'id': 'application-id',
            'user_id': 'volunteer-id',
            'status': 'selected',
            'created_at': '2026-07-27T11:00:00Z',
            'plus_one': true,
            'plus_one_name': 'Camille',
          },
        ],
      });

      expect(campaign.selectedCount, 1);
      expect(campaign.attributedPlacesCount, 2);
      expect(campaign.remainingPlaces, 1);
      expect(campaign.ownApplication?.plusOne, isTrue);
      expect(campaign.ownApplication?.plusOneName, 'Camille');
    });

    test('parse les trois statuts de compte', () {
      expect(UserAccountStatus.values.map((status) => status.jsonValue), [
        'invited',
        'active',
        'disabled',
      ]);
      expect(UserAccountStatus.fromJson('invited').label, 'Invitation envoyée');
    });

    test('parse une campagne et la candidature du bénévole', () {
      final campaign = InvitationCampaign.fromJson({
        'id': 'campaign-id',
        'organization_id': 'organization-id',
        'organization': {'name': 'AEG'},
        'venue_id': 'venue-id',
        'venue': {
          'id': 'venue-id',
          'name': 'Salle Pleyel',
          'public_address_line1': '252 rue du Faubourg Saint-Honoré',
          'public_address_line2': null,
          'postal_code': '75008',
          'city': 'Paris',
        },
        'title': 'Places concert',
        'available_places': 2,
        'status': 'open',
        'created_by': 'promoter-id',
        'created_at': '2026-07-27T10:00:00Z',
        'updated_at': '2026-07-27T10:00:00Z',
        'application_count': 3,
        'pending_count': 2,
        'selected_count': 1,
        'applications': [
          {
            'id': 'application-id',
            'user_id': 'volunteer-id',
            'status': 'pending',
            'created_at': '2026-07-27T11:00:00Z',
          },
        ],
      });

      expect(campaign.organizationName, 'AEG');
      expect(campaign.venueId, 'venue-id');
      expect(campaign.venue?.name, 'Salle Pleyel');
      expect(
        campaign.venue?.formattedAddress,
        '252 rue du Faubourg Saint-Honoré, 75008 Paris',
      );
      expect(campaign.applicationCount, 3);
      expect(campaign.pendingCount, 2);
      expect(campaign.selectedCount, 1);
      expect(campaign.remainingPlaces, 1);
      expect(
        campaign.ownApplication?.status,
        InvitationApplicationStatus.pending,
      );
    });

    test('sérialise la salle sélectionnée dans la campagne', () {
      const draft = InvitationCampaignDraft(
        organizationId: 'organization-id',
        venueId: 'venue-id',
        title: 'Places concert',
        availablePlaces: 2,
        status: InvitationCampaignStatus.open,
      );

      expect(draft.toJson()['venue_id'], 'venue-id');
    });

    test('sérialise la date de l’événement au format calendrier', () {
      final draft = InvitationCampaignDraft(
        organizationId: 'organization-id',
        venueId: 'venue-id',
        title: 'Places concert',
        availablePlaces: 2,
        status: InvitationCampaignStatus.open,
        eventDate: DateTime(2026, 9, 5),
      );

      expect(draft.toJson()['event_date'], '2026-09-05');
    });

    test('parse la date de l’événement pour l’affichage calendrier', () {
      final campaign = InvitationCampaign.fromJson({
        'id': 'campaign-id',
        'organization_id': 'organization-id',
        'venue_id': 'venue-id',
        'title': 'Places concert',
        'available_places': 2,
        'event_date': '2026-09-05',
        'status': 'open',
        'created_by': 'promoter-id',
        'created_at': '2026-07-27T10:00:00Z',
        'updated_at': '2026-07-27T10:00:00Z',
        'application_count': 0,
        'selected_count': 0,
      });

      expect(campaign.eventDate, DateTime(2026, 9, 5));
    });

    test('parse les statistiques informatives sans score', () {
      final statistics = profile_stats.VolunteerStatistics.fromJson({
        'member_since': '2025-01-15T10:00:00Z',
        'maraudes_completed': 8,
        'volunteering_hours': 21.5,
        'roles': {'team_leader': 2, 'logistics': 3},
        'invitations_obtained': 4,
        'collective_weight_kg': 128.75,
        'collective_meals': 96,
      });

      expect(statistics.maraudesCompleted, 8);
      expect(statistics.volunteeringHours, 21.5);
      expect(statistics.roles['team_leader'], 2);
      expect(statistics.invitationsObtained, 4);
      expect(statistics.collectiveWeightKg, 128.75);
      expect(statistics.collectiveMeals, 96);
    });

    test('conserve les droits historiques des données de section admin', () {
      const section = ConcertVolunteerSectionData(
        counts: ConcertVolunteerCounts.empty(),
        isAdmin: true,
        applications: [],
      );

      expect(section.canManageConcert, isTrue);
      expect(section.canViewApplications, isTrue);
      expect(section.canApply, isFalse);
    });
  });

  testWidgets('affiche la navigation Administrateur sans Opérations', (
    tester,
  ) async {
    await _pumpShell(tester, AppUserRole.admin);

    expect(find.text('Tableau de bord'), findsWidgets);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('Maraudes'), findsOneWidget);
    expect(find.text('Invitations'), findsOneWidget);
    expect(find.text('Organisations'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Consommables'), findsNothing);
    expect(find.text('Parc matériel'), findsNothing);
    expect(find.text('Bénévoles'), findsOneWidget);
    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('Opérations'), findsNothing);
  });

  testWidgets('affiche la navigation dédiée au Tourneur', (tester) async {
    await _pumpShell(tester, AppUserRole.promoter);

    expect(find.text('Tableau de bord'), findsWidgets);
    expect(find.text('TOURNEUR'), findsOneWidget);
    expect(find.text('Mes maraudes'), findsOneWidget);
    expect(find.text('Mes invitations'), findsOneWidget);
    expect(find.text('Mon compte'), findsOneWidget);
    expect(find.text('Organisations'), findsNothing);
    expect(find.text('Stock'), findsNothing);
    expect(find.text('Administration'), findsNothing);
  });

  testWidgets('affiche la navigation personnelle du Bénévole', (tester) async {
    await _pumpShell(tester, AppUserRole.volunteer);

    expect(find.text('Accueil'), findsWidgets);
    expect(find.text('BÉNÉVOLE'), findsOneWidget);
    expect(find.text('Mes maraudes'), findsOneWidget);
    expect(find.text('Invitations'), findsOneWidget);
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Stock'), findsNothing);
    expect(find.text('Administration'), findsNothing);
  });

  testWidgets('valide le mot de passe et le profil à l’activation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentAuthUserProvider.overrideWithValue(null)],
        child: const MaterialApp(home: ActivationScreen()),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('activation-password')),
      'mot-de-passe',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
      'autre-mot-de-passe',
    );
    await tester.tap(find.text('Activer mon compte'));
    await tester.pump();

    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
    expect(find.text('Ce champ est obligatoire.'), findsNWidgets(2));
  });

  testWidgets('valide la confirmation du nouveau mot de passe', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ResetPasswordScreen())),
    );

    await tester.enterText(
      find.byKey(const ValueKey('reset-password-password')),
      'mot-de-passe',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-password-confirmation')),
      'autre-mot-de-passe',
    );
    await tester.tap(find.byKey(const ValueKey('reset-password-submit')));
    await tester.pump();

    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
  });

  testWidgets('rend l’organisation obligatoire pour inviter un Tourneur', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          managedUsersProvider.overrideWith((ref) async => const []),
          organizationsProvider.overrideWith(
            (ref) async => [
              Organization(
                id: 'organization-id',
                name: 'Auguri',
                slug: 'auguri',
                createdAt: DateTime(2026, 7, 27),
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: AdministrationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inviter un utilisateur'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('invite-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tourneur').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('invite-last-name')),
      'Martin',
    );
    await tester.enterText(
      find.byKey(const ValueKey('invite-first-name')),
      'Camille',
    );
    await tester.enterText(
      find.byKey(const ValueKey('invite-email')),
      'camille@example.test',
    );
    await tester.tap(find.text('Envoyer l’invitation'));
    await tester.pump();

    expect(
      find.text('L’organisation est obligatoire pour un tourneur.'),
      findsOneWidget,
    );
  });

  testWidgets('pré-sélectionne l’organisation Tourneur d’après le domaine de '
      'l’adresse e-mail', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          managedUsersProvider.overrideWith((ref) async => const []),
          organizationsProvider.overrideWith(
            (ref) async => [
              Organization(
                id: 'organization-id',
                name: 'Auguri',
                slug: 'auguri',
                createdAt: DateTime(2026, 7, 27),
                emailDomain: 'auguri.fr',
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: AdministrationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inviter un utilisateur'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('invite-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tourneur').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('invite-email')),
      'camille@auguri.fr',
    );
    await tester.pump();

    expect(find.text('Auguri'), findsOneWidget);
    expect(
      find.text('Pré-sélectionnée d’après le domaine de l’adresse e-mail.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('invite-last-name')),
      'Martin',
    );
    await tester.enterText(
      find.byKey(const ValueKey('invite-first-name')),
      'Camille',
    );
    await tester.tap(find.text('Envoyer l’invitation'));
    await tester.pump();

    expect(
      find.text('L’organisation est obligatoire pour un tourneur.'),
      findsNothing,
    );
  });

  testWidgets(
    'réutilise le sélecteur de salles et enregistre son identifiant',
    (tester) async {
      final invitationRepository = _FakeInvitationRepository();
      final venueRepository = _FakeVenueRepository();
      await _pumpInvitations(
        tester,
        role: AppUserRole.promoter,
        campaigns: const [],
        invitationRepository: invitationRepository,
        venueRepository: venueRepository,
      );

      await tester.tap(find.text('Nouvelle campagne'));
      await tester.pumpAndSettle();

      expect(find.byType(VenueSearchField), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('invitation-title-field')),
        'Places Point Éphémère',
      );
      await tester.tap(find.byKey(const ValueKey('invitation-submit-button')));
      await tester.pump();
      expect(find.text('Ce champ est requis.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('invitation-venue-field')),
        'P',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(venueRepository.queries, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('invitation-venue-field')),
        'Po',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(venueRepository.queries, ['Po']);
      expect(find.text('Point Éphémère'), findsOneWidget);
      expect(find.text('200 quai de Valmy, 75010 Paris'), findsOneWidget);

      await tester.tap(find.text('Point Éphémère'));
      await tester.tap(find.byKey(const ValueKey('invitation-submit-button')));
      await tester.pumpAndSettle();

      expect(invitationRepository.createdDraft?.venueId, 'venue-id');
    },
  );

  testWidgets('renseigne la date de l’événement à la création d’une campagne', (
    tester,
  ) async {
    final invitationRepository = _FakeInvitationRepository();
    final venueRepository = _FakeVenueRepository();
    await _pumpInvitations(
      tester,
      role: AppUserRole.promoter,
      campaigns: const [],
      invitationRepository: invitationRepository,
      venueRepository: venueRepository,
    );

    await tester.tap(find.text('Nouvelle campagne'));
    await tester.pumpAndSettle();

    expect(find.text('Date de l’événement'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invitation-event-date-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('invitation-title-field')),
      'Places Point Éphémère',
    );
    await tester.enterText(
      find.byKey(const ValueKey('invitation-venue-field')),
      'Po',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Point Éphémère'));
    await tester.tap(find.byKey(const ValueKey('invitation-submit-button')));
    await tester.pumpAndSettle();

    expect(invitationRepository.createdDraft?.eventDate, isNotNull);
  });

  testWidgets(
    'affiche une campagne dans la vue calendrier grâce à sa date d’événement',
    (tester) async {
      final now = DateTime.now();
      final campaign = InvitationCampaign(
        id: 'campaign-id',
        organizationId: 'organization-id',
        organizationName: 'Auguri',
        venueId: _venue.id,
        venue: _venue,
        title: 'Concert du mois',
        availablePlaces: 2,
        status: InvitationCampaignStatus.open,
        createdBy: 'promoter-id',
        createdAt: DateTime.utc(2026, 7, 28),
        updatedAt: DateTime.utc(2026, 7, 28),
        applicationCount: 0,
        selectedCount: 0,
        attributedPlacesCount: 0,
        eventDate: DateTime(now.year, now.month, 15),
      );
      await _pumpInvitations(
        tester,
        role: AppUserRole.admin,
        campaigns: [campaign],
      );

      await tester.tap(find.text('Calendrier'));
      await tester.pumpAndSettle();

      expect(find.text('Concert du mois'), findsOneWidget);
    },
  );

  testWidgets('affiche la salle aux tourneur et bénévole puis dans la fiche', (
    tester,
  ) async {
    final campaign = _campaign(availablePlaces: 4, selectedCount: 1);
    await _pumpInvitations(
      tester,
      role: AppUserRole.promoter,
      campaigns: [campaign],
    );

    expect(find.text('Point Éphémère'), findsOneWidget);
    expect(find.text('200 quai de Valmy, 75010 Paris'), findsOneWidget);
    expect(find.text('3 places restantes'), findsOneWidget);
    expect(find.text('1 candidature'), findsNothing);
    await tester.tap(find.text('Voir les candidatures'));
    await tester.pumpAndSettle();
    expect(find.text('Point Éphémère'), findsNWidgets(2));
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    await _pumpInvitations(
      tester,
      role: AppUserRole.volunteer,
      campaigns: [campaign],
    );

    expect(find.text('Point Éphémère'), findsOneWidget);
    expect(find.text('Je candidate'), findsOneWidget);
  });

  testWidgets('réserve les invitations aux bénévoles ayant trois crédits', (
    tester,
  ) async {
    await _pumpInvitations(
      tester,
      role: AppUserRole.volunteer,
      campaigns: [_campaign()],
      volunteerCredits: 2,
    );

    expect(find.text('2 / 3 crédits nécessaires'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Je candidate'),
          )
          .onPressed,
      isNull,
    );

    await _pumpInvitations(
      tester,
      role: AppUserRole.volunteer,
      campaigns: [_campaign()],
      volunteerCredits: 3,
    );

    expect(find.text('3 / 3 crédits nécessaires'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Je candidate'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('le bénévole candidate en indiquant un +1', (tester) async {
    final repository = _FakeInvitationRepository();
    await _pumpInvitations(
      tester,
      role: AppUserRole.volunteer,
      campaigns: [_campaign()],
      invitationRepository: repository,
    );

    await tester.tap(find.byKey(const ValueKey('apply-plus-one-checkbox')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('apply-plus-one-name-field')),
      'Camille',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Je candidate'));
    await tester.pumpAndSettle();

    expect(repository.appliedPlusOnes, [true]);
    expect(repository.appliedPlusOneNames, ['Camille']);
  });

  testWidgets(
    'le bénévole modifie son +1 pendant que sa candidature est en attente',
    (tester) async {
      final repository = _FakeInvitationRepository();
      final ownApplication = InvitationApplication(
        id: 'application-id',
        userId: 'volunteer-profile-id',
        status: InvitationApplicationStatus.pending,
        createdAt: DateTime.utc(2026, 7, 28),
        plusOne: true,
        plusOneName: 'Camille',
      );
      await _pumpInvitations(
        tester,
        role: AppUserRole.volunteer,
        campaigns: [_campaign(ownApplication: ownApplication)],
        invitationRepository: repository,
      );

      expect(find.text('Vous venez avec un +1 (Camille).'), findsOneWidget);

      await tester.tap(find.text('Modifier mon +1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Je viens accompagné.e (+1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
      await tester.pumpAndSettle();

      expect(repository.plusOneUpdates, [('application-id', false, 'Camille')]);
    },
  );

  testWidgets('l’administrateur voit l’accompagnant d’un candidat', (
    tester,
  ) async {
    await _pumpInvitations(
      tester,
      role: AppUserRole.admin,
      campaigns: [_campaign()],
      candidates: [
        InvitationCandidate(
          applicationId: 'application-id',
          userId: 'volunteer-id',
          firstName: 'Bénévole',
          lastName: 'TEST',
          status: InvitationApplicationStatus.selected,
          memberSince: DateTime.utc(2026, 7, 27),
          maraudeCount: 0,
          withdrawalCount: 0,
          invitationCount: 1,
          canManage: true,
          plusOne: true,
          plusOneName: 'Camille',
        ),
      ],
    );

    await tester.tap(find.text('Voir les candidatures'));
    await tester.pumpAndSettle();

    expect(find.text('+1 · Camille'), findsOneWidget);
  });

  testWidgets(
    'le bénévole confirme une invitation attribuée avant sa date limite',
    (tester) async {
      final repository = _FakeInvitationRepository();
      final ownApplication = InvitationApplication(
        id: 'application-id',
        userId: 'volunteer-profile-id',
        status: InvitationApplicationStatus.selected,
        createdAt: DateTime.utc(2026, 7, 28),
        confirmationStatus: VolunteerConfirmationStatus.pending,
        confirmationDueAt: DateTime.utc(2026, 8, 5, 12),
      );
      await _pumpInvitations(
        tester,
        role: AppUserRole.volunteer,
        campaigns: [_campaign(ownApplication: ownApplication)],
        invitationRepository: repository,
      );

      expect(find.text('Invitation attribuée.'), findsOneWidget);
      expect(
        find.textContaining('Confirmez votre participation avant le'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('confirm-invitation-button')));
      await tester.pumpAndSettle();

      expect(repository.confirmedApplicationIds, ['application-id']);
    },
  );

  testWidgets(
    'la confirmation d’une invitation rafraîchit le solde de crédits du bénévole',
    (tester) async {
      final repository = _FakeInvitationRepository();
      var creditSummaryFetchCount = 0;
      final ownApplication = InvitationApplication(
        id: 'application-id',
        userId: 'volunteer-profile-id',
        status: InvitationApplicationStatus.selected,
        createdAt: DateTime.utc(2026, 7, 28),
        confirmationStatus: VolunteerConfirmationStatus.pending,
        confirmationDueAt: DateTime.utc(2026, 8, 5, 12),
      );

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserContextProvider.overrideWith(
              (ref) async => const CurrentUserContext(
                profileId: 'volunteer-profile-id',
                role: AppUserRole.volunteer,
                status: UserAccountStatus.active,
              ),
            ),
            invitationCampaignsProvider.overrideWith(
              (ref) async => [_campaign(ownApplication: ownApplication)],
            ),
            invitationRepositoryProvider.overrideWithValue(repository),
            volunteerCreditCountProvider.overrideWith((ref) async => 3),
            volunteerCreditSummaryProvider.overrideWith((ref) async {
              creditSummaryFetchCount += 1;
              return const VolunteerCreditSummary(
                earned: 3,
                consumed: 0,
                available: 3,
              );
            }),
          ],
          child: MaterialApp(
            home: Column(
              children: [
                const Expanded(child: InvitationsScreen()),
                Consumer(
                  builder: (context, ref, _) {
                    ref.watch(volunteerCreditSummaryProvider);
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fetchCountBeforeConfirm = creditSummaryFetchCount;

      await tester.tap(find.byKey(const ValueKey('confirm-invitation-button')));
      await tester.pumpAndSettle();

      expect(repository.confirmedApplicationIds, ['application-id']);
      expect(
        creditSummaryFetchCount,
        greaterThan(fetchCountBeforeConfirm),
        reason:
            'le solde de crédits doit être rechargé après la confirmation '
            'd’une invitation, sinon l’écran affiche un solde périmé',
      );
    },
  );

  testWidgets('une invitation confirmée par le bénévole est affichée validée', (
    tester,
  ) async {
    final ownApplication = InvitationApplication(
      id: 'application-id',
      userId: 'volunteer-profile-id',
      status: InvitationApplicationStatus.selected,
      createdAt: DateTime.utc(2026, 7, 28),
      confirmationStatus: VolunteerConfirmationStatus.confirmed,
      confirmationRespondedAt: DateTime.utc(2026, 8, 1),
    );
    await _pumpInvitations(
      tester,
      role: AppUserRole.volunteer,
      campaigns: [_campaign(ownApplication: ownApplication)],
    );

    expect(find.text('Invitation validée.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('confirm-invitation-button')),
      findsNothing,
    );
  });

  testWidgets(
    'l’administrateur distingue les invitations attribuées en attente et validées',
    (tester) async {
      await _pumpInvitations(
        tester,
        role: AppUserRole.admin,
        campaigns: [_campaign()],
        candidates: [
          InvitationCandidate(
            applicationId: 'application-pending',
            userId: 'volunteer-pending',
            firstName: 'En',
            lastName: 'Attente',
            status: InvitationApplicationStatus.selected,
            memberSince: DateTime.utc(2026, 7, 27),
            maraudeCount: 0,
            withdrawalCount: 0,
            invitationCount: 1,
            canManage: true,
            confirmationStatus: VolunteerConfirmationStatus.pending,
          ),
          InvitationCandidate(
            applicationId: 'application-confirmed',
            userId: 'volunteer-confirmed',
            firstName: 'Validé',
            lastName: 'Bénévole',
            status: InvitationApplicationStatus.selected,
            memberSince: DateTime.utc(2026, 7, 27),
            maraudeCount: 0,
            withdrawalCount: 0,
            invitationCount: 1,
            canManage: true,
            confirmationStatus: VolunteerConfirmationStatus.confirmed,
          ),
        ],
      );

      await tester.tap(find.text('Voir les candidatures'));
      await tester.pumpAndSettle();

      expect(find.text('En attente de confirmation'), findsOneWidget);
      expect(find.text('Invitation validée'), findsOneWidget);
    },
  );

  testWidgets('admin et tourneur peuvent supprimer une campagne confirmée', (
    tester,
  ) async {
    for (final role in [AppUserRole.admin, AppUserRole.promoter]) {
      final repository = _FakeInvitationRepository();
      await _pumpInvitations(
        tester,
        role: role,
        campaigns: [_campaign()],
        invitationRepository: repository,
      );

      await tester.tap(find.text('Supprimer la campagne'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer cette campagne ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(repository.deletedCampaignIds, ['campaign-id']);
      expect(find.text('Campagne supprimée.'), findsOneWidget);
    }
  });

  testWidgets('admin et tourneur peuvent clôturer une campagne ouverte', (
    tester,
  ) async {
    for (final role in [AppUserRole.admin, AppUserRole.promoter]) {
      final repository = _FakeInvitationRepository();
      await _pumpInvitations(
        tester,
        role: role,
        campaigns: [_campaign()],
        invitationRepository: repository,
      );

      await tester.tap(find.text('Clôturer la campagne'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
      await tester.pumpAndSettle();

      expect(repository.updatedCampaignStatuses, [
        InvitationCampaignStatus.closed,
      ]);
    }
  });

  testWidgets(
    'une invitation attribuée propose uniquement un retrait confirmé',
    (tester) async {
      final repository = _FakeInvitationRepository();
      await _pumpInvitations(
        tester,
        role: AppUserRole.admin,
        campaigns: [_campaign()],
        invitationRepository: repository,
        candidates: [
          InvitationCandidate(
            applicationId: 'application-id',
            userId: 'volunteer-id',
            firstName: 'Bénévole',
            lastName: 'TEST',
            status: InvitationApplicationStatus.selected,
            memberSince: DateTime.utc(2026, 7, 27),
            maraudeCount: 0,
            withdrawalCount: 2,
            invitationCount: 1,
            canManage: true,
          ),
        ],
      );

      await tester.tap(find.text('Voir les candidatures'));
      await tester.pumpAndSettle();

      expect(find.text('Retirer l’attribution'), findsOneWidget);
      expect(find.text('Attribuer'), findsNothing);
      expect(find.text('Ne pas attribuer'), findsNothing);
      expect(find.text('0 maraude réalisée'), findsOneWidget);
      expect(find.text('2 désistements'), findsOneWidget);
      expect(find.text('1 invitation obtenue'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('candidates-dialog-content')))
            .height,
        lessThan(600),
      );

      await tester.tap(find.text('Retirer l’attribution'));
      await tester.pumpAndSettle();
      expect(find.text('Retirer l’attribution ?'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Retirer l’attribution'),
      );
      await tester.pumpAndSettle();

      expect(repository.updatedStatuses, [InvitationApplicationStatus.pending]);
    },
  );
}

Future<void> _pumpShell(WidgetTester tester, AppUserRole role) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 800);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserContextProvider.overrideWith(
          (ref) async => CurrentUserContext(
            profileId: 'profile-id',
            role: role,
            status: UserAccountStatus.active,
            organizationId: role == AppUserRole.promoter
                ? 'organization-id'
                : null,
          ),
        ),
        currentProfileProvider.overrideWith((ref) async => null),
        currentAuthUserProvider.overrideWithValue(null),
      ],
      child: const MaterialApp(
        home: AppShell(
          location: '/dashboard',
          child: Center(child: Text('Contenu')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpInvitations(
  WidgetTester tester, {
  required AppUserRole role,
  required List<InvitationCampaign> campaigns,
  InvitationRepository? invitationRepository,
  VenueRepository? venueRepository,
  List<InvitationCandidate> candidates = const [],
  int volunteerCredits = 3,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 900);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserContextProvider.overrideWith(
          (ref) async => CurrentUserContext(
            profileId: '$role-profile-id',
            role: role,
            organizationId: role == AppUserRole.promoter
                ? 'organization-id'
                : null,
            organizationName: role == AppUserRole.promoter ? 'Auguri' : null,
            status: UserAccountStatus.active,
          ),
        ),
        invitationCampaignsProvider.overrideWith((ref) async => campaigns),
        volunteerCreditCountProvider.overrideWith(
          (ref) async => volunteerCredits,
        ),
        invitationCandidatesProvider(
          'campaign-id',
        ).overrideWith((ref) async => candidates),
        if (invitationRepository != null)
          invitationRepositoryProvider.overrideWithValue(invitationRepository),
        if (venueRepository != null)
          venueRepositoryProvider.overrideWithValue(venueRepository),
      ],
      child: const MaterialApp(home: InvitationsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

const _venue = Venue(
  id: 'venue-id',
  name: 'Point Éphémère',
  publicAddressLine1: '200 quai de Valmy',
  postalCode: '75010',
  city: 'Paris',
);

InvitationCampaign _campaign({
  int availablePlaces = 2,
  int selectedCount = 0,
  InvitationApplication? ownApplication,
}) => InvitationCampaign(
  id: 'campaign-id',
  organizationId: 'organization-id',
  organizationName: 'Auguri',
  venueId: _venue.id,
  venue: _venue,
  title: 'Places concert',
  availablePlaces: availablePlaces,
  status: InvitationCampaignStatus.open,
  createdBy: 'promoter-id',
  createdAt: DateTime.utc(2026, 7, 28),
  updatedAt: DateTime.utc(2026, 7, 28),
  applicationCount: 0,
  selectedCount: selectedCount,
  attributedPlacesCount: selectedCount,
  ownApplication: ownApplication,
);

SupabaseClient _testClient() => SupabaseClient(
  'http://localhost',
  'test-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  accessToken: () async => 'test-token',
);

class _FakeVenueRepository extends VenueRepository {
  _FakeVenueRepository() : super(_testClient());

  final queries = <String>[];

  @override
  Future<List<Venue>> searchActiveVenues(String query) async {
    queries.add(query);
    return const [_venue];
  }
}

class _FakeInvitationRepository extends InvitationRepository {
  _FakeInvitationRepository() : super(_testClient());

  InvitationCampaignDraft? createdDraft;
  final updatedStatuses = <InvitationApplicationStatus>[];
  final updatedCampaignStatuses = <InvitationCampaignStatus>[];
  final deletedCampaignIds = <String>[];
  final confirmedApplicationIds = <String>[];
  final appliedPlusOnes = <bool>[];
  final appliedPlusOneNames = <String?>[];
  final plusOneUpdates = <(String, bool, String?)>[];

  @override
  Future<InvitationCampaign> create(InvitationCampaignDraft draft) async {
    createdDraft = draft;
    return _campaign();
  }

  @override
  Future<void> setCandidateStatus(
    String applicationId,
    InvitationApplicationStatus status,
  ) async {
    updatedStatuses.add(status);
  }

  @override
  Future<void> confirm(String applicationId) async {
    confirmedApplicationIds.add(applicationId);
  }

  @override
  Future<void> apply(
    String campaignId, {
    bool plusOne = false,
    String? plusOneName,
  }) async {
    appliedPlusOnes.add(plusOne);
    appliedPlusOneNames.add(plusOneName);
  }

  @override
  Future<void> setPlusOne(
    String applicationId, {
    required bool plusOne,
    String? plusOneName,
  }) async {
    plusOneUpdates.add((applicationId, plusOne, plusOneName));
  }

  @override
  Future<void> setCampaignStatus(
    String campaignId,
    InvitationCampaignStatus status,
  ) async {
    updatedCampaignStatuses.add(status);
  }

  @override
  Future<void> deleteCampaign(String campaignId) async {
    deletedCampaignIds.add(campaignId);
  }
}
