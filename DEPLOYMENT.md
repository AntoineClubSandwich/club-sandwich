# Déploiement de Club Sandwich

Ce document décrit la préparation d'une préproduction puis la promotion vers
la production. Il ne constitue pas une autorisation de déployer. Les commandes
qui écrivent sur un service distant doivent être exécutées uniquement après
validation explicite de la cible.

## 1. État audité le 27 juillet 2026

### Application

- Flutter `3.44.7`, Dart `3.12.2`.
- Configuration injectée à la compilation avec `APP_ENV`, `SUPABASE_URL` et
  `SUPABASE_ANON_KEY`.
- L'application refuse de démarrer lorsque l'une des deux valeurs est absente.
- Aucune clé `service_role` n'est utilisée par Flutter.
- Le build Web release local occupe 43 Mio non compressés. Le fichier
  `main.dart.js` pèse environ 4,2 Mio, 1,23 Mio en gzip et 0,91 Mio en Brotli.
  Les fichiers CanvasKit/Wasm constituent l'essentiel du reste et le navigateur
  n'en charge pas toutes les variantes.
- Le test de génération PDF réussit avec Noto Sans Regular et Bold embarquées
  sous licence SIL OFL. Aucun téléchargement de police n'est réalisé pendant
  l'export en dehors des assets de l'application. Les deux polices représentent
  environ 1,15 Mio bruts et 0,57 Mio en gzip ; elles sont chargées lors de
  l'export PDF.
- `APP_ENV=preprod` affiche une bannière persistante au-dessus de
  l'application. Toute valeur absente, inconnue ou mal orthographiée est
  interprétée comme `production`.
- Les routes Web sont protégées par l'état d'authentification.
- Routes publiques connues : `/login`.
- Routes authentifiées principales : `/dashboard`, `/concerts`,
  `/concerts/:concertId`, `/operations`, `/volunteers`, `/venues`,
  `/settings`.
- Il n'existe pas encore de route de récupération de mot de passe ni d'action
  de déconnexion. La recette multi-comptes doit donc utiliser des profils de
  navigateur séparés ou supprimer les données du site entre deux comptes.

### Supabase

- Le dossier local est initialisé et utilise PostgreSQL 17.
- Le lien CLI local pointe actuellement vers le project ref de production
  `hmfamvfrronbnznywtdk`.
- Dix tables publiques sont présentes localement et ont toutes la RLS activée.
- Le catalogue local contient 9 enums, 14 triggers et 34 policies.
- Les RPC consommées par Flutter sont :
  - `get_concert_volunteer_counts`;
  - `get_concert_volunteer_team_details`;
  - `select_concert_volunteers`;
  - `start_maraude`;
  - `complete_maraude`.
- `get_concert_volunteer_details` est encore exposée mais n'est pas appelée par
  le client Flutter actuel. Elle n'est pas supprimée : son inutilité n'est pas
  démontrée pour d'éventuels clients externes.
- Aucun bucket Storage n'est déclaré et aucun appel Storage n'est présent dans
  Flutter. `avatar_url` est une URL stockée en base.
- Aucune Edge Function n'est présente.
- `supabase db lint --local --level warning` ne signale aucune anomalie.

### Netlify

- Le dossier local est lié au site
  `https://exquisite-crostata-897514.netlify.app`.
- Ce site n'est relié à aucun dépôt Git dans Netlify. Les publications sont
  donc manuelles.
- Le site existant est un environnement à préserver, pas une préproduction.
- La redirection SPA `/* -> /index.html` avec statut 200 est présente dans
  `netlify.toml` et `web/_redirects`.
- Les rafraîchissements de `/login`, `/concerts` et
  `/concerts/:concertId` répondent actuellement avec un statut HTTP 200.
- Seule la variable Netlify `SUPABASE_URL` est définie sur le site existant.
  `APP_ENV` et `SUPABASE_ANON_KEY` doivent être ajoutées avant tout build
  distant reproductible.
- Le dépôt fournit désormais `scripts/netlify-build.sh` et configure
  `bash scripts/netlify-build.sh` comme commande Netlify. Le script installe
  Flutter `3.44.7` stable dans un cache isolé avant de construire
  `build/web`.
- HSTS est fourni par Netlify. Aucune CSP, `Permissions-Policy`,
  `Referrer-Policy` ou politique `X-Robots-Tag` spécifique n'est configurée.
