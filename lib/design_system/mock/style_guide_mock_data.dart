import '../components/indicators/ds_status_chip.dart';

/// Sample data for the domain showcase cards (`DsMaraudeCard`,
/// `DsInvitationCard`, `DsVolunteerCard`, `DsOrganisationCard`) and the
/// `/style-guide` screen. Entirely fictional — never touches Supabase,
/// a provider, or any real Club Sandwich data.
class DsMaraudeCardData {
  const DsMaraudeCardData({
    required this.title,
    required this.dateLabel,
    required this.venue,
    required this.volunteersRegistered,
    required this.volunteersRequired,
    required this.status,
  });

  final String title;
  final String dateLabel;
  final String venue;
  final int volunteersRegistered;
  final int volunteersRequired;
  final DsChipStatus status;
}

class DsInvitationCardData {
  const DsInvitationCardData({
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });

  final String name;
  final String email;
  final String role;
  final DsChipStatus status;
}

class DsVolunteerCardData {
  const DsVolunteerCardData({
    required this.name,
    required this.initials,
    required this.maraudesCompleted,
    this.reliabilityLabel,
  });

  final String name;
  final String initials;
  final int maraudesCompleted;
  final String? reliabilityLabel;
}

class DsOrganisationCardData {
  const DsOrganisationCardData({
    required this.name,
    required this.initials,
    required this.memberCount,
    required this.city,
  });

  final String name;
  final String initials;
  final int memberCount;
  final String city;
}

const List<DsMaraudeCardData> dsMockMaraudes = [
  DsMaraudeCardData(
    title: 'Accor Arena — Fatal Bazooka',
    dateLabel: '27 août 2026 · 19:30',
    venue: 'Accor Arena, Paris',
    volunteersRegistered: 3,
    volunteersRequired: 5,
    status: DsChipStatus.active,
  ),
  DsMaraudeCardData(
    title: 'Élysée Montmartre — zefe',
    dateLabel: '27 août 2026 · 20:10',
    venue: 'Élysée Montmartre, Paris',
    volunteersRegistered: 5,
    volunteersRequired: 5,
    status: DsChipStatus.completed,
  ),
  DsMaraudeCardData(
    title: 'Le Bataclan — Structures',
    dateLabel: '3 septembre 2026 · 21:00',
    venue: 'Le Bataclan, Paris',
    volunteersRegistered: 1,
    volunteersRequired: 4,
    status: DsChipStatus.draft,
  ),
];

const List<DsInvitationCardData> dsMockInvitations = [
  DsInvitationCardData(
    name: 'Camille Rousseau',
    email: 'camille.rousseau@example.org',
    role: 'Bénévole',
    status: DsChipStatus.pending,
  ),
  DsInvitationCardData(
    name: 'Yanis Belkacem',
    email: 'yanis.belkacem@example.org',
    role: 'Chef d\'équipe',
    status: DsChipStatus.completed,
  ),
  DsInvitationCardData(
    name: 'Inès Fontaine',
    email: 'ines.fontaine@example.org',
    role: 'Bénévole',
    status: DsChipStatus.cancelled,
  ),
];

const List<DsVolunteerCardData> dsMockVolunteers = [
  DsVolunteerCardData(
    name: 'Sacha Lemoine',
    initials: 'SL',
    maraudesCompleted: 14,
    reliabilityLabel: 'Fiable',
  ),
  DsVolunteerCardData(
    name: 'Nour Haddad',
    initials: 'NH',
    maraudesCompleted: 3,
  ),
];

const List<DsOrganisationCardData> dsMockOrganisations = [
  DsOrganisationCardData(
    name: 'Studio Nomade Prod',
    initials: 'SN',
    memberCount: 6,
    city: 'Paris',
  ),
  DsOrganisationCardData(
    name: 'Bleu Nuit Events',
    initials: 'BN',
    memberCount: 3,
    city: 'Lyon',
  ),
];
