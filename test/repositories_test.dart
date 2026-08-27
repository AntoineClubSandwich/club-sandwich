import 'dart:convert';

import 'package:club_sandwich/features/concerts/data/concert_repository.dart';
import 'package:club_sandwich/features/invitations/data/invitation_repository.dart';
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
    'InvitationRepository précharge la salle avec chaque campagne',
    () async {
      late Request capturedRequest;
      final client = SupabaseClient(
        'http://localhost',
        'test-key',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/get_invitation_campaign_counts')) {
            return Response(
              jsonEncode([
                {
                  'campaign_id': 'campaign-id',
                  'application_count': 2,
                  'pending_count': 1,
                  'selected_count': 1,
                  'attributed_places_count': 1,
                  'awaiting_confirmation_count': 0,
                },
              ]),
              200,
              headers: jsonHeaders,
              request: request,
            );
          }
          capturedRequest = request;
          return Response(
            jsonEncode([
              {
                'id': 'campaign-id',
                'organization_id': 'organization-id',
                'organization': {'name': 'Auguri'},
                'venue_id': 'venue-id',
                'venue': {
                  'id': 'venue-id',
                  'name': 'Point Éphémère',
                  'public_address_line1': '200 quai de Valmy',
                  'public_address_line2': null,
                  'postal_code': '75010',
                  'city': 'Paris',
                },
                'title': 'Places concert',
                'available_places': 2,
                'status': 'open',
                'created_by': 'promoter-id',
                'created_at': '2026-07-28T10:00:00Z',
                'updated_at': '2026-07-28T10:00:00Z',
                'applications': [
                  {
                    'id': 'pending-id',
                    'user_id': 'volunteer-id',
                    'status': 'pending',
                    'created_at': '2026-07-28T11:00:00Z',
                  },
                  {
                    'id': 'selected-id',
                    'user_id': 'other-volunteer-id',
                    'status': 'selected',
                    'created_at': '2026-07-28T12:00:00Z',
                  },
                ],
              },
            ]),
            200,
            headers: jsonHeaders,
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);

      final campaigns = await InvitationRepository(client).fetchCampaigns();

      expect(campaigns.single.venue?.name, 'Point Éphémère');
      expect(campaigns.single.applicationCount, 2);
      expect(campaigns.single.pendingCount, 1);
      expect(campaigns.single.selectedCount, 1);
      expect(
        capturedRequest.url.queryParameters['select'],
        contains('venue:venues!invitation_campaigns_venue_id_fkey'),
      );
    },
  );

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

  test('ConcertRepository utilise la suppression transactionnelle', () async {
    late Request capturedRequest;
    final client = clientFor((request) async {
      capturedRequest = request;
      return Response('null', 200, headers: jsonHeaders, request: request);
    });
    addTearDown(client.dispose);

    await ConcertRepository(client).deleteConcert('concert-id');

    expect(capturedRequest.url.path, endsWith('/rpc/delete_concert'));
    expect(jsonDecode(capturedRequest.body), {
      'requested_concert_id': 'concert-id',
    });
  });
}