- `robots.txt` est absent et tombe actuellement sur le fallback SPA.
- Le favicon et les icônes PWA sont encore les ressources Flutter par défaut.
  Leur remplacement nécessite une ressource de marque validée.

### Dépendances

- Toutes les dépendances directes sont résolues et compatibles avec le SDK.
- `flutter_riverpod` est verrouillé en `3.3.2`; la version `3.4.1` est
  disponible et résoluble avec les contraintes actuelles.
- Aucune mise à niveau n'est réalisée dans ce sprint afin de ne pas modifier le
  comportement d'une version recettée. La mise à jour Riverpod doit faire
  l'objet d'un changement isolé avec exécution de toute la suite de tests.

## 2. Points bloquants avant une préproduction

1. Créer un projet Supabase de préproduction distinct de
   `hmfamvfrronbnznywtdk`.
2. Créer ou désigner un site Netlify de préproduction distinct du site
   existant. Ne jamais utiliser le site existant pour la première recette.
3. Renseigner sur cette cible les trois variables de compilation, avec
   `APP_ENV=preprod` et les valeurs du projet Supabase de préproduction.
4. Configurer dans Supabase Auth l'URL du site de préproduction et ses URL de
   redirection autorisées.
5. Créer manuellement les comptes de recette décrits dans `TEST_PLAN.md`.
6. Valider une stratégie de non-indexation pour la préproduction.
7. Fournir des icônes de marque validées avant la production.

Les absences de Storage et d'Edge Functions ne sont pas bloquantes : aucune
fonctionnalité V1 ne les utilise.

## 3. Séparation des environnements

| Environnement | Supabase | Netlify | Données |
| --- | --- | --- | --- |
| Local | stack Docker locale | `flutter run` | données locales jetables |
| Préproduction | projet dédié | site dédié | comptes et scénario de recette |
| Production | `hmfamvfrronbnznywtdk` | `exquisite-crostata-897514` | données réelles |

La préproduction doit avoir le même schéma et le même build que la production,
mais jamais les mêmes données ni les mêmes identifiants Supabase.

## 4. Variables et secrets

Variables requises par le build Netlify :

```text
APP_ENV
SUPABASE_URL
SUPABASE_ANON_KEY
```

Valeur de préproduction :

```text
APP_ENV=preprod
```

Seule la valeur exacte `preprod` active la bannière. La production peut omettre
`APP_ENV` ou utiliser explicitement `APP_ENV=production`.

Malgré son nom historique, `SUPABASE_ANON_KEY` doit contenir la **Publishable
key** du projet Supabase. Elle est nécessaire au client Web et sera donc
présente dans les fichiers compilés. Sa sécurité repose sur la RLS. Ne jamais
y placer une **Secret key**, une clé `service_role` ou un autre secret
d'administration.

Les fichiers `.env` et `.env.*` sont ignorés par Git. Aucun chargeur dotenv
n'est utilisé par l'application : les valeurs sont transmises par
`--dart-define`.

Exemple local, avec des valeurs de préproduction déjà exportées dans le shell :

```bash
flutter run -d chrome --web-port 3000 \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_ENV=preprod
```

Vérifier uniquement la présence des variables, sans afficher leur valeur :

```bash
test -n "$SUPABASE_URL"
test -n "$SUPABASE_ANON_KEY"
test -n "$APP_ENV"
```

Dans Netlify, créer les mêmes noms pour le contexte de préproduction. La clé
publique peut être injectée au build ; aucun secret d'administration Supabase
ne doit être ajouté au site. Définir également `APP_ENV=preprod` sur la cible
de préproduction.

## 5. Préparation Supabase

### 5.1 Créer la cible

Créer manuellement un projet Supabase dédié et relever :

- son project ref ;
- son URL API ;
- sa clé publique/publishable ;
- sa version majeure PostgreSQL.

La version PostgreSQL doit être compatible avec `major_version = 17` dans
`supabase/config.toml`.

### 5.2 Protéger la production avant de relier la CLI

Le dépôt est actuellement lié à la production. Avant toute commande distante,
définir et contrôler explicitement la nouvelle cible :

```bash
export SUPABASE_PREPROD_PROJECT_REF="<project-ref-preproduction>"
supabase link --project-ref "$SUPABASE_PREPROD_PROJECT_REF"
test "$(cat supabase/.temp/project-ref)" = "$SUPABASE_PREPROD_PROJECT_REF"
```

