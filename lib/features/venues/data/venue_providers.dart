import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/venues/data/venue_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final venueRepositoryProvider = Provider<VenueRepository>(
  (ref) => VenueRepository(ref.watch(supabaseClientProvider)),
);
