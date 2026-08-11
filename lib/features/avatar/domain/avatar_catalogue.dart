/// Static catalogue of everything a user can equip on their avatar, plus
/// the gamification thresholds that unlock each item. There is no backend
/// table for this — it's a fixed content list, versioned with the app.
enum AvatarCategory {
  body,
  face,
  hair,
  top,
  bottom,
  shoes,
  head,
  back,
  held,
  jewelry,
  tattoo,
  pet,
}

class AvatarItem {
  const AvatarItem({
    required this.id,
    required this.label,
    required this.category,
    this.maraudesRequired = 0,
    this.seasonalMonths,
    this.spritePath,
    this.badgeCondition,
  });

  final String id;
  final String label;
  final AvatarCategory category;

  /// Real extracted pixel-art sprite (from the Figma "Personnages
  /// modulables" library), when one exists — `null` falls back to a
  /// generic Lucide glyph in the picker grid (see [avatarItemIcon]).
  final String? spritePath;

  /// Maraudes the volunteer must have completed to unlock this item.
  /// `0` means available from sign-up. Ignored when [badgeCondition] is
  /// set.
  final int maraudesRequired;

  /// Inclusive (startMonth, endMonth) in 1-12 for seasonal items (e.g.
  /// (12, 12) for December only, (6, 8) for June-August). `null` for
  /// non-seasonal items.
  final (int, int)? seasonalMonths;

  /// Flavor text for a specific-achievement unlock (e.g. "A recruté 3
  /// bénévoles") rather than a maraude-count threshold. There's no badge
  /// system in the app yet (see project memory) — items with this set
  /// stay permanently locked until one exists; the tooltip explains why
  /// rather than pretending a count would unlock them.
  final String? badgeCondition;

  bool get isSeasonal => seasonalMonths != null;
  bool get requiresBadge => badgeCondition != null;

  bool isUnlockedFor({required int maraudesCompleted, DateTime? now}) {
    if (requiresBadge) return false;
    if (isSeasonal) {
      final month = (now ?? DateTime.now()).month;
      final (start, end) = seasonalMonths!;
      return start <= end
          ? month >= start && month <= end
          : month >= start || month <= end;
    }
    return maraudesCompleted >= maraudesRequired;
  }

  String get lockedTooltip => requiresBadge
      ? 'Badge : $badgeCondition (bientôt disponible)'
      : isSeasonal
      ? 'Déblocable pendant sa saison'
      : maraudesRequired <= 1
      ? 'Déblocable après ta 1ère maraude'
      : 'Déblocable après $maraudesRequired maraudes';
}

class AvatarCatalogue {
  const AvatarCatalogue._();

  /// Root of the sprites extracted from the Figma "Personnages modulables"
  /// library (page `07 - Personnages modulables`, file
  /// `bl2vhyDT3XbDAZZp9V41VY`) — auto-detoured to real transparent PNGs.
  /// Items below without a matching real sprite still render via
  /// [avatarItemIcon]'s generic glyphs.
  static const _props = 'assets/avatar/props';

