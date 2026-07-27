import 'dart:convert';

import 'package:club_sandwich/features/concerts/data/concert_repository.dart';
import 'package:club_sandwich/features/organizations/data/organization_repository.dart';
import 'package:club_sandwich/features/venues/data/venue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  SupabaseClient clientFor(Future<Response> Function(Request request) handler) {
    return SupabaseClient(
      'http://localhost',
      'test-key',
      httpClient: MockClient(handler),
      accessToken: () async => 'test-token',
    );
  }

  const jsonHeaders = {'content-type': 'application/json'};

  test('OrganizationRepository renvoie les organisations reçues', () async {
    final client = clientFor(
      (request) async => Response(
        jsonEncode([
          {
            'id': 'organization-id',
            'name': 'Club Sandwich',
            'slug': 'club-sandwich',
            'created_at': '2026-07-25T10:00:00.000Z',
          },
        ]),
        200,
        headers: jsonHeaders,
        request: request,
      ),
    );
    addTearDown(client.dispose);

    final organizations = await OrganizationRepository(
      client,
    ).fetchOrganizations();

    expect(organizations, hasLength(1));
    expect(organizations.single.slug, 'club-sandwich');
  });

  test('OrganizationRepository renvoie null sans résultat', () async {
    final client = clientFor((request) async {
      return Response('[]', 200, headers: jsonHeaders, request: request);
    });
    addTearDown(client.dispose);

    final organization = await OrganizationRepository(
      client,
    ).fetchOrganization('missing');

    expect(organization, isNull);
  });

  test('OrganizationRepository propage une erreur Supabase', () async {
    final client = clientFor(
      (request) async => Response(
        jsonEncode({
          'code': 'XX000',
          'message': 'Erreur simulée',
          'details': null,
          'hint': null,
        }),
        500,
        headers: jsonHeaders,
        request: request,
      ),
    );
    addTearDown(client.dispose);

    expect(
      OrganizationRepository(client).fetchOrganizations(),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'VenueRepository recherche les salles actives avec une limite',
    () async {
      late Request capturedRequest;
      final client = clientFor((request) async {
        capturedRequest = request;
        return Response(
          jsonEncode([
            {
              'id': 'venue-id',
              'name': 'Salle Pleyel',
              'public_address_line1': '252 rue du Faubourg Saint-Honoré',
              'public_address_line2': null,
              'postal_code': '75008',
              'city': 'Paris',
            },
          ]),
          200,
          headers: jsonHeaders,
          request: request,
        );
      });
      addTearDown(client.dispose);

      final venues = await VenueRepository(client).searchActiveVenues('Pleyel');

      expect(venues.single.name, 'Salle Pleyel');
      expect(capturedRequest.url.queryParameters['limit'], '10');
      expect(capturedRequest.url.queryParameters['is_active'], 'eq.true');
      expect(capturedRequest.url.queryParameters['name'], 'ilike.%Pleyel%');
    },
  );

  test('VenueRepository ne lance aucune requête avant 2 caractères', () async {
    var requestCount = 0;
    final client = clientFor((request) async {
      requestCount++;
      return Response('[]', 200, headers: jsonHeaders, request: request);
    });
    addTearDown(client.dispose);

    final venues = await VenueRepository(client).searchActiveVenues('P');

    expect(venues, isEmpty);
    expect(requestCount, 0);
  });

  test(
    'ConcertRepository appelle les RPC transactionnelles de maraude',
    () async {
      final requests = <Request>[];
      final client = clientFor((request) async {
        requests.add(request);
        return Response('null', 200, headers: jsonHeaders, request: request);
      });
      addTearDown(client.dispose);
      final repository = ConcertRepository(client);

      await repository.startMaraude('concert-id');
      await repository.completeMaraude('concert-id');

      expect(requests[0].url.path, endsWith('/rpc/start_maraude'));
      expect(requests[1].url.path, endsWith('/rpc/complete_maraude'));
      expect(jsonDecode(requests[0].body), {
        'requested_concert_id': 'concert-id',
      });
      expect(jsonDecode(requests[1].body), {
        'requested_concert_id': 'concert-id',
      });
    },
  );
}
