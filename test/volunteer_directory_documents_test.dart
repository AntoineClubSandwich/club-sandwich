import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/volunteers/data/volunteer_document_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/volunteer_document.dart';
import 'package:club_sandwich/features/volunteers/presentation/volunteers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'l’administrateur ouvre les documents d’un bénévole depuis l’annuaire',
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
            managedUsersProvider.overrideWith(
              (ref) async => [
                ManagedUser(
                  profileId: 'volunteer-id',
                  firstName: 'Camille',
                  lastName: 'Martin',
                  email: 'camille@example.com',
                  role: AppUserRole.volunteer,
                  status: UserAccountStatus.active,
                  invitedAt: DateTime.utc(2026, 1, 1),
                ),
              ],
            ),
            volunteerDocumentsProvider('volunteer-id').overrideWith(
              (ref) async => [
                const VolunteerDocument(
                  id: 'doc-identity',
                  type: VolunteerDocumentType.identity,
                  status: VolunteerDocumentStatus.approved,
                  storagePath: 'volunteer-id/identity.pdf',
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: VolunteersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Documents'), findsOneWidget);
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      expect(find.text('Documents - Camille Martin'), findsOneWidget);
      expect(find.text('Pièce d’identité'), findsOneWidget);
      expect(find.text('Validé'), findsOneWidget);
    },
  );
}
