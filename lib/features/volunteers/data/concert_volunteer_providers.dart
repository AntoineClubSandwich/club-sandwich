import 'package:club_sandwich/core/supabase/realtime_invalidation.dart';
import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_repository.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final concertVolunteerRepositoryProvider = Provider<ConcertVolunteerRepository>(
  (ref) => ConcertVolunteerRepository(ref.watch(supabaseClientProvider)),
);

List<RealtimeWatch> _concertTeamWatches(String concertId) => [
  RealtimeWatch(
    'concert_volunteers',
    filterColumn: 'concert_id',
    filterValue: concertId,
  ),
  RealtimeWatch(
    'concert_volunteer_events',
    filterColumn: 'concert_id',
    filterValue: concertId,
  ),
];

final concertVolunteerSectionProvider =
    FutureProvider.family<ConcertVolunteerSectionData, String>((
      ref,
      concertId,
    ) {
      ref.watch(authStateProvider);
      final repository = ref.watch(concertVolunteerRepositoryProvider);
      watchRealtimeInvalidation(
        ref: ref,
        client: repository.client,
        channelName: 'concert-team-section-$concertId',
        watches: _concertTeamWatches(concertId),
      );
      return repository.fetchSection(concertId);
    });

final maraudeAttendanceProvider =
    FutureProvider.family<MaraudeAttendanceData, String>((ref, concertId) {
      ref.watch(authStateProvider);
      final repository = ref.watch(concertVolunteerRepositoryProvider);
      watchRealtimeInvalidation(
        ref: ref,
        client: repository.client,
        channelName: 'concert-team-attendance-$concertId',
        watches: _concertTeamWatches(concertId),
      );
      return repository.fetchAttendance(concertId);
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
      final repository = ref.watch(concertVolunteerRepositoryProvider);
      watchRealtimeInvalidation(
        ref: ref,
        client: repository.client,
        channelName: 'concert-team-roster-$concertId',
        watches: _concertTeamWatches(concertId),
      );
      return repository.fetchRoster(concertId);
    });
