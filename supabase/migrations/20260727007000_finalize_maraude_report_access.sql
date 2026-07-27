create or replace function private.is_present_maraude_member(
  requested_concert_id uuid,
  requested_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.concert_volunteers cv
    where cv.concert_id = requested_concert_id
      and cv.user_id = requested_user_id
      and cv.status = 'selected'::public.concert_volunteer_status
      and cv.attendance_status =
        'present'::public.volunteer_attendance_status
  );
$$;

revoke all on function private.is_present_maraude_member(uuid, uuid)
  from public, anon;
grant execute on function private.is_present_maraude_member(uuid, uuid)
  to authenticated;

drop policy if exists "Members can view accessible concerts"
  on public.concerts;

create policy "Members can view accessible concerts"
on public.concerts
for select
to authenticated
using (
  private.is_organization_member(organization_id, (select auth.uid()))
  and (
    maraude_status <> 'completed'::public.maraude_status
    or private.is_club_sandwich_admin((select auth.uid()))
    or private.is_present_maraude_member(id, (select auth.uid()))
  )
);
