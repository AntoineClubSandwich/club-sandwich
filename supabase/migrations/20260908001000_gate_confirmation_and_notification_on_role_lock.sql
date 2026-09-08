-- Antoine's report: a volunteer could confirm their participation as
-- soon as ANY role was assigned, before the admin clicked "Verrouiller".
-- That button exists specifically as a guardrail (20260828009000) against
-- an accidental role/status change silently invalidating a confirmation -
-- but nothing ever actually required the lock before confirmation was
-- allowed, so the guardrail wasn't protecting anything yet.
--
-- Also folds in a follow-up decision from the same conversation: the
-- "you're selected, go confirm" / "your role changed, reconfirm"
-- notifications (previously fired straight off team_role changing, see
-- 20260908000000) should likewise wait for the lock - a volunteer told
-- to "confirm your participation" for a role they can't yet confirm
-- (unlocked) is the same premature-notification problem in a different
-- guise.

-- 1. Confirmation now requires a locked role, not just an assigned one.
create or replace function public.confirm_concert_participation(
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
    and application.team_role_locked
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

-- 2. Stop notifying off team_role changes directly - the role isn't
--    settled until it's locked, so notifying earlier just repeats the
--    original bug.
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

  return new;
end;
$$;

drop trigger if exists concert_volunteers_notify_role_change
  on public.concert_volunteers;
drop function if exists
  private.notify_role_change_requires_reconfirmation();

-- 3. The single notification point: the admin locking a role, which is
--    also now the only thing that makes the role confirmable.
create function private.notify_volunteer_role_locked()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  concert_artist text;
  role_label text;
begin
  if new.team_role_locked is not true
    or old.team_role_locked is true
    or new.status <> 'selected'::public.concert_volunteer_status
    or new.team_role is null
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

  perform private.notify_user(
    new.user_id,
    new.concert_id,
    'selection_requested',
    'Vous êtes sélectionné',
    format(
      'Votre rôle pour la maraude %s est confirmé : %s. '
      || 'Confirmez votre participation et prenez connaissance de votre '
      || 'fiche de mission.',
      concert_artist,
      role_label
    )
  );

  return new;
end;
$$;

revoke all on function private.notify_volunteer_role_locked()
  from public, anon, authenticated;

create trigger concert_volunteers_notify_role_locked
after update of team_role_locked on public.concert_volunteers
for each row execute function private.notify_volunteer_role_locked();
