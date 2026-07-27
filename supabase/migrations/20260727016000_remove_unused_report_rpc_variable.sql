create or replace function public.save_maraude_report(
  requested_concert_id uuid,
  requested_total_weight_kg numeric,
  requested_estimated_meals integer,
  requested_comment text default null,
  requested_photo_folder_url text default null,
  requested_complete boolean default true
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  changed_at timestamptz := clock_timestamp();
begin
  if requested_total_weight_kg is null or requested_total_weight_kg < 0 then
    raise exception 'Le poids doit être positif ou nul'
      using errcode = '22023';
  end if;

  if requested_estimated_meals is null or requested_estimated_meals < 0 then
    raise exception 'Le nombre de repas doit être positif ou nul'
      using errcode = '22023';
  end if;

  perform 1
  from public.concerts c
  where c.id = requested_concert_id
    and private.is_organization_member(
      c.organization_id,
      (select auth.uid())
    )
  for update;

  if not found then
    raise exception 'Concert inaccessible'
      using errcode = '42501';
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
    comment,
    photo_folder_url,
    last_modified_by
  )
  values (
    requested_concert_id,
    requested_total_weight_kg,
    requested_estimated_meals,
    nullif(btrim(requested_comment), ''),
    nullif(btrim(requested_photo_folder_url), ''),
    (select auth.uid())
  )
  on conflict (concert_id) do update
  set
    total_weight_kg = excluded.total_weight_kg,
    estimated_meals = excluded.estimated_meals,
    comment = excluded.comment,
    photo_folder_url = excluded.photo_folder_url,
    last_modified_by = excluded.last_modified_by;

  if requested_complete then
    update public.concerts
    set
      maraude_status = 'completed'::public.maraude_status,
      actual_start_at = coalesce(actual_start_at, changed_at),
      actual_end_at = greatest(
        changed_at,
        coalesce(actual_start_at, changed_at)
      )
    where id = requested_concert_id;
  end if;
end;
$$;

revoke all on function public.save_maraude_report(
  uuid,
  numeric,
  integer,
  text,
  text,
  boolean
) from public, anon;
grant execute on function public.save_maraude_report(
  uuid,
  numeric,
  integer,
  text,
  text,
  boolean
) to authenticated;
