import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/organizations/domain/membership.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:club_sandwich/features/profiles/domain/profile.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const organizationJson = {
    'id': '3bc8ad12-a047-4a80-a3de-abab6791dc35',
    'name': 'Organisation',
    'slug': 'organisation',
    'created_at': '2026-07-24T10:00:00.000Z',
  };

  const profileJson = {
    'id': '2ca333d2-f686-4084-a36e-cde0e811bc12',
    'first_name': 'Prénom',
    'last_name': 'Nom',
    'phone': null,
    'avatar_url': null,
    'created_at': '2026-07-24T10:00:00.000Z',
  };

  const membershipJson = {
    'id': 'ba00539d-f3c5-49aa-9c33-b882516e3c83',
    'organization_id': '3bc8ad12-a047-4a80-a3de-abab6791dc35',
    'profile_id': '2ca333d2-f686-4084-a36e-cde0e811bc12',
    'role': 'coordinator',
    'created_at': '2026-07-24T10:00:00.000Z',
  };

  test('Organization se sérialise depuis et vers JSON', () {
    final organization = Organization.fromJson(organizationJson);

    expect(organization.toJson(), organizationJson);
  });

  test('Profile se sérialise depuis et vers JSON', () {
    final profile = Profile.fromJson(profileJson);

    expect(profile.toJson(), profileJson);
  });

  test('Membership et son rôle se sérialisent depuis et vers JSON', () {
    final membership = Membership.fromJson(membershipJson);

    expect(membership.role, MemberRole.coordinator);
    expect(membership.toJson(), membershipJson);
  });

  test('Concert se sérialise depuis et vers JSON', () {
    const json = {
      'id': '8714fd8c-c080-47e8-849a-1309bbd9950d',
      'organization_id': '3bc8ad12-a047-4a80-a3de-abab6791dc35',
      'title': 'Titre',
      'artist': 'Artiste',
      'tour': null,
      'concert_date': '2026-07-24',
      'concert_time': '20:30:00',
      'status': 'confirmed',
      'maraude_status': 'started',
      'actual_start_at': '2026-07-24T19:12:00.000Z',
      'actual_end_at': null,
      'closing_comment': null,
      'collections': <Map<String, dynamic>>[],
      'distribution': null,
      'notes': null,
      'venue_id': 'eb3127ff-a9af-4968-ac67-cba782488eef',
      'catering_closes_at': '23:00:00',
      'promoter_organization_id': null,
      'promoter_contact_name': null,
      'promoter_contact_phone': null,
      'promoter_contact_email': null,
      'catering_contact_name': null,
      'catering_contact_phone': null,
      'catering_contact_email': null,
      'created_by': '2ca333d2-f686-4084-a36e-cde0e811bc12',
      'created_at': '2026-07-24T10:00:00.000Z',
      'updated_at': '2026-07-24T10:00:00.000Z',
    };

    final concert = Concert.fromJson(json);

    expect(concert.status, ConcertStatus.confirmed);
    expect(concert.maraudeStatus, MaraudeStatus.started);
    expect(concert.actualStartAt, DateTime.utc(2026, 7, 24, 19, 12));
    expect(concert.toJson(), json);
  });

  test('CreateConcertDraft ne sérialise que les champs de publication', () {
    final draft = CreateConcertDraft(
      artist: 'Artiste',
      date: DateTime(2026, 7, 24),
      venueId: 'eb3127ff-a9af-4968-ac67-cba782488eef',
      cateringClosesAt: '23:00:00',
    );

    expect(draft.toJson(), {
      'artist': 'Artiste',
      'concert_date': '2026-07-24',
      'venue_id': 'eb3127ff-a9af-4968-ac67-cba782488eef',
      'catering_closes_at': '23:00:00',
      'notes': null,
    });
    expect(draft.toJson(), isNot(contains('status')));
    expect(draft.toJson(), isNot(contains('title')));
    expect(draft.toJson(), isNot(contains('concert_time')));
  });

  test('Concert lit les noms de salle et de producteur préchargés', () {
    final concert = Concert.fromJson({
      'id': '8714fd8c-c080-47e8-849a-1309bbd9950d',
      'organization_id': '3bc8ad12-a047-4a80-a3de-abab6791dc35',
      'title': null,
      'artist': 'Artiste',
      'tour': null,
      'concert_date': '2026-09-15',
      'concert_time': null,
      'status': 'planned',
      'notes': null,
      'venue_id': 'eb3127ff-a9af-4968-ac67-cba782488eef',
      'catering_closes_at': '22:30:00',
      'promoter_organization_id': 'cb586966-4a95-4730-8431-c8b66e08fb5f',
      'created_by': '2ca333d2-f686-4084-a36e-cde0e811bc12',
      'created_at': '2026-07-24T10:00:00.000Z',
      'updated_at': '2026-07-24T10:00:00.000Z',
      'venue': {
        'id': 'eb3127ff-a9af-4968-ac67-cba782488eef',
        'name': 'Salle Pleyel',
        'public_address_line1': '252 rue du Faubourg Saint-Honoré',
        'public_address_line2': null,
        'postal_code': '75008',
        'city': 'Paris',
      },
      'promoter_organization': {'name': 'Producteur'},
      'promoter_contact_name': 'Camille',
      'promoter_contact_phone': '+33 6 00 00 00 00',
      'promoter_contact_email': 'camille@example.com',
      'catering_contact_name': 'Alex',
      'catering_contact_phone': '+33 6 11 11 11 11',
      'catering_contact_email': 'alex@example.com',
    });

    expect(concert.venueName, 'Salle Pleyel');
    expect(
      concert.venue?.formattedAddress,
      '252 rue du Faubourg Saint-Honoré, 75008 Paris',
    );
    expect(concert.promoterOrganizationName, 'Producteur');
    expect(concert.promoterContactName, 'Camille');
    expect(concert.promoterContactEmail, 'camille@example.com');
    expect(concert.cateringContactName, 'Alex');
    expect(concert.cateringContactPhone, '+33 6 11 11 11 11');
  });

  test('ConcertDraft transforme les contacts vides en NULL', () {
    final draft = ConcertDraft(
      title: 'Titre',
      artist: 'Artiste',
      date: DateTime(2026, 9, 15),
      time: '20:00:00',
      status: ConcertStatus.planned,
      promoterContactName: '   ',
      promoterContactPhone: ' +33 6 00 00 00 00 ',
      cateringContactEmail: '',
    );

    expect(draft.toJson()['promoter_contact_name'], isNull);
    expect(draft.toJson()['promoter_contact_phone'], '+33 6 00 00 00 00');
    expect(draft.toJson()['catering_contact_email'], isNull);
  });

  test('Concert accepte l’absence de tous les champs optionnels', () {
    final concert = Concert.fromJson(const {
      'id': 'concert-id',
      'organization_id': 'organization-id',
      'artist': 'Artiste',
      'concert_date': '2026-09-15',
      'status': 'planned',
      'created_by': 'profile-id',
      'created_at': '2026-07-25T10:00:00.000Z',
      'updated_at': '2026-07-25T10:00:00.000Z',
    });

    expect(concert.title, isNull);
    expect(concert.venue, isNull);
    expect(concert.notes, isNull);
    expect(concert.promoterContactName, isNull);
    expect(concert.cateringContactEmail, isNull);
    expect(concert.maraudeStatus, MaraudeStatus.planned);
    expect(concert.actualStartAt, isNull);
    expect(concert.actualEndAt, isNull);
  });

  test('Concert rejette un JSON privé d’un champ obligatoire', () {
    expect(
      () => Concert.fromJson(const {
        'id': 'concert-id',
        'organization_id': 'organization-id',
      }),
      throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
    );
  });

  test('ConcertStatus rejette une valeur inconnue', () {
    expect(
      () => ConcertStatus.fromJson('unknown'),
      throwsA(isA<FormatException>()),
    );
  });

  test('MaraudeStatus sérialise les trois états et rejette l’inconnu', () {
    expect(MaraudeStatus.planned.label, 'Préparation');
    expect(MaraudeStatus.started.label, 'En cours');
    expect(MaraudeStatus.completed.label, 'Terminée');
    expect(
      () => MaraudeStatus.fromJson('cancelled'),
      throwsA(isA<FormatException>()),
    );
  });

  test('Venue expose son adresse publique complète', () {
    final venue = Venue.fromJson(const {
      'id': 'eb3127ff-a9af-4968-ac67-cba782488eef',
      'name': 'Salle',
      'public_address_line1': '1 rue de Paris',
      'public_address_line2': null,
      'postal_code': '75001',
      'city': 'Paris',
    });

    expect(venue.formattedAddress, '1 rue de Paris, 75001 Paris');
  });
}
