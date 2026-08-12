import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/venues/data/venue_repository.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final venueRepositoryProvider = Provider<VenueRepository>(
  (ref) => VenueRepository(ref.watch(supabaseClientProvider)),
);

final venuesProvider = FutureProvider<List<Venue>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(venueRepositoryProvider).fetchAllVenues();
});
