import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_repository.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final concertVolunteerRepositoryProvider = Provider<ConcertVolunteerRepository>(
  (ref) => ConcertVolunteerRepository(ref.watch(supabaseClientProvider)),
);

final concertVolunteerSectionProvider =
    FutureProvider.family<ConcertVolunteerSectionData, String>(
      (ref, concertId) =>
          ref.watch(concertVolunteerRepositoryProvider).fetchSection(concertId),
    );
