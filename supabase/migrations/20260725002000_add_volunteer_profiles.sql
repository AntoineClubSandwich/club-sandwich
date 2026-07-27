create table public.volunteer_profiles (
  user_id uuid primary key
    references public.profiles(id) on delete cascade,
  birth_date date,
  has_driving_license boolean,
  can_lift_heavy_loads boolean,
  emergency_contact_name text,
  emergency_contact_phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger volunteer_profiles_set_updated_at
before update on public.volunteer_profiles
for each row execute function private.set_updated_at();

alter table public.volunteer_profiles enable row level security;

create policy "Users can view their own volunteer profile"
on public.volunteer_profiles
for select
to authenticated
using (user_id = (select auth.uid()));

create policy "Users can create their own volunteer profile"
on public.volunteer_profiles
for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy "Users can update their own volunteer profile"
on public.volunteer_profiles
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "Club Sandwich admins can view candidate volunteer profiles"
on public.volunteer_profiles
for select
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  and exists (
    select 1
    from public.concert_volunteers cv
    join public.concerts c on c.id = cv.concert_id
    where cv.user_id = volunteer_profiles.user_id
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  )
);

create or replace function public.get_concert_volunteer_admin_details(
  requested_concert_id uuid
)
returns table (
  id uuid,
  concert_id uuid,
  user_id uuid,
  status public.concert_volunteer_status,
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
  withdrawn_applications bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with candidate_statistics as (
    select
      cv.user_id,
      count(*) as total_applications,
      count(*) filter (
        where cv.status = 'selected'::public.concert_volunteer_status
      ) as selected_applications,
      count(*) filter (
        where cv.status = 'withdrawn'::public.concert_volunteer_status
      ) as withdrawn_applications
    from public.concert_volunteers cv
    join public.concerts c on c.id = cv.concert_id
    where private.is_organization_member(
      c.organization_id,
      (select auth.uid())
    )
    group by cv.user_id
  )
  select
    cv.id,
    cv.concert_id,
    cv.user_id,
    cv.status,
    cv.created_at,
    cv.updated_at,
    p.first_name,
    p.last_name,
    p.phone,
    p.avatar_url,
    vp.birth_date,
    vp.has_driving_license,
    vp.can_lift_heavy_loads,
    vp.emergency_contact_name,
    vp.emergency_contact_phone,
    coalesce(cs.total_applications, 0),
    coalesce(cs.selected_applications, 0),
    coalesce(cs.withdrawn_applications, 0)
  from public.concert_volunteers cv
  join public.concerts c on c.id = cv.concert_id
  join public.profiles p on p.id = cv.user_id
  left join public.volunteer_profiles vp on vp.user_id = cv.user_id
  left join candidate_statistics cs on cs.user_id = cv.user_id
  where cv.concert_id = requested_concert_id
    and private.is_club_sandwich_admin((select auth.uid()))
    and private.is_organization_member(
      c.organization_id,
      (select auth.uid())
    )
  order by cv.created_at;
$$;

revoke all on public.volunteer_profiles from anon, authenticated;
grant select, insert, update on public.volunteer_profiles to authenticated;

revoke all on function public.get_concert_volunteer_admin_details(uuid)
  from public, anon;
grant execute on function public.get_concert_volunteer_admin_details(uuid)
  to authenticated;