  static const heldObjects = [
    AvatarItem(id: 'sandwich', label: 'Club Sandwich', category: AvatarCategory.held),
    AvatarItem(id: 'backpack_maraude', label: 'Sac de maraude', category: AvatarCategory.held, maraudesRequired: 1),
    AvatarItem(id: 'cabas', label: 'Cabas courses', category: AvatarCategory.held, maraudesRequired: 1),
    AvatarItem(id: 'thermos', label: 'Thermos', category: AvatarCategory.held, maraudesRequired: 3),
    AvatarItem(id: 'megaphone', label: 'Mégaphone', category: AvatarCategory.held, maraudesRequired: 3),
    AvatarItem(id: 'guitar', label: 'Guitare', category: AvatarCategory.held, maraudesRequired: 5),
    AvatarItem(id: 'vinyl', label: 'Disque vinyle', category: AvatarCategory.held, maraudesRequired: 5),
    AvatarItem(id: 'mic', label: 'Micro', category: AvatarCategory.held, maraudesRequired: 5),
    AvatarItem(id: 'lightsaber', label: 'Sabre laser', category: AvatarCategory.held, maraudesRequired: 5, spritePath: '$_props/held_objects/held_12_emerald_lightsaber.png'),
    AvatarItem(id: 'magic_wand', label: 'Baguette magique', category: AvatarCategory.held, maraudesRequired: 10, spritePath: '$_props/held_objects/held_02_magic_wand.png'),
    AvatarItem(id: 'mjolnir', label: 'Marteau Mjölnir', category: AvatarCategory.held, maraudesRequired: 20),
    // Bonus items extracted with the real sprite library — no maraude
    // theme of their own, just extra flair, so unlocked from sign-up.
    AvatarItem(id: 'iron_broadsword', label: 'Épée en fer', category: AvatarCategory.held, spritePath: '$_props/held_objects/held_01_iron_broadsword.png'),
    AvatarItem(id: 'spring_bouquet', label: 'Bouquet de fleurs', category: AvatarCategory.held, spritePath: '$_props/held_objects/held_03_spring_bouquet.png'),
    AvatarItem(id: 'pizza_slice', label: 'Part de pizza', category: AvatarCategory.held, spritePath: '$_props/held_objects/held_04_pizza_slice.png'),
    AvatarItem(id: 'open_spellbook', label: 'Grimoire ouvert', category: AvatarCategory.held, spritePath: '$_props/held_objects/held_05_open_spellbook.png'),
    AvatarItem(id: 'rain_umbrella', label: 'Parapluie', category: AvatarCategory.held, spritePath: '$_props/held_objects/held_06_rain_umbrella.png'),
    AvatarItem(id: 'ruby_balloon', label: 'Ballon rubis', category: AvatarCategory.held, spritePath: '$_props/held_objects/held_07_ruby_balloon.png'),
    AvatarItem(id: 'championship_cup', label: 'Coupe de champion', category: AvatarCategory.held, spritePath: '$_props/held_objects/held_08_championship_cup.png'),
    AvatarItem(id: 'artist_paintbrush', label: 'Pinceau d\'artiste', category: AvatarCategory.held, spritePath: '$_props/held_objects/held_09_artist_paintbrush.png'),
    AvatarItem(id: 'bamboo_fishing_rod', label: 'Canne à pêche', category: AvatarCategory.held, spritePath: '$_props/held_objects/held_10_bamboo_fishing_rod.png'),
    AvatarItem(id: 'strawberry_cone', label: 'Glace à la fraise', category: AvatarCategory.held, spritePath: '$_props/held_objects/held_11_strawberry_cone.png'),
    AvatarItem(id: 'skateboard', label: 'Skateboard', category: AvatarCategory.held, spritePath: '$_props/accessories/acc_07_skateboard.png'),
    AvatarItem(id: 'coffee_cup', label: 'Café à emporter', category: AvatarCategory.held, spritePath: '$_props/accessories/acc_08_coffee_cup.png'),
    AvatarItem(id: 'smartphone', label: 'Smartphone', category: AvatarCategory.held, spritePath: '$_props/accessories/acc_09_smartphone.png'),
    AvatarItem(id: 'messenger_bag', label: 'Sacoche', category: AvatarCategory.held, spritePath: '$_props/accessories/acc_06_messenger_bag.png'),
    AvatarItem(id: 'camera', label: 'Appareil photo', category: AvatarCategory.held, spritePath: '$_props/accessories/acc_15_camera.png'),
  ];

  static const headAccessories = [
    AvatarItem(id: 'cap', label: 'Casquette', category: AvatarCategory.head),
    AvatarItem(id: 'cap_backward', label: 'Casquette à l\'envers', category: AvatarCategory.head),
    AvatarItem(id: 'beanie', label: 'Bonnet', category: AvatarCategory.head),
    AvatarItem(id: 'headphones', label: 'Casque audio', category: AvatarCategory.head, spritePath: '$_props/accessories/acc_11_headphones.png'),
    AvatarItem(id: 'sunglasses', label: 'Lunettes de soleil', category: AvatarCategory.head, spritePath: '$_props/accessories/acc_01_round_sunglasses.png'),
    AvatarItem(id: 'bandana', label: 'Bandana', category: AvatarCategory.head),
    AvatarItem(id: 'bucket_hat', label: 'Bob', category: AvatarCategory.head),
    AvatarItem(id: 'helmet_daft', label: 'Casque robot', category: AvatarCategory.head, maraudesRequired: 10),
    AvatarItem(id: 'elton_glasses', label: 'Lunettes étoile', category: AvatarCategory.head, maraudesRequired: 10),
    AvatarItem(id: 'crown', label: 'Couronne', category: AvatarCategory.head, maraudesRequired: 20),
    AvatarItem(id: 'santa_hat', label: 'Bonnet de Noël', category: AvatarCategory.head, seasonalMonths: (12, 12)),
    // Bonus glasses variants from the real sprite library.
    AvatarItem(id: 'aviator_glasses', label: 'Lunettes aviateur', category: AvatarCategory.head, spritePath: '$_props/accessories/acc_02_aviator_glasses.png'),
    AvatarItem(id: 'nerd_glasses', label: 'Lunettes intello', category: AvatarCategory.head, spritePath: '$_props/accessories/acc_03_nerd_glasses.png'),
    AvatarItem(id: 'eye_patch', label: 'Cache-œil', category: AvatarCategory.head, spritePath: '$_props/accessories/acc_04_eye_patch.png'),
  ];

