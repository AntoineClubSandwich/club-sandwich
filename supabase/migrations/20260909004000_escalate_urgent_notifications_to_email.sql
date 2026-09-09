-- Closes the last deferred item from the notification/email overhaul
-- spec: "évite l'e-mail immédiat [...] sauf si la maraude est proche ou
-- manque de bénévoles" (nouveau volontariat) and "e-mail seulement si
-- la validation bloque une maraude proche" (documents/conventions).
-- Thresholds confirmed by Antoine: "proche" = within 3 days,
-- "manque de bénévoles" = fewer than 3 currently selected (matches the
-- team-size minimum already shown in the "Équipe retenue" panel).

-- 1. Nouveau volontariat: escalate to email when the maraude is close
--    or short-staffed - otherwise stays in-app-only as before.
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
  selected_count integer;
  escalate boolean;
begin
  select concert.artist, concert.concert_date, venue.name
  into concert_artist, concert_date_value, venue_name_value
  from public.concerts concert
  left join public.venues venue on venue.id = concert.venue_id
  where concert.id = new.concert_id;

  if tg_op = 'INSERT'
    and new.status = 'pending'::public.concert_volunteer_status
  then
    select count(*)
    into selected_count
    from public.concert_volunteers
    where concert_id = new.concert_id
      and status = 'selected'::public.concert_volunteer_status;

    escalate := coalesce(concert_date_value <= current_date + 3, false)
      or selected_count < 3;

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
      escalate
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

-- 2. Document déposé: escalate only if the submitting volunteer is
--    currently selected on a maraude within 3 days - their documents
--    were already required-approved to be selected at all (this
--    session's earlier fix), so a fresh submission while selected means
--    a validation just lapsed or got rejected and needs a prompt look.
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
declare
  escalate boolean;
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

  select exists (
    select 1
    from public.concert_volunteers volunteer
    join public.concerts concert on concert.id = volunteer.concert_id
    where volunteer.user_id = (select auth.uid())
      and volunteer.status = 'selected'::public.concert_volunteer_status
      and concert.maraude_status not in (
        'completed'::public.maraude_status,
        'cancelled'::public.maraude_status
      )
      and concert.concert_date <= current_date + 3
  )
  into escalate;

  perform private.notify_active_admins(
    null,
    'volunteer_document_submitted',
    'Document à valider',
    'Un bénévole a déposé un document en attente de validation.',
    escalate
  );
end;
$$;

revoke all on function public.submit_my_volunteer_document(
  public.volunteer_document_type, text, uuid
) from public, anon;
grant execute on function public.submit_my_volunteer_document(
  public.volunteer_document_type, text, uuid
) to authenticated;

-- 3. Convention déposée: escalate only if the promoter's organization
--    has a maraude within 3 days.
create or replace function public.submit_my_organization_convention(
  requested_organization_id uuid,
  requested_storage_path text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  escalate boolean;
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

  select exists (
    select 1
    from public.concerts concert
    where concert.promoter_organization_id = requested_organization_id
      and concert.maraude_status not in (
        'completed'::public.maraude_status,
        'cancelled'::public.maraude_status
      )
      and concert.concert_date <= current_date + 3
  )
  into escalate;

  perform private.notify_active_admins(
    null,
    'organization_convention_submitted',
    'Convention à valider',
    'Un tourneur a déposé une convention de partenariat en attente de contre-signature.',
    escalate
  );
end;
$$;

revoke all on function public.submit_my_organization_convention(uuid, text)
  from public, anon;
grant execute on function public.submit_my_organization_convention(uuid, text)
  to authenticated;
