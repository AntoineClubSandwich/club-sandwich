create or replace function private.protect_started_maraude_team_changes()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_maraude_status public.maraude_status;
begin
  if new.status is not distinct from old.status
    and new.team_role is not distinct from old.team_role
    and new.concert_id is not distinct from old.concert_id
  then
    return new;
  end if;

  select concert.maraude_status
  into current_maraude_status
  from public.concerts concert
  where concert.id = old.concert_id;

  if current_maraude_status in (
    'in_progress'::public.maraude_status,
    'completed'::public.maraude_status,
    'cancelled'::public.maraude_status
  ) then
    raise exception
      'La composition de l’équipe est verrouillée après le démarrage'
      using errcode = '55000';
  end if;

  return new;
end;
$$;

revoke all on function private.protect_started_maraude_team_changes()
  from public, anon, authenticated;

drop trigger if exists protect_started_maraude_team_changes
on public.concert_volunteers;

create trigger protect_started_maraude_team_changes
before update of concert_id, status, team_role
on public.concert_volunteers
for each row
execute function private.protect_started_maraude_team_changes();

create or replace function public.complete_maraude_flexible(
  requested_concert_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  quantities_are_unavailable boolean;
begin
  if not private.can_edit_maraude_report(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Vous ne pouvez pas terminer cette maraude'
      using errcode = '42501';
  end if;

  select not exists (
    select 1
    from public.maraude_collections collection
    where collection.concert_id = requested_concert_id
  )
  into quantities_are_unavailable;

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
    quantities_are_unavailable,
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
