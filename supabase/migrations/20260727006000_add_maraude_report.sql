alter table public.concerts
  add column closing_comment text;

create or replace function private.enforce_maraude_closing_comment()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.closing_comment is not distinct from old.closing_comment then
    return new;
  end if;

  if old.maraude_status <> 'completed'::public.maraude_status then
    raise exception 'Le commentaire de fin est modifiable uniquement après la clôture'
      using errcode = '22023';
  end if;

  if (
    not private.is_club_sandwich_admin((select auth.uid()))
    or not private.is_organization_member(
      old.organization_id,
      (select auth.uid())
    )
  ) then
    raise exception 'Seul un administrateur peut modifier le commentaire de fin'
      using errcode = '42501';
  end if;

  new.closing_comment = nullif(btrim(new.closing_comment), '');
  return new;
end;
$$;

revoke all on function private.enforce_maraude_closing_comment()
  from public;

create trigger concerts_enforce_maraude_closing_comment
before update of closing_comment
on public.concerts
for each row execute function private.enforce_maraude_closing_comment();

drop policy if exists "Members can view concerts in their organizations"
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
    or exists (
      select 1
      from public.concert_volunteers cv
      where cv.concert_id = concerts.id
        and cv.user_id = (select auth.uid())
        and cv.status = 'selected'::public.concert_volunteer_status
        and cv.attendance_status =
          'present'::public.volunteer_attendance_status
    )
  )
);

grant update (closing_comment) on public.concerts
  to authenticated;

drop function public.get_concert_volunteer_counts(uuid);

create function public.get_concert_volunteer_counts(
  requested_concert_id uuid
)
returns table (
  application_count bigint,
  selected_count bigint,
  present_count bigint,
  absent_count bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    count(cv.id) filter (
      where cv.status <> 'withdrawn'::public.concert_volunteer_status
    ) as application_count,
    count(cv.id) filter (
      where cv.status = 'selected'::public.concert_volunteer_status
    ) as selected_count,
    count(cv.id) filter (
      where cv.status = 'selected'::public.concert_volunteer_status
        and cv.attendance_status =
          'present'::public.volunteer_attendance_status
    ) as present_count,
    count(cv.id) filter (
      where cv.status = 'selected'::public.concert_volunteer_status
        and cv.attendance_status =
          'absent'::public.volunteer_attendance_status
    ) as absent_count
  from public.concerts c
  left join public.concert_volunteers cv on cv.concert_id = c.id
  where c.id = requested_concert_id
    and private.is_organization_member(
      c.organization_id,
      (select auth.uid())
    )
  group by c.id;
$$;

revoke all on function public.get_concert_volunteer_counts(uuid)
  from public, anon;
grant execute on function public.get_concert_volunteer_counts(uuid)
  to authenticated;
