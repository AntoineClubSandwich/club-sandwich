alter table public.maraude_operational_reports
  alter column total_weight_kg drop not null,
  alter column total_weight_kg drop default,
  alter column estimated_meals drop not null,
  alter column estimated_meals drop default,
  alter column distance_km drop not null,
  alter column distance_km drop default;

update public.maraude_operational_reports
set
  total_weight_kg = null,
  estimated_meals = null
where quantities_unavailable
  and total_weight_kg = 0
  and estimated_meals = 0;

create or replace function public.save_maraude_operational_report_v2(
  requested_concert_id uuid,
  requested_total_weight_kg numeric,
  requested_distance_km numeric,
  requested_quantities_unavailable boolean,
  requested_comment text default null,
  requested_photo_folder_url text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if requested_quantities_unavailable is not true
    and requested_total_weight_kg is null
  then
    raise exception 'Le poids doit être renseigné'
      using errcode = '22023';
  end if;

  if requested_total_weight_kg is not null
    and requested_total_weight_kg < 0
  then
    raise exception 'Le poids doit être positif ou nul'
      using errcode = '22023';
  end if;

  if requested_distance_km is not null
    and requested_distance_km < 0
  then
    raise exception 'La distance doit être positive ou nulle'
      using errcode = '22023';
  end if;

  if not private.can_edit_maraude_report(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Vous ne pouvez pas modifier ce compte rendu'
      using errcode = '42501';
  end if;

  insert into public.maraude_operational_reports (
    concert_id,
    total_weight_kg,
    estimated_meals,
    distance_km,
    quantities_unavailable,
    comment,
    photo_folder_url,
    last_modified_by
  )
  values (
    requested_concert_id,
    case
      when requested_quantities_unavailable then null
      else requested_total_weight_kg
    end,
    null,
    requested_distance_km,
    requested_quantities_unavailable,
    nullif(btrim(requested_comment), ''),
    nullif(btrim(requested_photo_folder_url), ''),
    (select auth.uid())
  )
  on conflict (concert_id) do update
  set
    total_weight_kg = excluded.total_weight_kg,
    estimated_meals = excluded.estimated_meals,
    distance_km = excluded.distance_km,
    quantities_unavailable = excluded.quantities_unavailable,
    comment = excluded.comment,
    photo_folder_url = excluded.photo_folder_url,
    last_modified_by = excluded.last_modified_by;
end;
$$;

create or replace function public.complete_maraude_flexible(
  requested_concert_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.can_edit_maraude_report(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Vous ne pouvez pas terminer cette maraude'
      using errcode = '42501';
  end if;

  insert into public.maraude_operational_reports (
    concert_id,
    total_weight_kg,
    estimated_meals,
    distance_km,
    quantities_unavailable,
    last_modified_by
  )
  values (
    requested_concert_id,
    null,
    null,
    null,
    true,
    (select auth.uid())
  )
  on conflict (concert_id) do nothing;

  perform public.set_maraude_status(
    requested_concert_id,
    'completed'::public.maraude_status,
    null
  );
end;
$$;
