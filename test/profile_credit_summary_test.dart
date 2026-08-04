import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/features/profiles/domain/profile.dart';
import 'package:club_sandwich/features/profiles/domain/volunteer_private_profile.dart';
import 'package:club_sandwich/features/profiles/domain/volunteer_statistics.dart';
import 'package:club_sandwich/features/profiles/presentation/profile_screen.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/data/volunteer_document_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart'
    show VolunteerCreditSummary;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'le profil bénévole affiche les crédits gagnés, consommés et disponibles',
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
            volunteerStatisticsProvider.overrideWith(
              (ref) async => VolunteerStatistics(
                memberSince: DateTime.utc(2025, 1, 15),
                maraudesCompleted: 8,
                volunteeringHours: 21.5,
                roles: const {},
                invitationsObtained: 4,
                collectiveWeightKg: 128.75,
                collectiveMeals: 96,
              ),
            ),
            volunteerCreditSummaryProvider.overrideWith(
              (ref) async => const VolunteerCreditSummary(
                earned: 5,
                consumed: 3,
                available: 2,
              ),
            ),
            currentVolunteerPrivateProfileProvider.overrideWith(
              (ref) async => const VolunteerPrivateProfile(),
            ),
            myVolunteerDocumentsProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Mes crédits d’invitation'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mes crédits d’invitation'), findsOneWidget);
      expect(find.text('Crédits disponibles'), findsOneWidget);
      expect(find.text('Crédits gagnés'), findsOneWidget);
      expect(find.text('Crédits consommés'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    },
  );
}
