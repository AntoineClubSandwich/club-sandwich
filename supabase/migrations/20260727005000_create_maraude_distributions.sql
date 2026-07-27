create table public.maraude_distributions (
  id uuid primary key default gen_random_uuid(),
  concert_id uuid not null unique
    references public.concerts(id) on delete cascade,
  distribution_location text,
  estimated_beneficiaries integer
    check (estimated_beneficiaries >= 0),
  distributed_meals integer
    check (distributed_meals >= 0),
  remaining_weight_kg numeric
    check (remaining_weight_kg >= 0),
  distribution_started_at timestamptz,
  distribution_completed_at timestamptz,
  incident_comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    distribution_completed_at is null
    or (
      distribution_started_at is not null
      and distribution_completed_at >= distribution_started_at
    )
  )
);

create trigger maraude_distributions_set_updated_at
before update on public.maraude_distributions
for each row execute function private.set_updated_at();

create or replace function private.enforce_distribution_during_maraude()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  current_status public.maraude_status;
begin
  if tg_op = 'UPDATE' and new.concert_id <> old.concert_id then
    raise exception 'Une distribution ne peut pas changer de maraude'
      using errcode = '22023';
  end if;

  select c.maraude_status
  into current_status
  from public.concerts c
  where c.id = new.concert_id
  for key share;

  if not found then
    raise exception 'Concert introuvable'
      using errcode = '23503';
  end if;

  if current_status <> 'started'::public.maraude_status then
    raise exception 'La distribution est modifiable uniquement pendant la maraude'
      using errcode = '22023';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_distribution_during_maraude()
  from public;

create trigger maraude_distributions_enforce_active_maraude
before insert or update
on public.maraude_distributions
for each row execute function private.enforce_distribution_during_maraude();

alter table public.maraude_distributions enable row level security;

create policy "Present maraude members can view distribution"
on public.maraude_distributions
for select
to authenticated
using (
  exists (
    select 1
    from public.concert_volunteers cv
    where cv.concert_id = maraude_distributions.concert_id
      and cv.user_id = (select auth.uid())
      and cv.status = 'selected'::public.concert_volunteer_status
      and cv.attendance_status =
        'present'::public.volunteer_attendance_status
  )
);

create policy "Club Sandwich admins can view distribution"
on public.maraude_distributions
for select
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  and exists (
    select 1
    from public.concerts c
    where c.id = maraude_distributions.concert_id
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  )
);

create policy "Club Sandwich admins can create distribution"
on public.maraude_distributions
for insert
to authenticated
with check (
  private.is_club_sandwich_admin((select auth.uid()))
  and exists (
    select 1
    from public.concerts c
    where c.id = maraude_distributions.concert_id
      and c.maraude_status = 'started'::public.maraude_status
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  )
);

create policy "Club Sandwich admins can update distribution"
on public.maraude_distributions
for update
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  and exists (
    select 1
    from public.concerts c
    where c.id = maraude_distributions.concert_id
      and c.maraude_status = 'started'::public.maraude_status
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  )
)
with check (
  private.is_club_sandwich_admin((select auth.uid()))
  and exists (
    select 1
    from public.concerts c
    where c.id = maraude_distributions.concert_id
      and c.maraude_status = 'started'::public.maraude_status
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  )
);

revoke all on public.maraude_distributions from anon, authenticated;
grant select, insert, update on public.maraude_distributions
  to authenticated;
