-- Antoine's feedback on tourneur-facing notifications (2026-09-16):
--
-- 1. "Bilan de maraude disponible" (maraude_report_available) should reach
--    the concerned tourneur only, not every promoter of the organization -
--    and no longer by email, in-app only.
-- 2. "La maraude a été modifiée" (schedule_changed) no longer goes to
--    promoters at all. Replaced by a more useful prompt: once the admin
--    validates a complete team (maraude_status -> team_ready), remind the
--    concerned tourneur to fill in whatever is still missing among the
--    catering, the tourneur contact and the horaire (catering closing
--    time) - only if something actually is missing.
-- 3. maraude_cancelled: unchanged.
-- 4. Convention contresignée/refusée (organization_convention_reviewed):
--    no longer notifies tourneurs at all.
--
-- "Concerned tourneur" = whoever created the maraude, if they're a
-- promoter; otherwise (an admin created it on behalf of an organization)
-- every active promoter of the assigned promoter organization, since
-- there's no single individual to target in that case.
--
-- Also fixes a latent bug found while doing (1): notify_completed_maraude_
-- promoters matched accounts on concerts.organization_id (the Club
-- Sandwich tenant the maraude belongs to), not concerts.
-- promoter_organization_id (the tourneur's own organization) like every
-- other promoter-facing notification added since - so it likely never
-- reached the right people, or anyone at all.

create or replace function private.resolve_maraude_promoter_recipients(
  target_promoter_organization_id uuid,
  target_created_by uuid
)
returns setof uuid
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  creator_is_promoter boolean;
begin
  select exists (
    select 1
    from public.user_accounts
    where profile_id = target_created_by
      and role = 'promoter'::public.app_role
      and status = 'active'::public.user_account_status
  )
  into creator_is_promoter;

  if creator_is_promoter then
    return query select target_created_by;
  elsif target_promoter_organization_id is not null then
    return query
      select account.profile_id
      from public.user_accounts account
      where account.role = 'promoter'::public.app_role
        and account.status = 'active'::public.user_account_status
        and account.organization_id = target_promoter_organization_id;
  end if;
  return;
end;
$$;

revoke all on function private.resolve_maraude_promoter_recipients(uuid, uuid)
from public, anon, authenticated;

-- 1. Bilan de maraude : uniquement le tourneur concerné, sans e-mail.
create or replace function private.notify_completed_maraude_promoters()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  recipient uuid;
begin
  if new.maraude_status = 'completed'::public.maraude_status
    and old.maraude_status is distinct from new.maraude_status
  then
    for recipient in
      select *
      from private.resolve_maraude_promoter_recipients(
        new.promoter_organization_id,
        new.created_by
      )
    loop
      perform private.notify_user(
        recipient,
        new.id,
        'maraude_report_available',
        'Bilan de maraude disponible',
        format(
          'La maraude %s est terminée. Son bilan est disponible.',
          new.artist
        ),
        false
      );
    end loop;
  end if;
  return new;
end;
$$;

revoke all on function private.notify_completed_maraude_promoters()
from public, anon, authenticated;

-- 2a. schedule_changed : on ne prévient plus les tourneurs (seuls les
-- bénévoles dont la sélection est remise en cause restent notifiés, et
-- l'équipe est toujours réinitialisée comme avant).
create or replace function private.reset_team_on_maraude_schedule_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor uuid := (select auth.uid());
  application record;
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

  return new;
end;
$$;

revoke all on function private.reset_team_on_maraude_schedule_change()
from public, anon, authenticated;

-- 2b. Nouveau : une fois l'équipe validée (-> team_ready), rappelle au
-- tourneur concerné ce qu'il lui reste à renseigner, s'il manque quelque
-- chose.
create or replace function private.notify_promoter_missing_maraude_details()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  recipient uuid;
  missing_parts text[] := '{}';
  missing_summary text;
begin
  if new.maraude_status <> 'team_ready'::public.maraude_status
    or old.maraude_status is not distinct from new.maraude_status
  then
    return new;
  end if;

  if new.catering_contact_name is null then
    missing_parts := missing_parts || 'le catering'::text;
  end if;
  if new.catering_closes_at is null then
    missing_parts := missing_parts || 'l’horaire (fermeture du catering)'::text;
  end if;
  if new.promoter_contact_name is null or new.promoter_contact_phone is null
  then
    missing_parts := missing_parts || 'le contact tourneur'::text;
  end if;

  if array_length(missing_parts, 1) is null then
    return new;
  end if;

  missing_summary := array_to_string(missing_parts, ', ');

  for recipient in
    select *
    from private.resolve_maraude_promoter_recipients(
      new.promoter_organization_id,
      new.created_by
    )
  loop
    perform private.notify_user(
      recipient,
      new.id,
      'maraude_details_missing',
      'Équipe validée : informations à compléter',
      format(
        'L’équipe de la maraude "%s" est validée. Merci de renseigner : %s.',
        new.artist,
        missing_summary
      )
    );
  end loop;

  return new;
end;
$$;

revoke all on function private.notify_promoter_missing_maraude_details()
from public, anon, authenticated;

create trigger concerts_team_ready_missing_details_notification
after update of maraude_status on public.concerts
for each row execute function private.notify_promoter_missing_maraude_details();

-- 4. Convention contresignée / refusée : ne notifie plus les tourneurs.
create or replace function public.admin_set_organization_convention(
  requested_organization_id uuid,
  requested_storage_path text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Accès administrateur requis' using errcode = '42501';
  end if;

  if requested_storage_path is null
    or char_length(btrim(requested_storage_path)) = 0
  then
    raise exception 'Le fichier est requis' using errcode = '22023';
  end if;

  insert into public.organization_conventions (
    organization_id, storage_path, status,
    uploaded_by, uploaded_at, reviewed_by, reviewed_at
  )
  values (
    requested_organization_id,
    requested_storage_path,
    'approved'::public.volunteer_document_status,
    (select auth.uid()),
    clock_timestamp(),
    (select auth.uid()),
    clock_timestamp()
  )
  on conflict (organization_id) do update set
    storage_path = excluded.storage_path,
    status = 'approved'::public.volunteer_document_status,
    uploaded_by = excluded.uploaded_by,
    uploaded_at = excluded.uploaded_at,
    reviewed_by = excluded.reviewed_by,
    reviewed_at = excluded.reviewed_at,
    rejection_reason = null,
    updated_at = now();
end;
$$;

revoke all on function public.admin_set_organization_convention(uuid, text)
  from public, anon;
grant execute on function public.admin_set_organization_convention(uuid, text)
  to authenticated;

create or replace function public.review_organization_convention(
  requested_organization_id uuid,
  requested_status public.volunteer_document_status,
  requested_rejection_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Accès administrateur requis' using errcode = '42501';
  end if;

  if requested_status <> 'rejected'::public.volunteer_document_status then
    raise exception 'Seul un rejet est possible via cette fonction'
      using errcode = '22023';
  end if;

  if requested_rejection_reason is null
    or char_length(btrim(requested_rejection_reason)) = 0
  then
    raise exception 'Un motif de refus est requis' using errcode = '22023';
  end if;

  update public.organization_conventions
  set
    status = 'rejected'::public.volunteer_document_status,
    reviewed_by = (select auth.uid()),
    reviewed_at = clock_timestamp(),
    rejection_reason = btrim(requested_rejection_reason),
    updated_at = now()
  where organization_id = requested_organization_id
    and storage_path is not null;

  if not found then
    raise exception 'Convention introuvable ou non déposée' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.review_organization_convention(
  uuid, public.volunteer_document_status, text
) from public, anon;
grant execute on function public.review_organization_convention(
  uuid, public.volunteer_document_status, text
) to authenticated;

drop function if exists private.notify_organization_promoters(
  uuid, text, text, text
);
