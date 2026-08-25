# Mascotte Club Sandwich

Asset vectoriel officiel de la mascotte Club Sandwich (le personnage
note-de-musique/livre). Vectorisés fidèlement à partir de
`assets_source/club_sandwich_reference.png` par traçage bitmap déterministe
(`potrace`) — aucune génération ni réinterprétation graphique. Correspondance
pixel mesurée contre la référence : 98,8 %, les ~1 % restants sont de
l'anti-aliasing de bord inhérent à tout aller-retour raster → vecteur →
raster, pas une forme modifiée.

## Assets

| Fichier | Description |
|---|---|
| `club_sandwich_mascot_blue.svg` | Mascotte officielle, note en bleu marque |

Le fichier utilise un `viewBox="0 0 548 665"` et deux groupes nommés :

- `#mascot-outline` — traits/silhouette noirs (`#000000`)
- `#mascot-note-accent` — la note de musique bleue

Aucun bitmap intégré ; compatible `flutter_svg`.

## Couleurs utilisées

| Rôle | Hex | Origine |
|---|---|---|
| Silhouette | `#000000` | échantillonné sur la référence |
| Note bleue | `#293283` | échantillonnée sur la référence ; identique à `AppColors.primary` (`lib/core/theme/app_theme.dart`) et `DsColors.secondary` (`lib/design_system/tokens/ds_colors.dart`) |

## Règles d'utilisation

- **Ne jamais redessiner, recolorier ou déformer la mascotte.** Toute nouvelle variante de couleur doit être
  produite par le même processus de traçage à partir de la référence, jamais
  dessinée à la main ni générée.
- Utiliser le widget `ClubSandwichMascot`
  (`lib/design_system/widgets/club_sandwich_mascot.dart`), pas les fichiers
  SVG directement, pour bénéficier du dimensionnement/API cohérents dans
  toute l'app.
- Respecter la zone de respiration native du dessin (le `viewBox` inclut déjà
  une marge) — ne pas recadrer davantage ni superposer d'éléments dessus.
- La note reste toujours bleue (`#293283`), conformément au logo associatif.
- Ne pas utiliser la mascotte comme icône fonctionnelle (bouton, statut) —
  c'est un élément de marque/illustration, pas une icône UI (utiliser
  `lib/design_system/icons/ds_icons.dart` pour ça).

## Provenance

Référence source : `assets_source/club_sandwich_reference.png` (548×665,
recadrage haute résolution du lockup `club sandwich` bleu). Traçage :
`potrace 1.16`, un calque bitmap par couleur (silhouette / accent),
coordonnées normalisées dans un repère pixel unique partagé par les deux
calques pour garantir leur alignement.