Si le dernier contrôle échoue, arrêter immédiatement. Ne jamais exécuter
`supabase db push` sans ce contrôle.

### 5.3 Contrôler puis appliquer les migrations

```bash
supabase migration list --linked
supabase db push --linked --dry-run
```

Lire la liste annoncée, vérifier qu'elle contient uniquement les migrations
attendues, puis seulement après validation :

```bash
supabase db push --linked
supabase migration list --linked
```

Ne jamais utiliser `supabase db reset` sur une base distante. Ne pas ajouter
`--include-seed` : aucun seed n'est prévu.

### 5.4 Ordre des migrations

Les 18 migrations locales sont uniques et s'appliquent dans cet ordre :

1. `20260724000000_create_foundation.sql`
2. `20260724001000_initialize_users.sql`
3. `20260724002000_create_concerts.sql`
4. `20260724003000_reconcile_profile_policies.sql`
5. `20260724004000_add_venues_and_concert_workflow.sql`
6. `20260725000000_add_concert_contacts.sql`
7. `20260725001000_create_concert_volunteers.sql`
8. `20260725002000_add_volunteer_profiles.sql`
9. `20260725003000_add_volunteer_history.sql`
10. `20260725004000_finalize_volunteer_history_access.sql`
11. `20260727000000_add_maraude_team_roles.sql`
12. `20260727001000_preserve_existing_team_roles.sql`
13. `20260727002000_add_volunteer_attendance.sql`
14. `20260727003000_add_maraude_lifecycle.sql`
15. `20260727004000_create_maraude_collections.sql`
16. `20260727005000_create_maraude_distributions.sql`
17. `20260727006000_add_maraude_report.sql`
18. `20260727007000_finalize_maraude_report_access.sql`

Les deux derniers identifiants utilisent `006000` et `007000`. Ils sont
acceptés comme versions par la CLI et leur ordre lexical est correct, mais les
segments minutes `60` et `70` ne sont pas des heures valides. Ne pas renommer
ces migrations si elles ont été appliquées sur un environnement : toute
correction future doit être une nouvelle migration.

Les redéfinitions successives des RPC d'équipe et d'historique sont
intentionnelles : les migrations ultérieures remplacent les versions
précédentes. Aucun doublon actif n'a été trouvé dans le catalogue local.

La migration `20260724004000_add_venues_and_concert_workflow.sql` insère le
référentiel initial de salles. C'est la seule donnée de référence créée pendant
la migration ; aucun compte, concert ou scénario de recette n'est créé.

### 5.5 Authentification

Dans les paramètres Auth de la préproduction :

- définir `Site URL` avec l'URL HTTPS exacte du site Netlify de préproduction ;
- ajouter cette même origine aux redirect URLs ;
- désactiver l'inscription publique si les comptes sont gérés manuellement ;
- choisir une politique de mot de passe adaptée à la recette et à la
  production ;
- vérifier la rotation des refresh tokens ;
- ne pas configurer de redirect `/reset-password` tant que cette route
  n'existe pas dans Flutter.

La création d'un utilisateur Auth déclenche automatiquement la création de son
`profile`. L'affectation des memberships reste manuelle et est décrite dans
`TEST_PLAN.md`.

## 6. Préparation Netlify

Créer un site Netlify dédié à la préproduction. Le site
`exquisite-crostata-897514` ne doit pas être réutilisé.

Deux stratégies sont possibles :

1. site lié au dépôt Git avec une branche de préproduction et une étape
   d'installation Flutter reproductible ;
2. build local validé puis upload manuel de `build/web`.

Le dépôt est préparé pour la première stratégie. Le site Netlify existant reste
actuellement non lié à Git : cette liaison sera une action distante séparée.

### Build Git automatique

`netlify.toml` contient :

```toml
[build]
  command = "bash scripts/netlify-build.sh"
  publish = "build/web"
```

Le script :

- utilise exclusivement Flutter `3.44.7` stable ;
- clone le SDK dans `NETLIFY_CACHE_DIR` lorsque cette variable existe, sinon
  dans un dossier temporaire ;
- ajoute `flutter/bin` au `PATH` ;
- active Flutter Web et résout les dépendances ;
- refuse le build si l'une des trois variables Netlify est absente ou vide ;
- ne journalise jamais leur valeur ;
- transmet les trois variables avec `--dart-define`.

