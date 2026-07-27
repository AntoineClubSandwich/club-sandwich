import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VenueRepository {
  const VenueRepository(this._client);

  final SupabaseClient _client;

  Future<List<Venue>> searchActiveVenues(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) return const [];

    final rows = await _client
        .from('venues')
        .select(
          'id, name, public_address_line1, public_address_line2, '
          'postal_code, city, '
          'access_details:venue_access_details('
          'artist_entrance_address_line1, artist_entrance_address_line2, '
          'artist_entrance_postal_code, artist_entrance_city, '
          'access_instructions'
          ')',
        )
        .eq('is_active', true)
        .ilike('name', '%$normalizedQuery%')
        .order('name')
        .limit(10);

    return rows.map(Venue.fromJson).toList(growable: false);
  }
}