  static const backItems = [
    AvatarItem(id: 'backpack_maraude', label: 'Sac à dos maraude', category: AvatarCategory.back, maraudesRequired: 1),
    AvatarItem(id: 'guitar_back', label: 'Guitare dans le dos', category: AvatarCategory.back, maraudesRequired: 5, spritePath: '$_props/accessories/acc_10_guitar.png'),
    AvatarItem(id: 'cape', label: 'Cape', category: AvatarCategory.back, maraudesRequired: 10),
    AvatarItem(id: 'wings', label: 'Ailes', category: AvatarCategory.back, maraudesRequired: 50),
    AvatarItem(id: 'red_backpack', label: 'Sac à dos rouge', category: AvatarCategory.back, spritePath: '$_props/accessories/acc_05_red_backpack.png'),
  ];

  static const jewelryItems = [
    AvatarItem(id: 'gold_chain_necklace', label: 'Collier chaîne dorée', category: AvatarCategory.jewelry, spritePath: '$_props/jewelry/jewelry_01_gold_chain_necklace.png'),
    AvatarItem(id: 'silver_hoop_earrings', label: 'Créoles argentées', category: AvatarCategory.jewelry, spritePath: '$_props/jewelry/jewelry_02_silver_hoop_earrings.png'),
    AvatarItem(id: 'nose_ring_gold', label: 'Piercing nez doré', category: AvatarCategory.jewelry, spritePath: '$_props/jewelry/jewelry_03_nose_ring_gold.png'),
    AvatarItem(id: 'diamond_stud_earring', label: 'Puce diamant', category: AvatarCategory.jewelry, spritePath: '$_props/jewelry/jewelry_04_diamond_stud_earring.png'),
    AvatarItem(id: 'leather_choker', label: 'Ras-de-cou cuir', category: AvatarCategory.jewelry, spritePath: '$_props/jewelry/jewelry_05_leather_choker.png'),
    AvatarItem(id: 'pearl_necklace', label: 'Collier de perles', category: AvatarCategory.jewelry, spritePath: '$_props/jewelry/jewelry_06_pearl_necklace.png'),
    AvatarItem(id: 'lip_ring_silver', label: 'Piercing lèvre argenté', category: AvatarCategory.jewelry, spritePath: '$_props/jewelry/jewelry_07_lip_ring_silver.png'),
    AvatarItem(id: 'beaded_bracelet', label: 'Bracelet de perles', category: AvatarCategory.jewelry, spritePath: '$_props/jewelry/jewelry_08_beaded_bracelet.png'),
    AvatarItem(id: 'dog_tag_necklace', label: 'Plaques militaires', category: AvatarCategory.jewelry, spritePath: '$_props/jewelry/jewelry_09_dog_tag_necklace.png'),
    AvatarItem(id: 'anklet_gold_chain', label: 'Bracelet de cheville doré', category: AvatarCategory.jewelry, spritePath: '$_props/jewelry/jewelry_10_anklet_gold_chain.png'),
    AvatarItem(id: 'watch', label: 'Montre', category: AvatarCategory.jewelry, spritePath: '$_props/accessories/acc_12_watch.png'),
    AvatarItem(id: 'yellow_scarf', label: 'Écharpe jaune', category: AvatarCategory.jewelry, spritePath: '$_props/accessories/acc_13_yellow_scarf.png'),
    AvatarItem(id: 'necklace_chain', label: 'Chaîne collier', category: AvatarCategory.jewelry, spritePath: '$_props/accessories/acc_14_necklace_chain.png'),
  ];

