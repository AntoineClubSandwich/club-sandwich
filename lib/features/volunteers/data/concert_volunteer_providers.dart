import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_repository.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final concertVolunteerRepositoryProvider = Provider<ConcertVolunteerRepository>(
  (ref) => ConcertVolunteerRepository(ref.watch(supabaseClientProvider)),
);

final concertVolunteerSectionProvider =
    FutureProvider.family<ConcertVolunteerSectionData, String>((
      ref,
      concertId,
    ) {
      ref.watch(authStateProvider);
      return ref
          .watch(concertVolunteerRepositoryProvider)
          .fetchSection(concertId);
    });

final maraudeAttendanceProvider =
    FutureProvider.family<MaraudeAttendanceData, String>((ref, concertId) {
      ref.watch(authStateProvider);
      return ref
          .watch(concertVolunteerRepositoryProvider)
          .fetchAttendance(concertId);
    });

final volunteerCreditCountProvider = FutureProvider<int>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(concertVolunteerRepositoryProvider).fetchCreditCount();
});

final volunteerCreditSummaryProvider = FutureProvider<VolunteerCreditSummary>((
  ref,
) {
  ref.watch(authStateProvider);
  return ref.watch(concertVolunteerRepositoryProvider).fetchCreditSummary();
});

final concertVolunteerRosterProvider =
    FutureProvider.family<List<ConcertVolunteerRosterEntry>, String>((
      ref,
      concertId,
    ) {
      ref.watch(authStateProvider);
      return ref
          .watch(concertVolunteerRepositoryProvider)
          .fetchRoster(concertId);
    });
