alter table public.concert_volunteers
  add column confirmation_due_at timestamptz,
  add column role_acknowledged_at timestamptz,
  add column attendance_validated_at timestamptz,
  add column attendance_validated_by uuid
    references public.profiles(id) on delete set null,
  add column last_modified_by uuid
    references public.profiles(id) on delete set null;

update public.concert_volunteers
set
  confirmation_due_at = confirmation_requested_at + interval '24 hours',
  role_acknowledged_at = case
    when confirmation_status =
      'confirmed'::public.volunteer_confirmation_status
      then confirmation_responded_at
    else null
  end
where status = 'selected'::public.concert_volunteer_status;

alter table public.concert_volunteers
  drop constraint if exists
    concert_volunteers_confirmation_requires_selection;

alter table public.concert_volunteers
  add constraint concert_volunteers_confirmation_requires_selection
  check (
    (
      status = 'selected'::public.concert_volunteer_status
      and confirmation_status is not null
      and confirmation_requested_at is not null
      and confirmation_due_at is not null
      and (
        confirmation_status =
          'pending'::public.volunteer_confirmation_status
        or (
          confirmation_status =
            'confirmed'::public.volunteer_confirmation_status
          and confirmation_responded_at is not null
          and role_acknowledged_at is not null
        )
      )
    )
    or (
      status <> 'selected'::public.concert_volunteer_status
      and confirmation_status is null
      and confirmation_requested_at is null
      and confirmation_due_at is null
      and confirmation_responded_at is null
      and role_acknowledged_at is null
    )
  );

alter table public.concert_volunteers
  add constraint concert_volunteers_attendance_validation_is_coherent
  check (
    (
      attendance_validated_at is null
      and attendance_validated_by is null
    )
    or (
      status = 'selected'::public.concert_volunteer_status
      and confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
      and attendance_status in (
        'present'::public.volunteer_attendance_status,
        'absent'::public.volunteer_attendance_status
      )
      and attendance_validated_at is not null
      and attendance_validated_by is not null
    )
  );

create table public.maraude_workflow_events (
  id uuid primary key default gen_random_uuid(),
  concert_id uuid not null
    references public.concerts(id) on delete cascade,
  application_id uuid
    references public.concert_volunteers(id) on delete cascade,
  event_type text not null check (
    event_type in (
      'selection_requested',
      'status_changed',
      'role_changed',
      'confirmation_completed',
      'confirmation_expired',
      'attendance_changed',
      'attendance_corrected',
      'attendance_validated',
      'maraude_started',
      'maraude_completed',
      'credit_awarded',
      'credit_revoked'
    )
  ),
  actor_id uuid references public.profiles(id) on delete set null,
  previous_value jsonb,
  new_value jsonb,
  created_at timestamptz not null default now()
);

create index maraude_workflow_events_concert_created_idx
on public.maraude_workflow_events (concert_id, created_at desc);

create index maraude_workflow_events_application_created_idx
on public.maraude_workflow_events (application_id, created_at desc)
where application_id is not null;

create table public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  concert_id uuid references public.concerts(id) on delete cascade,
  notification_type text not null,
  title text not null check (char_length(btrim(title)) > 0),
  body text not null check (char_length(btrim(body)) > 0),
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index user_notifications_user_created_idx
on public.user_notifications (user_id, created_at desc);

create table public.volunteer_credits (
  id uuid primary key default gen_random_uuid(),
  concert_id uuid not null
    references public.concerts(id) on delete cascade,
  application_id uuid not null
    references public.concert_volunteers(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'active'
    check (status in ('active', 'revoked')),
  awarded_by uuid not null
    references public.profiles(id) on delete restrict,
  awarded_at timestamptz not null default now(),
  revoked_by uuid references public.profiles(id) on delete set null,
  revoked_at timestamptz,
  revocation_reason text,
  unique (concert_id, user_id),
  check (
    (
      status = 'active'
      and revoked_by is null
      and revoked_at is null
    )
    or (
      status = 'revoked'
      and revoked_at is not null
    )
  )
);

create index volunteer_credits_user_status_idx
on public.volunteer_credits (user_id, status, awarded_at desc);

alter table public.maraude_workflow_events enable row level security;
alter table public.user_notifications enable row level security;
alter table public.volunteer_credits enable row level security;

create policy "Users view their maraude workflow events"
on public.maraude_workflow_events
for select
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  or exists (
    select 1
    from public.concert_volunteers application
    where application.id = maraude_workflow_events.application_id
      and application.user_id = (select auth.uid())
  )
);

