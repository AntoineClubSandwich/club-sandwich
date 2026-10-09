-- Bug remonté par Antoine (2026-09-20) : côté tourneur, le bilan d'une
-- maraude terminée affiche 0 lot / 0 kg / 0 pièce et aucune distribution,
-- alors que la collecte a bien eu lieu. `Concert.collections` et
-- `Concert.distribution` viennent d'un embed PostgREST direct sur
-- `maraude_collections` / `maraude_distributions`, soumis à leur RLS -
-- or ces tables n'ont jamais eu de policy SELECT pour les tourneurs (seuls
-- les bénévoles sélectionnés/présents et les admins existent), donc
-- l'embed revient vide sans erreur.
--
-- Même correctif que 20260917000000 pour `concert_volunteers` : accès en
-- lecture seule, limité aux maraudes dont le tourneur est l'organisation
-- promotrice. L'UI prévoit déjà que le tourneur consulte le bilan
-- (`canViewReport`), c'est donc un trou de droits, pas un choix.

create policy "Promoters view collections of their maraudes"
on public.maraude_collections
for select
to authenticated
using (
  exists (
    select 1
    from public.concerts concert
    where concert.id = maraude_collections.concert_id
      and private.is_promoter_account_member(
        concert.promoter_organization_id,
        (select auth.uid())
      )
  )
);

create policy "Promoters view distribution of their maraudes"
on public.maraude_distributions
for select
to authenticated
using (
  exists (
    select 1
    from public.concerts concert
    where concert.id = maraude_distributions.concert_id
      and private.is_promoter_account_member(
        concert.promoter_organization_id,
        (select auth.uid())
      )
  )
);
