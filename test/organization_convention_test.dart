import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/organizations/data/organization_convention_providers.dart';
import 'package:club_sandwich/features/organizations/data/organization_convention_repository.dart';
import 'package:club_sandwich/features/organizations/domain/organization_convention.dart';
import 'package:club_sandwich/features/organizations/presentation/organization_convention_panel.dart';
import 'package:club_sandwich/features/volunteers/domain/volunteer_document.dart'
    show VolunteerDocumentStatus;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('le tourneur voit sa convention en attente de contre-signature', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserContextProvider.overrideWith(
            (ref) async => const CurrentUserContext(
              profileId: 'promoter-id',
              role: AppUserRole.promoter,
              status: UserAccountStatus.active,
              organizationId: 'organization-id',
            ),
          ),
          organizationConventionProvider('organization-id').overrideWith(
            (ref) async => const OrganizationConvention(
              status: VolunteerDocumentStatus.pending,
              storagePath: 'organization-id/convention.pdf',
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: OrganizationConventionPanel(
              organizationId: 'organization-id',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Convention de partenariat — En attente de contre-signature'),
      findsOneWidget,
    );
  });

  testWidgets(
    'l’administrateur voit le bouton de contre-signature et peut refuser la convention',
    (tester) async {
      final repository = _FakeOrganizationConventionRepository();
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
            organizationConventionRepositoryProvider.overrideWithValue(
              repository,
            ),
            organizationConventionProvider('organization-id').overrideWith(
              (ref) async => const OrganizationConvention(
                status: VolunteerDocumentStatus.pending,
                storagePath: 'organization-id/convention.pdf',
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OrganizationConventionPanel(
                organizationId: 'organization-id',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Déposer la version contresignée'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);

      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Signature manquante');
      await tester.tap(find.widgetWithText(FilledButton, 'Refuser'));
      await tester.pumpAndSettle();

      expect(repository.rejectedOrganizationIds, ['organization-id']);
      expect(repository.rejectedReasons, ['Signature manquante']);
    },
  );

  testWidgets('l’administrateur voit la convention comme non fournie', (
    tester,
  ) async {
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
          organizationConventionProvider(
            'organization-id',
          ).overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: OrganizationConventionPanel(
              organizationId: 'organization-id',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Non fourni'), findsOneWidget);
    expect(find.text('Refuser'), findsNothing);
  });
}

class _FakeOrganizationConventionRepository
    extends OrganizationConventionRepository {
  _FakeOrganizationConventionRepository()
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final rejectedOrganizationIds = <String>[];
  final rejectedReasons = <String>[];

  @override
  Future<void> reject({
    required String organizationId,
    required String rejectionReason,
  }) async {
    rejectedOrganizationIds.add(organizationId);
    rejectedReasons.add(rejectionReason);
  }
}
