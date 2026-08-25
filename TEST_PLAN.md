# Plan de recette V1

Ce plan s'exécute uniquement sur la préproduction. Il ne crée automatiquement
aucun compte ni aucune donnée. Chaque résultat doit être daté et associé au
SHA Git et à l'identifiant du deploy Netlify.

## 1. Critères d'entrée

- [ ] Le site Netlify de préproduction est distinct de la production.
- [ ] Le projet Supabase de préproduction est distinct de
      `hmfamvfrronbnznywtdk`.
- [ ] Toutes les migrations locales sont appliquées dans l'ordre.
- [ ] Les deux variables Supabase du build ciblent la préproduction.
- [ ] Le build contient exactement `APP_ENV=preprod`.
- [ ] La bannière `PRÉPRODUCTION` est visible dès la page de connexion.
- [ ] La bannière indique que les données peuvent être réinitialisées.
- [ ] Les validations automatiques de `DEPLOYMENT.md` sont vertes.
- [ ] La préproduction envoie une directive `noindex`.
- [ ] Aucun compte ou jeu de données de production n'a été copié.

## 2. Comptes de recette

| Compte | Affectation | Usage |
| --- | --- | --- |
| `admin@test.local` | admin Club Sandwich | gestion complète |
| `tourneur@test.local` | coordinateur Club Sandwich + membre producteur | publication avec producteur automatique |
| `benevole1@test.local` | bénévole Club Sandwich | candidat sélectionné et présent |
| `benevole2@test.local` | bénévole Club Sandwich | candidat sélectionné puis absent/désisté |
| `catering@test.local` | aucun membership | utilisateur extérieur et refus RLS |

`catering` n'est pas un rôle V1. Ce compte sert uniquement à vérifier qu'un
utilisateur authentifié extérieur ne peut pas lire les données métier. Aucun
droit artificiel ne doit lui être ajouté.

### Création manuelle

1. Dans Supabase Dashboard > Authentication > Users, créer les cinq comptes.
2. Utiliser des mots de passe uniques transmis hors Git.
3. Confirmer les comptes selon la politique Auth choisie.
4. Vérifier qu'une ligne `profiles` a été créée par le trigger pour chacun.
5. Exécuter le SQL ci-dessous dans le SQL Editor de la préproduction seulement.
6. Vérifier les résultats avant `commit`.

Adapter uniquement les noms de personnes et de l'organisation producteur :

```sql
begin;

select private.assign_club_sandwich_admin('admin@test.local');

insert into public.organizations (name, slug, kind)
values ('Producteur recette', 'producteur-recette', 'producer')
on conflict (slug) do update
set
  name = excluded.name,
  kind = excluded.kind;

with club as (
  select id
  from public.organizations
  where slug = 'club-sandwich'
),
producer as (
  select id
  from public.organizations
  where slug = 'producteur-recette'
),
users_by_email as (
  select id, lower(email) as email
  from auth.users
  where lower(email) in (
    'tourneur@test.local',
    'benevole1@test.local',
    'benevole2@test.local'
  )
)
insert into public.memberships (organization_id, profile_id, role)
select club.id, users_by_email.id,
  case
    when users_by_email.email = 'tourneur@test.local'
      then 'coordinator'::public.app_role
    else 'volunteer'::public.app_role
  end
from club
cross join users_by_email
on conflict (organization_id, profile_id)
do update set role = excluded.role;

insert into public.memberships (organization_id, profile_id, role)
select
  producer.id,
  users_by_email.id,
  'coordinator'::public.app_role
from public.organizations producer
join auth.users users_by_email
  on lower(users_by_email.email) = 'tourneur@test.local'
where producer.slug = 'producteur-recette'
on conflict (organization_id, profile_id)
do update set role = excluded.role;

update public.profiles profile
set
  first_name = values_to_apply.first_name,
  last_name = values_to_apply.last_name,
  phone = values_to_apply.phone
from (
  values
    ('admin@test.local', 'Alice', 'Admin', '+33100000001'),
    ('tourneur@test.local', 'Théo', 'Tourneur', '+33100000002'),
    ('benevole1@test.local', 'Béatrice', 'Présente', '+33100000003'),
    ('benevole2@test.local', 'Benoît', 'Absent', null),
    ('catering@test.local', 'Camille', 'Extérieur', null)
) as values_to_apply(email, first_name, last_name, phone)
join auth.users auth_user
  on lower(auth_user.email) = values_to_apply.email
where profile.id = auth_user.id;

select
  auth_user.email,
  profile.first_name,
  profile.last_name,
  organization.slug,
  membership.role
from auth.users auth_user
join public.profiles profile on profile.id = auth_user.id
left join public.memberships membership
  on membership.profile_id = auth_user.id
left join public.organizations organization
  on organization.id = membership.organization_id
where lower(auth_user.email) like '%@test.local'
order by auth_user.email, organization.slug;

-- Remplacer par COMMIT uniquement après vérification du SELECT.
rollback;
```

