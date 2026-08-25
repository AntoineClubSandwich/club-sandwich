create table public.encounters (
  id uuid primary key default gen_random_uuid(),
  maraude_id uuid not null
    references public.concerts(id) on delete cascade,
  created_by uuid not null
    references public.profiles(id) on delete restrict,
  latitude numeric(6, 3) not null
    check (latitude between -90 and 90),
  longitude numeric(6, 3) not null
    check (longitude between -180 and 180),
  accuracy numeric(7, 2) not null
    check (accuracy between 0 and 100),
  created_at timestamptz not null default now()
);

comment on table public.encounters is
  'Points anonymisés d’activité terrain. Aucune donnée sur les bénéficiaires.';
comment on column public.encounters.latitude is
  'Latitude arrondie à 3 décimales côté base (environ 100 mètres).';
comment on column public.encounters.longitude is
  'Longitude arrondie à 3 décimales côté base (environ 100 mètres).';

create index encounters_maraude_created_idx
on public.encounters (maraude_id, created_at desc);

create index encounters_created_idx
on public.encounters (created_at desc);

create index encounters_creator_created_idx
on public.encounters (created_by, created_at desc);

alter table public.encounters enable row level security;

create policy "Operational team can view maraude encounters"
on public.encounters
for select
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  or exists (
    select 1
    from public.concert_volunteers member
    where member.concert_id = encounters.maraude_id
      and member.user_id = (select auth.uid())
      and member.status = 'selected'::public.concert_volunteer_status
  )
);

create policy "Operational team can record distribution encounters"
on public.encounters
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and private.can_edit_maraude_operations(
    maraude_id,
    (select auth.uid())
  )
  and exists (
    select 1
    from public.maraude_operations operation
    where operation.concert_id = encounters.maraude_id
      and operation.current_step =
        'distribution'::public.maraude_operational_step
  )
);

revoke all on public.encounters from anon, authenticated;
grant select, insert on public.encounters to authenticated;

create or replace function public.record_maraude_encounter(
  requested_maraude_id uuid,
  requested_latitude double precision,
  requested_longitude double precision,
  requested_accuracy double precision
)
returns public.encounters
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  saved public.encounters;
begin
  if requested_latitude is null
    or requested_latitude < -90
    or requested_latitude > 90
    or requested_longitude is null
    or requested_longitude < -180
    or requested_longitude > 180
  then
    raise exception 'Position GPS invalide' using errcode = '22023';
  end if;

  if requested_accuracy is null
    or requested_accuracy < 0
    or requested_accuracy > 100
  then
    raise exception 'Précision GPS insuffisante' using errcode = '22023';
  end if;

  insert into public.encounters (
    maraude_id,
    created_by,
    latitude,
    longitude,
    accuracy
  )
  values (
    requested_maraude_id,
    (select auth.uid()),
    round(requested_latitude::numeric, 3),
    round(requested_longitude::numeric, 3),
    round(requested_accuracy::numeric, 2)
  )
  returning * into saved;

  return saved;
end;
$$;

revoke all on function public.record_maraude_encounter(
  uuid,
  double precision,
  double precision,
  double precision
) from public, anon;
grant execute on function public.record_maraude_encounter(
  uuid,
  double precision,
  double precision,
  double precision
) to authenticated;

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
  if not private.is_club_sandwich_admin((select auth.uid())) then
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
  timestamptz,
  timestamptz,
  uuid,
  uuid,
  uuid
) from public, anon;
grant execute on function public.get_admin_encounter_map(
  timestamptz,
  timestamptz,
  uuid,
  uuid,
  uuid
) to authenticated;

create or replace function public.get_maraude_operation_bundle(
  requested_concert_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.can_view_maraude_operations(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Maraude inaccessible' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'operation', (
      select to_jsonb(operation)
      from public.maraude_operations operation
      where operation.concert_id = requested_concert_id
    ),
    'consumables', coalesce((
      select jsonb_agg(
        to_jsonb(allocation) || jsonb_build_object(
          'name', item.name,
          'unit', item.unit,
          'available_quantity', item.current_quantity
        ) order by item.name
      )
      from public.maraude_consumable_allocations allocation
      join public.consumables item on item.id = allocation.consumable_id
      where allocation.concert_id = requested_concert_id
    ), '[]'::jsonb),
    'equipment', coalesce((
      select jsonb_agg(
        to_jsonb(allocation) || jsonb_build_object(
          'name', asset.name,
          'status', asset.status,
          'quantity_total', asset.quantity_total,
          'location_name', location.name
        ) order by asset.name
      )
      from public.maraude_equipment_allocations allocation
      join public.equipment_assets asset on asset.id = allocation.equipment_id
      left join public.equipment_locations location on location.id = asset.location_id
      where allocation.concert_id = requested_concert_id
    ), '[]'::jsonb),
    'collections', coalesce((
      select jsonb_agg(to_jsonb(collection) order by collection.created_at)
      from public.maraude_collections collection
      where collection.concert_id = requested_concert_id
    ), '[]'::jsonb),
    'distribution', (
      select to_jsonb(distribution)
      from public.maraude_distributions distribution
      where distribution.concert_id = requested_concert_id
    ),
    'encounter_count', (
      select count(*)
      from public.encounters encounter
      where encounter.maraude_id = requested_concert_id
    ),
    'history', coalesce((
      select jsonb_agg(to_jsonb(event) order by event.created_at desc)
      from public.maraude_step_events event
      where event.concert_id = requested_concert_id
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_maraude_operation_bundle(uuid)
from public, anon;
grant execute on function public.get_maraude_operation_bundle(uuid)
to authenticated;
