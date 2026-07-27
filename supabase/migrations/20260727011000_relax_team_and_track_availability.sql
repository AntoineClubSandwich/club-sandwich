drop index if exists public.concert_volunteers_one_team_leader_idx;
drop index if exists public.concert_volunteers_one_communication_idx;
drop index if exists public.concert_volunteers_one_logistics_idx;

create or replace function public.save_maraude_team(
  requested_concert_id uuid,
  requested_team jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  requested_count integer;
  distinct_application_count integer;
  assigned_role_count integer;
  matched_count integer;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut constituer une équipe'
      using errcode = '42501';
  end if;

  perform 1
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

  if jsonb_typeof(requested_team) is distinct from 'array' then
    raise exception 'L’équipe doit être transmise sous forme de liste'
      using errcode = '22023';
  end if;

  requested_count := jsonb_array_length(requested_team);

  begin
    select
      count(distinct requested.application_id),
      count(requested.team_role)
    into distinct_application_count, assigned_role_count
    from jsonb_to_recordset(requested_team)
      as requested(application_id uuid, team_role public.maraude_role);
  exception
    when invalid_text_representation then
      raise exception 'Un rôle ou un identifiant de candidature est invalide'
        using errcode = '22023';
  end;

  if distinct_application_count <> requested_count then
    raise exception 'Une candidature ne peut apparaître qu’une seule fois'
      using errcode = '22023';
  end if;

  if assigned_role_count <> requested_count then
    raise exception 'Chaque bénévole sélectionné doit avoir un rôle'
      using errcode = '22023';
  end if;

  perform 1
  from public.concert_volunteers cv
  where cv.concert_id = requested_concert_id
  for update;

  select count(*)
  into matched_count
  from public.concert_volunteers cv
  join jsonb_to_recordset(requested_team)
    as requested(application_id uuid, team_role public.maraude_role)
    on requested.application_id = cv.id
  where cv.concert_id = requested_concert_id
    and cv.status <> 'withdrawn'::public.concert_volunteer_status;

  if matched_count <> requested_count then
    raise exception 'Une candidature est invalide ou désistée'
      using errcode = '22023';
  end if;

  update public.concert_volunteers cv
  set
    status = 'not_selected'::public.concert_volunteer_status,
    team_role = null
  where cv.concert_id = requested_concert_id
    and cv.status = 'selected'::public.concert_volunteer_status
    and not exists (
      select 1
      from jsonb_to_recordset(requested_team)
        as requested(application_id uuid, team_role public.maraude_role)
      where requested.application_id = cv.id
    );

  update public.concert_volunteers cv
  set
    status = 'selected'::public.concert_volunteer_status,
    team_role = requested.team_role
  from jsonb_to_recordset(requested_team)
    as requested(application_id uuid, team_role public.maraude_role)
  where cv.id = requested.application_id
    and cv.concert_id = requested_concert_id;
end;
$$;

revoke all on function public.save_maraude_team(uuid, jsonb)
  from public, anon;
grant execute on function public.save_maraude_team(uuid, jsonb)
  to authenticated;

create table public.concert_volunteer_events (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null
    references public.concert_volunteers(id) on delete cascade,
  previous_status public.concert_volunteer_status,
  status public.concert_volunteer_status not null,
  changed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index concert_volunteer_events_application_created_idx
on public.concert_volunteer_events (application_id, created_at desc);

insert into public.concert_volunteer_events (
  application_id,
  previous_status,
  status,
  changed_by,
  created_at
)
select
  cv.id,
  null,
  cv.status,
  cv.user_id,
  cv.updated_at
from public.concert_volunteers cv;

create or replace function private.record_concert_volunteer_status()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.concert_volunteer_events (
      application_id,
      previous_status,
      status,
      changed_by
    )
    values (
      new.id,
      case when tg_op = 'INSERT' then null else old.status end,
      new.status,
      (select auth.uid())
    );
  end if;
  return new;
end;
$$;

revoke all on function private.record_concert_volunteer_status()
  from public, anon, authenticated;

create trigger concert_volunteers_record_status
after insert or update of status
on public.concert_volunteers
for each row execute function private.record_concert_volunteer_status();

alter table public.concert_volunteer_events enable row level security;

create policy "Users view their own availability history"
on public.concert_volunteer_events
for select
to authenticated
using (
  exists (
    select 1
    from public.concert_volunteers cv
    where cv.id = concert_volunteer_events.application_id
      and cv.user_id = (select auth.uid())
  )
);

create policy "Admins view availability history in their organization"
on public.concert_volunteer_events
for select
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  and exists (
    select 1
    from public.concert_volunteers cv
    join public.concerts c on c.id = cv.concert_id
    where cv.id = concert_volunteer_events.application_id
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  )
);

revoke all on public.concert_volunteer_events from anon, authenticated;
grant select on public.concert_volunteer_events to authenticated;

create or replace function public.reapply_to_concert(
  requested_concert_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.concert_volunteers cv
  set status = 'pending'::public.concert_volunteer_status
  from public.concerts c
  where cv.concert_id = requested_concert_id
    and cv.user_id = (select auth.uid())
    and cv.status = 'withdrawn'::public.concert_volunteer_status
    and c.id = cv.concert_id
    and c.maraude_status = 'planned'::public.maraude_status
    and private.is_organization_member(
      c.organization_id,
      (select auth.uid())
    );

  if not found then
    raise exception 'Cette disponibilité ne peut pas être renouvelée'
      using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.reapply_to_concert(uuid)
  from public, anon;
grant execute on function public.reapply_to_concert(uuid)
  to authenticated;

drop trigger if exists concerts_enforce_maraude_lifecycle
  on public.concerts;
drop function if exists private.enforce_maraude_lifecycle();

alter table public.concerts
  drop constraint if exists concerts_maraude_dates_match_status;

alter type public.maraude_status
  rename value 'planned' to 'open';

alter type public.maraude_status
  rename value 'started' to 'in_progress';

alter type public.maraude_status add value if not exists 'draft' before 'open';
alter type public.maraude_status add value if not exists 'team_ready' after 'open';
alter type public.maraude_status add value if not exists 'cancelled' after 'completed';