Au premier passage, garder `rollback`, inspecter le résultat, puis réexécuter la
transaction avec `commit`. Ne jamais exécuter ce script sur la production.

## 3. Scénario de données

Le scénario est créé exclusivement via l'interface, sauf la préparation des
comptes et memberships.

1. L'administrateur choisit une salle du référentiel de préproduction.
2. Le tourneur crée un concert futur :
   - artiste : `RECETTE V1`;
   - date : date future connue de l'équipe de recette ;
   - salle : salle choisie ;
   - fermeture catering : `23:00`;
   - notes : `Scénario de recette V1`.
3. Vérifier que le producteur est déterminé automatiquement.
4. Les deux bénévoles se proposent.
5. L'administrateur sélectionne les deux candidatures en une action.
6. Affecter un chef d'équipe et un conducteur.
7. Marquer le bénévole 1 présent et le bénévole 2 absent.
8. Démarrer la maraude.
9. Ajouter deux lots :
   - repas préparés, 25 pièces, poids facultatif ;
   - fruits et légumes, 2 caisses, poids renseigné.
10. Créer la distribution avec lieu, bénéficiaires, repas, horaires et un
    commentaire d'incident non sensible.
11. Terminer la maraude.
12. Ajouter le commentaire de clôture.
13. Exporter le PDF.

Utiliser un second concert de recette pour les scénarios de suppression,
absence de bénévole présent et désistement. Ne pas supprimer le scénario
principal avant la fin de la recette.

## 4. Authentification et navigation

- [ ] Un utilisateur non connecté arrive sur `/login`.
- [ ] Un deep link `/maraudes` non connecté redirige vers `/login`.
- [ ] Un deep link `/maraudes/<id>` non connecté redirige vers `/login`.
- [ ] Un e-mail invalide affiche une validation en français.
- [ ] Un mot de passe vide affiche une validation en français.
- [ ] Des identifiants invalides affichent un message non technique.
- [ ] Le bouton de connexion est désactivé pendant la requête.
- [ ] Une connexion valide ouvre le tableau de bord.
- [ ] La bannière de préproduction reste visible après connexion.
- [ ] Un rafraîchissement conserve la session.
- [ ] Un rafraîchissement sur `/maraudes/<id>` recharge la bonne fiche.
- [ ] Les boutons précédent/suivant du navigateur restent cohérents.
- [ ] Une URL de concert inexistante affiche l'état introuvable.
- [ ] Aucune route `/reset-password` n'est annoncée dans les e-mails.

Pour changer de compte, utiliser l'action de déconnexion du panneau de compte.
Des profils de navigateur distincts restent utiles pour une recette simultanée
de plusieurs rôles.

## 5. Concerts

