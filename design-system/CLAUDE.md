# Club Sandwich — Refonte Graphique (Bento Soft Modern)

> Référence de design pour le style "Bento Soft Modern" de l'app Club
> Sandwich. Ce fichier documente l'intention ; la source de vérité
> exécutable reste `lib/design_system/tokens/*.dart` (Flutter/Dart —
> cette app n'utilise ni CSS ni Tailwind, ces valeurs sont portées en
> constantes Dart, pas copiées telles quelles).

## Direction artistique

Style : Bento Soft Modern — coins généreux, ombres douces, profondeur
subtile, premium sans être corporate. Inspirations : Linear, Raycast,
Arc Browser.

## Palette de couleurs

### Principales
- `primary` (encre) : `#1A1A2E` (deep indigo-black)
- `primary-light` : `#2D2B55`
- `secondary` (violet — CTA, interactions) : `#6C5CE7`
- `secondary-light` : `#A29BFE`
- `accent` (mint-teal) : `#00D2A0` — non utilisé actuellement (voir
  note ci-dessous sur le conflit avec `success`)
- `accent-light` : `#55EFC4`

> Note : dans `DsColorTokens` (Dart), les rôles sont nommés à
> l'inverse — `colors.primary` = le violet interactif `#6C5CE7`
> (couleur des CTA), `colors.secondary` = l'encre `#1A1A2E` (contour
> neutre). Les *valeurs* correspondent, seul le *nom* diffère —
> pas de renommage prévu, `colors.primary` est déjà la bonne couleur
> pour tout bouton/action principale.

### Fonds
- `bg-page` : `#F8F7F4` (warm white — déjà en place, ne pas toucher)
- `bg-card` : `#FFFFFF`
- `bg-subtle` : `#F1F0ED`
- `bg-dark` : `#1A1A2E`

### Textes
- `text-primary` : `#1A1A2E`
- `text-secondary` : `#6B7280`
- `text-muted` : `#9CA3AF`
- `text-inverse` : `#FFFFFF`
- `text-link` : `#6C5CE7`

### Fonctionnelles (base / bg / text)
- `success` : `#34D399` / bg `#ECFDF5` / text `#059669`
- `warning` : `#FBBF24` / bg `#FFFBEB` / text `#D97706`
- `error` : `#EF4444` / bg `#FEF2F2` / text `#DC2626`
- `info` : `#60A5FA` / bg `#EFF6FF` / text `#2563EB`

## Typographie

Police unique : Inter.

| Style | Taille | Poids | Line-height | Tracking |
|---|---|---|---|---|
| H1 | 32px | Bold | 40px | -0.02em |
| H2 | 24px | Semibold | 32px | -0.01em |
| H3 | 18px | Semibold | 28px | — |
| Body | 15px | Regular | 24px | — |
| Body small | 13px | Regular | 20px | — |
| Label | 11px | Medium, uppercase | — | 0.05em |
| Stat large | 36px | Bold, tabular-nums | — | -0.02em |
| Stat moyen | 24px | Bold, tabular-nums | — | — |

## Radius / Ombres / Bordures

Radius : sm 8px, md 12px, lg 16px, xl 24px, full 9999px.

Ombres :
- `shadow-card` : `0 2px 8px rgba(0,0,0,0.06), 0 0 1px rgba(0,0,0,0.1)`
- `shadow-md` : `0 4px 12px rgba(0,0,0,0.08)`
- `shadow-lg` : `0 8px 24px rgba(0,0,0,0.12)`

Bordures : 1px solid `#E5E7EB` (défaut), focus 2px solid `#6C5CE7` +
ring `rgba(108,92,231,0.1)`.

## Corrections par page

### Sidebar (toutes les pages)
Garder le fond sombre — ne pas passer en blanc.
- Fond : `#1A1A2E` (indigo profond, pas violet vif)
- Items nav : texte `#A1A1AA`, icônes outline 1.5px
- Item actif : fond `rgba(108,92,231,0.15)`, texte blanc, weight 600
- Hover : fond `rgba(255,255,255,0.05)`
- Bouton "Se déconnecter" : ghost discret, pas violet plein

### Dashboard
- Header "BONJOUR" : pas de gradient violet — carte blanche
  (shadow-card, radius 16px), texte H1 noir, badge ADMIN en pill
  (bg `#F5F3FF` text `#6C5CE7`).
- Stat cards : garder bordures existantes + ajouter shadow-card,
  radius 16px, label 11px uppercase muted, chiffre 36px Bold
  tabular-nums.
- Actions rapides : "Nouvelle maraude" bg `#6C5CE7` text blanc radius
  12px (pas vert) ; les autres bg blanc, border 1px `#E5E7EB`, radius
  12px ; hover translateY(-1px) + shadow-md.
- Activité récente : garder les carrés arrondis teintés avec emoji
  (pas de remplacement par icônes Lucide) ; badges dates en pill
  bg `#F5F3FF` text `#6C5CE7` (pas violet plein saturé).

### Maraudes
- Toggle Liste/Calendrier : container bg `#F1F0ED` padding 4px radius
  12px ; tab active bg blanc + shadow-sm + radius 8px ; tab inactive
  transparent, text-secondary.
- Bouton "+ Nouvelle maraude" : bg `#6C5CE7` text blanc (pas
  vert/teal), radius 12px.
- Cartes maraudes : garder bordures + ajouter shadow-card, radius
  16px, bordure neutre `#E5E7EB` (pas vert), titre H3 18px Semibold.
- Badges statuts : pills **pleines** (bg + texte coloré, pas outline) :
  "Terminé"/"Ouverte" bg `#ECFDF5` text `#059669` ; "Équipe incomplète"
  bg `#FFFBEB` text `#D97706` ; "Annulée" bg `#FEF2F2` text `#DC2626` ;
  "Maraude culturelle" bg `#F5F3FF` text `#7C3AED`.
- Filtres : accordéon radius 12px, bordure subtile.

## 10 règles

1. Fond de page = `#F8F7F4` (déjà en place)
2. Sidebar = sombre `#1A1A2E` (ne pas passer en blanc)
3. Cartes = garder bordures + ajouter shadow-card
4. Icônes activité = garder carrés arrondis teintés avec emoji
5. Police unique : Inter
6. Radius minimum 8px — jamais de coins carrés
7. Couleur interactive = `#6C5CE7` (violet) — pas vert pour les boutons
8. Vert/teal = réservé aux statuts succès/terminé/ouvert
9. Badges = pills pleines (bg + texte coloré), pas outline
10. Transitions 200ms ease sur tout élément interactif
