do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'maraude_role'
  ) then
    create type public.maraude_role as enum (
      'team_leader',
      'driver',
      'volunteer'
    );
  end if;
end;
$$;

alter table public.concert_volunteers
  add column team_role public.maraude_role;

alter table public.concert_volunteers
  add constraint concert_volunteers_role_requires_selection
  check (
    team_role is null
    or status = 'selected'::public.concert_volunteer_status
  );

create unique index concert_volunteers_one_team_leader_idx
on public.concert_volunteers (concert_id)
where team_role = 'team_leader'::public.maraude_role;

create or replace function private.normalize_concert_volunteer_role()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status <> 'selected'::public.concert_volunteer_status then
    new.team_role = null;
  end if;

  return new;
end;
$$;

revoke all on function private.normalize_concert_volunteer_role()
  from public;

create trigger concert_volunteers_normalize_team_role
before insert or update of status, team_role
on public.concert_volunteers
for each row execute function private.normalize_concert_volunteer_role();

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
      'volunteer'::public.maraude_role
    )
  where concert_id = requested_concert_id
    and id = any(requested_application_ids);
end;
$$;

revoke all on function public.select_concert_volunteers(uuid, uuid[])
  from public, anon;
grant execute on function public.select_concert_volunteers(uuid, uuid[])
  to authenticated;

grant update (team_role) on public.concert_volunteers to authenticated;

create or replace function public.get_concert_volunteer_team_details(
  requested_concert_id uuid
)
returns table (
  id uuid,
  concert_id uuid,
  user_id uuid,
  status public.concert_volunteer_status,
  team_role public.maraude_role,
  created_at timestamptz,
  updated_at timestamptz,
  first_name text,
  last_name text,
  phone text,
  avatar_url text,
  birth_date date,
  has_driving_license boolean,
  can_lift_heavy_loads boolean,
  emergency_contact_name text,
  emergency_contact_phone text,
  total_applications bigint,
  selected_applications bigint,
  not_selected_applications bigint,
  withdrawn_applications bigint,
  last_selected_date date,
  history jsonb
)
language sql
stable
set search_path = public, pg_temp
as $$
  select
    details.id,
    details.concert_id,
    details.user_id,
    details.status,
    cv.team_role,
    details.created_at,
    details.updated_at,
    details.first_name,
    details.last_name,
    details.phone,
    details.avatar_url,
    details.birth_date,
    details.has_driving_license,
    details.can_lift_heavy_loads,
    details.emergency_contact_name,
    details.emergency_contact_phone,
    details.total_applications,
    details.selected_applications,
    details.not_selected_applications,
    details.withdrawn_applications,
    details.last_selected_date,
    details.history
  from public.get_concert_volunteer_details(requested_concert_id) details
  join public.concert_volunteers cv on cv.id = details.id;
$$;

revoke all on function public.get_concert_volunteer_team_details(uuid)
  from public, anon;
grant execute on function public.get_concert_volunteer_team_details(uuid)
  to authenticated;
