-- Volunteers currently have no way to see the encounters map at all
-- (get_admin_encounter_map is admin-only, and the client never routes
-- non-admins to /encounters-map). The underlying RLS select policy on
-- public.encounters already lets a volunteer read encounters for any
-- maraude they were selected on ("Operational team can view maraude
-- encounters", 20260825003000) - this just exposes that same scope
-- through an aggregate RPC mirroring get_admin_encounter_map's shape, so
-- the existing map screen can reuse all of its filtering/rendering code
-- unchanged for volunteers.

create function public.get_my_encounter_map(
  requested_from timestamptz,
  requested_to timestamptz
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
    and exists (
      select 1
      from public.concert_volunteers own
      where own.concert_id = encounter.maraude_id
        and own.user_id = (select auth.uid())
        and own.status = 'selected'::public.concert_volunteer_status
    )
  order by encounter.created_at desc
  limit 5000;
end;
$$;

revoke all on function public.get_my_encounter_map(timestamptz, timestamptz)
  from public, anon;
grant execute on function public.get_my_encounter_map(timestamptz, timestamptz)
  to authenticated;
