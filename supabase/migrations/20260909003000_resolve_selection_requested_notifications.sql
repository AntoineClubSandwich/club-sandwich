-- Continuing the deferred "fermer ou rendre obsolète une notification
-- lorsque l'action correspondante a été effectuée" guardrail, scoped
-- (as flagged in 20260909002000) to the one case with an unambiguous
-- correlation: 'selection_requested' ties 1:1 to a (user_id, concert_id)
-- pair via concert_volunteers' own uniqueness, so resolving it needs no
-- new reference-id column. Documents/conventions still need one before
-- they can be resolved precisely (a user can have several pending at
-- once) - not attempted here.
--
-- Also wires the bell UI: a resolved-but-never-opened notification no
-- longer counts as needing attention (badge, dot) - distinct from
-- "read", but treated the same visually, since the point in both cases
-- is the same: nothing left to do here.

alter table public.user_notifications
  add column resolved_at timestamptz;

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

    if new.status <> 'selected'::public.concert_volunteer_status
      and old.attendance_validated_at is not null then
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

  -- Still logged for the audit trail / timeline, just no longer notified
  -- here directly - see notify_volunteer_role_locked() below.
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

  -- The "confirmez votre participation" ask is done with once: the
  -- volunteer actually confirms, they leave 'selected' entirely
  -- (withdrawn/removed - moot), or their role changes (superseded by
  -- whatever notification the next lock fires).
  if (
    new.confirmation_status = 'confirmed'::public.volunteer_confirmation_status
    and old.confirmation_status is distinct from new.confirmation_status
  ) or (
    new.status <> 'selected'::public.concert_volunteer_status
    and old.status is distinct from new.status
  ) or (
    new.team_role is distinct from old.team_role
  ) then
    update public.user_notifications
    set resolved_at = clock_timestamp()
    where user_id = new.user_id
      and concert_id = new.concert_id
      and notification_type = 'selection_requested'
      and resolved_at is null;
  end if;

  return new;
end;
$$;

revoke all on function private.record_volunteer_workflow_event()
from public, anon, authenticated;