Commande exécutée automatiquement par Netlify :

```bash
bash scripts/netlify-build.sh
```

### Build local équivalent

```bash
APP_ENV=preprod \
SUPABASE_URL="$SUPABASE_URL" \
SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
bash scripts/netlify-build.sh
```

Contrôler le contenu avant envoi :

```bash
test -f build/web/index.html
test -f build/web/flutter_bootstrap.js
test -f build/web/_redirects
du -sh build/web
```

Lorsqu'un déploiement sera explicitement autorisé, publier uniquement sur le
site de préproduction :

```bash
netlify deploy \
  --site "$NETLIFY_PREPROD_SITE_ID" \
  --dir build/web \
  --prod \
  --no-build
```

`--prod` désigne ici l'URL stable du site de préproduction, pas le site de
production Club Sandwich. Vérifier l'identifiant de site avant la commande.

### SPA et deep links

Les deux configurations suivantes doivent rester présentes :

```toml
[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

```text
/* /index.html 200
```

Après publication de la préproduction, tester directement puis rafraîchir :

- `/login`;
- `/dashboard`;
- `/concerts`;
- `/concerts/<identifiant-existant>`;
- `/volunteers`;
- `/venues`;
- `/settings`.

### Indexation et en-têtes

La préproduction doit envoyer :

```text
X-Robots-Tag: noindex, nofollow
```

Cette règle doit être configurée uniquement sur le site ou le contexte de
préproduction. Ne pas ajouter un `robots.txt` bloquant commun aux builds de
production.

La CSP doit d'abord être testée en `Content-Security-Policy-Report-Only`. Elle
doit autoriser au minimum l'origine Supabase de préproduction, ses connexions
HTTPS/WebSocket et les besoins réels du moteur Flutter/PDF. Une CSP stricte ne
doit pas être activée sans recette navigateur, car elle peut bloquer le
bootstrap Flutter ou l'export PDF.

## 7. Vérifications avant publication

```bash
dart format lib test
flutter analyze
flutter test
supabase test db
supabase db lint --local --level warning
APP_ENV=preprod \
SUPABASE_URL="$SUPABASE_URL" \
SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
bash scripts/netlify-build.sh
git diff --check
```

Le script Netlify refuse immédiatement un build auquel il manque une des trois
variables. L'application conserve en plus son repli défensif :
une valeur `APP_ENV` inconnue se comporte comme `production`.

## 8. Vérifications post-déploiement

1. Vérifier l'URL et l'identifiant du site Netlify.
2. Vérifier que la page de connexion est celle de Club Sandwich.
3. Vérifier que la bannière `PRÉPRODUCTION` est visible avant et après
   connexion.
4. Contrôler les deep links et les rafraîchissements.
5. Se connecter avec chaque profil de recette.
6. Exécuter l'intégralité de `TEST_PLAN.md`.
7. Vérifier la console navigateur : aucune exception non gérée.
8. Vérifier le panneau Réseau : aucune requête vers le project ref de
   production.
9. Contrôler que seules les clés publiques apparaissent dans les assets.
10. Vérifier les en-têtes de non-indexation de la préproduction.
11. Archiver le SHA Git, les versions Flutter/Supabase CLI et l'identifiant du
    deploy Netlify recetté.

## 9. Promotion et rollback

### Promotion

La production doit recevoir exactement :

- le SHA Git recetté ;
- les mêmes versions d'outils ;
- les mêmes migrations ;
- le même build, recompilé uniquement avec les variables de production.

Contrôler à nouveau le project ref avant toute migration ou publication.

### Rollback applicatif

Netlify conserve les deploys immuables. En cas de régression :

1. arrêter les écritures si la compatibilité de schéma est en doute ;
2. republier depuis l'interface Netlify le dernier deploy sain ;
3. vérifier `/login`, `/concerts` et un deep link de concert ;
4. documenter le deploy restauré.

### Rollback base de données

Les migrations sont forward-only. Ne jamais modifier une migration déjà
appliquée et ne jamais lancer de reset. En cas de problème :

1. conserver la base et diagnostiquer ;
2. créer une migration corrective ;
3. utiliser une restauration Supabase/PITR uniquement après validation
   explicite et vérification de la sauvegarde ;
4. synchroniser le client Flutter avec le schéma restauré ou corrigé.
