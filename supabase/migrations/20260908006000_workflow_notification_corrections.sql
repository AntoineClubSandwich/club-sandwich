-- Phase 3 ("corrections de notifications") of the notification/email
-- overhaul. Uses the send_email flag added in phase 1
-- (20260908005000) to make several existing notifications in-app-only,
-- fixes a withdrawal notification that fired regardless of whether the
-- volunteer had ever been selected, extends the schedule-change
-- notification to also cover venue changes and locked roles, adds the
-- missing "new volontariat" heads-up to admins, and stops the
-- day-before reminder from duplicating a schedule-change email sent the
-- same day.
--
-- Deliberately deferred (needs product judgment, not just wiring):
-- the "email quand même si la maraude est proche ou manque de
-- bénévoles" escalation on new-volontariat/document-submitted - these
-- ship as in-app-only unconditionally in this pass. Flagged for a
-- follow-up once the "proche"/"manque" thresholds are decided.

-- notify_active_admins gains a 5th, defaulted send_email parameter -
-- dropped and recreated (not create-or-replace) because a differing
-- arg count creates a second overload instead of replacing the
-- function, as already hit once this session with notify_user
-- (20260908005100).
drop function private.notify_active_admins(uuid, text, text, text);

create function private.notify_active_admins(
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
declare
  admin_account record;
begin
  for admin_account in
    select account.profile_id
    from public.user_accounts account
    where account.role = 'admin'::public.app_role
      and account.status = 'active'::public.user_account_status
  loop
    perform private.notify_user(
      admin_account.profile_id,
      requested_concert_id,
      requested_type,
      requested_title,
      requested_body,
      requested_send_email
    );
  end loop;
end;
$$;

revoke all on function private.notify_active_admins(
  uuid, text, text, text, boolean
) from public, anon, authenticated;

-- 1. Nouveau volontariat: the volunteer's own "c'est enregistré" ack
--    moves in-app-only (it's not an action or a critical change per the
--    spec's own routing principle), and admins now get a heads-up
--    (previously nothing at all notified them of a new volontariat).
create or replace function private.notify_volunteer_application_changes()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  concert_artist text;
  concert_date_value date;
  venue_name_value text;
begin
  select concert.artist, concert.concert_date, venue.name
  into concert_artist, concert_date_value, venue_name_value
  from public.concerts concert
  left join public.venues venue on venue.id = concert.venue_id
  where concert.id = new.concert_id;

  if tg_op = 'INSERT'
    and new.status = 'pending'::public.concert_volunteer_status
  then
    perform private.notify_user(
      new.user_id,
      new.concert_id,
      'application_received',
      'Volontariat enregistré',
      format(
        'Votre volontariat pour la maraude %s a bien été enregistré.',
        concert_artist
      ),
      false
    );

    perform private.notify_active_admins(
      new.concert_id,
      'volunteer_application_submitted',
      format(
        'Nouveau volontariat — %s — %s',
        coalesce(to_char(concert_date_value, 'DD/MM/YYYY'), 'date à confirmer'),
        coalesce(venue_name_value, 'lieu à confirmer')
      ),
      format(
        'Un bénévole s’est positionné sur la maraude %s.',
        concert_artist
      ),
      false
    );
  elsif new.status is distinct from old.status then
    if new.status = 'not_selected'::public.concert_volunteer_status then
      perform private.notify_user(
        new.user_id,
        new.concert_id,
        'application_rejected',
        'Volontariat non retenu',
        format(
          'Votre volontariat pour la maraude %s n’a pas été retenu.',
          concert_artist
        )
      );
    elsif new.status = 'withdrawn'::public.concert_volunteer_status
      and old.status = 'selected'::public.concert_volunteer_status
    then
      -- Only a volunteer who was actually selected (or confirmed - that's
      -- a confirmation_status layered on top of the same 'selected' row
      -- status, so this one check covers both) leaves a real vacancy.
      -- A simple candidate withdrawing before selection isn't an admin's
      -- problem to react to.
      perform private.notify_active_admins(
        new.concert_id,
        'volunteer_withdrawn',
        'Désistement bénévole',
        format(
          'Un bénévole %s s’est désisté de la maraude %s.',
          case
            when old.team_role is not null
              then 'sélectionné en tant que ' ||
                private.maraude_role_label(old.team_role)
            else 'sélectionné'
          end,
          concert_artist
        )
      );
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.notify_volunteer_application_changes()
from public, anon, authenticated;

-- 4. Documents: "validé" no longer warrants an email (the volunteer
--    isn't asked to do anything), "refusé" keeps email+in-app (an
--    action is expected: re-submit). Submission to admins moves
--    in-app-only, same as the new-volontariat heads-up above.
create or replace function public.submit_my_volunteer_document(
  requested_document_type public.volunteer_document_type,
  requested_storage_path text,
  requested_document_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_volunteer_account((select auth.uid())) then
    raise exception 'Compte bénévole actif requis' using errcode = '42501';
  end if;

  if requested_storage_path is null
    or char_length(btrim(requested_storage_path)) = 0
  then
    raise exception 'Le fichier est requis' using errcode = '22023';
  end if;

  if requested_document_type = 'other'::public.volunteer_document_type then
    if requested_document_id is null then
      raise exception 'Document demandé introuvable' using errcode = 'P0002';
    end if;

    update public.volunteer_documents
    set
      storage_path = requested_storage_path,
      status = 'pending'::public.volunteer_document_status,
      uploaded_by = (select auth.uid()),
      uploaded_at = clock_timestamp(),
      reviewed_by = null,
      reviewed_at = null,
      rejection_reason = null,
      updated_at = now()
    where id = requested_document_id
      and user_id = (select auth.uid())
      and document_type = 'other'::public.volunteer_document_type;

    if not found then
      raise exception 'Document demandé introuvable' using errcode = 'P0002';
    end if;
  else
    insert into public.volunteer_documents (
      user_id, document_type, storage_path, status, uploaded_by, uploaded_at
    )
    values (
      (select auth.uid()),
      requested_document_type,
      requested_storage_path,
      'pending'::public.volunteer_document_status,
      (select auth.uid()),
      clock_timestamp()
    )
    on conflict (user_id, document_type)
    where document_type <> 'other'::public.volunteer_document_type
    do update set
      storage_path = excluded.storage_path,
      status = 'pending'::public.volunteer_document_status,
      uploaded_by = excluded.uploaded_by,
      uploaded_at = excluded.uploaded_at,
      reviewed_by = null,
      reviewed_at = null,
      rejection_reason = null,
      updated_at = now();
  end if;

  perform private.notify_active_admins(
    null,
    'volunteer_document_submitted',
    'Document à valider',
    'Un bénévole a déposé un document en attente de validation.',
    false
  );
end;
$$;

revoke all on function public.submit_my_volunteer_document(
  public.volunteer_document_type, text, uuid
) from public, anon;
grant execute on function public.submit_my_volunteer_document(
  public.volunteer_document_type, text, uuid
) to authenticated;

create or replace function public.review_volunteer_document(
  requested_document_id uuid,
  requested_status public.volunteer_document_status,
  requested_rejection_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target record;
  notification_title text;
  notification_body text;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Accès administrateur requis' using errcode = '42501';
  end if;

  if requested_status not in (
    'approved'::public.volunteer_document_status,
    'rejected'::public.volunteer_document_status
  ) then
    raise exception 'Statut de validation invalide' using errcode = '22023';
  end if;

  if requested_status = 'rejected'::public.volunteer_document_status
    and (
      requested_rejection_reason is null
      or char_length(btrim(requested_rejection_reason)) = 0
    )
  then
    raise exception 'Un motif de refus est requis' using errcode = '22023';
  end if;

  select *
  into target
  from public.volunteer_documents
  where id = requested_document_id
    and storage_path is not null
  for update;

  if not found then
    raise exception 'Document introuvable ou non déposé' using errcode = 'P0002';
  end if;

  update public.volunteer_documents
  set
    status = requested_status,
    reviewed_by = (select auth.uid()),
    reviewed_at = clock_timestamp(),
    rejection_reason = case
      when requested_status = 'rejected'::public.volunteer_document_status
        then btrim(requested_rejection_reason)
      else null
    end,
    updated_at = now()
  where id = requested_document_id;

  if requested_status = 'approved'::public.volunteer_document_status then
    notification_title := 'Document validé';
    notification_body := 'Votre document a été validé.';
  else
    notification_title := 'Document refusé';
    notification_body := format(
      'Votre document a été refusé : %s. Merci de le déposer à nouveau.',
      btrim(requested_rejection_reason)
    );
  end if;

  perform private.notify_user(
    target.user_id, null, 'volunteer_document_reviewed',
    notification_title, notification_body,
    requested_status <> 'approved'::public.volunteer_document_status
  );
end;
$$;

revoke all on function public.review_volunteer_document(
  uuid, public.volunteer_document_status, text
) from public, anon;
grant execute on function public.review_volunteer_document(
  uuid, public.volunteer_document_status, text
) to authenticated;

-- Same logic for organization conventions: submission to admins moves
-- in-app-only. Countersigned/refused (public.review_organization_convention
-- and public.admin_set_organization_convention) are untouched - both
-- already carry an expected action for the promoter (nothing to fix).
create or replace function public.submit_my_organization_convention(
  requested_organization_id uuid,
  requested_storage_path text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_promoter_account_member(
    requested_organization_id, (select auth.uid())
  ) then
    raise exception 'Compte tourneur actif requis pour cette organisation'
      using errcode = '42501';
  end if;

  if requested_storage_path is null
    or char_length(btrim(requested_storage_path)) = 0
  then
    raise exception 'Le fichier est requis' using errcode = '22023';
  end if;

  insert into public.organization_conventions (
    organization_id, storage_path, status, uploaded_by, uploaded_at
  )
  values (
    requested_organization_id,
    requested_storage_path,
    'pending'::public.volunteer_document_status,
    (select auth.uid()),
    clock_timestamp()
  )
  on conflict (organization_id) do update set
    storage_path = excluded.storage_path,
    status = 'pending'::public.volunteer_document_status,
    uploaded_by = excluded.uploaded_by,
    uploaded_at = excluded.uploaded_at,
    reviewed_by = null,
    reviewed_at = null,
    rejection_reason = null,
    updated_at = now();

  perform private.notify_active_admins(
    null,
    'organization_convention_submitted',
    'Convention à valider',
    'Un tourneur a déposé une convention de partenariat en attente de contre-signature.',
    false
  );
end;
$$;

revoke all on function public.submit_my_organization_convention(uuid, text)
  from public, anon;
grant execute on function public.submit_my_organization_convention(uuid, text)
  to authenticated;

-- 4bis. Modification d'une maraude: locked roles are now notified too
-- (still protected from the reset-to-pending, per the whole point of
-- locking - just no longer left in the dark about the change), venue
-- changes are handled the same as date/time changes (previously not
-- watched at all), and the promoter organization is notified.
drop trigger concerts_reset_team_on_schedule_change on public.concerts;

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
  end loop;

  if new.promoter_organization_id is not null then
    for promoter_account in
      select account.profile_id
      from public.user_accounts account
      where account.role = 'promoter'::public.app_role
        and account.status = 'active'::public.user_account_status
        and account.organization_id = new.promoter_organization_id
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

create trigger concerts_reset_team_on_schedule_change
after update of concert_date, concert_time, venue_id on public.concerts
for each row execute function private.reset_team_on_maraude_schedule_change();

-- 5. Rappels: don't repeat "c'est demain" the same day a schedule-change
--    email already told this volunteer about the maraude.
create or replace function private.enqueue_maraude_email_reminders()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  candidate record;
  queued integer := 0;
begin
  for candidate in
    select
      volunteer.user_id,
      volunteer.concert_id,
      concert.artist,
      volunteer.team_role
    from public.concert_volunteers volunteer
    join public.concerts concert on concert.id = volunteer.concert_id
    where concert.concert_date = current_date + 1
      and concert.maraude_status not in (
        'completed'::public.maraude_status,
        'cancelled'::public.maraude_status
      )
      and volunteer.status = 'selected'::public.concert_volunteer_status
      and volunteer.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
      and not exists (
        select 1
        from public.user_notifications notification
        where notification.user_id = volunteer.user_id
          and notification.concert_id = volunteer.concert_id
          and notification.notification_type = 'maraude_tomorrow'
      )
      and not exists (
        select 1
        from public.user_notifications notification
        where notification.user_id = volunteer.user_id
          and notification.concert_id = volunteer.concert_id
          and notification.notification_type = 'schedule_changed'
          and notification.created_at > now() - interval '24 hours'
      )
  loop
    perform private.notify_user(
      candidate.user_id,
      candidate.concert_id,
      'maraude_tomorrow',
      'Votre maraude a lieu demain',
      format(
        'Rendez-vous demain pour la maraude %s. Consultez les informations pratiques et votre rôle.',
        candidate.artist
      )
    );
    queued := queued + 1;
  end loop;

  for candidate in
    select concert.id, concert.artist
    from public.concerts concert
    where concert.concert_date = current_date + 1
      and concert.maraude_status not in (
        'completed'::public.maraude_status,
        'cancelled'::public.maraude_status
      )
      and not exists (
        select 1
        from public.concert_volunteers leader
        where leader.concert_id = concert.id
          and leader.status = 'selected'::public.concert_volunteer_status
          and leader.team_role = 'team_leader'::public.maraude_role
          and leader.confirmation_status =
            'confirmed'::public.volunteer_confirmation_status
      )
      and not exists (
        select 1
        from public.user_notifications notification
        where notification.concert_id = concert.id
          and notification.notification_type = 'team_leader_missing'
      )
  loop
    perform private.notify_active_admins(
      candidate.id,
      'team_leader_missing',
      'Chef d’équipe non confirmé',
      format(
        'La maraude %s a lieu demain sans chef d’équipe confirmé.',
        candidate.artist
      )
    );
    queued := queued + 1;
  end loop;
  return queued;
end;
$$;

revoke all on function private.enqueue_maraude_email_reminders()
from public, anon, authenticated;
