-- Demande d'Antoine (2026-10-09) : le tourneur doit pouvoir voir l'e-mail
-- des bénévoles de sa maraude pour leur envoyer ensuite un QR code ou un
-- accès (badge, liste d'invités...) par e-mail.
--
-- get_promoter_concert_applications n'exposait jusqu'ici que nom/avatar/
-- statut/rôle. On ajoute la colonne `email` (lue dans auth.users, comme
-- get_concert_volunteer_team_details côté admin), mais uniquement pour les
-- bénévoles sélectionnés dans l'équipe : ce sont les seuls qui viendront
-- réellement et ont besoin d'un accès. Les candidats en attente, non
-- retenus ou désistés restent sans contact visible pour le tourneur
-- (minimisation RGPD - un tourneur est un tiers externe à Club Sandwich).
--
-- Le type de retour change : il faut drop puis recréer. La seule
-- appelante est get_concert_volunteer_bundle (plpgsql, résolution au
-- runtime), qui fait `to_jsonb(candidate)` et transmet donc la nouvelle
-- colonne au client sans modification.

drop function public.get_promoter_concert_applications(uuid);

create function public.get_promoter_concert_applications(
  requested_concert_id uuid
)
returns table (
  id uuid,
  concert_id uuid,
  user_id uuid,
  status public.concert_volunteer_status,
  team_role public.maraude_role,
  attendance_status public.volunteer_attendance_status,
  created_at timestamptz,
  updated_at timestamptz,
  first_name text,
  last_name text,
  avatar_url text,
  email text,
  total_applications bigint,
  selected_applications bigint,
  not_selected_applications bigint,
  withdrawn_applications bigint,
  last_selected_date date,
  history jsonb
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
      and private.is_promoter_account_member(
        concert.promoter_organization_id,
        (select auth.uid())
      )
  ) then
    raise exception 'Maraude inaccessible' using errcode = '42501';
  end if;

  return query
  select
    application.id,
    application.concert_id,
    application.user_id,
    application.status,
    application.team_role,
    application.attendance_status,
    application.created_at,
    application.updated_at,
    profile.first_name,
    profile.last_name,
    profile.avatar_url,
    case
      when application.status = 'selected'::public.concert_volunteer_status
        then account.email::text
    end,
    0::bigint,
    0::bigint,
    0::bigint,
    0::bigint,
    null::date,
    '[]'::jsonb
  from public.concert_volunteers application
  join public.profiles profile on profile.id = application.user_id
  left join auth.users account on account.id = application.user_id
  where application.concert_id = requested_concert_id
  order by application.created_at;
end;
$$;

revoke all on function public.get_promoter_concert_applications(uuid)
  from public, anon;
grant execute on function public.get_promoter_concert_applications(uuid)
  to authenticated;
