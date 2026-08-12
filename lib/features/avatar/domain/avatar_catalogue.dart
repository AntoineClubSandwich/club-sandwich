/// Static catalogue of every animal companion a user can equip, plus the
/// maraude-count thresholds that unlock each one. There is no backend
/// table for this — it's a fixed content list, versioned with the app.
class AvatarItem {
  const AvatarItem({
    required this.id,
    required this.label,
    required this.spritePath,
    this.maraudesRequired = 0,
    this.badgeCondition,
  });

  final String id;
  final String label;

  /// Real extracted pixel-art sprite (from the Figma "Personnages
  /// modulables" library, page `07 - Personnages modulables`).
  final String spritePath;

  /// Maraudes the volunteer must have completed to unlock this item.
  /// `0` means available from sign-up. Ignored when [badgeCondition] is
  /// set.
  final int maraudesRequired;

  /// Flavor text for a specific-achievement unlock (e.g. "A recruté 3
  /// bénévoles") rather than a maraude-count threshold. There's no badge
  /// system in the app yet (see project memory) — items with this set
  /// stay permanently locked until one exists; the tooltip explains why
  /// rather than pretending a count would unlock them.
  final String? badgeCondition;

  bool get requiresBadge => badgeCondition != null;

  bool isUnlockedFor({required int maraudesCompleted}) {
    if (requiresBadge) return false;
    return maraudesCompleted >= maraudesRequired;
  }

  String get lockedTooltip => requiresBadge
      ? 'Badge : $badgeCondition (bientôt disponible)'
      : maraudesRequired <= 1
      ? 'Déblocable après ta 1ère maraude'
      : 'Déblocable après $maraudesRequired maraudes';
}

class AvatarCatalogue {
  const AvatarCatalogue._();

