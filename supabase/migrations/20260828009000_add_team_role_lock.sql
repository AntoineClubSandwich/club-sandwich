-- Lets an admin lock a volunteer's team role (in particular: team leader)
-- once it's settled, to prevent an accidental "Retirer de l'équipe" click
-- or role change from silently reverting it - exactly what happened live
-- during testing (a confirmed team leader ended up back on the default
-- role after what was presumably an accidental removal + re-selection).

alter table public.concert_volunteers
  add column team_role_locked boolean not null default false;

create or replace function private.protect_locked_team_role()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if old.team_role_locked
    and new.team_role_locked
    and (
      new.status is distinct from old.status
      or new.team_role is distinct from old.team_role
    )
  then
    raise exception
      'Le rôle de ce bénévole est verrouillé : déverrouillez-le avant de le modifier'
      using errcode = '55000';
  end if;
  return new;
end;
$$;

revoke all on function private.protect_locked_team_role()
  from public, anon, authenticated;

create trigger concert_volunteers_protect_locked_role
before update of status, team_role, team_role_locked
on public.concert_volunteers
for each row execute function private.protect_locked_team_role();

create function public.set_volunteer_role_lock(
  requested_application_id uuid,
  requested_locked boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  application_concert_id uuid;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut verrouiller un rôle'
      using errcode = '42501';
  end if;

  select application.concert_id
  into application_concert_id
  from public.concert_volunteers application
  join public.concerts concert on concert.id = application.concert_id
  where application.id = requested_application_id
    and private.is_organization_member(
      concert.organization_id,
      (select auth.uid())
    );

  if application_concert_id is null then
    raise exception 'Volontaire introuvable' using errcode = 'P0002';
  end if;

  update public.concert_volunteers
  set team_role_locked = requested_locked
  where id = requested_application_id;
end;
$$;

revoke all on function public.set_volunteer_role_lock(uuid, boolean)
  from public, anon;
grant execute on function public.set_volunteer_role_lock(uuid, boolean)
  to authenticated;

drop function public.get_concert_volunteer_team_details(uuid);

create function public.get_concert_volunteer_team_details(
  requested_concert_id uuid
)
returns table (
  id uuid,
  concert_id uuid,
  user_id uuid,
  status concert_volunteer_status,
  team_role maraude_role,
  team_role_locked boolean,
  attendance_status volunteer_attendance_status,
  created_at timestamptz,
  updated_at timestamptz,
  first_name text,
  last_name text,
  email text,
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
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $$
  select
    details.id,
    details.concert_id,
    details.user_id,
    details.status,
    cv.team_role,
    cv.team_role_locked,
    cv.attendance_status,
    details.created_at,
    details.updated_at,
    details.first_name,
    details.last_name,
    u.email::text,
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
    greatest(
      details.withdrawn_applications,
      coalesce(withdrawal_history.total, 0)
    ),
    details.last_selected_date,
    details.history
  from public.get_concert_volunteer_details(requested_concert_id) details
  join public.concert_volunteers cv on cv.id = details.id
  join auth.users u on u.id = details.user_id
  left join lateral (
    select count(*)::bigint as total
    from public.concert_volunteers volunteer_application
    join public.concert_volunteer_events event
      on event.application_id = volunteer_application.id
    where volunteer_application.user_id = details.user_id
      and event.status = 'withdrawn'::public.concert_volunteer_status
  ) withdrawal_history on true;
$$;

grant execute on function public.get_concert_volunteer_team_details(uuid)
  to authenticated;
