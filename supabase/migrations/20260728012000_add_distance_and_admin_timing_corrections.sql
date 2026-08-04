alter table public.maraude_operational_reports
  add column if not exists distance_km numeric not null default 0
    check (distance_km >= 0),
  add column if not exists quantities_unavailable boolean not null
    default false;

create or replace function private.can_edit_maraude_report(
  requested_concert_id uuid,
  requested_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    private.is_club_sandwich_admin(requested_user_id)
    or exists (
      select 1
      from public.concert_volunteers volunteer
      join public.concerts concert
        on concert.id = volunteer.concert_id
      where volunteer.concert_id = requested_concert_id
        and volunteer.user_id = requested_user_id
        and volunteer.status =
          'selected'::public.concert_volunteer_status
        and volunteer.team_role = 'team_leader'::public.maraude_role
        and volunteer.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
        and concert.maraude_status =
          'in_progress'::public.maraude_status
    );
$$;

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
  if requested_total_weight_kg is null
    or requested_total_weight_kg < 0
  then
    raise exception 'Le poids doit être positif ou nul'
      using errcode = '22023';
  end if;

  if requested_distance_km is null or requested_distance_km < 0 then
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
    requested_total_weight_kg,
    0,
    requested_distance_km,
    requested_quantities_unavailable,
    nullif(btrim(requested_comment), ''),
    nullif(btrim(requested_photo_folder_url), ''),
    (select auth.uid())
  )
  on conflict (concert_id) do update
  set
    total_weight_kg = excluded.total_weight_kg,
    estimated_meals = 0,
    distance_km = excluded.distance_km,
    quantities_unavailable = excluded.quantities_unavailable,
    comment = excluded.comment,
    photo_folder_url = excluded.photo_folder_url,
    last_modified_by = excluded.last_modified_by;
end;
$$;

revoke all on function public.save_maraude_operational_report_v2(
  uuid, numeric, numeric, boolean, text, text
) from public, anon;
grant execute on function public.save_maraude_operational_report_v2(
  uuid, numeric, numeric, boolean, text, text
) to authenticated;

create or replace function public.correct_maraude_timing(
  requested_concert_id uuid,
  requested_start_at timestamptz,
  requested_end_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Action réservée aux administrateurs'
      using errcode = '42501';
  end if;

  if requested_start_at is not null
    and requested_end_at is not null
    and requested_end_at < requested_start_at
  then
    raise exception 'La fin doit être postérieure au début'
      using errcode = '22023';
  end if;

  update public.concerts concert
  set
    actual_start_at = requested_start_at,
    actual_end_at = requested_end_at
  where concert.id = requested_concert_id
    and private.is_organization_member(
      concert.organization_id,
      (select auth.uid())
    );

  if not found then
    raise exception 'Concert inaccessible'
      using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.correct_maraude_timing(
  uuid, timestamptz, timestamptz
) from public, anon;
grant execute on function public.correct_maraude_timing(
  uuid, timestamptz, timestamptz
) to authenticated;
