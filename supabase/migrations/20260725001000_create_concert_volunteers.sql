do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'concert_volunteer_status'
  ) then
    create type public.concert_volunteer_status as enum (
      'pending',
      'selected',
      'not_selected',
      'withdrawn'
    );
  end if;
end;
$$;

create table public.concert_volunteers (
  id uuid primary key default gen_random_uuid(),
  concert_id uuid not null
    references public.concerts(id) on delete cascade,
  user_id uuid not null
    references public.profiles(id) on delete cascade,
  status public.concert_volunteer_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (concert_id, user_id)
);

create index concert_volunteers_concert_status_idx
  on public.concert_volunteers (concert_id, status);

create index concert_volunteers_user_id_idx
  on public.concert_volunteers (user_id);

create trigger concert_volunteers_set_updated_at
before update on public.concert_volunteers
for each row execute function private.set_updated_at();

alter table public.concert_volunteers enable row level security;

create policy "Users can view their own concert applications"
on public.concert_volunteers
for select
to authenticated
using (user_id = (select auth.uid()));

create policy "Club Sandwich admins can view concert applications"
on public.concert_volunteers
for select
to authenticated
using (private.is_club_sandwich_admin((select auth.uid())));

create policy "Users can create their own pending application"
on public.concert_volunteers
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and status = 'pending'::public.concert_volunteer_status
  and exists (
    select 1
    from public.concerts c
    where c.id = concert_id
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  )
);

create policy "Users can withdraw their own application"
on public.concert_volunteers
for update
to authenticated
using (user_id = (select auth.uid()))
with check (
  user_id = (select auth.uid())
  and status = 'withdrawn'::public.concert_volunteer_status
);

create policy "Club Sandwich admins can update concert applications"
on public.concert_volunteers
for update
to authenticated
using (private.is_club_sandwich_admin((select auth.uid())))
with check (private.is_club_sandwich_admin((select auth.uid())));

create policy "Club Sandwich admins can view applicant profiles"
on public.profiles
for select
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  and exists (
    select 1
    from public.concert_volunteers cv
    join public.concerts c on c.id = cv.concert_id
    where cv.user_id = profiles.id
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  )
);

create or replace function public.get_concert_volunteer_counts(
  requested_concert_id uuid
)
returns table (
  application_count bigint,
  selected_count bigint
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
    ) as selected_count
  from public.concerts c
  left join public.concert_volunteers cv on cv.concert_id = c.id
  where c.id = requested_concert_id
    and private.is_organization_member(
      c.organization_id,
      (select auth.uid())
    )
  group by c.id;
$$;

revoke all on public.concert_volunteers from anon, authenticated;
grant select, insert on public.concert_volunteers to authenticated;
grant update (status) on public.concert_volunteers to authenticated;

revoke all on function public.get_concert_volunteer_counts(uuid)
  from public, anon;
grant execute on function public.get_concert_volunteer_counts(uuid)
  to authenticated;
