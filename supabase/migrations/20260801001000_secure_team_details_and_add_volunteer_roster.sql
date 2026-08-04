-- Vue restreinte (sans donnée personnelle) permettant à tout bénévole de
-- consulter les candidatures déposées et les bénévoles déjà sélectionnés
-- sur une maraude qui lui est visible, avant de se positionner lui-même.
create function public.get_concert_volunteer_roster(
  requested_concert_id uuid
)
returns table (
  id uuid,
  user_id uuid,
  status public.concert_volunteer_status,
  team_role public.maraude_role,
  first_name text,
  last_name text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1
    from public.concerts concert
    where concert.id = requested_concert_id
      and private.is_active_user((select auth.uid()))
      and (
        private.is_club_sandwich_admin((select auth.uid()))
        or private.is_promoter_account_member(
          concert.promoter_organization_id,
          (select auth.uid())
        )
        or (
          private.is_volunteer_account((select auth.uid()))
          and (
            concert.maraude_status = 'open'::public.maraude_status
            or exists (
              select 1
              from public.concert_volunteers own_application
              where own_application.concert_id = concert.id
                and own_application.user_id = (select auth.uid())
            )
          )
        )
      )
  ) then
    raise exception 'Maraude inaccessible' using errcode = '42501';
  end if;

  return query
  select
    application.id,
    application.user_id,
    application.status,
    application.team_role,
    profile.first_name,
    profile.last_name
  from public.concert_volunteers application
  join public.profiles profile on profile.id = application.user_id
  where application.concert_id = requested_concert_id
    and application.status <> 'withdrawn'::public.concert_volunteer_status
  order by
    application.status = 'selected'::public.concert_volunteer_status desc,
    profile.last_name,
    profile.first_name;
end;
$$;

revoke all on function public.get_concert_volunteer_roster(uuid)
  from public, anon;
grant execute on function public.get_concert_volunteer_roster(uuid)
  to authenticated;

comment on function public.get_concert_volunteer_roster(uuid) is
  'Liste restreinte (prénom, nom, statut, rôle — aucune donnée '
  'personnelle) des candidatures d’une maraude, accessible à tout '
  'bénévole pouvant déjà voir la maraude.';
