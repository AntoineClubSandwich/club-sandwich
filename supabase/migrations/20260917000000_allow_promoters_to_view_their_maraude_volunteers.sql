-- Bug remonté par Antoine (2026-09-17) : côté tourneur, la liste des
-- maraudes affiche toujours "0 bénévole" même quand une équipe est
-- confirmée. `concerts_screen.dart` compte les bénévoles sélectionnés à
-- partir d'un embed PostgREST (`volunteer_applications:concert_volunteers
-- (status)`) sur la liste des concerts, qui est soumis au RLS direct de
-- `concert_volunteers` - or ce RLS n'a jamais accordé de policy SELECT
-- aux tourneurs sur cette table (seuls "sa propre candidature" et "admin"
-- existaient depuis sa création). Les écrans qui marchent déjà pour les
-- tourneurs (bilan, équipe) passent tous par des RPC security definer
-- (get_promoter_concert_applications, get_concert_volunteer_counts) qui
-- font leur propre vérification et contournent ce trou - mais l'embed
-- direct de la liste n'a pas cette protection.
--
-- get_promoter_concert_applications expose déjà user_id/first_name/
-- last_name/avatar_url/team_role/status aux tourneurs pour leurs propres
-- maraudes : cette policy RLS leur donne un accès équivalent, pas plus
-- large que ce qui existe déjà par un autre chemin.

create policy "Promoters view applications for their maraudes"
on public.concert_volunteers
for select
to authenticated
using (
  exists (
    select 1
    from public.concerts concert
    where concert.id = concert_volunteers.concert_id
      and private.is_promoter_account_member(
        concert.promoter_organization_id,
        (select auth.uid())
      )
  )
);