  static const tattoos = [
    AvatarItem(id: 'tribal_arm_band', label: 'Brassard tribal', category: AvatarCategory.tattoo, spritePath: '$_props/tattoos/tattoo_01_tribal_arm_band.png'),
    AvatarItem(id: 'crimson_rose', label: 'Rose pourpre', category: AvatarCategory.tattoo, spritePath: '$_props/tattoos/tattoo_02_crimson_rose.png'),
    AvatarItem(id: 'retro_skull', label: 'Crâne rétro', category: AvatarCategory.tattoo, spritePath: '$_props/tattoos/tattoo_03_retro_skull.png'),
    AvatarItem(id: 'jade_dragon', label: 'Dragon de jade', category: AvatarCategory.tattoo, spritePath: '$_props/tattoos/tattoo_04_jade_dragon.png'),
    AvatarItem(id: 'heart_and_arrow', label: 'Cœur et flèche', category: AvatarCategory.tattoo, spritePath: '$_props/tattoos/tattoo_05_heart_and_arrow.png'),
    AvatarItem(id: 'sailor_anchor', label: 'Ancre marine', category: AvatarCategory.tattoo, spritePath: '$_props/tattoos/tattoo_06_sailor_anchor.png'),
    AvatarItem(id: 'serpent_wrap', label: 'Serpent enroulé', category: AvatarCategory.tattoo, spritePath: '$_props/tattoos/tattoo_07_serpent_wrap.png'),
    AvatarItem(id: 'constellation', label: 'Constellation', category: AvatarCategory.tattoo, spritePath: '$_props/tattoos/tattoo_08_constellation.png'),
    AvatarItem(id: 'classic_flame', label: 'Flamme classique', category: AvatarCategory.tattoo, spritePath: '$_props/tattoos/tattoo_09_classic_flame.png'),
    AvatarItem(id: 'pixel_mandala', label: 'Mandala pixel', category: AvatarCategory.tattoo, spritePath: '$_props/tattoos/tattoo_10_pixel_mandala.png'),
  ];

