-- Reported live: a volunteer got "Vous êtes sélectionné - Confirmez votre
-- participation et prenez connaissance de votre rôle" right when the
-- admin merely selected them (status -> 'selected'), before any role was
-- ever assigned. Since 20260902001000, selection deliberately leaves
-- team_role null - assigning a role is a separate, later admin action
-- (set_volunteer_team_role) - but nobody moved the notification to fire
-- from that step instead, so volunteers were told to go check a role
-- that didn't exist yet.
--
-- Fix: selection no longer notifies. The "you're selected" notification
-- now fires from the team_role update trigger, on the volunteer's first
-- role assignment (old.team_role is null -> new.team_role is not null),
-- and includes the actual role. The existing "your role changed"
-- notification (role changed after the volunteer had already confirmed)
-- is unchanged.

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

create or replace function private.notify_role_change_requires_reconfirmation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  concert_artist text;
  role_label text;
begin
  if new.status <> 'selected'::public.concert_volunteer_status
    or new.team_role is not distinct from old.team_role
  then
    return new;
  end if;

  select concert.artist into concert_artist
  from public.concerts concert
  where concert.id = new.concert_id;

  role_label := case new.team_role
    when 'team_leader'::public.maraude_role then 'chef.fe d’équipe'
    when 'communication'::public.maraude_role
      then 'chargé.e de communication'
    when 'logistics'::public.maraude_role then 'chargé.e de logistique'
    when 'collection_distribution'::public.maraude_role
      then 'chargé.e de récolte et distribution'
    else 'non attribué'
  end;

  if old.team_role is null then
    perform private.notify_user(
      new.user_id,
      new.concert_id,
      'selection_requested',
      'Vous êtes sélectionné',
      format(
        'Vous avez été sélectionné.e pour la maraude %s en tant que %s. '
        || 'Confirmez votre participation et prenez connaissance de votre '
        || 'fiche de mission.',
        concert_artist,
        role_label
      )
    );
  elsif old.confirmation_status =
      'confirmed'::public.volunteer_confirmation_status
    and new.confirmation_status =
      'pending'::public.volunteer_confirmation_status
  then
    perform private.notify_user(
      new.user_id,
      new.concert_id,
      'role_changed',
      'Votre rôle a changé',
      format(
        'Votre rôle pour la maraude %s a été modifié (%s). '
        || 'Merci de confirmer à nouveau votre participation.',
        concert_artist,
        role_label
      )
    );
  end if;

  return new;
end;
$$;

revoke all on function private.notify_role_change_requires_reconfirmation()
from public, anon, authenticated;