- [ ] La liste gère chargement, erreur, état vide et succès.
- [ ] Les concerts futurs apparaissent avant les concerts passés.
- [ ] La création impose artiste, date et salle.
- [ ] La recherche de salle commence après deux caractères.
- [ ] La fermeture catering reste facultative.
- [ ] L'arrivée recommandée vaut fermeture moins 15 minutes.
- [ ] Un double clic ne crée pas deux concerts.
- [ ] La liste se rafraîchit après création.
- [ ] La modification conserve les valeurs après une erreur.
- [ ] La liste se rafraîchit après modification.
- [ ] La suppression demande une confirmation et décrit ses conséquences.
- [ ] L'annulation de la confirmation ne modifie rien.
- [ ] La liste se rafraîchit après suppression.
- [ ] Le producteur du compte tourneur est automatique.
- [ ] Le compte administrateur peut publier sans producteur.
- [ ] Un bénévole ne peut pas créer ou modifier un concert malgré l'affichage
      éventuel d'une action client.

## 6. Candidatures et profils

- [ ] Le bénévole 1 voit `Je me propose`.
- [ ] Une candidature créée est `En attente`.
- [ ] Une seconde candidature au même concert est refusée.
- [ ] `Je me désiste` conserve la ligne avec le statut `Désisté`.
- [ ] Un bénévole ne voit pas les candidatures des autres.
- [ ] L'administrateur voit les candidatures du concert.
- [ ] Les cartes affichent identité, téléphone disponible, permis et
      statistiques.
- [ ] Un profil incomplet reste lisible.
- [ ] Le dialogue détaillé affiche l'historique trié du plus récent au plus
      ancien.
- [ ] Les taux sont absents lorsque le nombre de candidatures est nul.
- [ ] Le compte extérieur ne peut lire aucun profil candidat.

## 7. Équipe, rôles et présences

- [ ] La sélection multiple est transactionnelle.
- [ ] Les candidatures retenues deviennent `Sélectionné`.
- [ ] Les autres décisions utilisent `Non sélectionné`.
- [ ] Un seul chef d'équipe peut être affecté.
- [ ] Plusieurs conducteurs peuvent être affectés.
- [ ] Un rôle ne peut être affecté qu'à une candidature sélectionnée.
- [ ] Une désélection ou un désistement retire automatiquement le rôle.
- [ ] La présence initiale d'un sélectionné est `En attente`.
- [ ] L'administrateur peut choisir `Présent` et `Absent`.
- [ ] Un non-sélectionné ne peut recevoir de présence.
- [ ] Une désélection retire automatiquement la présence.
- [ ] Les compteurs sélectionnés, présents, absents et en attente sont exacts.
- [ ] Un bénévole voit uniquement son propre rôle et sa propre présence.

## 8. Cycle de vie

- [ ] Un nouveau concert est en préparation.
- [ ] Le démarrage sans bénévole sélectionné présent est refusé.
- [ ] Le démarrage avec au moins un bénévole présent réussit.
- [ ] La date réelle de début est ajoutée automatiquement.
- [ ] Une maraude démarrée ne peut revenir en préparation.
- [ ] Une maraude démarrée peut être terminée.
- [ ] La date réelle de fin est ajoutée automatiquement.
- [ ] La fin est postérieure ou égale au début.
- [ ] Une maraude terminée ne peut revenir en cours.
- [ ] Un bénévole ne voit aucun bouton de transition.

## 9. Collecte

- [ ] La collecte vide affiche un état explicite.
- [ ] Un lot ne peut être ajouté qu'en cours de maraude.
- [ ] La quantité doit être strictement positive.
- [ ] Le poids éventuel doit être positif ou nul.
- [ ] Toutes les catégories enum sont sélectionnables.
- [ ] Toutes les unités enum sont sélectionnables.
- [ ] La création rafraîchit la synthèse.
- [ ] La modification rafraîchit la synthèse.
- [ ] La suppression demande confirmation.
- [ ] La suppression rafraîchit la synthèse.
- [ ] Nombre de lots, poids total et pièces sont exacts.
- [ ] Une maraude terminée est en lecture seule.
- [ ] Un membre présent peut lire les lots.
- [ ] Un bénévole extérieur ne peut pas les lire.

## 10. Distribution

