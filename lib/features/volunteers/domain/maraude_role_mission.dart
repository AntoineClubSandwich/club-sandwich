import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';

class MaraudeRoleMission {
  const MaraudeRoleMission({
    required this.responsibilities,
    required this.checklist,
    required this.bestPractices,
    required this.objectives,
  });

  final List<String> responsibilities;
  final List<String> checklist;
  final List<String> bestPractices;
  final List<String> objectives;
}

const Map<MaraudeRole, MaraudeRoleMission> maraudeRoleMissions = {
  MaraudeRole.teamLeader: MaraudeRoleMission(
    responsibilities: [
      'Être le point de contact unique de l’équipe pendant toute la maraude.',
      'Coordonner les autres membres et s’assurer que chacun connaît son rôle.',
      'Superviser le bon déroulement de la récolte, de la distribution et de la communication.',
      'Transmettre le compte-rendu final de la maraude.',
    ],
    checklist: [
      'Vérifier que l’équipe est au complet avant le départ.',
      'S’assurer que chaque membre a confirmé sa participation et pris connaissance de sa fiche de mission.',
      'Superviser l’enregistrement des récoltes et des distributions dans l’application.',
      'Renseigner le compte-rendu opérationnel à la fin de la maraude.',
      'Signaler tout incident à l’équipe organisatrice.',
    ],
    bestPractices: [
      'Rester joignable pour l’équipe et pour les organisateurs pendant toute la maraude.',
      'Reformuler les consignes en cas de doute pour éviter les malentendus.',
      'Privilégier le dialogue en cas de désaccord ou d’imprévu sur le terrain.',
    ],
    objectives: [
      'Une équipe coordonnée et informée.',
      'Une récolte et une distribution correctement tracées dans l’application.',
      'Un compte-rendu complet transmis sans délai.',
    ],
  ),
  MaraudeRole.communication: MaraudeRoleMission(
    responsibilities: [
      'Documenter le déroulement de la maraude en images.',
      'Alimenter la galerie photo de la maraude.',
      'Assurer la communication au sein de l’équipe via le chat dédié.',
    ],
    checklist: [
      'Prendre des photos représentatives des temps forts de la maraude.',
      'Ajouter les photos à la galerie (5 photos maximum).',
      'Vérifier avant publication qu’aucune personne vulnérable n’est identifiable sans son accord.',
      'Relayer les informations utiles à l’équipe via le chat de la maraude.',
    ],
    bestPractices: [
      'Privilégier des photos de l’action collective plutôt que des gros plans de personnes.',
      'Demander l’accord des personnes concernées avant de les photographier.',
      'Garder un ton factuel et bienveillant dans le chat.',
    ],
    objectives: [
      'Une galerie photo illustrant fidèlement la maraude, dans le respect de la vie privée des personnes accompagnées.',
      'Une équipe bien informée tout au long de la maraude.',
    ],
  ),
  MaraudeRole.logistics: MaraudeRoleMission(
    responsibilities: [
      'Veiller au bon déroulement matériel de la maraude.',
      'Vérifier la disponibilité du matériel nécessaire à la collecte et à la distribution.',
      'Appuyer le chef d’équipe sur l’organisation du parcours et des arrêts.',
    ],
    checklist: [
      'Vérifier avant le départ que le matériel nécessaire est disponible.',
      'Confirmer les points de collecte et de distribution prévus.',
      'Signaler au chef d’équipe toute contrainte matérielle rencontrée sur le terrain.',
    ],
    bestPractices: [
      'Anticiper les imprévus matériels plutôt que de les découvrir sur place.',
      'Communiquer rapidement toute difficulté pour permettre une adaptation en temps réel.',
    ],
    objectives: [
      'Une maraude qui se déroule sans accroc matériel.',
      'Une équipe qui dispose de tout le nécessaire au bon moment.',
    ],
  ),
  MaraudeRole.collectionDistribution: MaraudeRoleMission(
    responsibilities: [
      'Réceptionner et peser les denrées collectées.',
      'Distribuer les repas dans le respect des régimes alimentaires signalés.',
      'Veiller à une distribution ordonnée et équitable.',
    ],
    checklist: [
      'Peser et enregistrer chaque collecte dans l’application.',
      'Identifier et signaler les régimes alimentaires particuliers (sans gluten, végétarien, allergènes, etc.).',
      'Enregistrer chaque distribution effectuée.',
      'Respecter les règles d’hygiène lors de la manipulation des denrées.',
    ],
    bestPractices: [
      'Vérifier les régimes alimentaires avant de servir plutôt qu’après réclamation.',
      'Rester attentif à un partage équitable entre les personnes accompagnées.',
    ],
    objectives: [
      'Une récolte intégralement tracée et pesée.',
      'Une distribution respectueuse des régimes alimentaires de chacun.',
    ],
  ),
};
