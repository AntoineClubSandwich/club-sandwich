/// A ready-made, fully-assembled pixel-art character portrait — the real
/// visual payoff of the avatar module. Extracted from the Figma
/// "Personnages modulables" library (`assembled-characters-vol-1/2` and
/// the "Personnages contextuels (App)" section), since per-piece
/// modular sprites don't exist for worn items (see [AvatarCatalogue]'s
/// doc comment on the categories that stayed icon-only).
class CharacterPortrait {
  const CharacterPortrait({
    required this.id,
    required this.label,
    this.role,
  });

  final String id;
  final String label;

  /// Bénévole/tourneur role flavor text, when this portrait belongs to
  /// the app-contextual roster rather than the generic cast.
  final String? role;

  String get spritePath => 'assets/avatar/characters/$id.png';
}

class CharacterCatalogue {
  const CharacterCatalogue._();

  /// Bénévoles/maraudeurs — each drawn with the cooler-bag identity
  /// marker (black insulated bag, reflective silver stripes).
  static const volunteers = [
    CharacterPortrait(id: 'volunteer_lucas', label: 'Lucas', role: 'Bénévole'),
    CharacterPortrait(id: 'volunteer_ines', label: 'Inès', role: 'Bénévole'),
    CharacterPortrait(id: 'volunteer_antoine', label: 'Antoine', role: 'Bénévole'),
    CharacterPortrait(id: 'volunteer_malik', label: 'Malik', role: 'Bénévole'),
    CharacterPortrait(id: 'volunteer_chloe', label: 'Chloé', role: 'Bénévole'),
    CharacterPortrait(id: 'volunteer_thomas', label: 'Thomas', role: 'Bénévole'),
  ];

  /// Tourneurs/producteurs — each drawn with the identity marker
  /// (backstage pass on a lanyard).
  static const promoters = [
    CharacterPortrait(id: 'promoter_antoine_slick', label: "Antoine 'Slick'", role: 'Venue Promoter'),
    CharacterPortrait(id: 'promoter_chloe_vibe', label: "Chloé 'Vibe'", role: 'Booking Agent'),
    CharacterPortrait(id: 'promoter_malik_roots', label: "Malik 'Roots'", role: 'Production Mgr'),
    CharacterPortrait(id: 'promoter_hugo_tech', label: "Hugo 'Tech'", role: 'Stage Manager'),
    CharacterPortrait(id: 'promoter_ines_rocker', label: "Inès 'Rocker'", role: 'Artist Relations'),
    CharacterPortrait(id: 'promoter_marc_clock', label: "Marc 'Clock'", role: 'Show Coordinator'),
  ];

  /// Generic cast — no maraude theming, just extra variety/fun.
  static const generic = [
    CharacterPortrait(id: 'skater_sam', label: 'Skater Sam'),
    CharacterPortrait(id: 'chef_amara', label: 'Chef Amara'),
    CharacterPortrait(id: 'astro_kim', label: 'Astro Kim'),
    CharacterPortrait(id: 'punk_zara', label: 'Punk Zara'),
    CharacterPortrait(id: 'wizard_kofi', label: 'Wizard Kofi'),
    CharacterPortrait(id: 'sport_maya', label: 'Sport Maya'),
    CharacterPortrait(id: 'dj_riku', label: 'DJ Riku'),
    CharacterPortrait(id: 'ninja_yuki', label: 'Ninja Yuki'),
    CharacterPortrait(id: 'cowboy_jake', label: 'Cowboy Jake'),
    CharacterPortrait(id: 'doctor_priya', label: 'Doctor Priya'),
    CharacterPortrait(id: 'pirate_rosa', label: 'Pirate Rosa'),
    CharacterPortrait(id: 'gamer_leo', label: 'Gamer Leo'),
  ];

  static const all = [...volunteers, ...promoters, ...generic];

  static const defaultCharacterId = 'volunteer_lucas';

  static CharacterPortrait byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => all.first);
}