- [ ] L'absence de fiche est explicite.
- [ ] La fiche ne peut être créée qu'en cours de maraude.
- [ ] Une seule distribution est possible par concert.
- [ ] Les valeurs numériques refusent les nombres négatifs.
- [ ] La fin ne peut précéder le début.
- [ ] La modification est possible pendant la maraude.
- [ ] La fiche est en lecture seule après clôture.
- [ ] Un membre présent peut la lire.
- [ ] Un bénévole extérieur ne peut pas la lire.

## 11. Bilan et PDF

- [ ] La carte Bilan n'apparaît que lorsque la maraude est terminée.
- [ ] Artiste, salle et date sont exacts.
- [ ] La durée réelle est exacte.
- [ ] Sélectionnés, présents et absents sont exacts.
- [ ] Nombre de lots, poids et pièces sont exacts.
- [ ] Toutes les données de distribution sont reprises.
- [ ] Le commentaire de clôture est modifiable uniquement après clôture.
- [ ] L'export génère un PDF ouvrable.
- [ ] Le PDF contient général, équipe, collecte, distribution et commentaire.
- [ ] Les accents français sont lisibles.
- [ ] `Élodie`, `Maël`, `Anaïs`, `Point Éphémère`, `œ` et `€` sont rendus
      correctement.
- [ ] Le nom de fichier ne divulgue aucune donnée sensible imprévue.
- [ ] Un membre présent peut consulter le bilan.
- [ ] Un absent, non-sélectionné ou extérieur ne peut pas le consulter.

## 12. Matrice de contrôle d'accès

| Action | Admin | Tourneur | Présent | Absent | Extérieur | Anonyme |
| --- | --- | --- | --- | --- | --- | --- |
| Voir ses concerts accessibles | oui | oui | selon RLS | selon RLS | non | non |
| Créer un concert | oui | oui avec producteur | non | non | non | non |
| Se proposer | possible | possible | oui | oui | selon accès concert | non |
| Voir toutes les candidatures | oui | non | non | non | non | non |
| Sélectionner et attribuer les rôles | oui | non | non | non | non | non |
| Gérer les présences | oui | non | non | non | non | non |
| Démarrer/terminer | oui | non | non | non | non | non |
| Modifier collecte/distribution | oui | non | non | non | non | non |
| Lire collecte/distribution terminée | oui | selon RLS | oui | non | non | non |
| Lire le bilan terminé | oui | selon RLS | oui | non | non | non |

Pour chaque refus :

- [ ] aucune donnée n'apparaît brièvement avant le refus ;
- [ ] la réponse réseau est 401/403 ou vide selon la policy ;
- [ ] aucun message SQL technique n'est affiché à l'utilisateur ;
- [ ] une mutation refusée ne modifie aucune ligne.

## 13. Responsive et accessibilité

Tester au minimum :

| Cible | Vue indicative |
| --- | --- |
| mobile compact | 360 × 800 |
| mobile large | 430 × 932 |
| tablette portrait | 768 × 1024 |
| tablette paysage | 1024 × 768 |
| desktop | 1440 × 900 |

Sur chaque cible :

- [ ] aucun overflow jaune/noir ;
- [ ] aucun scroll horizontal involontaire ;
- [ ] navigation Drawer/Rail adaptée ;
- [ ] dialogs accessibles sans dépasser la fenêtre ;
- [ ] clavier virtuel ne masque pas l'action principale ;
- [ ] cartes et textes longs restent lisibles ;
- [ ] menus d'actions restent dans le viewport ;
- [ ] zones tactiles sont suffisamment grandes ;
- [ ] navigation clavier suit un ordre logique ;
- [ ] focus visible sur champs, boutons, menus et liens ;
- [ ] labels et tooltips sont annoncés par le lecteur d'écran ;
- [ ] contraste contrôlé pour chips et états.

Navigateurs :

- [ ] Chrome stable desktop ;
- [ ] Safari stable desktop/iOS ;
- [ ] Firefox stable desktop ;
- [ ] Chrome Android si disponible.

## 14. États dégradés

