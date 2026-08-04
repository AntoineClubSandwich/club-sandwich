drop function if exists public.get_volunteer_private_information(uuid);

create function public.get_volunteer_private_information(
  requested_user_id uuid
)
returns table (
  additional_information text,
  emergency_contact_name text,
  emergency_contact_phone text,
  certifications text[]
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    volunteer_profiles.additional_information,
    volunteer_profiles.emergency_contact_name,
    volunteer_profiles.emergency_contact_phone,
    volunteer_profiles.certifications
  from public.volunteer_profiles
  where volunteer_profiles.user_id = requested_user_id
    and private.is_club_sandwich_admin((select auth.uid()));
$$;

revoke all on function public.get_volunteer_private_information(uuid)
  from public, anon;
grant execute on function public.get_volunteer_private_information(uuid)
  to authenticated;
