-- Phase 4 ("garde-fous anti-spam") of the notification/email overhaul -
-- scoped to what's concretely buildable without inventing new UI or a
-- delayed-send infrastructure this pass. Two guardrails:
--
-- 1. Dedup at the single choke point every notification already goes
--    through (private.notify_user): skip inserting a notification that
--    is an exact duplicate (same recipient, concert, type, title AND
--    body) of one created in the last 5 minutes. Catches accidental
--    double-fires (a retry, a multi-column UPDATE re-triggering the
--    same logical event) without suppressing two genuinely different
--    occurrences of the same notification type later on - title/body
--    equality is a deliberately tight bar precisely so it doesn't
--    swallow real, distinct events.
--
-- 2. Don't notify the person who just performed the action: the
--    schedule-change notification (20260908006000) loops every
--    selected volunteer and every active promoter of the concert's
--    organization - if the person editing the maraude is themselves a
--    promoter with manage rights on it (or, edge case, an admin who's
--    also a selected volunteer there), they'd get emailed about their
--    own edit. Both loops now skip the acting user.
--
-- Deliberately NOT built this pass (flagged, not silently dropped):
-- - Cross-request batching beyond what 20260908006000 already does
--   (multiple fields changed in one "modifier la maraude" submit
--   already coalesce into one notification, since it's one row-level
--   UPDATE trigger firing once - true batching across separate saves
--   minutes apart would need a delayed-send queue, a new system).
-- - Auto-closing a notification once its action is completed - doing
--   this without leaving a dead, invisible DB column (the exact
--   "estimated_meals never displayed" mistake fixed in f31bb39) needs
--   real bell-UI work (a resolved-state badge/filter), not just a
--   column - scoped out as a follow-up with its own review rather than
--   half-built here.
-- - Re-verifying maraude/volunteer status at actual send time (the
--   dispatch cron can lag up to a minute behind enqueue) - a narrow
--   race window that doesn't justify per-type re-validation logic in
--   this pass.

create or replace function private.notify_user(
  requested_user_id uuid,
  requested_concert_id uuid,
  requested_type text,
  requested_title text,
  requested_body text,
  requested_send_email boolean default true
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (
    select 1
    from public.user_notifications existing
    where existing.user_id = requested_user_id
      and existing.notification_type = requested_type
      and existing.title = requested_title
      and existing.body = requested_body
      and existing.concert_id is not distinct from requested_concert_id
      and existing.created_at > clock_timestamp() - interval '5 minutes'
  ) then
    return;
  end if;

  insert into public.user_notifications (
    user_id,
    concert_id,
    notification_type,
    title,
    body,
    send_email
  )
  values (
    requested_user_id,
    requested_concert_id,
    requested_type,
    requested_title,
    requested_body,
    requested_send_email
  );
end;
$$;

revoke all on function private.notify_user(
  uuid, uuid, text, text, text, boolean
) from public, anon, authenticated;

create or replace function private.reset_team_on_maraude_schedule_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor uuid := (select auth.uid());
  application record;
  promoter_account record;
  new_venue_name text;
  change_parts text[] := '{}';
  change_summary text;
begin
  if new.concert_date is not distinct from old.concert_date
    and new.concert_time is not distinct from old.concert_time
    and new.venue_id is not distinct from old.venue_id
  then
    return new;
  end if;

  if new.maraude_status not in (
    'open'::public.maraude_status,
    'team_ready'::public.maraude_status
  ) then
    return new;
  end if;

  if new.concert_date is distinct from old.concert_date then
    change_parts := change_parts ||
      format('nouvelle date : %s', to_char(new.concert_date, 'DD/MM/YYYY'));
  end if;
  if new.concert_time is distinct from old.concert_time then
    change_parts := change_parts ||
      format('nouvel horaire : %s', to_char(new.concert_time, 'HH24:MI'));
  end if;
  if new.venue_id is distinct from old.venue_id then
    select name into new_venue_name
    from public.venues
    where id = new.venue_id;
    change_parts := change_parts ||
      format('nouveau lieu : %s', coalesce(new_venue_name, 'à préciser'));
  end if;
  change_summary := array_to_string(change_parts, ', ');

  for application in
    select id, user_id, team_role_locked
    from public.concert_volunteers
    where concert_id = new.id
      and status = 'selected'::public.concert_volunteer_status
  loop
    if not application.team_role_locked then
      update public.concert_volunteers
      set status = 'pending'::public.concert_volunteer_status
      where id = application.id;

      insert into public.maraude_workflow_events (
        concert_id,
        application_id,
        event_type,
        actor_id,
        previous_value,
        new_value
      )
      values (
        new.id,
        application.id,
        'schedule_changed',
        actor,
        jsonb_build_object(
          'concert_date', old.concert_date,
          'concert_time', old.concert_time,
          'venue_id', old.venue_id,
          'status', 'selected'
        ),
        jsonb_build_object(
          'concert_date', new.concert_date,
          'concert_time', new.concert_time,
          'venue_id', new.venue_id,
          'status', 'pending'
        )
      );
    end if;

    -- Don't tell the editor about their own edit.
    if application.user_id <> actor then
      perform private.notify_user(
        application.user_id,
        new.id,
        'schedule_changed',
        'La maraude a été modifiée',
        case
          when application.team_role_locked then
            format(
              'La maraude "%s" a été modifiée (%s). Votre rôle reste '
              || 'verrouillé, mais vérifiez les nouvelles informations.',
              new.artist,
              change_summary
            )
          else
            format(
              'La maraude "%s" a été modifiée (%s). Votre sélection a été '
              || 'annulée : l’équipe doit être reconstituée pour les '
              || 'nouvelles informations.',
              new.artist,
              change_summary
            )
        end
      );
    end if;
  end loop;

  if new.promoter_organization_id is not null then
    for promoter_account in
      select account.profile_id
      from public.user_accounts account
      where account.role = 'promoter'::public.app_role
        and account.status = 'active'::public.user_account_status
        and account.organization_id = new.promoter_organization_id
        and account.profile_id <> actor
    loop
      perform private.notify_user(
        promoter_account.profile_id,
        new.id,
        'schedule_changed',
        'La maraude a été modifiée',
        format(
          'La maraude "%s" a été modifiée (%s).',
          new.artist,
          change_summary
        )
      );
    end loop;
  end if;

  return new;
end;
$$;

revoke all on function private.reset_team_on_maraude_schedule_change()
  from public, anon, authenticated;
