alter type public.maraude_role
  rename value 'driver' to 'logistics';

alter type public.maraude_role
  rename value 'photographer' to 'communication';

alter type public.maraude_role
  rename value 'volunteer' to 'collection_distribution';

create unique index concert_volunteers_one_communication_idx
on public.concert_volunteers (concert_id)
where team_role = 'communication'::public.maraude_role;

create unique index concert_volunteers_one_logistics_idx
on public.concert_volunteers (concert_id)
where team_role = 'logistics'::public.maraude_role;

create or replace function public.select_concert_volunteers(
  requested_concert_id uuid,
  requested_application_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  requested_count integer;
  matched_count integer;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut constituer une équipe'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.concerts c
    where c.id = requested_concert_id
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  ) then
    raise exception 'Concert inaccessible'
      using errcode = '42501';
  end if;

  select count(distinct application_id)
  into requested_count
  from unnest(requested_application_ids) as application_id;

  if requested_count = 0 then
    raise exception 'Aucune candidature sélectionnée'
      using errcode = '22023';
  end if;

  select count(*)
  into matched_count
  from public.concert_volunteers cv
  where cv.concert_id = requested_concert_id
    and cv.id = any(requested_application_ids)
    and cv.status <> 'withdrawn'::public.concert_volunteer_status;

  if matched_count <> requested_count then
    raise exception 'Une candidature est invalide ou désistée'
      using errcode = '22023';
  end if;

  update public.concert_volunteers
  set
    status = 'selected'::public.concert_volunteer_status,
    team_role = coalesce(
      team_role,
      'collection_distribution'::public.maraude_role
    ),
    attendance_status = coalesce(
      attendance_status,
      'pending'::public.volunteer_attendance_status
    )
  where concert_id = requested_concert_id
    and id = any(requested_application_ids);
end;
$$;

revoke all on function public.select_concert_volunteers(uuid, uuid[])
  from public, anon;
grant execute on function public.select_concert_volunteers(uuid, uuid[])
  to authenticated;

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
  communication_count integer;
  logistics_count integer;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut constituer une équipe'
      using errcode = '42501';
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

  if jsonb_typeof(requested_team) is distinct from 'array' then
    raise exception 'L’équipe doit être transmise sous forme de liste'
      using errcode = '22023';
  end if;

  requested_count := jsonb_array_length(requested_team);
  if requested_count < 4 then
    raise exception 'Une équipe doit compter au moins quatre bénévoles'
      using errcode = '22023';
  end if;

  begin
    select
      count(distinct requested.application_id),
      count(requested.team_role),
      count(*) filter (
        where requested.team_role =
          'team_leader'::public.maraude_role
      ),
      count(*) filter (
        where requested.team_role =
          'communication'::public.maraude_role
      ),
      count(*) filter (
        where requested.team_role =
          'logistics'::public.maraude_role
      )
    into
      distinct_application_count,
      assigned_role_count,
      leader_count,
      communication_count,
      logistics_count
    from jsonb_to_recordset(requested_team)
      as requested(application_id uuid, team_role public.maraude_role);
  exception
    when invalid_text_representation then
      raise exception 'Un rôle ou un identifiant de candidature est invalide'
        using errcode = '22023';
  end;

  if distinct_application_count <> requested_count then
    raise exception 'Une candidature ne peut apparaître qu’une seule fois'
      using errcode = '22023';
  end if;

  if assigned_role_count <> requested_count then
    raise exception 'Chaque bénévole sélectionné doit avoir un rôle'
      using errcode = '22023';
  end if;

  if leader_count <> 1 then
    raise exception 'L’équipe doit avoir exactement un chef d’équipe'
      using errcode = '22023';
  end if;

  if communication_count > 1 or logistics_count > 1 then
    raise exception
      'Les rôles Communication et Logistique sont limités à une personne'
      using errcode = '22023';
  end if;

  perform 1
  from public.concert_volunteers cv
  where cv.concert_id = requested_concert_id
  for update;

  select count(*)
  into matched_count
  from public.concert_volunteers cv
  join jsonb_to_recordset(requested_team)
    as requested(application_id uuid, team_role public.maraude_role)
    on requested.application_id = cv.id
  where cv.concert_id = requested_concert_id
    and cv.status <> 'withdrawn'::public.concert_volunteer_status;

  if matched_count <> requested_count then
    raise exception 'Une candidature est invalide ou désistée'
      using errcode = '22023';
  end if;

  update public.concert_volunteers cv
  set
    status = 'not_selected'::public.concert_volunteer_status,
    team_role = null
  where cv.concert_id = requested_concert_id
    and cv.status = 'selected'::public.concert_volunteer_status
    and not exists (
      select 1
      from jsonb_to_recordset(requested_team)
        as requested(application_id uuid, team_role public.maraude_role)
      where requested.application_id = cv.id
    );

  update public.concert_volunteers cv
  set
    status = 'selected'::public.concert_volunteer_status,
    team_role = requested.team_role
  from jsonb_to_recordset(requested_team)
    as requested(application_id uuid, team_role public.maraude_role)
  where cv.id = requested.application_id
    and cv.concert_id = requested_concert_id;
end;
$$;

revoke all on function public.save_maraude_team(uuid, jsonb)
  from public, anon;
grant execute on function public.save_maraude_team(uuid, jsonb)
  to authenticated;