- [ ] Réseau coupé pendant le chargement : état d'erreur, pas d'écran blanc.
- [ ] Réseau coupé pendant une mutation : message clair et données conservées.
- [ ] Réseau rétabli : le bouton Réessayer fonctionne.
- [ ] Session expirée : retour cohérent vers la connexion.
- [ ] Réponse Supabase vide : état vide ou introuvable.
- [ ] Erreur RPC métier : traduction en message français.
- [ ] Double soumission : une seule mutation réseau.
- [ ] Export PDF bloqué par le navigateur : message compréhensible.

## 15. Performance

Mesurer avec les DevTools du navigateur, cache désactivé puis activé :

- [ ] temps jusqu'au premier rendu de `/login` ;
- [ ] poids transféré au premier chargement ;
- [ ] nombre d'appels lors de l'ouverture de `/maraudes` ;
- [ ] nombre d'appels lors de l'ouverture d'un concert détaillé ;
- [ ] durée du chargement de la liste et du détail ;
- [ ] durée de génération du PDF ;
- [ ] absence de requête par carte concert, lot ou bénévole ;
- [ ] absence de requêtes en boucle ;
- [ ] absence de rebuild visible ou boucle de provider ;
- [ ] cache HTTP des assets statiques vérifié ;
- [ ] aucune exception dans la console.

Architecture attendue au moment de l'audit :

- liste des concerts : une requête jointe avec salle et producteur ;
- détail : concert, collectes et distribution préchargés ensemble ;
- section bénévoles : trois requêtes constantes (compteurs, droit admin,
  détails groupés), sans N+1.

Consigner les mesures :

| Vue | Requêtes | Transfert | Chargement | Console |
| --- | ---: | ---: | ---: | --- |
| Login |  |  |  |  |
| Concerts |  |  |  |  |
| Détail |  |  |  |  |
| Export PDF |  |  |  |  |

## 16. Sécurité

- [ ] Les assets ne contiennent aucune clé `service_role`.
- [ ] L'URL Supabase du build est celle de la préproduction.
- [ ] La clé publique du build appartient à la préproduction.
- [ ] Une valeur `APP_ENV` absente ou différente de `preprod` n'affiche aucune
      bannière.
- [ ] L'inscription publique Auth est désactivée si elle n'est pas utilisée.
- [ ] Les mots de passe de recette ne sont jamais écrits dans Git.
- [ ] Les tokens de session sont supprimés entre les profils de recette.
- [ ] Le stockage de session navigateur est accepté comme risque client et
      protégé par une politique anti-XSS.
- [ ] Toutes les tables publiques ont la RLS activée.
- [ ] Les RPC refusent les utilisateurs non autorisés.
- [ ] Aucun appel client ne contourne la RLS avec une clé d'administration.
- [ ] Le PDF ne contient que les données attendues.
- [ ] Les URL d'avatar externes ne chargent pas de domaine inattendu.
- [ ] HTTPS et HSTS sont actifs.
- [ ] La CSP en mode Report-Only ne bloque ni Flutter ni Supabase ni le PDF.
- [ ] La préproduction envoie `X-Robots-Tag: noindex, nofollow`.
- [ ] `/robots.txt` ne renvoie pas silencieusement l'application en production.

Le client `supabase_flutter` persiste par défaut la session dans le
`localStorage` du navigateur Web. Il faut donc traiter toute injection de script
comme un risque d'accès au token : CSP testée, dépendances à jour, absence de
HTML non fiable et recette systématique de la console.

## 17. Sortie de recette

- [ ] Toutes les anomalies bloquantes sont corrigées et retestées.
- [ ] Les anomalies non bloquantes sont documentées avec responsable et date.
- [ ] Le SHA Git testé est figé.
- [ ] L'identifiant du deploy Netlify est archivé.
- [ ] Le project ref Supabase de préproduction est archivé.
- [ ] Les résultats automatiques sont joints.
- [ ] Les comptes et données de recette restent uniquement en préproduction.
- [ ] La décision de passage en production est explicite.

## 18. Journal

| Date | Testeur | SHA | Deploy | Résultat | Anomalies |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |
