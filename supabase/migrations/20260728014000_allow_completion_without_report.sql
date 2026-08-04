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
    0,
    0,
    0,
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

revoke all on function public.complete_maraude_flexible(uuid)
  from public, anon;
grant execute on function public.complete_maraude_flexible(uuid)
  to authenticated;
