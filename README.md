# Club Sandwich

Application Flutter Web pour la gestion des opérations de récupération
alimentaire de Club Sandwich.

## Architecture

Le code suit une organisation feature-first :

```text
lib/
  core/       configuration, navigation, thème et Supabase
  features/   données, domaine et présentation par fonctionnalité
  shared/     composants visuels partagés
```

Riverpod fournit les dépendances et les états asynchrones, GoRouter gère les
routes et Supabase reste la source de vérité métier. Les règles critiques sont
garanties par les contraintes, triggers, RPC et policies RLS.

## Configuration

Supabase est configuré avec des variables de compilation afin qu'aucun secret
ne soit enregistré dans le dépôt :

```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://votre-projet.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=votre-cle-anon \
  --dart-define=APP_ENV=preprod
```

Les mêmes paramètres doivent être ajoutés à `flutter build web`.
`APP_ENV=preprod` affiche la bannière de recette. Toute valeur absente ou
différente de `preprod` est traitée comme `production`.

## Supabase distant

Le projet distant utilise la référence `hmfamvfrronbnznywtdk`.

Pour appliquer les migrations :

```sh
supabase login
supabase link --project-ref hmfamvfrronbnznywtdk
supabase db push
```

La commande `db push` applique uniquement les migrations absentes. Elle ne
réinitialise pas la base et ne supprime pas les données existantes.

Une migration déjà appliquée ne doit pas être modifiée. Toute correction est
ajoutée dans une nouvelle migration horodatée. Pour vérifier localement :

```sh
supabase migration up --local
supabase test db
```

## Initialiser le premier administrateur

1. Créer le compte utilisateur dans Supabase Authentication.
2. Ouvrir le SQL Editor du projet.
3. Exécuter la requête suivante avec l'adresse réelle du compte :

```sql
select private.assign_club_sandwich_admin(
  'administrateur@example.com'
);
```

La procédure retrouve l'utilisateur par son adresse, crée ou met à jour son
membership pour l'organisation `Club Sandwich`, et ne nécessite aucun UUID
enregistré dans Git.

## Conventions d'interface

- composants et couleurs issus du thème Material 3 global ;
- dialogues compacts, défilables et utilisables au clavier ;
- confirmation explicite avant toute action irréversible ;
- message utilisateur après chaque mutation importante ;
- états de chargement, vide et erreur pour les données asynchrones ;
- libellés et erreurs affichés en français.

## Qualité

La validation complète du projet s'exécute avec :

```sh
dart format lib test
flutter analyze
flutter test
supabase test db
flutter build web --release
git diff --check
```

Les tests Flutter couvrent les modèles, repositories, providers, écrans,
formulaires, routes, états responsive et génération PDF. Les tests pgTAP
vérifient les contraintes SQL, les transitions métier et les règles RLS.

## Préproduction

La préparation des environnements, l'application contrôlée des migrations et
le rollback sont décrits dans [DEPLOYMENT.md](DEPLOYMENT.md). La recette
fonctionnelle, responsive, de performance et de sécurité est détaillée dans
[TEST_PLAN.md](TEST_PLAN.md).
