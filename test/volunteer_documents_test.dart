import 'package:club_sandwich/features/dashboard/presentation/dashboard_screen.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/invitations/data/invitation_providers.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/features/profiles/domain/profile.dart';
import 'package:club_sandwich/features/profiles/domain/volunteer_private_profile.dart';
import 'package:club_sandwich/features/profiles/presentation/profile_screen.dart';
import 'package:club_sandwich/features/volunteers/data/volunteer_document_providers.dart';
import 'package:club_sandwich/features/volunteers/data/volunteer_document_repository.dart';
import 'package:club_sandwich/features/volunteers/domain/volunteer_document.dart';
import 'package:club_sandwich/features/volunteers/presentation/volunteer_documents_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('le profil bénévole affiche le statut de ses documents', (
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
          currentProfileProvider.overrideWith(
            (ref) async => Profile(
              id: 'volunteer-id',
              firstName: 'Camille',
              lastName: 'Martin',
              createdAt: DateTime.utc(2025, 1, 15),
            ),
          ),
          currentVolunteerPrivateProfileProvider.overrideWith(
            (ref) async => const VolunteerPrivateProfile(),
          ),
          myVolunteerDocumentsProvider.overrideWith(
            (ref) async => [
              const VolunteerDocument(
                id: 'doc-identity',
                type: VolunteerDocumentType.identity,
                status: VolunteerDocumentStatus.approved,
                storagePath: 'volunteer-id/identity.pdf',
              ),
              const VolunteerDocument(
                id: 'doc-social',
                type: VolunteerDocumentType.socialSecurity,
                status: VolunteerDocumentStatus.rejected,
                storagePath: 'volunteer-id/social.pdf',
                rejectionReason: 'Document illisible',
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pièce d’identité — Validé'), findsOneWidget);
    expect(find.text('Carte de sécurité sociale — Refusé'), findsOneWidget);
    expect(find.text('Document illisible'), findsOneWidget);
  });

  testWidgets(
    'le profil bénévole affiche le contrat en attente de contre-signature',
    (tester) async {
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
            currentProfileProvider.overrideWith(
              (ref) async => Profile(
                id: 'volunteer-id',
                firstName: 'Camille',
                lastName: 'Martin',
                createdAt: DateTime.utc(2025, 1, 15),
              ),
            ),
            currentVolunteerPrivateProfileProvider.overrideWith(
              (ref) async => const VolunteerPrivateProfile(),
            ),
            myVolunteerDocumentsProvider.overrideWith(
              (ref) async => [
                const VolunteerDocument(
                  id: 'doc-contract',
                  type: VolunteerDocumentType.contract,
                  status: VolunteerDocumentStatus.pending,
                  storagePath: 'volunteer-id/contract-signed.pdf',
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Contrat de bénévolat — En attente de contre-signature'),
        find.byType(ListView),
        const Offset(0, -200),
      );

      expect(
        find.text('Contrat de bénévolat — En attente de contre-signature'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'l’administrateur valide un document depuis le panneau du bénévole',
    (tester) async {
      final repository = _FakeVolunteerDocumentRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            volunteerDocumentRepositoryProvider.overrideWithValue(repository),
            volunteerDocumentsProvider('volunteer-id').overrideWith(
              (ref) async => [
                const VolunteerDocument(
                  id: 'doc-identity',
                  type: VolunteerDocumentType.identity,
                  status: VolunteerDocumentStatus.pending,
                  storagePath: 'volunteer-id/identity.pdf',
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VolunteerDocumentsPanel(userId: 'volunteer-id'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Valider'), findsOneWidget);
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(repository.reviewedDocumentIds, ['doc-identity']);
      expect(repository.reviewedStatuses, [VolunteerDocumentStatus.approved]);
    },
  );

  testWidgets(
    'l’administrateur refuse un document avec un motif depuis le panneau',
    (tester) async {
      final repository = _FakeVolunteerDocumentRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            volunteerDocumentRepositoryProvider.overrideWithValue(repository),
            volunteerDocumentsProvider('volunteer-id').overrideWith(
              (ref) async => [
                const VolunteerDocument(
                  id: 'doc-identity',
                  type: VolunteerDocumentType.identity,
                  status: VolunteerDocumentStatus.pending,
                  storagePath: 'volunteer-id/identity.pdf',
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VolunteerDocumentsPanel(userId: 'volunteer-id'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Photo floue');
      await tester.tap(find.widgetWithText(FilledButton, 'Refuser'));
      await tester.pumpAndSettle();

      expect(repository.reviewedDocumentIds, ['doc-identity']);
      expect(repository.reviewedStatuses, [VolunteerDocumentStatus.rejected]);
      expect(repository.reviewedReasons, ['Photo floue']);
    },
  );

  testWidgets(
    'l’administrateur voit le bouton de contre-signature pour un contrat et pas de validation en un clic',
    (tester) async {
      final repository = _FakeVolunteerDocumentRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            volunteerDocumentRepositoryProvider.overrideWithValue(repository),
            volunteerDocumentsProvider('volunteer-id').overrideWith(
              (ref) async => [
                const VolunteerDocument(
                  id: 'doc-contract',
                  type: VolunteerDocumentType.contract,
                  status: VolunteerDocumentStatus.pending,
                  storagePath: 'volunteer-id/contract-signed.pdf',
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VolunteerDocumentsPanel(userId: 'volunteer-id'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Déposer la version contresignée'), findsOneWidget);
      expect(find.text('Valider'), findsNothing);
      expect(find.text('Refuser'), findsOneWidget);

      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Signature manquante');
      await tester.tap(find.widgetWithText(FilledButton, 'Refuser'));
      await tester.pumpAndSettle();

      expect(repository.reviewedDocumentIds, ['doc-contract']);
      expect(repository.reviewedStatuses, [VolunteerDocumentStatus.rejected]);
      expect(repository.reviewedReasons, ['Signature manquante']);
    },
  );

  testWidgets(
    'le dashboard admin liste les documents en attente et permet de les traiter',
    (tester) async {
      final repository = _FakeVolunteerDocumentRepository();
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
            invitationCampaignsProvider.overrideWith((ref) async => []),
            volunteerDocumentRepositoryProvider.overrideWithValue(repository),
            pendingVolunteerDocumentsProvider.overrideWith(
              (ref) async => [
                const PendingVolunteerDocument(
                  id: 'doc-identity',
                  userId: 'volunteer-id',
                  firstName: 'Camille',
                  lastName: 'Martin',
                  type: VolunteerDocumentType.identity,
                  storagePath: 'volunteer-id/identity.pdf',
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Documents en attente'), findsOneWidget);
      expect(find.text('Camille Martin'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);

      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(repository.reviewedDocumentIds, ['doc-identity']);
      expect(repository.reviewedStatuses, [VolunteerDocumentStatus.approved]);
    },
  );
}

class _FakeVolunteerDocumentRepository extends VolunteerDocumentRepository {
  _FakeVolunteerDocumentRepository()
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final reviewedDocumentIds = <String>[];
  final reviewedStatuses = <VolunteerDocumentStatus>[];
  final reviewedReasons = <String?>[];

  @override
  Future<void> reviewDocument({
    required String documentId,
    required VolunteerDocumentStatus status,
    String? rejectionReason,
  }) async {
    reviewedDocumentIds.add(documentId);
    reviewedStatuses.add(status);
    reviewedReasons.add(rejectionReason);
  }

  @override
  Future<String> signedUrl(String storagePath) async =>
      'https://example.test/$storagePath';
}
