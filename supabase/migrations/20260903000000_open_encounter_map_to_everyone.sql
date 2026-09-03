-- Product decision: encounters carry no beneficiary data at all
-- ("Aucune donnée sur les bénéficiaires", 20260825003000's table
-- comment) - there's no privacy reason to restrict the map to admins or
-- to a volunteer's own maraudes. Opens it to every active account.
--
-- Retires yesterday's get_my_encounter_map (20260902000000) - it's
-- redundant now that the admin map itself is open to everyone, and
-- keeping two near-identical functions in sync is its own source of
-- future bugs.

create or replace function public.get_admin_encounter_map(
  requested_from timestamptz,
  requested_to timestamptz,
  requested_maraude_id uuid default null,
  requested_venue_id uuid default null,
  requested_created_by uuid default null
)
returns table (
  id uuid,
  maraude_id uuid,
  latitude double precision,
  longitude double precision,
  accuracy double precision,
  created_at timestamptz,
  maraude_date date,
  artist text,
  venue_id uuid,
  venue_name text,
  created_by uuid,
  created_by_name text,
  team_names text[]
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_active_user((select auth.uid())) then
    raise exception 'Carte des rencontres inaccessible'
      using errcode = '42501';
  end if;

  if requested_from is null
    or requested_to is null
    or requested_to <= requested_from
  then
    raise exception 'Période invalide' using errcode = '22023';
  end if;

  return query
  select
    encounter.id,
    encounter.maraude_id,
    encounter.latitude::double precision,
    encounter.longitude::double precision,
    encounter.accuracy::double precision,
    encounter.created_at,
    concert.concert_date,
    concert.artist,
    venue.id,
    venue.name,
    encounter.created_by,
    coalesce(
      nullif(
        btrim(concat_ws(' ', creator.first_name, creator.last_name)),
        ''
      ),
      'Utilisateur'
    ),
    coalesce(team.names, array[]::text[])
  from public.encounters encounter
  join public.concerts concert on concert.id = encounter.maraude_id
  join public.venues venue on venue.id = concert.venue_id
  join public.profiles creator on creator.id = encounter.created_by
  left join lateral (
    select array_agg(
      coalesce(
        nullif(btrim(concat_ws(' ', profile.first_name, profile.last_name)), ''),
        'Bénévole'
      )
      order by profile.first_name, profile.last_name
    ) as names
    from public.concert_volunteers member
    join public.profiles profile on profile.id = member.user_id
    where member.concert_id = encounter.maraude_id
      and member.status = 'selected'::public.concert_volunteer_status
  ) team on true
  where encounter.created_at >= requested_from
    and encounter.created_at < requested_to
    and (
      requested_maraude_id is null
      or encounter.maraude_id = requested_maraude_id
    )
    and (
      requested_venue_id is null
      or concert.venue_id = requested_venue_id
    )
    and (
      requested_created_by is null
      or encounter.created_by = requested_created_by
    )
  order by encounter.created_at desc
  limit 5000;
end;
$$;

revoke all on function public.get_admin_encounter_map(
  timestamptz, timestamptz, uuid, uuid, uuid
) from public, anon;
grant execute on function public.get_admin_encounter_map(
  timestamptz, timestamptz, uuid, uuid, uuid
) to authenticated;

drop function if exists public.get_my_encounter_map(timestamptz, timestamptz);
