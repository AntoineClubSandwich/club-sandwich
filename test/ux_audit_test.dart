import 'package:club_sandwich/core/config/environment.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/presentation/login_screen.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_detail_screen.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_form.dart';
import 'package:club_sandwich/features/dashboard/presentation/dashboard_screen.dart';
import 'package:club_sandwich/features/distributions/presentation/maraude_distribution_form_dialog.dart';
import 'package:club_sandwich/features/invitations/data/invitation_providers.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/shared/widgets/app_shell.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:club_sandwich/shared/widgets/environment_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_data.dart';

void main() {
  testWidgets('les états communs restent explicites et accessibles', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppErrorState(
            message: 'Impossible de charger les données.',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Chargement impossible'), findsOneWidget);
    expect(find.text('Impossible de charger les données.'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(retried, isTrue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppLoadingState(label: 'Chargement des maraudes')),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Chargement des maraudes'), findsOneWidget);
  });

  testWidgets(
    'le dashboard signale une indisponibilité partielle sans masquer le reste',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            maraudeOverviewProvider.overrideWith((ref) async => const []),
            invitationCampaignsProvider.overrideWith(
              (ref) => Future.error(StateError('Erreur simulée')),
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Les invitations sont temporairement indisponibles.'),
        findsOneWidget,
      );
      expect(find.text('Aucune action en attente.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    },
  );

  testWidgets('la connexion valide le format de l’adresse e-mail', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 640));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: DsTheme.light, home: const LoginScreen()),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Adresse e-mail'),
      'adresse-invalide',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'mot-de-passe',
    );
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le shell reste lisible sur mobile et desktop', (tester) async {
    await _setViewport(tester, const Size(320, 640));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => null),
          currentAuthUserProvider.overrideWithValue(null),
          maraudeOverviewProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: DsTheme.light,
          home: const AppShell(
            location: '/dashboard',
            child: DashboardScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accueil'), findsWidgets);
    expect(find.byKey(AppShell.desktopSidebarKey), findsNothing);
    expect(tester.takeException(), isNull);

    await _setViewport(tester, const Size(1280, 800));
    await tester.pumpAndSettle();

    expect(find.byKey(AppShell.desktopSidebarKey), findsOneWidget);
    expect(find.text('Accueil'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('APP_ENV accepte uniquement preprod et replie sinon en production', () {
    const compiledAppEnv = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'production',
    );
    expect(
      Environment.appEnvironment,
      Environment.resolveAppEnvironment(compiledAppEnv),
    );
    expect(Environment.resolveAppEnvironment(null), AppEnvironment.production);
    expect(Environment.resolveAppEnvironment(''), AppEnvironment.production);
    expect(
      Environment.resolveAppEnvironment('PREPROD'),
      AppEnvironment.production,
    );
    expect(
      Environment.resolveAppEnvironment('preprod '),
      AppEnvironment.production,
    );
    expect(
      Environment.resolveAppEnvironment('staging'),
      AppEnvironment.production,
    );
    expect(
      Environment.resolveAppEnvironment('preprod'),
      AppEnvironment.preprod,
    );
  });

  testWidgets('la bannière apparaît uniquement en préproduction', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 640));
    await tester.pumpWidget(
      const MaterialApp(
        home: AppEnvironmentBanner(
          environment: AppEnvironment.production,
          child: Scaffold(body: Text('Contenu')),
        ),
      ),
    );

    expect(find.text('PRÉPRODUCTION'), findsNothing);
    expect(find.text('Contenu'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: DsTheme.light,
        home: const AppEnvironmentBanner(
          environment: AppEnvironment.preprod,
          child: Scaffold(body: Text('Contenu')),
        ),
      ),
    );

    expect(find.textContaining('PRÉPRODUCTION'), findsOneWidget);
    expect(
      find.textContaining('Les données peuvent être réinitialisées'),
      findsOneWidget,
    );
    expect(find.text('Contenu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la fiche concert terminée ne déborde pas sur mobile', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 640));
    final concert = buildConcert(
      maraudeStatus: MaraudeStatus.completed,
      actualStartAt: DateTime(2026, 7, 27, 21, 12),
      actualEndAt: DateTime(2026, 7, 27, 23, 5),
      venue: testVenue,
      closingComment: 'Maraude terminée sans incident.',
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
              isAdmin: true,
              applications: [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: DsTheme.light,
          home: const ConcertDetailScreen(concertId: 'concert-id'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bilan'), findsWidgets);
    final operations = find.byKey(
      const ValueKey('maraude-workspace-operations'),
    );
    await tester.ensureVisible(operations);
    await tester.tap(operations);
    await tester.pumpAndSettle();
    expect(
      find.text('L’état est archivé et ne peut plus être modifié.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('les dialogues métier restent utilisables sur mobile', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 640));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: DsTheme.light,
          home: Scaffold(
            body: MaraudeDistributionFormDialog(onSubmit: (draft) async {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ajouter la distribution'), findsWidgets);
    expect(find.text('Lieu de distribution'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: DsTheme.light,
          home: Scaffold(body: ConcertForm(onSubmit: (_) async {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle maraude'), findsOneWidget);
    expect(find.text('Artiste'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}
