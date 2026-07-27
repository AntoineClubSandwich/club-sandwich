import 'package:club_sandwich/features/administration/presentation/administration_screen.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/auth/presentation/activation_screen.dart';
import 'package:club_sandwich/features/invitations/domain/invitation_campaign.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/features/profiles/domain/volunteer_statistics.dart'
    as profile_stats;
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/shared/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
        'title': 'Places concert',
        'available_places': 2,
        'status': 'open',
        'created_by': 'promoter-id',
        'created_at': '2026-07-27T10:00:00Z',
        'updated_at': '2026-07-27T10:00:00Z',
        'application_count': 3,
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
      expect(campaign.applicationCount, 3);
      expect(campaign.selectedCount, 1);
      expect(
        campaign.ownApplication?.status,
        InvitationApplicationStatus.pending,
      );
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
    expect(find.text('Maraudes'), findsOneWidget);
    expect(find.text('Invitations'), findsOneWidget);
    expect(find.text('Organisations'), findsOneWidget);
    expect(find.text('Bénévoles'), findsOneWidget);
    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('Opérations'), findsNothing);
  });

  testWidgets('affiche la navigation dédiée au Tourneur', (tester) async {
    await _pumpShell(tester, AppUserRole.promoter);

    expect(find.text('Tableau de bord'), findsWidgets);
    expect(find.text('Mes maraudes'), findsOneWidget);
    expect(find.text('Mes invitations'), findsOneWidget);
    expect(find.text('Mon compte'), findsOneWidget);
    expect(find.text('Organisations'), findsNothing);
    expect(find.text('Administration'), findsNothing);
  });

  testWidgets('affiche la navigation personnelle du Bénévole', (tester) async {
    await _pumpShell(tester, AppUserRole.volunteer);

    expect(find.text('Accueil'), findsWidgets);
    expect(find.text('Mes maraudes'), findsOneWidget);
    expect(find.text('Invitations'), findsOneWidget);
    expect(find.text('Mon profil'), findsOneWidget);
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
