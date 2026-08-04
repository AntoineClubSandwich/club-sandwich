create or replace function public.save_maraude_team(
  requested_concert_id uuid,
  requested_team jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  requested_count integer;
  distinct_application_count integer;
  assigned_role_count integer;
  matched_count integer;
  leader_count integer;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut constituer une équipe'
      using errcode = '42501';
  end if;

  perform public.expire_volunteer_confirmations();

  perform 1
  from public.concerts concert
  where concert.id = requested_concert_id
    and private.is_organization_member(
      concert.organization_id,
      (select auth.uid())
    )
  for update;

  if not found then
    raise exception 'Concert inaccessible' using errcode = '42501';
  end if;

  if jsonb_typeof(requested_team) is distinct from 'array' then
    raise exception 'L’équipe doit être transmise sous forme de liste'
      using errcode = '22023';
  end if;

  requested_count := jsonb_array_length(requested_team);

  if requested_count < 3 then
    raise exception
      'L’équipe doit comprendre un chef d’équipe et au moins deux autres bénévoles'
      using errcode = '22023';
  end if;

  begin
    select
      count(distinct requested.application_id),
      count(requested.team_role),
      count(*) filter (
        where requested.team_role = 'team_leader'::public.maraude_role
      )
    into distinct_application_count, assigned_role_count, leader_count
    from jsonb_to_recordset(requested_team)
      as requested(application_id uuid, team_role public.maraude_role);
  exception
    when invalid_text_representation then
      raise exception 'Un rôle ou un identifiant est invalide'
        using errcode = '22023';
  end;

  if distinct_application_count <> requested_count
    or assigned_role_count <> requested_count
  then
    raise exception 'Chaque bénévole doit apparaître une fois avec un rôle'
      using errcode = '22023';
  end if;

  if leader_count > 1 then
    raise exception 'Un seul chef d''équipe est autorisé'
      using errcode = '23505';
  end if;

  if leader_count = 0 then
    raise exception 'L’équipe doit avoir exactement un chef d’équipe'
      using errcode = '22023';
  end if;

  perform 1
  from public.concert_volunteers application
  where application.concert_id = requested_concert_id
  for update;

  select count(*)
  into matched_count
  from public.concert_volunteers application
  join jsonb_to_recordset(requested_team)
    as requested(application_id uuid, team_role public.maraude_role)
    on requested.application_id = application.id
  where application.concert_id = requested_concert_id
    and application.status <>
      'withdrawn'::public.concert_volunteer_status;

  if matched_count <> requested_count then
    raise exception 'Une candidature est invalide ou désistée'
      using errcode = '22023';
  end if;

  update public.concert_volunteers application
  set status = 'not_selected'::public.concert_volunteer_status
  where application.concert_id = requested_concert_id
    and application.status = 'selected'::public.concert_volunteer_status
    and not exists (
      select 1
      from jsonb_to_recordset(requested_team)
        as requested(application_id uuid, team_role public.maraude_role)
      where requested.application_id = application.id
    );

  update public.concert_volunteers application
  set
    status = 'selected'::public.concert_volunteer_status,
    team_role = requested.team_role
  from jsonb_to_recordset(requested_team)
    as requested(application_id uuid, team_role public.maraude_role)
  where application.id = requested.application_id
    and application.concert_id = requested_concert_id;
end;
$$;

revoke all on function public.save_maraude_team(uuid, jsonb)
  from public, anon;
grant execute on function public.save_maraude_team(uuid, jsonb)
  to authenticated;

create or replace function private.require_complete_team_before_start()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  confirmed_member_count integer;
  confirmed_leader_count integer;
begin
  if new.maraude_status = 'in_progress'::public.maraude_status
    and old.maraude_status is distinct from
      'in_progress'::public.maraude_status
  then
    select
      count(*),
      count(*) filter (
        where application.team_role =
          'team_leader'::public.maraude_role
      )
    into confirmed_member_count, confirmed_leader_count
    from public.concert_volunteers application
    where application.concert_id = new.id
      and application.status =
        'selected'::public.concert_volunteer_status
      and application.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status;

    if confirmed_member_count < 3 or confirmed_leader_count <> 1 then
      raise exception
        'Trois bénévoles confirmés sont requis, dont exactement un chef d’équipe'
        using errcode = '22023';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.require_complete_team_before_start()
  from public, anon, authenticated;

drop trigger if exists require_complete_team_before_start
on public.concerts;

create trigger require_complete_team_before_start
before update of maraude_status
on public.concerts
for each row
execute function private.require_complete_team_before_start();