create policy "Users view their notifications"
on public.user_notifications
for select
to authenticated
using (user_id = (select auth.uid()));

create policy "Users mark their notifications as read"
on public.user_notifications
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "Users view their credits"
on public.volunteer_credits
for select
to authenticated
using (
  user_id = (select auth.uid())
  or private.is_club_sandwich_admin((select auth.uid()))
);

revoke all on public.maraude_workflow_events from anon, authenticated;
revoke all on public.user_notifications from anon, authenticated;
revoke all on public.volunteer_credits from anon, authenticated;
grant select on public.maraude_workflow_events to authenticated;
grant select, update (read_at) on public.user_notifications to authenticated;
grant select on public.volunteer_credits to authenticated;

create or replace function private.notify_user(
  requested_user_id uuid,
  requested_concert_id uuid,
  requested_type text,
  requested_title text,
  requested_body text
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.user_notifications (
    user_id,
    concert_id,
    notification_type,
    title,
    body
  )
  values (
    requested_user_id,
    requested_concert_id,
    requested_type,
    requested_title,
    requested_body
  );
$$;

revoke all on function private.notify_user(
  uuid, uuid, text, text, text
) from public, anon, authenticated;

drop trigger if exists concert_volunteers_normalize_confirmation
  on public.concert_volunteers;

create or replace function private.normalize_volunteer_confirmation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  changed_at timestamptz := clock_timestamp();
begin
  if new.status = 'selected'::public.concert_volunteer_status then
    if tg_op = 'INSERT'
      or old.status is distinct from
        'selected'::public.concert_volunteer_status
      or new.team_role is distinct from old.team_role
    then
      new.confirmation_status :=
        'pending'::public.volunteer_confirmation_status;
      new.confirmation_requested_at := changed_at;
      new.confirmation_due_at := changed_at + interval '24 hours';
      new.confirmation_responded_at := null;
      new.role_acknowledged_at := null;
      new.attendance_status :=
        'pending'::public.volunteer_attendance_status;
      new.attendance_validated_at := null;
      new.attendance_validated_by := null;
    elsif new.confirmation_status =
      'confirmed'::public.volunteer_confirmation_status
      and old.confirmation_status is distinct from
        'confirmed'::public.volunteer_confirmation_status
    then
      if new.role_acknowledged_at is null then
        raise exception 'La fiche de mission doit être reconnue'
          using errcode = '22023';
      end if;
      new.confirmation_responded_at := changed_at;
    end if;
  else
    new.confirmation_status := null;
    new.confirmation_requested_at := null;
    new.confirmation_due_at := null;
    new.confirmation_responded_at := null;
    new.role_acknowledged_at := null;
    new.attendance_validated_at := null;
    new.attendance_validated_by := null;
  end if;

  new.last_modified_by := (select auth.uid());
  return new;
end;
$$;

revoke all on function private.normalize_volunteer_confirmation()
  from public, anon, authenticated;

create trigger concert_volunteers_normalize_confirmation
before insert or update of
  status,
  team_role,
  confirmation_status,
  attendance_status
on public.concert_volunteers
for each row execute function private.normalize_volunteer_confirmation();

create or replace function private.record_volunteer_workflow_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor uuid := (select auth.uid());
begin
  if new.status is distinct from old.status then
    insert into public.maraude_workflow_events (
      concert_id,
      application_id,
      event_type,
      actor_id,
      previous_value,
      new_value
    )
    values (
      new.concert_id,
      new.id,
      case
        when new.status = 'selected'::public.concert_volunteer_status
          then 'selection_requested'
        else 'status_changed'
      end,
      actor,
      jsonb_build_object('status', old.status),
      jsonb_build_object('status', new.status, 'role', new.team_role)
    );

    if new.status = 'selected'::public.concert_volunteer_status then
      perform private.notify_user(
        new.user_id,
        new.concert_id,
        'selection_requested',
        'Vous êtes sélectionné',
        'Confirmez votre participation et prenez connaissance de votre rôle.'
      );
    elsif old.attendance_validated_at is not null then
      update public.volunteer_credits
      set
        status = 'revoked',
        revoked_by = actor,
        revoked_at = clock_timestamp(),
        revocation_reason =
          'Participation retirée après validation des présences'
      where application_id = new.id
        and status = 'active';

      if found then
        insert into public.maraude_workflow_events (
          concert_id,
          application_id,
          event_type,
          actor_id,
          previous_value,
          new_value
        )
        values (
          new.concert_id,
          new.id,
          'credit_revoked',
          actor,
          jsonb_build_object('credit', 'active'),
          jsonb_build_object('credit', 'revoked')
        );
      end if;
    end if;
  end if;

  if new.status = 'selected'::public.concert_volunteer_status
    and new.team_role is distinct from old.team_role
    and old.status = 'selected'::public.concert_volunteer_status
  then
    insert into public.maraude_workflow_events (
      concert_id,
      application_id,
      event_type,
      actor_id,
      previous_value,
      new_value
    )
    values (
      new.concert_id,
      new.id,
      'role_changed',
      actor,
      jsonb_build_object('role', old.team_role),
      jsonb_build_object('role', new.team_role)
    );

    perform private.notify_user(
      new.user_id,
      new.concert_id,
      'role_changed',
      'Votre rôle a changé',
      'Consultez votre nouvelle fiche de mission et confirmez à nouveau.'
    );
  end if;

  if new.confirmation_status is distinct from old.confirmation_status
    and new.confirmation_status =
      'confirmed'::public.volunteer_confirmation_status
  then
    insert into public.maraude_workflow_events (
      concert_id,
      application_id,
      event_type,
      actor_id,
      previous_value,
      new_value
    )
    values (
      new.concert_id,
      new.id,
      'confirmation_completed',
      actor,
      jsonb_build_object('confirmation', old.confirmation_status),
      jsonb_build_object('confirmation', new.confirmation_status)
    );
  end if;

  if new.attendance_status is distinct from old.attendance_status then
    insert into public.maraude_workflow_events (
      concert_id,
      application_id,
      event_type,
      actor_id,
      previous_value,
      new_value
    )
    values (
      new.concert_id,
      new.id,
      'attendance_changed',
      actor,
      jsonb_build_object('attendance', old.attendance_status),
      jsonb_build_object('attendance', new.attendance_status)
    );
  end if;

  return new;
end;
$$;

revoke all on function private.record_volunteer_workflow_event()
  from public, anon, authenticated;

create trigger concert_volunteers_record_workflow
after update of status, team_role, confirmation_status, attendance_status
on public.concert_volunteers
for each row execute function private.record_volunteer_workflow_event();

with ranked_leaders as (
  select
    id,
    row_number() over (
      partition by concert_id
      order by updated_at, id
    ) as position
  from public.concert_volunteers
  where team_role = 'team_leader'::public.maraude_role
)
update public.concert_volunteers application
set team_role = 'collection_distribution'::public.maraude_role
from ranked_leaders
where ranked_leaders.id = application.id
  and ranked_leaders.position > 1;

create unique index concert_volunteers_one_team_leader_idx
on public.concert_volunteers (concert_id)
where team_role = 'team_leader'::public.maraude_role;

create or replace function public.expire_volunteer_confirmations()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  expired_application record;
  expired_count integer := 0;
begin
  if not private.is_active_user((select auth.uid())) then
    raise exception 'Compte actif requis' using errcode = '42501';
  end if;

  for expired_application in
    select application.id, application.concert_id, application.user_id
    from public.concert_volunteers application
    join public.concerts concert on concert.id = application.concert_id
    where application.status =
        'selected'::public.concert_volunteer_status
      and application.confirmation_status =
        'pending'::public.volunteer_confirmation_status
      and application.confirmation_due_at <= clock_timestamp()
      and concert.maraude_status in (
        'open'::public.maraude_status,
        'team_ready'::public.maraude_status
      )
    for update of application skip locked
  loop
    insert into public.maraude_workflow_events (
      concert_id,
      application_id,
      event_type,
      previous_value,
      new_value
    )
    values (
      expired_application.concert_id,
      expired_application.id,
      'confirmation_expired',
      jsonb_build_object('confirmation', 'pending'),
      jsonb_build_object('status', 'pending')
    );

    update public.concert_volunteers
    set status = 'pending'::public.concert_volunteer_status
    where id = expired_application.id;

    perform private.notify_user(
      expired_application.user_id,
      expired_application.concert_id,
      'confirmation_expired',
      'Délai de confirmation expiré',
      'Votre place a été libérée. Vous pouvez de nouveau être sélectionné.'
    );
    expired_count := expired_count + 1;
  end loop;

  return expired_count;
end;
$$;

revoke all on function public.expire_volunteer_confirmations()
  from public, anon;
grant execute on function public.expire_volunteer_confirmations()
  to authenticated;

drop function if exists public.confirm_concert_participation(uuid);

create function public.confirm_concert_participation(
  requested_concert_id uuid,
  requested_role_acknowledged boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_volunteer_account((select auth.uid())) then
    raise exception 'Compte bénévole actif requis'
      using errcode = '42501';
  end if;

  if requested_role_acknowledged is not true then
    raise exception 'La fiche de mission doit être reconnue'
      using errcode = '22023';
  end if;

  perform public.expire_volunteer_confirmations();

  update public.concert_volunteers application
  set
    role_acknowledged_at = clock_timestamp(),
    confirmation_status =
      'confirmed'::public.volunteer_confirmation_status
  where application.concert_id = requested_concert_id
    and application.user_id = (select auth.uid())
    and application.status = 'selected'::public.concert_volunteer_status
    and application.team_role is not null
    and application.confirmation_status =
      'pending'::public.volunteer_confirmation_status
    and application.confirmation_due_at > clock_timestamp();

  if not found then
    raise exception 'Aucune participation à confirmer'
      using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.confirm_concert_participation(uuid, boolean)
  from public, anon;
grant execute on function public.confirm_concert_participation(uuid, boolean)
  to authenticated;

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
  leader_count integer;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut constituer une équipe'
      using errcode = '42501';
  end if;

  perform public.expire_volunteer_confirmations();

  perform 1
  from public.concerts concert
  where concert.id = requested_concert_id
    and private.is_organization_member(
      concert.organization_id,
      (select auth.uid())
    )
  for update;

  if not found then
    raise exception 'Concert inaccessible' using errcode = '42501';
  end if;

  if jsonb_typeof(requested_team) is distinct from 'array' then
    raise exception 'L’équipe doit être transmise sous forme de liste'
      using errcode = '22023';
  end if;

  requested_count := jsonb_array_length(requested_team);

  begin
    select
      count(distinct requested.application_id),
      count(requested.team_role),
      count(*) filter (
        where requested.team_role = 'team_leader'::public.maraude_role
      )
    into distinct_application_count, assigned_role_count, leader_count
    from jsonb_to_recordset(requested_team)
      as requested(application_id uuid, team_role public.maraude_role);
  exception
    when invalid_text_representation then
      raise exception 'Un rôle ou un identifiant est invalide'
        using errcode = '22023';
  end;

  if distinct_application_count <> requested_count
    or assigned_role_count <> requested_count
  then
    raise exception 'Chaque bénévole doit apparaître une fois avec un rôle'
      using errcode = '22023';
  end if;

  if leader_count > 1 then
    raise exception 'Un seul chef d''équipe est autorisé'
      using errcode = '23505';
  end if;

  perform 1
  from public.concert_volunteers application
  where application.concert_id = requested_concert_id
  for update;

  select count(*)
  into matched_count
  from public.concert_volunteers application
  join jsonb_to_recordset(requested_team)
    as requested(application_id uuid, team_role public.maraude_role)
    on requested.application_id = application.id
  where application.concert_id = requested_concert_id
    and application.status <>
      'withdrawn'::public.concert_volunteer_status;

  if matched_count <> requested_count then
    raise exception 'Une candidature est invalide ou désistée'
      using errcode = '22023';
  end if;

  update public.concert_volunteers application
  set status = 'not_selected'::public.concert_volunteer_status
  where application.concert_id = requested_concert_id
    and application.status = 'selected'::public.concert_volunteer_status
    and not exists (
      select 1
      from jsonb_to_recordset(requested_team)
        as requested(application_id uuid, team_role public.maraude_role)
      where requested.application_id = application.id
    );

  update public.concert_volunteers application
  set
    status = 'selected'::public.concert_volunteer_status,
    team_role = requested.team_role
  from jsonb_to_recordset(requested_team)
    as requested(application_id uuid, team_role public.maraude_role)
  where application.id = requested.application_id
    and application.concert_id = requested_concert_id;
end;
$$;

revoke all on function public.save_maraude_team(uuid, jsonb)
  from public, anon;
grant execute on function public.save_maraude_team(uuid, jsonb)
  to authenticated;

create function public.get_maraude_attendance(
  requested_concert_id uuid
)
returns table (
  application_id uuid,
  user_id uuid,
  display_name text,
  team_role public.maraude_role,
  confirmation_status public.volunteer_confirmation_status,
  attendance_status public.volunteer_attendance_status,
  attendance_validated_at timestamptz,
  attendance_validated_by uuid,
  last_modified_at timestamptz,
  last_modified_by_name text,
  can_validate boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  caller_is_admin boolean :=
    private.is_club_sandwich_admin((select auth.uid()));
  caller_is_leader boolean;
begin
  perform public.expire_volunteer_confirmations();

  select exists (
    select 1
    from public.concert_volunteers leader
    where leader.concert_id = requested_concert_id
      and leader.user_id = (select auth.uid())
      and leader.status = 'selected'::public.concert_volunteer_status
      and leader.team_role = 'team_leader'::public.maraude_role
      and leader.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
  )
  into caller_is_leader;

  if not caller_is_admin and not caller_is_leader then
    raise exception 'Accès aux présences refusé' using errcode = '42501';
  end if;

  return query
  select
    application.id,
    application.user_id,
    nullif(btrim(profile.first_name || ' ' || profile.last_name), ''),
    application.team_role,
    application.confirmation_status,
    application.attendance_status,
    application.attendance_validated_at,
    application.attendance_validated_by,
    application.updated_at,
    nullif(
      btrim(modifier.first_name || ' ' || modifier.last_name),
      ''
    ),
    caller_is_admin
  from public.concert_volunteers application
  join public.profiles profile on profile.id = application.user_id
  left join public.profiles modifier
    on modifier.id = application.last_modified_by
  where application.concert_id = requested_concert_id
    and application.status = 'selected'::public.concert_volunteer_status
  order by
    case
      when application.team_role = 'team_leader'::public.maraude_role
        then 0
      else 1
    end,
    profile.first_name,
    profile.last_name;
end;
$$;

revoke all on function public.get_maraude_attendance(uuid)
  from public, anon;
grant execute on function public.get_maraude_attendance(uuid)
  to authenticated;

create function public.set_volunteer_attendance(
  requested_application_id uuid,
  requested_status public.volunteer_attendance_status
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target record;
  caller_is_admin boolean :=
    private.is_club_sandwich_admin((select auth.uid()));
  previous_was_validated boolean;
begin
  select application.*, concert.maraude_status
  into target
  from public.concert_volunteers application
  join public.concerts concert on concert.id = application.concert_id
  where application.id = requested_application_id
  for update of application;

  if not found then
    raise exception 'Bénévole introuvable' using errcode = 'P0002';
  end if;

  if not caller_is_admin and not exists (
    select 1
    from public.concert_volunteers leader
    where leader.concert_id = target.concert_id
      and leader.user_id = (select auth.uid())
      and leader.status = 'selected'::public.concert_volunteer_status
      and leader.team_role = 'team_leader'::public.maraude_role
      and leader.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
  ) then
    raise exception 'Gestion des présences refusée' using errcode = '42501';
  end if;

  if target.status <> 'selected'::public.concert_volunteer_status
    or target.confirmation_status <>
      'confirmed'::public.volunteer_confirmation_status
  then
    raise exception 'La présence exige une participation confirmée'
      using errcode = '22023';
  end if;

  if target.maraude_status = 'completed'::public.maraude_status
    and not caller_is_admin
  then
    raise exception 'Seul un administrateur corrige après la clôture'
      using errcode = '42501';
  end if;

  previous_was_validated := target.attendance_validated_at is not null;

  update public.concert_volunteers
  set
    attendance_status = requested_status,
    attendance_validated_at = null,
    attendance_validated_by = null
  where id = requested_application_id;

  if previous_was_validated then
    update public.volunteer_credits
    set
      status = 'revoked',
      revoked_by = (select auth.uid()),
      revoked_at = clock_timestamp(),
      revocation_reason = 'Présence corrigée après validation'
    where application_id = requested_application_id
      and status = 'active';

    insert into public.maraude_workflow_events (
      concert_id,
      application_id,
      event_type,
      actor_id,
      previous_value,
      new_value
    )
    values (
      target.concert_id,
      requested_application_id,
      'attendance_corrected',
      (select auth.uid()),
      jsonb_build_object('attendance', target.attendance_status),
      jsonb_build_object('attendance', requested_status)
    );
  end if;
end;
$$;

revoke all on function public.set_volunteer_attendance(
  uuid, public.volunteer_attendance_status
) from public, anon;
grant execute on function public.set_volunteer_attendance(
  uuid, public.volunteer_attendance_status
) to authenticated;

create function public.validate_maraude_attendance(
  requested_concert_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  awarded_count integer;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Validation administrateur requise'
      using errcode = '42501';
  end if;

  perform 1
  from public.concerts concert
  where concert.id = requested_concert_id
    and concert.maraude_status = 'completed'::public.maraude_status
    and private.is_organization_member(
      concert.organization_id,
      (select auth.uid())
    )
  for update;

  if not found then
    raise exception 'La maraude doit être terminée'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.concert_volunteers application
    where application.concert_id = requested_concert_id
      and application.status = 'selected'::public.concert_volunteer_status
      and application.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
      and application.attendance_status =
        'pending'::public.volunteer_attendance_status
  ) then
    raise exception 'Toutes les présences doivent être renseignées'
      using errcode = '22023';
  end if;

  select count(*)
  into awarded_count
  from public.concert_volunteers application
  where application.concert_id = requested_concert_id
    and application.status = 'selected'::public.concert_volunteer_status
    and application.confirmation_status =
      'confirmed'::public.volunteer_confirmation_status
    and application.attendance_status =
      'present'::public.volunteer_attendance_status
    and not exists (
      select 1
      from public.volunteer_credits credit
      where credit.concert_id = application.concert_id
        and credit.user_id = application.user_id
        and credit.status = 'active'
    );

  update public.concert_volunteers
  set
    attendance_validated_at = clock_timestamp(),
    attendance_validated_by = (select auth.uid())
  where concert_id = requested_concert_id
    and status = 'selected'::public.concert_volunteer_status
    and confirmation_status =
      'confirmed'::public.volunteer_confirmation_status
    and attendance_status in (
      'present'::public.volunteer_attendance_status,
      'absent'::public.volunteer_attendance_status
    );

  insert into public.volunteer_credits (
    concert_id,
    application_id,
    user_id,
    status,
    awarded_by,
    awarded_at,
    revoked_by,
    revoked_at,
    revocation_reason
  )
  select
    application.concert_id,
    application.id,
    application.user_id,
    'active',
    (select auth.uid()),
    clock_timestamp(),
    null,
    null,
    null
  from public.concert_volunteers application
  where application.concert_id = requested_concert_id
    and application.status = 'selected'::public.concert_volunteer_status
    and application.confirmation_status =
      'confirmed'::public.volunteer_confirmation_status
    and application.attendance_status =
      'present'::public.volunteer_attendance_status
  on conflict (concert_id, user_id) do update
  set
    status = 'active',
    application_id = excluded.application_id,
    awarded_by = excluded.awarded_by,
    awarded_at = excluded.awarded_at,
    revoked_by = null,
    revoked_at = null,
    revocation_reason = null;

  insert into public.maraude_workflow_events (
    concert_id,
    event_type,
    actor_id,
    new_value
  )
  values (
    requested_concert_id,
    'attendance_validated',
    (select auth.uid()),
    jsonb_build_object('credits_awarded', awarded_count)
  );

  return awarded_count;
end;
$$;

revoke all on function public.validate_maraude_attendance(uuid)
  from public, anon;
grant execute on function public.validate_maraude_attendance(uuid)
  to authenticated;

create or replace function private.volunteer_credit_count(
  requested_user_id uuid
)
returns bigint
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select count(*)::bigint
  from public.volunteer_credits credit
  where credit.user_id = requested_user_id
    and credit.status = 'active';
$$;

revoke all on function private.volunteer_credit_count(uuid)
  from public, anon, authenticated;

create function public.get_my_volunteer_credit_count()
returns bigint
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select private.volunteer_credit_count((select auth.uid()));
$$;

revoke all on function public.get_my_volunteer_credit_count()
  from public, anon;
grant execute on function public.get_my_volunteer_credit_count()
  to authenticated;

drop policy if exists "Volunteers create their invitation applications"
  on public.invitation_applications;

create policy "Eligible volunteers create invitation applications"
on public.invitation_applications
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and status = 'pending'::public.invitation_application_status
  and private.is_volunteer_account((select auth.uid()))
  and private.volunteer_credit_count((select auth.uid())) >= 3
  and exists (
    select 1
    from public.invitation_campaigns campaign
    where campaign.id = invitation_applications.campaign_id
      and campaign.status = 'open'::public.invitation_campaign_status
      and (
        campaign.application_deadline is null
        or campaign.application_deadline >= now()
      )
  )
);

revoke update (
  team_role,
  attendance_status,
  confirmation_status,
  confirmation_requested_at,
  confirmation_responded_at,
  confirmation_due_at,
  role_acknowledged_at,
  attendance_validated_at,
  attendance_validated_by,
  last_modified_by
) on public.concert_volunteers from authenticated;

create or replace function public.set_maraude_status(
  requested_concert_id uuid,
  requested_status public.maraude_status,
  requested_cancellation_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  changed_at timestamptz := clock_timestamp();
  current_status public.maraude_status;
  is_admin boolean :=
    private.is_club_sandwich_admin((select auth.uid()));
  is_confirmed_team_leader boolean;
begin
  perform public.expire_volunteer_confirmations();

  select concert.maraude_status
  into current_status
  from public.concerts concert
  where concert.id = requested_concert_id
    and (
      (
        is_admin
        and private.is_organization_member(
          concert.organization_id,
          (select auth.uid())
        )
      )
      or exists (
        select 1
        from public.concert_volunteers leader
        where leader.concert_id = concert.id
          and leader.user_id = (select auth.uid())
          and leader.status =
            'selected'::public.concert_volunteer_status
          and leader.team_role = 'team_leader'::public.maraude_role
          and leader.confirmation_status =
            'confirmed'::public.volunteer_confirmation_status
      )
    )
  for update;

  if not found then
    raise exception 'Concert inaccessible' using errcode = '42501';
  end if;

  select exists (
    select 1
    from public.concert_volunteers leader
    where leader.concert_id = requested_concert_id
      and leader.user_id = (select auth.uid())
      and leader.status = 'selected'::public.concert_volunteer_status
      and leader.team_role = 'team_leader'::public.maraude_role
      and leader.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
  )
  into is_confirmed_team_leader;

  if not is_admin and not (
    is_confirmed_team_leader
    and (
      (
        current_status in (
          'open'::public.maraude_status,
          'team_ready'::public.maraude_status
        )
        and requested_status = 'in_progress'::public.maraude_status
      )
      or (
        current_status = 'in_progress'::public.maraude_status
        and requested_status = 'completed'::public.maraude_status
      )
    )
  ) then
    raise exception 'Action réservée au chef d''équipe'
      using errcode = '42501';
  end if;

  if requested_status = 'in_progress'::public.maraude_status then
    if current_status not in (
      'open'::public.maraude_status,
      'team_ready'::public.maraude_status
    ) then
      raise exception 'Cette maraude ne peut pas être démarrée'
        using errcode = '22023';
    end if;

    if not exists (
      select 1
      from public.concert_volunteers leader
      where leader.concert_id = requested_concert_id
        and leader.status = 'selected'::public.concert_volunteer_status
        and leader.team_role = 'team_leader'::public.maraude_role
        and leader.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
        and leader.attendance_status =
          'present'::public.volunteer_attendance_status
    ) then
      raise exception 'Un chef d''équipe confirmé et présent est requis'
        using errcode = '22023';
    end if;
  end if;

  if requested_status = 'completed'::public.maraude_status
    and current_status <> 'in_progress'::public.maraude_status
  then
    raise exception 'La maraude doit être en cours avant sa clôture'
      using errcode = '22023';
  end if;

  if current_status in (
    'completed'::public.maraude_status,
    'cancelled'::public.maraude_status
  ) and requested_status is distinct from current_status
  then
    raise exception 'Une maraude archivée ne peut plus changer d''état'
      using errcode = '22023';
  end if;

  update public.concerts
  set
    maraude_status = requested_status,
    actual_start_at = case
      when requested_status = 'in_progress'::public.maraude_status
        then coalesce(actual_start_at, changed_at)
      else actual_start_at
    end,
    actual_end_at = case
      when requested_status = 'completed'::public.maraude_status
        then greatest(changed_at, coalesce(actual_start_at, changed_at))
      else actual_end_at
    end,
    cancellation_reason = case
      when requested_status = 'cancelled'::public.maraude_status
        then nullif(btrim(requested_cancellation_reason), '')
      else cancellation_reason
    end
  where id = requested_concert_id;

  if requested_status in (
    'in_progress'::public.maraude_status,
    'completed'::public.maraude_status
  ) and requested_status is distinct from current_status
  then
    insert into public.maraude_workflow_events (
      concert_id,
      event_type,
      actor_id,
      previous_value,
      new_value
    )
    values (
      requested_concert_id,
      case
        when requested_status = 'in_progress'::public.maraude_status
          then 'maraude_started'
        else 'maraude_completed'
      end,
      (select auth.uid()),
      jsonb_build_object('status', current_status),
      jsonb_build_object('status', requested_status, 'at', changed_at)
    );
  end if;
end;
$$;

revoke all on function public.set_maraude_status(
  uuid, public.maraude_status, text
) from public, anon;
grant execute on function public.set_maraude_status(
  uuid, public.maraude_status, text
) to authenticated;
