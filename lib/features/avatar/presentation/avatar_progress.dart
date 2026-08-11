/// The badge-pill label shown under the avatar name, e.g. "Maraude
/// Warrior · 5 maraudes complétées" (per the Figma reference, node
/// 147:125). Purely cosmetic flavor text tied to the same maraude-count
/// tiers as [AvatarCatalogue]'s unlock thresholds.
String avatarTierLabel(int maraudesCompleted) {
  final tier = switch (maraudesCompleted) {
    0 => 'Nouveau bénévole',
    >= 1 && < 3 => 'Maraudeur',
    >= 3 && < 5 => 'Maraudeur confirmé',
    >= 5 && < 10 => 'Maraude Warrior',
    >= 10 && < 20 => 'Vétéran',
    >= 20 && < 50 => 'Légende',
    _ => 'Mythique',
  };
  final count = maraudesCompleted == 1
      ? '1 maraude complétée'
      : '$maraudesCompleted maraudes complétées';
  return '$tier · $count';
}
