import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/distributions/domain/maraude_distribution.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';

Concert buildConcert({
  String id = 'concert-id',
  String organizationId = 'organization-id',
  String artist = 'Artiste',
  DateTime? date,
  String? time,
  ConcertStatus status = ConcertStatus.planned,
  String? notes,
  String? cateringClosesAt,
  Venue? venue,
  String? promoterOrganizationName,
  String? promoterContactName,
  String? promoterContactPhone,
  String? promoterContactEmail,
  String? cateringContactName,
  String? cateringContactPhone,
  String? cateringContactEmail,
  MaraudeStatus maraudeStatus = MaraudeStatus.open,
  DateTime? actualStartAt,
  DateTime? actualEndAt,
  String? closingComment,
  MaraudeOperationalReport? operationalReport,
  List<MaraudeCollection> collections = const [],
  MaraudeDistribution? distribution,
  int selectedVolunteerCount = 0,
}) {
  return Concert(
    id: id,
    organizationId: organizationId,
    artist: artist,
    date: date ?? DateTime(2026, 9, 15),
    time: time,
    status: status,
    maraudeStatus: maraudeStatus,
    actualStartAt: actualStartAt,
    actualEndAt: actualEndAt,
    closingComment: closingComment,
    operationalReport: operationalReport,
    collections: collections,
    distribution: distribution,
    createdBy: 'profile-id',
    createdAt: DateTime(2026, 7, 25),
    updatedAt: DateTime(2026, 7, 25),
    notes: notes,
    cateringClosesAt: cateringClosesAt,
    venueId: venue?.id,
    venue: venue,
    promoterOrganizationName: promoterOrganizationName,
    promoterContactName: promoterContactName,
    promoterContactPhone: promoterContactPhone,
    promoterContactEmail: promoterContactEmail,
    cateringContactName: cateringContactName,
    cateringContactPhone: cateringContactPhone,
    cateringContactEmail: cateringContactEmail,
    selectedVolunteerCount: selectedVolunteerCount,
  );
}

const testVenue = Venue(
  id: 'venue-id',
  name: 'Salle Pleyel',
  publicAddressLine1: '252 rue du Faubourg Saint-Honoré',
  postalCode: '75008',
  city: 'Paris',
);