  static const pets = [
    AvatarItem(id: 'orange_tabby_cat', label: 'Chat roux tigré', category: AvatarCategory.pet, spritePath: '$_props/pets/pet_01_orange_tabby_cat.png'),
    AvatarItem(id: 'small_brown_dog', label: 'Petit chien brun', category: AvatarCategory.pet, spritePath: '$_props/pets/pet_02_small_brown_dog.png'),
    AvatarItem(id: 'green_parrot', label: 'Perroquet vert', category: AvatarCategory.pet, spritePath: '$_props/pets/pet_03_green_parrot.png'),
    AvatarItem(id: 'tiny_beige_hamster', label: 'Petit hamster beige', category: AvatarCategory.pet, spritePath: '$_props/pets/pet_04_tiny_beige_hamster.png'),
    AvatarItem(id: 'green_coiled_snake', label: 'Serpent vert lové', category: AvatarCategory.pet, spritePath: '$_props/pets/pet_05_green_coiled_snake.png'),
    AvatarItem(id: 'small_brown_owl', label: 'Petite chouette brune', category: AvatarCategory.pet, spritePath: '$_props/pets/pet_06_small_brown_owl.png'),
    AvatarItem(id: 'goldfish_in_bowl', label: 'Poisson rouge en bocal', category: AvatarCategory.pet, spritePath: '$_props/pets/pet_07_goldfish_in_bowl.png'),
    AvatarItem(id: 'white_bunny', label: 'Lapin blanc', category: AvatarCategory.pet, spritePath: '$_props/pets/pet_08_white_bunny.png'),
    AvatarItem(id: 'green_shell_turtle', label: 'Tortue à carapace verte', category: AvatarCategory.pet, spritePath: '$_props/pets/pet_09_green_shell_turtle.png'),
    AvatarItem(id: 'black_cat', label: 'Chat noir', category: AvatarCategory.pet, spritePath: '$_props/pets/pet_10_black_cat.png'),
    // Tiered progression system (paliers 1-5 by maraudesRequired + badge
    // unlocks) extracted from Figma page "07 - Personnages modulables",
    // sections "Niveau 1..5" and "Badges" — 98 sprites, all wearing the
    // maraude cooler bag per the brief. A few Figma layer names don't
    // quite match their actual artwork (e.g. "tier3_licorne" renders as
    // a griffon) — kept as named since there's no way to re-verify all
    // 98 against their visual content at this scale; cosmetic only.
    AvatarItem(id: 'ferme_vache', label: 'Vache', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_vache.png'),
    AvatarItem(id: 'ferme_cochon', label: 'Cochon', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_cochon.png'),
    AvatarItem(id: 'ferme_mouton', label: 'Mouton', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_mouton.png'),
    AvatarItem(id: 'ferme_coq', label: 'Coq', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_coq.png'),
    AvatarItem(id: 'ferme_cheval', label: 'Cheval', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_cheval.png'),
    AvatarItem(id: 'ferme_ane', label: 'Âne', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_ane.png'),
    AvatarItem(id: 'ferme_chevre', label: 'Chèvre', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_chevre.png'),
    AvatarItem(id: 'ferme_canard', label: 'Canard', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_canard.png'),
    AvatarItem(id: 'amphibien_grenouille', label: 'Grenouille', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/amphibien_grenouille.png'),
    AvatarItem(id: 'amphibien_crapaud', label: 'Crapaud', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/amphibien_crapaud.png'),
    AvatarItem(id: 'reptile_gecko', label: 'Gecko', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/reptile_gecko.png'),
    AvatarItem(id: 'reptile_tortue_galapagos', label: 'Tortue galapagos', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/reptile_tortue_galapagos.png'),
    AvatarItem(id: 'insecte_coccinelle', label: 'Coccinelle', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/insecte_coccinelle.png'),
    AvatarItem(id: 'insecte_fourmi', label: 'Fourmi', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/insecte_fourmi.png'),
    AvatarItem(id: 'insecte_luciole', label: 'Luciole', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/insecte_luciole.png'),
    AvatarItem(id: 'oiseau_corbeau', label: 'Corbeau', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/oiseau_corbeau.png'),
    AvatarItem(id: 'oiseau_kiwi', label: 'Kiwi', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/oiseau_kiwi.png'),
    AvatarItem(id: 'montagne_marmotte', label: 'Marmotte', category: AvatarCategory.pet, maraudesRequired: 0, spritePath: 'assets/avatar/pets/montagne_marmotte.png'),
    AvatarItem(id: 'oiseau_toucan', label: 'Toucan', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/oiseau_toucan.png'),
    AvatarItem(id: 'oiseau_colibri', label: 'Colibri', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/oiseau_colibri.png'),
    AvatarItem(id: 'oiseau_aigle', label: 'Aigle', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/oiseau_aigle.png'),
    AvatarItem(id: 'oiseau_hibou_grand_duc', label: 'Hibou grand duc', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/oiseau_hibou_grand_duc.png'),
    AvatarItem(id: 'oiseau_pinguoin_empereur', label: 'Pingouin empereur', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/oiseau_pinguoin_empereur.png'),
    AvatarItem(id: 'oiseau_martin_pecheur', label: 'Martin-pêcheur', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/oiseau_martin_pecheur.png'),
    AvatarItem(id: 'reptile_crocodile', label: 'Crocodile', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/reptile_crocodile.png'),
    AvatarItem(id: 'reptile_iguane', label: 'Iguane', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/reptile_iguane.png'),
    AvatarItem(id: 'reptile_cobra_royal', label: 'Cobra royal', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/reptile_cobra_royal.png'),
    AvatarItem(id: 'amphibien_salamandre', label: 'Salamandre', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/amphibien_salamandre.png'),
    AvatarItem(id: 'insecte_papillon', label: 'Papillon', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/insecte_papillon.png'),
    AvatarItem(id: 'insecte_mante_religieuse', label: 'Mante religieuse', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/insecte_mante_religieuse.png'),
    AvatarItem(id: 'insecte_libellule', label: 'Libellule', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/insecte_libellule.png'),
    AvatarItem(id: 'insecte_scarabee_dore', label: 'Scarabée doré', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/insecte_scarabee_dore.png'),
    AvatarItem(id: 'arachnide_araignee', label: 'Araignée', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/arachnide_araignee.png'),
    AvatarItem(id: 'montagne_bouquetin', label: 'Bouquetin', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/montagne_bouquetin.png'),
    AvatarItem(id: 'montagne_aigle_royal', label: 'Aigle royal', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/montagne_aigle_royal.png'),
    AvatarItem(id: 'polaire_harfang', label: 'Harfang', category: AvatarCategory.pet, maraudesRequired: 5, spritePath: 'assets/avatar/pets/polaire_harfang.png'),
    AvatarItem(id: 'tier2_flamant_rose', label: 'Flamant rose', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_flamant_rose.png'),
    AvatarItem(id: 'tier2_paon', label: 'Paon', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_paon.png'),
    AvatarItem(id: 'tier2_tigre_bengale', label: 'Tigre bengale', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_tigre_bengale.png'),
    AvatarItem(id: 'tier2_panda_roux', label: 'Panda roux', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_panda_roux.png'),
    AvatarItem(id: 'tier2_panthere_noire', label: 'Panthère noire', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_panthere_noire.png'),
    AvatarItem(id: 'tier2_ara_macaw', label: 'Ara macaw', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_ara_macaw.png'),
    AvatarItem(id: 'tier2_zebre', label: 'Zèbre', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_zebre.png'),
    AvatarItem(id: 'tier2_girafe', label: 'Girafe', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_girafe.png'),
    AvatarItem(id: 'polaire_ours_blanc', label: 'Ours blanc', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/polaire_ours_blanc.png'),
    AvatarItem(id: 'polaire_renard_arctique', label: 'Renard arctique', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/polaire_renard_arctique.png'),
    AvatarItem(id: 'polaire_phoque', label: 'Phoque', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/polaire_phoque.png'),
    AvatarItem(id: 'polaire_morse', label: 'Morse', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/polaire_morse.png'),
    AvatarItem(id: 'insolite_axolotl', label: 'Axolotl', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/insolite_axolotl.png'),
    AvatarItem(id: 'insolite_ornithorynque', label: 'Ornithorynque', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/insolite_ornithorynque.png'),
    AvatarItem(id: 'insolite_pangolin', label: 'Pangolin', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/insolite_pangolin.png'),
    AvatarItem(id: 'insolite_dodo', label: 'Dodo', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/insolite_dodo.png'),
    AvatarItem(id: 'insolite_cameleon', label: 'Caméléon', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/insolite_cameleon.png'),
    AvatarItem(id: 'mystique_tanuki', label: 'Tanuki', category: AvatarCategory.pet, maraudesRequired: 10, spritePath: 'assets/avatar/pets/mystique_tanuki.png'),
    AvatarItem(id: 'dino_stegosaure', label: 'Stegosaure', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_stegosaure.png'),
    AvatarItem(id: 'dino_pterodactyle', label: 'Ptérodactyle', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_pterodactyle.png'),
    AvatarItem(id: 'dino_brontosaure', label: 'Brontosaure', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_brontosaure.png'),
    AvatarItem(id: 'dino_ankylosaure', label: 'Ankylosaure', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_ankylosaure.png'),
    AvatarItem(id: 'dino_pachycephalosaure', label: 'Pachycephalosaure', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_pachycephalosaure.png'),
    AvatarItem(id: 'marin_poulpe', label: 'Poulpe', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_poulpe.png'),
    AvatarItem(id: 'marin_requin', label: 'Requin', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_requin.png'),
    AvatarItem(id: 'marin_hippocampe', label: 'Hippocampe', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_hippocampe.png'),
    AvatarItem(id: 'marin_crabe', label: 'Crabe', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_crabe.png'),
    AvatarItem(id: 'marin_meduse', label: 'Méduse', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_meduse.png'),
    AvatarItem(id: 'marin_tortue_mer', label: 'Tortue de mer', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_tortue_mer.png'),
    AvatarItem(id: 'marin_narval', label: 'Narval', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_narval.png'),
    AvatarItem(id: 'marin_etoile_mer', label: 'Étoile de mer', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_etoile_mer.png'),
    AvatarItem(id: 'mythe_kappa', label: 'Kappa', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/mythe_kappa.png'),
    AvatarItem(id: 'mythe_yeti', label: 'Yeti', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/mythe_yeti.png'),
    AvatarItem(id: 'mythe_wolpertinger', label: 'Wolpertinger', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/mythe_wolpertinger.png'),
    AvatarItem(id: 'mythe_baku', label: 'Baku', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/mythe_baku.png'),
    AvatarItem(id: 'mystique_loup_spectral', label: 'Loup spectral', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/mystique_loup_spectral.png'),
    AvatarItem(id: 'dino_t_rex', label: 'T-Rex', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_t_rex.png'),
    AvatarItem(id: 'dino_triceratops', label: 'Triceratops', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_triceratops.png'),
    AvatarItem(id: 'dino_velociraptor', label: 'Velociraptor', category: AvatarCategory.pet, maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_velociraptor.png'),
    AvatarItem(id: 'tier3_dragon_mini', label: 'Dragon miniature', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_dragon_mini.png'),
    AvatarItem(id: 'tier3_licorne', label: 'Licorne', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_licorne.png'),
    AvatarItem(id: 'tier3_phenix', label: 'Phénix', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_phenix.png'),
    AvatarItem(id: 'tier3_renard_neuf_queues', label: 'Renard à neuf queues', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_renard_neuf_queues.png'),
    AvatarItem(id: 'tier3_chat_aile', label: 'Chat ailé', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_chat_aile.png'),
    AvatarItem(id: 'tier3_pegase', label: 'Pégase', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_pegase.png'),
    AvatarItem(id: 'tier3_renard_celeste_bleu', label: 'Renard céleste bleu', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_renard_celeste_bleu.png'),
    AvatarItem(id: 'tier4_griffon', label: 'Griffon', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier4_griffon.png'),
    AvatarItem(id: 'tier4_hydre_mini', label: 'Hydre miniature', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier4_hydre_mini.png'),
    AvatarItem(id: 'tier4_chimere', label: 'Chimère', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier4_chimere.png'),
    AvatarItem(id: 'tier4_dragon_jade', label: 'Dragon de jade', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier4_dragon_jade.png'),
    AvatarItem(id: 'tier4_serpent_plumes', label: 'Serpent à plumes', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier4_serpent_plumes.png'),
    AvatarItem(id: 'tier5_phenix_dore', label: 'Phénix doré', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier5_phenix_dore.png'),
    AvatarItem(id: 'mythe_minotaure', label: 'Minotaure', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/mythe_minotaure.png'),
    AvatarItem(id: 'mythe_sphinx', label: 'Sphinx', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/mythe_sphinx.png'),
    AvatarItem(id: 'mythe_basilic', label: 'Basilic', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/mythe_basilic.png'),
    AvatarItem(id: 'mythe_manticore', label: 'Manticore', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/mythe_manticore.png'),
    AvatarItem(id: 'mystique_cerbere_mini', label: 'Cerbère miniature', category: AvatarCategory.pet, maraudesRequired: 20, spritePath: 'assets/avatar/pets/mystique_cerbere_mini.png'),
    AvatarItem(id: 'badge_10_maraudes_tortue_sage', label: 'Tortue sage', category: AvatarCategory.pet, spritePath: 'assets/avatar/pets/badge_10_maraudes_tortue_sage.png', badgeCondition: '10 maraudes clôturées'),
    AvatarItem(id: 'badge_500_repas_pelican', label: 'Pélican généreux', category: AvatarCategory.pet, spritePath: 'assets/avatar/pets/badge_500_repas_pelican.png', badgeCondition: '500 repas sauvés cumulés'),
    AvatarItem(id: 'badge_recrutement_abeille_reine', label: 'Abeille reine', category: AvatarCategory.pet, spritePath: 'assets/avatar/pets/badge_recrutement_abeille_reine.png', badgeCondition: 'A recruté 3 bénévoles'),
    AvatarItem(id: 'badge_maraude_culturelle_rossignol', label: 'Rossignol', category: AvatarCategory.pet, spritePath: 'assets/avatar/pets/badge_maraude_culturelle_rossignol.png', badgeCondition: 'A participé à une maraude culturelle'),
    AvatarItem(id: 'badge_membre_1an_elephant', label: 'Éléphant vétéran', category: AvatarCategory.pet, spritePath: 'assets/avatar/pets/badge_membre_1an_elephant.png', badgeCondition: 'Membre depuis 1 an'),
  ];

  static const topStyles = [
    AvatarItem(id: 'tshirt', label: 'T-shirt', category: AvatarCategory.top),
    AvatarItem(id: 'hoodie', label: 'Hoodie', category: AvatarCategory.top),
    AvatarItem(id: 'jacket', label: 'Veste', category: AvatarCategory.top),
    AvatarItem(id: 'tanktop', label: 'Débardeur', category: AvatarCategory.top),
    AvatarItem(id: 'hawaiian', label: 'Chemise hawaïenne', category: AvatarCategory.top),
    AvatarItem(id: 'punk_vest', label: 'Gilet punk', category: AvatarCategory.top),
    AvatarItem(id: 'leather_jacket', label: 'Veste en cuir', category: AvatarCategory.top),
    AvatarItem(id: 'chef_coat', label: 'Veste de chef', category: AvatarCategory.top),
  ];

  static const bottomStyles = [
    AvatarItem(id: 'jeans', label: 'Jean', category: AvatarCategory.bottom),
    AvatarItem(id: 'cargo', label: 'Pantalon cargo', category: AvatarCategory.bottom),
    AvatarItem(id: 'shorts', label: 'Short', category: AvatarCategory.bottom),
    AvatarItem(id: 'jogger', label: 'Jogger', category: AvatarCategory.bottom),
    AvatarItem(id: 'skirt', label: 'Jupe', category: AvatarCategory.bottom),
    AvatarItem(id: 'overalls', label: 'Salopette', category: AvatarCategory.bottom),
  ];

  static const shoesStyles = [
    AvatarItem(id: 'sneakers', label: 'Baskets', category: AvatarCategory.shoes),
    AvatarItem(id: 'boots', label: 'Bottines', category: AvatarCategory.shoes),
    AvatarItem(id: 'sandals', label: 'Sandales', category: AvatarCategory.shoes),
    AvatarItem(id: 'converse', label: 'Converse', category: AvatarCategory.shoes),
    AvatarItem(id: 'docs', label: 'Docs Martens', category: AvatarCategory.shoes),
    AvatarItem(id: 'platforms', label: 'Plateformes', category: AvatarCategory.shoes),
  ];

  static const hairStyles = [
    AvatarItem(id: 'short', label: 'Court', category: AvatarCategory.hair),
    AvatarItem(id: 'long', label: 'Long', category: AvatarCategory.hair),
    AvatarItem(id: 'afro', label: 'Afro', category: AvatarCategory.hair),
    AvatarItem(id: 'ponytail', label: 'Queue de cheval', category: AvatarCategory.hair),
    AvatarItem(id: 'mohawk', label: 'Crête', category: AvatarCategory.hair),
    AvatarItem(id: 'curly', label: 'Bouclé', category: AvatarCategory.hair),
    AvatarItem(id: 'buzz', label: 'Ras', category: AvatarCategory.hair),
    AvatarItem(id: 'bald', label: 'Chauve', category: AvatarCategory.hair),
  ];

  static const eyeStyles = [
    AvatarItem(id: 'default', label: 'Neutres', category: AvatarCategory.face),
    AvatarItem(id: 'happy', label: 'Joyeux', category: AvatarCategory.face),
    AvatarItem(id: 'cool', label: 'Cool', category: AvatarCategory.face),
    AvatarItem(id: 'tired', label: 'Fatigués', category: AvatarCategory.face),
  ];

  static const mouthStyles = [
    AvatarItem(id: 'smile', label: 'Sourire', category: AvatarCategory.face),
    AvatarItem(id: 'neutral', label: 'Neutre', category: AvatarCategory.face),
    AvatarItem(id: 'grin', label: 'Grand sourire', category: AvatarCategory.face),
  ];

  static const bodyTypes = [
    AvatarItem(id: '1', label: 'Silhouette 1', category: AvatarCategory.body),
    AvatarItem(id: '2', label: 'Silhouette 2', category: AvatarCategory.body),
    AvatarItem(id: '3', label: 'Silhouette 3', category: AvatarCategory.body),
  ];

  static const skinTones = [
    '#F5D0A9',
    '#E8B084',
    '#D89B6A',
    '#C08552',
    '#A86B3C',
    '#8A5232',
    '#6B3F26',
    '#4A2C1A',
  ];

  static const colorPresets = [
    '#6C5CE7',
    '#2563EB',
    '#059669',
    '#D97706',
    '#DC2626',
    '#DB2777',
    '#1A1A2E',
    '#6B7280',
    '#F5D0A9',
    '#0EA5E9',
    '#84CC16',
    '#FFFFFF',
  ];

  /// Every unlockable item across all categories, for a flat unlock check
  /// (progress screens, "new item unlocked" notifications, etc).
  static List<AvatarItem> get allUnlockable => [
    ...heldObjects,
    ...headAccessories,
    ...backItems,
    ...jewelryItems,
    ...tattoos,
    ...pets,
  ];

  static List<AvatarItem> itemsFor(AvatarCategory category) => switch (category) {
    AvatarCategory.body => bodyTypes,
    AvatarCategory.face => eyeStyles, // eyes/mouth handled separately in UI
    AvatarCategory.hair => hairStyles,
    AvatarCategory.top => topStyles,
    AvatarCategory.bottom => bottomStyles,
    AvatarCategory.shoes => shoesStyles,
    AvatarCategory.head => headAccessories,
    AvatarCategory.back => backItems,
    AvatarCategory.held => heldObjects,
    AvatarCategory.jewelry => jewelryItems,
    AvatarCategory.tattoo => tattoos,
    AvatarCategory.pet => pets,
  };
}