  /// Tiered progression system (paliers 1-5 by maraudesRequired + badge
  /// unlocks) extracted from Figma page "07 - Personnages modulables",
  /// sections "Niveau 1..5" and "Badges" — 98 sprites, all wearing the
  /// maraude cooler bag per the brief. A few Figma layer names don't
  /// quite match their actual artwork (e.g. "tier3_licorne" renders as
  /// a griffon) — kept as named since there's no way to re-verify all
  /// 98 against their visual content at this scale; cosmetic only.
  static const pets = [
    AvatarItem(id: 'ferme_vache', label: 'Vache', maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_vache.png'),
    AvatarItem(id: 'ferme_cochon', label: 'Cochon', maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_cochon.png'),
    AvatarItem(id: 'ferme_mouton', label: 'Mouton', maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_mouton.png'),
    AvatarItem(id: 'ferme_coq', label: 'Coq', maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_coq.png'),
    AvatarItem(id: 'ferme_cheval', label: 'Cheval', maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_cheval.png'),
    AvatarItem(id: 'ferme_ane', label: 'Âne', maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_ane.png'),
    AvatarItem(id: 'ferme_chevre', label: 'Chèvre', maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_chevre.png'),
    AvatarItem(id: 'ferme_canard', label: 'Canard', maraudesRequired: 0, spritePath: 'assets/avatar/pets/ferme_canard.png'),
    AvatarItem(id: 'amphibien_grenouille', label: 'Grenouille', maraudesRequired: 0, spritePath: 'assets/avatar/pets/amphibien_grenouille.png'),
    AvatarItem(id: 'amphibien_crapaud', label: 'Crapaud', maraudesRequired: 0, spritePath: 'assets/avatar/pets/amphibien_crapaud.png'),
    AvatarItem(id: 'reptile_gecko', label: 'Gecko', maraudesRequired: 0, spritePath: 'assets/avatar/pets/reptile_gecko.png'),
    AvatarItem(id: 'reptile_tortue_galapagos', label: 'Tortue galapagos', maraudesRequired: 0, spritePath: 'assets/avatar/pets/reptile_tortue_galapagos.png'),
    AvatarItem(id: 'insecte_coccinelle', label: 'Coccinelle', maraudesRequired: 0, spritePath: 'assets/avatar/pets/insecte_coccinelle.png'),
    AvatarItem(id: 'insecte_fourmi', label: 'Fourmi', maraudesRequired: 0, spritePath: 'assets/avatar/pets/insecte_fourmi.png'),
    AvatarItem(id: 'insecte_luciole', label: 'Luciole', maraudesRequired: 0, spritePath: 'assets/avatar/pets/insecte_luciole.png'),
    AvatarItem(id: 'oiseau_corbeau', label: 'Corbeau', maraudesRequired: 0, spritePath: 'assets/avatar/pets/oiseau_corbeau.png'),
    AvatarItem(id: 'oiseau_kiwi', label: 'Kiwi', maraudesRequired: 0, spritePath: 'assets/avatar/pets/oiseau_kiwi.png'),
    AvatarItem(id: 'montagne_marmotte', label: 'Marmotte', maraudesRequired: 0, spritePath: 'assets/avatar/pets/montagne_marmotte.png'),
    AvatarItem(id: 'oiseau_toucan', label: 'Toucan', maraudesRequired: 5, spritePath: 'assets/avatar/pets/oiseau_toucan.png'),
    AvatarItem(id: 'oiseau_colibri', label: 'Colibri', maraudesRequired: 5, spritePath: 'assets/avatar/pets/oiseau_colibri.png'),
    AvatarItem(id: 'oiseau_aigle', label: 'Aigle', maraudesRequired: 5, spritePath: 'assets/avatar/pets/oiseau_aigle.png'),
    AvatarItem(id: 'oiseau_hibou_grand_duc', label: 'Hibou grand duc', maraudesRequired: 5, spritePath: 'assets/avatar/pets/oiseau_hibou_grand_duc.png'),
    AvatarItem(id: 'oiseau_pinguoin_empereur', label: 'Pingouin empereur', maraudesRequired: 5, spritePath: 'assets/avatar/pets/oiseau_pinguoin_empereur.png'),
    AvatarItem(id: 'oiseau_martin_pecheur', label: 'Martin-pêcheur', maraudesRequired: 5, spritePath: 'assets/avatar/pets/oiseau_martin_pecheur.png'),
    AvatarItem(id: 'reptile_crocodile', label: 'Crocodile', maraudesRequired: 5, spritePath: 'assets/avatar/pets/reptile_crocodile.png'),
    AvatarItem(id: 'reptile_iguane', label: 'Iguane', maraudesRequired: 5, spritePath: 'assets/avatar/pets/reptile_iguane.png'),
    AvatarItem(id: 'reptile_cobra_royal', label: 'Cobra royal', maraudesRequired: 5, spritePath: 'assets/avatar/pets/reptile_cobra_royal.png'),
    AvatarItem(id: 'amphibien_salamandre', label: 'Salamandre', maraudesRequired: 5, spritePath: 'assets/avatar/pets/amphibien_salamandre.png'),
    AvatarItem(id: 'insecte_papillon', label: 'Papillon', maraudesRequired: 5, spritePath: 'assets/avatar/pets/insecte_papillon.png'),
    AvatarItem(id: 'insecte_mante_religieuse', label: 'Mante religieuse', maraudesRequired: 5, spritePath: 'assets/avatar/pets/insecte_mante_religieuse.png'),
    AvatarItem(id: 'insecte_libellule', label: 'Libellule', maraudesRequired: 5, spritePath: 'assets/avatar/pets/insecte_libellule.png'),
    AvatarItem(id: 'insecte_scarabee_dore', label: 'Scarabée doré', maraudesRequired: 5, spritePath: 'assets/avatar/pets/insecte_scarabee_dore.png'),
    AvatarItem(id: 'arachnide_araignee', label: 'Araignée', maraudesRequired: 5, spritePath: 'assets/avatar/pets/arachnide_araignee.png'),
    AvatarItem(id: 'montagne_bouquetin', label: 'Bouquetin', maraudesRequired: 5, spritePath: 'assets/avatar/pets/montagne_bouquetin.png'),
    AvatarItem(id: 'montagne_aigle_royal', label: 'Aigle royal', maraudesRequired: 5, spritePath: 'assets/avatar/pets/montagne_aigle_royal.png'),
    AvatarItem(id: 'polaire_harfang', label: 'Harfang', maraudesRequired: 5, spritePath: 'assets/avatar/pets/polaire_harfang.png'),
    AvatarItem(id: 'tier2_flamant_rose', label: 'Flamant rose', maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_flamant_rose.png'),
    AvatarItem(id: 'tier2_paon', label: 'Paon', maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_paon.png'),
    AvatarItem(id: 'tier2_tigre_bengale', label: 'Tigre bengale', maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_tigre_bengale.png'),
    AvatarItem(id: 'tier2_panda_roux', label: 'Panda roux', maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_panda_roux.png'),
    AvatarItem(id: 'tier2_panthere_noire', label: 'Panthère noire', maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_panthere_noire.png'),
    AvatarItem(id: 'tier2_ara_macaw', label: 'Ara macaw', maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_ara_macaw.png'),
    AvatarItem(id: 'tier2_zebre', label: 'Zèbre', maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_zebre.png'),
    AvatarItem(id: 'tier2_girafe', label: 'Girafe', maraudesRequired: 10, spritePath: 'assets/avatar/pets/tier2_girafe.png'),
    AvatarItem(id: 'polaire_ours_blanc', label: 'Ours blanc', maraudesRequired: 10, spritePath: 'assets/avatar/pets/polaire_ours_blanc.png'),
    AvatarItem(id: 'polaire_renard_arctique', label: 'Renard arctique', maraudesRequired: 10, spritePath: 'assets/avatar/pets/polaire_renard_arctique.png'),
    AvatarItem(id: 'polaire_phoque', label: 'Phoque', maraudesRequired: 10, spritePath: 'assets/avatar/pets/polaire_phoque.png'),
    AvatarItem(id: 'polaire_morse', label: 'Morse', maraudesRequired: 10, spritePath: 'assets/avatar/pets/polaire_morse.png'),
    AvatarItem(id: 'insolite_axolotl', label: 'Axolotl', maraudesRequired: 10, spritePath: 'assets/avatar/pets/insolite_axolotl.png'),
    AvatarItem(id: 'insolite_ornithorynque', label: 'Ornithorynque', maraudesRequired: 10, spritePath: 'assets/avatar/pets/insolite_ornithorynque.png'),
    AvatarItem(id: 'insolite_pangolin', label: 'Pangolin', maraudesRequired: 10, spritePath: 'assets/avatar/pets/insolite_pangolin.png'),
    AvatarItem(id: 'insolite_dodo', label: 'Dodo', maraudesRequired: 10, spritePath: 'assets/avatar/pets/insolite_dodo.png'),
    AvatarItem(id: 'insolite_cameleon', label: 'Caméléon', maraudesRequired: 10, spritePath: 'assets/avatar/pets/insolite_cameleon.png'),
    AvatarItem(id: 'mystique_tanuki', label: 'Tanuki', maraudesRequired: 10, spritePath: 'assets/avatar/pets/mystique_tanuki.png'),
    AvatarItem(id: 'dino_stegosaure', label: 'Stegosaure', maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_stegosaure.png'),
    AvatarItem(id: 'dino_pterodactyle', label: 'Ptérodactyle', maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_pterodactyle.png'),
    AvatarItem(id: 'dino_brontosaure', label: 'Brontosaure', maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_brontosaure.png'),
    AvatarItem(id: 'dino_ankylosaure', label: 'Ankylosaure', maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_ankylosaure.png'),
    AvatarItem(id: 'dino_pachycephalosaure', label: 'Pachycephalosaure', maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_pachycephalosaure.png'),
    AvatarItem(id: 'marin_poulpe', label: 'Poulpe', maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_poulpe.png'),
    AvatarItem(id: 'marin_requin', label: 'Requin', maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_requin.png'),
    AvatarItem(id: 'marin_hippocampe', label: 'Hippocampe', maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_hippocampe.png'),
    AvatarItem(id: 'marin_crabe', label: 'Crabe', maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_crabe.png'),
    AvatarItem(id: 'marin_meduse', label: 'Méduse', maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_meduse.png'),
    AvatarItem(id: 'marin_tortue_mer', label: 'Tortue de mer', maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_tortue_mer.png'),
    AvatarItem(id: 'marin_narval', label: 'Narval', maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_narval.png'),
    AvatarItem(id: 'marin_etoile_mer', label: 'Étoile de mer', maraudesRequired: 15, spritePath: 'assets/avatar/pets/marin_etoile_mer.png'),
    AvatarItem(id: 'mythe_kappa', label: 'Kappa', maraudesRequired: 15, spritePath: 'assets/avatar/pets/mythe_kappa.png'),
    AvatarItem(id: 'mythe_yeti', label: 'Yeti', maraudesRequired: 15, spritePath: 'assets/avatar/pets/mythe_yeti.png'),
    AvatarItem(id: 'mythe_wolpertinger', label: 'Wolpertinger', maraudesRequired: 15, spritePath: 'assets/avatar/pets/mythe_wolpertinger.png'),
    AvatarItem(id: 'mythe_baku', label: 'Baku', maraudesRequired: 15, spritePath: 'assets/avatar/pets/mythe_baku.png'),
    AvatarItem(id: 'mystique_loup_spectral', label: 'Loup spectral', maraudesRequired: 15, spritePath: 'assets/avatar/pets/mystique_loup_spectral.png'),
    AvatarItem(id: 'dino_t_rex', label: 'T-Rex', maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_t_rex.png'),
    AvatarItem(id: 'dino_triceratops', label: 'Triceratops', maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_triceratops.png'),
    AvatarItem(id: 'dino_velociraptor', label: 'Velociraptor', maraudesRequired: 15, spritePath: 'assets/avatar/pets/dino_velociraptor.png'),
    AvatarItem(id: 'tier3_dragon_mini', label: 'Dragon miniature', maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_dragon_mini.png'),
    AvatarItem(id: 'tier3_licorne', label: 'Licorne', maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_licorne.png'),
    AvatarItem(id: 'tier3_phenix', label: 'Phénix', maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_phenix.png'),
    AvatarItem(id: 'tier3_renard_neuf_queues', label: 'Renard à neuf queues', maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_renard_neuf_queues.png'),
    AvatarItem(id: 'tier3_chat_aile', label: 'Chat ailé', maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_chat_aile.png'),
    AvatarItem(id: 'tier3_pegase', label: 'Pégase', maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_pegase.png'),
    AvatarItem(id: 'tier3_renard_celeste_bleu', label: 'Renard céleste bleu', maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier3_renard_celeste_bleu.png'),
    AvatarItem(id: 'tier4_griffon', label: 'Griffon', maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier4_griffon.png'),
    AvatarItem(id: 'tier4_hydre_mini', label: 'Hydre miniature', maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier4_hydre_mini.png'),
    AvatarItem(id: 'tier4_chimere', label: 'Chimère', maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier4_chimere.png'),
    AvatarItem(id: 'tier4_dragon_jade', label: 'Dragon de jade', maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier4_dragon_jade.png'),
    AvatarItem(id: 'tier4_serpent_plumes', label: 'Serpent à plumes', maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier4_serpent_plumes.png'),
    AvatarItem(id: 'tier5_phenix_dore', label: 'Phénix doré', maraudesRequired: 20, spritePath: 'assets/avatar/pets/tier5_phenix_dore.png'),
    AvatarItem(id: 'mythe_minotaure', label: 'Minotaure', maraudesRequired: 20, spritePath: 'assets/avatar/pets/mythe_minotaure.png'),
    AvatarItem(id: 'mythe_sphinx', label: 'Sphinx', maraudesRequired: 20, spritePath: 'assets/avatar/pets/mythe_sphinx.png'),
    AvatarItem(id: 'mythe_basilic', label: 'Basilic', maraudesRequired: 20, spritePath: 'assets/avatar/pets/mythe_basilic.png'),
    AvatarItem(id: 'mythe_manticore', label: 'Manticore', maraudesRequired: 20, spritePath: 'assets/avatar/pets/mythe_manticore.png'),
    AvatarItem(id: 'mystique_cerbere_mini', label: 'Cerbère miniature', maraudesRequired: 20, spritePath: 'assets/avatar/pets/mystique_cerbere_mini.png'),
    AvatarItem(id: 'badge_10_maraudes_tortue_sage', label: 'Tortue sage', spritePath: 'assets/avatar/pets/badge_10_maraudes_tortue_sage.png', badgeCondition: '10 maraudes clôturées'),
    AvatarItem(id: 'badge_500_repas_pelican', label: 'Pélican généreux', spritePath: 'assets/avatar/pets/badge_500_repas_pelican.png', badgeCondition: '500 repas sauvés cumulés'),
    AvatarItem(id: 'badge_recrutement_abeille_reine', label: 'Abeille reine', spritePath: 'assets/avatar/pets/badge_recrutement_abeille_reine.png', badgeCondition: 'A recruté 3 bénévoles'),
    AvatarItem(id: 'badge_maraude_culturelle_rossignol', label: 'Rossignol', spritePath: 'assets/avatar/pets/badge_maraude_culturelle_rossignol.png', badgeCondition: 'A participé à une maraude culturelle'),
    AvatarItem(id: 'badge_membre_1an_elephant', label: 'Éléphant vétéran', spritePath: 'assets/avatar/pets/badge_membre_1an_elephant.png', badgeCondition: 'Membre depuis 1 an'),
  ];

  static AvatarItem byId(String id) =>
      pets.firstWhere((item) => item.id == id, orElse: () => pets.first);
}
