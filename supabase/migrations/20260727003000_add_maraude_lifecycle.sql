do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'maraude_status'
  ) then
    create type public.maraude_status as enum (
      'planned',
      'started',
      'completed'
    );
  end if;
end;
$$;

alter table public.concerts
  add column maraude_status public.maraude_status
    not null default 'planned',
  add column actual_start_at timestamptz,
  add column actual_end_at timestamptz;

alter table public.concerts
  add constraint concerts_maraude_dates_match_status
  check (
    (
      maraude_status = 'planned'::public.maraude_status
      and actual_start_at is null
      and actual_end_at is null
    )
    or (
      maraude_status = 'started'::public.maraude_status
      and actual_start_at is not null
      and actual_end_at is null
    )
    or (
      maraude_status = 'completed'::public.maraude_status
      and actual_start_at is not null
      and actual_end_at is not null
    )
  ),
  add constraint concerts_maraude_dates_chronological
  check (
    actual_end_at is null
    or actual_end_at >= actual_start_at
  );

create or replace function private.enforce_maraude_lifecycle()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    if new.maraude_status <> 'planned'::public.maraude_status then
      raise exception 'Une maraude doit être créée en préparation'
        using errcode = '22023';
    end if;
    return new;
  end if;

  if new.maraude_status = old.maraude_status then
    return new;
  end if;

  if (
    old.maraude_status = 'planned'::public.maraude_status
    and new.maraude_status = 'started'::public.maraude_status
  ) or (
    old.maraude_status = 'started'::public.maraude_status
    and new.maraude_status = 'completed'::public.maraude_status
  ) then
    return new;
  end if;

  raise exception 'Transition de maraude interdite : % vers %',
    old.maraude_status,
    new.maraude_status
    using errcode = '22023';
end;
$$;

revoke all on function private.enforce_maraude_lifecycle()
  from public;

create trigger concerts_enforce_maraude_lifecycle
before insert or update of maraude_status
on public.concerts
for each row execute function private.enforce_maraude_lifecycle();

create or replace function public.start_maraude(
  requested_concert_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_status public.maraude_status;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut démarrer une maraude'
      using errcode = '42501';
  end if;

  select c.maraude_status
  into current_status
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

  if current_status <> 'planned'::public.maraude_status then
    raise exception 'La maraude n’est pas en préparation'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.concert_volunteers cv
    where cv.concert_id = requested_concert_id
      and cv.status = 'selected'::public.concert_volunteer_status
      and cv.attendance_status =
        'present'::public.volunteer_attendance_status
  ) then
    raise exception 'Au moins un bénévole sélectionné doit être présent'
      using errcode = '22023';
  end if;

  update public.concerts
  set
    maraude_status = 'started'::public.maraude_status,
    actual_start_at = clock_timestamp(),
    actual_end_at = null
  where id = requested_concert_id;
end;
$$;

revoke all on function public.start_maraude(uuid)
  from public, anon;
grant execute on function public.start_maraude(uuid)
  to authenticated;

create or replace function public.complete_maraude(
  requested_concert_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_status public.maraude_status;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut terminer une maraude'
      using errcode = '42501';
  end if;

  select c.maraude_status
  into current_status
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

  if current_status <> 'started'::public.maraude_status then
    raise exception 'Seule une maraude en cours peut être terminée'
      using errcode = '22023';
  end if;

  update public.concerts
  set
    maraude_status = 'completed'::public.maraude_status,
    actual_end_at = greatest(clock_timestamp(), actual_start_at)
  where id = requested_concert_id;
end;
$$;

revoke all on function public.complete_maraude(uuid)
  from public, anon;
grant execute on function public.complete_maraude(uuid)
  to authenticated;
