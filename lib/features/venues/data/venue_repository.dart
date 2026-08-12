import 'dart:typed_data';

import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _venueSelect =
    'id, name, public_address_line1, public_address_line2, '
    'postal_code, city, photo_url, '
    'access_details:venue_access_details('
    'artist_entrance_address_line1, artist_entrance_address_line2, '
    'artist_entrance_postal_code, artist_entrance_city, '
    'access_instructions'
    ')';

class VenueRepository {
  const VenueRepository(this._client);

  final SupabaseClient _client;

  Future<List<Venue>> searchActiveVenues(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) return const [];

    final rows = await _client
        .from('venues')
        .select(_venueSelect)
        .eq('is_active', true)
        .ilike('name', '%$normalizedQuery%')
        .order('name')
        .limit(10);

    return rows.map(Venue.fromJson).toList(growable: false);
  }

  /// Every venue visible to the current user (admins see inactive ones
  /// too, per the `venues` RLS policy) — backs the Salles admin screen.
  Future<List<Venue>> fetchAllVenues() async {
    final rows = await _client.from('venues').select(_venueSelect).order('name');
    return rows.map(Venue.fromJson).toList(growable: false);
  }

  /// Uploads to a path fixed per venue (`<venueId>/photo.<extension>`) so
  /// re-uploading overwrites the previous photo instead of littering the
  /// bucket with orphaned blobs, then stores the resulting public URL —
  /// `venue-photos` is a public bucket (see its migration), so this is a
  /// cheap local string build, not a network round trip like the signed
  /// URLs used for private buckets elsewhere in the app.
  Future<String> uploadVenuePhoto({
    required String venueId,
    required String extension,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final path = '$venueId/photo.$extension';
    await _client.storage
        .from('venue-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    // A fixed path means re-uploads keep the same base URL, which HTTP/
    // image caches would treat as unchanged — the query param busts that
    // so replacing a photo doesn't keep showing the old one.
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final photoUrl =
        '${_client.storage.from('venue-photos').getPublicUrl(path)}?v=$timestamp';
    await _client.from('venues').update({'photo_url': photoUrl}).eq(
      'id',
      venueId,
    );
    return photoUrl;
  }
}
