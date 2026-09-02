-- Reported live: every volunteer got "Votre rôle a changé" even though
-- the admin was assigning their role for the very first time.
--
-- Root cause: select_concert_volunteers silently defaulted a fresh
-- selection's team_role to 'collection_distribution' via coalesce().
-- When the admin then actually picked a role for that person (a
-- separate action, since team building selects first and assigns roles
-- after), record_volunteer_workflow_event saw team_role go from that
-- phantom default to the chosen role - on an already-'selected' row -
-- and treated it as a genuine reassignment, notifying the volunteer of
-- a "change" they never experienced.
--
-- Fixed at both ends: selection no longer invents a default role (stays
-- null until the admin actually picks one), and the notification only
-- fires when there was a real previous role to change away from.

create or replace function public.select_concert_volunteers(
  requested_concert_id uuid,
  requested_application_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  requested_count integer;
  matched_count integer;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut constituer une équipe'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.concerts c
    where c.id = requested_concert_id
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  ) then
    raise exception 'Concert inaccessible'
      using errcode = '42501';
  end if;

  select count(distinct application_id)
  into requested_count
  from unnest(requested_application_ids) as application_id;

  if requested_count = 0 then
    raise exception 'Aucun volontaire sélectionné'
      using errcode = '22023';
  end if;

  select count(*)
  into matched_count
  from public.concert_volunteers cv
  where cv.concert_id = requested_concert_id
    and cv.id = any(requested_application_ids)
    and cv.status <> 'withdrawn'::public.concert_volunteer_status;

  if matched_count <> requested_count then
    raise exception 'Un volontaire est invalide ou désisté'
      using errcode = '22023';
  end if;

  update public.concert_volunteers
  set
    status = 'selected'::public.concert_volunteer_status,
    attendance_status = coalesce(
      attendance_status,
      'pending'::public.volunteer_attendance_status
    )
  where concert_id = requested_concert_id
    and id = any(requested_application_ids);
end;
$$;

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
    and old.team_role is not null
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
