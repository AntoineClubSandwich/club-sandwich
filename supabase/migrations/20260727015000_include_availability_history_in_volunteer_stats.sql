create or replace function public.get_concert_volunteer_team_details(
  requested_concert_id uuid
)
returns table (
  id uuid,
  concert_id uuid,
  user_id uuid,
  status public.concert_volunteer_status,
  team_role public.maraude_role,
  attendance_status public.volunteer_attendance_status,
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
set search_path = public, auth, pg_temp
as $$
  select
    details.id,
    details.concert_id,
    details.user_id,
    details.status,
    cv.team_role,
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

revoke all on function public.get_concert_volunteer_team_details(uuid)
  from public, anon;
grant execute on function public.get_concert_volunteer_team_details(uuid)
  to authenticated;
