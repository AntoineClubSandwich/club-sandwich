# Déploiement de Club Sandwich

Ce document décrit la préparation d'une préproduction puis la promotion vers
la production. Il ne constitue pas une autorisation de déployer. Les commandes
qui écrivent sur un service distant doivent être exécutées uniquement après
validation explicite de la cible.

## 1. État audité le 24 août 2026

### Application

- Flutter `3.44.7`, Dart `3.12.2`.
- Configuration injectée à la compilation avec `APP_ENV`, `SUPABASE_URL` et
  `SUPABASE_ANON_KEY`.
- L'application refuse de démarrer lorsque l'une des deux valeurs est absente.
- Aucune clé `service_role` n'est utilisée par Flutter.
- Le build Web release local occupe environ 49 Mio non compressés. Le fichier
  `main.dart.js` pèse environ 4,77 Mio, 1,39 Mio en gzip et 1,02 Mio en Brotli.
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
- Routes publiques : `/login`, `/forgot-password`, `/reset-password` et
  `/activate`.
- Routes authentifiées principales : `/dashboard`, `/maraudes`,
  `/maraudes/:concertId`, `/invitations`, `/organizations`, `/venues`,
  `/volunteers`, `/administration`, `/profile` et `/account`, selon le rôle.
- La déconnexion est disponible depuis le panneau de compte du shell.
- Les anciennes routes `/concerts` redirigent vers `/maraudes` pour préserver
  les anciens liens.

### Supabase

- Le dossier local est initialisé et utilise PostgreSQL 17.
- Le lien CLI local pointe actuellement vers le project ref de préproduction
  `yyqjhncuttwjgqtnzeyb`.
- Le dépôt contient 89 migrations forward-only et 30 suites pgTAP déclarant
  455 assertions SQL/RLS.
- Les RPC couvrent notamment la visibilité des maraudes, la constitution des
  équipes, les présences, les crédits, les invitations, les documents et les
  exports.
- Cinq buckets Storage sont déclarés : `maraude-photos`,
  `volunteer-private-documents`, `document-templates`,
  `organization-private-documents` et `venue-photos`.
- Deux Edge Functions sont présentes : `admin-users` et
  `workflow-email-dispatch`.
- Les tests et le lint Supabase doivent être rejoués avec le daemon Docker
  actif avant toute publication.

### Netlify

- Le dossier local est lié au site Netlify d'identifiant
  `1355ec2b-525e-444e-bb07-777a1daa6ec8`.
- La préproduction publique est
  `https://club-sandwich-preprod.netlify.app`.
- La liaison Git exacte doit être contrôlée dans Netlify avant toute
  modification de configuration distante.
- La redirection SPA `/* -> /index.html` avec statut 200 est présente dans
  `netlify.toml` et `web/_redirects`.
- Les rafraîchissements de `/login`, `/maraudes` et
  `/maraudes/:concertId` répondent actuellement avec un statut HTTP 200.
- Les trois variables Netlify `APP_ENV`, `SUPABASE_URL` et
  `SUPABASE_ANON_KEY` sont requises par tout build distant reproductible. Leur
  présence doit être contrôlée sans afficher leurs valeurs.
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

1. Vérifier que le projet Supabase lié est bien la préproduction
   `yyqjhncuttwjgqtnzeyb`, distincte de `hmfamvfrronbnznywtdk`.
2. Vérifier que le site Netlify lié est bien la préproduction, distincte du
   site de production.
3. Renseigner sur cette cible les trois variables de compilation, avec
   `APP_ENV=preprod` et les valeurs du projet Supabase de préproduction.
4. Configurer dans Supabase Auth l'URL du site de préproduction et ses URL de
   redirection autorisées.
5. Créer manuellement les comptes de recette décrits dans `TEST_PLAN.md`.
6. Valider une stratégie de non-indexation pour la préproduction.
7. Fournir des icônes de marque validées avant la production.

Les buckets et Edge Functions doivent être configurés et recettés sur chaque
environnement au même titre que les migrations.

## 3. Séparation des environnements

| Environnement | Supabase | Netlify | Données |
| --- | --- | --- | --- |
| Local | stack Docker locale | `flutter run` | données locales jetables |
| Préproduction | `yyqjhncuttwjgqtnzeyb` | `club-sandwich-preprod` | comptes et scénario de recette |
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

Les migrations sont appliquées par ordre lexical de leur version à 14
chiffres. La liste courante ne doit pas être recopiée manuellement dans cette
documentation : elle évolue à chaque sprint. La vérifier directement avec :

```bash
find supabase/migrations -maxdepth 1 -name '*.sql' -print | sort
supabase migration list --linked
```

Les 89 versions locales sont uniques au 24 août 2026. Ne jamais renommer une
migration déjà appliquée.

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

Utiliser le site Netlify dédié à la préproduction. Le site
`exquisite-crostata-897514` reste la cible de production et ne doit pas être
utilisé pour la recette.

Deux stratégies sont possibles :

1. site lié au dépôt Git avec une branche de préproduction et une étape
   d'installation Flutter reproductible ;
2. build local validé puis upload manuel de `build/web`.

Le dépôt est préparé pour la première stratégie. Contrôler la liaison Git dans
Netlify avant de modifier la branche ou la commande de build.

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
- transmet les trois variables avec `--dart-define` ;
- publie `build-info.json` avec le SHA Netlify non sensible pour identifier le
  build servi ;
- génère uniquement en préproduction un `robots.txt` bloquant et l'en-tête
  `X-Robots-Tag: noindex, nofollow`.

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
- `/maraudes`;
- `/maraudes/<identifiant-existant>`;
- `/invitations`;
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
3. vérifier `/login`, `/maraudes` et un deep link de maraude ;
4. documenter le deploy restauré.

### Rollback base de données

Les migrations sont forward-only. Ne jamais modifier une migration déjà
appliquée et ne jamais lancer de reset. En cas de problème :

1. conserver la base et diagnostiquer ;
2. créer une migration corrective ;
3. utiliser une restauration Supabase/PITR uniquement après validation
   explicite et vérification de la sauvegarde ;
4. synchroniser le client Flutter avec le schéma restauré ou corrigé.
