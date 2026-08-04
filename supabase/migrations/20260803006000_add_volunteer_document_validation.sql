create type public.volunteer_document_type as enum (
  'identity',
  'social_security',
  'other'
);

create type public.volunteer_document_status as enum (
  'pending',
  'approved',
  'rejected'
);

create table public.volunteer_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  document_type public.volunteer_document_type not null,
  label text,
  storage_path text,
  status public.volunteer_document_status not null default 'pending',
  uploaded_by uuid references public.profiles(id) on delete set null,
  uploaded_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (
      document_type = 'other'::public.volunteer_document_type
      and label is not null
      and char_length(btrim(label)) > 0
    )
    or (
      document_type <> 'other'::public.volunteer_document_type
      and label is null
    )
  ),
  check (
    status <> 'rejected'::public.volunteer_document_status
    or rejection_reason is not null
  ),
  check (storage_path is not null or status = 'pending'::public.volunteer_document_status)
);

create unique index volunteer_documents_unique_fixed_type
on public.volunteer_documents (user_id, document_type)
where document_type <> 'other'::public.volunteer_document_type;

create index volunteer_documents_user_idx
on public.volunteer_documents (user_id);

create index volunteer_documents_pending_review_idx
on public.volunteer_documents (status)
where storage_path is not null;

-- Migrate the two document paths previously stored on volunteer_profiles.
insert into public.volunteer_documents (user_id, document_type, storage_path, status)
select user_id, 'identity'::public.volunteer_document_type, identity_document_path, 'pending'::public.volunteer_document_status
from public.volunteer_profiles
where identity_document_path is not null;

insert into public.volunteer_documents (user_id, document_type, storage_path, status)
select user_id, 'social_security'::public.volunteer_document_type, social_security_document_path, 'pending'::public.volunteer_document_status
from public.volunteer_profiles
where social_security_document_path is not null;

alter table public.volunteer_profiles
  drop column identity_document_path,
  drop column social_security_document_path;

alter table public.volunteer_documents enable row level security;

create policy "Volunteers and admins view volunteer documents"
on public.volunteer_documents
for select
to authenticated
using (
  user_id = (select auth.uid())
  or private.is_club_sandwich_admin((select auth.uid()))
);

revoke all on public.volunteer_documents from anon, authenticated;
grant select on public.volunteer_documents to authenticated;

-- Admins can also write into any volunteer's storage folder (on-behalf uploads).
create policy "Admins upload volunteer private documents"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'volunteer-private-documents'
  and private.is_club_sandwich_admin((select auth.uid()))
);

create policy "Admins update volunteer private documents"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'volunteer-private-documents'
  and private.is_club_sandwich_admin((select auth.uid()))
);

create or replace function private.volunteer_has_required_documents(
  requested_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    exists (
      select 1
      from public.volunteer_documents document
      where document.user_id = requested_user_id
        and document.document_type = 'identity'::public.volunteer_document_type
        and document.status = 'approved'::public.volunteer_document_status
    )
    and exists (
      select 1
      from public.volunteer_documents document
      where document.user_id = requested_user_id
        and document.document_type = 'social_security'::public.volunteer_document_type
        and document.status = 'approved'::public.volunteer_document_status
    )
    and not exists (
      select 1
      from public.volunteer_documents document
      where document.user_id = requested_user_id
        and document.document_type = 'other'::public.volunteer_document_type
        and document.status <> 'approved'::public.volunteer_document_status
    );
$$;

revoke all on function private.volunteer_has_required_documents(uuid)
from public, anon;
grant execute on function private.volunteer_has_required_documents(uuid)
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

  if requested_count < 3 then
    raise exception
      'L’équipe doit comprendre un chef d’équipe et au moins deux autres bénévoles'
      using errcode = '22023';
  end if;

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

  if leader_count = 0 then
    raise exception 'L’équipe doit avoir exactement un chef d’équipe'
      using errcode = '22023';
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

  if exists (
    select 1
    from public.concert_volunteers application
    join jsonb_to_recordset(requested_team)
      as requested(application_id uuid, team_role public.maraude_role)
      on requested.application_id = application.id
    where application.concert_id = requested_concert_id
      and not private.volunteer_has_required_documents(application.user_id)
  ) then
    raise exception
      'Un bénévole sélectionné n’a pas tous ses documents validés'
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
    'Un bénévole a déposé un document en attente de validation.'
  );
end;
$$;

revoke all on function public.submit_my_volunteer_document(
  public.volunteer_document_type, text, uuid
) from public, anon;
grant execute on function public.submit_my_volunteer_document(
  public.volunteer_document_type, text, uuid
) to authenticated;

create or replace function public.admin_set_volunteer_document(
  requested_user_id uuid,
  requested_document_type public.volunteer_document_type,
  requested_storage_path text default null,
  requested_label text default null,
  requested_document_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  result_id uuid;
  has_path boolean :=
    requested_storage_path is not null
    and char_length(btrim(requested_storage_path)) > 0;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Accès administrateur requis' using errcode = '42501';
  end if;

  if requested_document_id is not null then
    update public.volunteer_documents
    set
      storage_path = coalesce(requested_storage_path, storage_path),
      status = case
        when has_path then 'approved'::public.volunteer_document_status
        else status
      end,
      uploaded_by = case
        when has_path then (select auth.uid()) else uploaded_by
      end,
      uploaded_at = case
        when has_path then clock_timestamp() else uploaded_at
      end,
      reviewed_by = case
        when has_path then (select auth.uid()) else reviewed_by
      end,
      reviewed_at = case
        when has_path then clock_timestamp() else reviewed_at
      end,
      rejection_reason = case when has_path then null else rejection_reason end,
      updated_at = now()
    where id = requested_document_id
    returning id into result_id;

    if not found then
      raise exception 'Document introuvable' using errcode = 'P0002';
    end if;

    return result_id;
  end if;

  if requested_document_type = 'other'::public.volunteer_document_type then
    if requested_label is null or char_length(btrim(requested_label)) = 0 then
      raise exception 'Le libellé est requis pour un document libre'
        using errcode = '22023';
    end if;

    insert into public.volunteer_documents (
      user_id, document_type, label, storage_path, status,
      uploaded_by, uploaded_at, reviewed_by, reviewed_at
    )
    values (
      requested_user_id,
      'other'::public.volunteer_document_type,
      btrim(requested_label),
      requested_storage_path,
      case
        when has_path then 'approved'::public.volunteer_document_status
        else 'pending'::public.volunteer_document_status
      end,
      case when has_path then (select auth.uid()) else null end,
      case when has_path then clock_timestamp() else null end,
      case when has_path then (select auth.uid()) else null end,
      case when has_path then clock_timestamp() else null end
    )
    returning id into result_id;

    if not has_path then
      perform private.notify_user(
        requested_user_id,
        null,
        'volunteer_document_requested',
        'Document demandé',
        format(
          'Merci de fournir le document suivant : %s.',
          btrim(requested_label)
        )
      );
    end if;

    return result_id;
  end if;

  if not has_path then
    raise exception 'Le fichier est requis pour ce type de document'
      using errcode = '22023';
  end if;

  insert into public.volunteer_documents (
    user_id, document_type, storage_path, status,
    uploaded_by, uploaded_at, reviewed_by, reviewed_at
  )
  values (
    requested_user_id,
    requested_document_type,
    requested_storage_path,
    'approved'::public.volunteer_document_status,
    (select auth.uid()),
    clock_timestamp(),
    (select auth.uid()),
    clock_timestamp()
  )
  on conflict (user_id, document_type)
  where document_type <> 'other'::public.volunteer_document_type
  do update set
    storage_path = excluded.storage_path,
    status = 'approved'::public.volunteer_document_status,
    uploaded_by = excluded.uploaded_by,
    uploaded_at = excluded.uploaded_at,
    reviewed_by = excluded.reviewed_by,
    reviewed_at = excluded.reviewed_at,
    rejection_reason = null,
    updated_at = now()
  returning id into result_id;

  return result_id;
end;
$$;

revoke all on function public.admin_set_volunteer_document(
  uuid, public.volunteer_document_type, text, text, uuid
) from public, anon;
grant execute on function public.admin_set_volunteer_document(
  uuid, public.volunteer_document_type, text, text, uuid
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
    notification_title, notification_body
  );
end;
$$;

revoke all on function public.review_volunteer_document(
  uuid, public.volunteer_document_status, text
) from public, anon;
grant execute on function public.review_volunteer_document(
  uuid, public.volunteer_document_status, text
) to authenticated;

create or replace function public.notify_missing_volunteer_documents(
  requested_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  missing_labels text[];
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Accès administrateur requis' using errcode = '42501';
  end if;

  select array_agg(missing.label order by missing.label)
  into missing_labels
  from (
    select 'Pièce d’identité' as label
    where not exists (
      select 1
      from public.volunteer_documents document
      where document.user_id = requested_user_id
        and document.document_type = 'identity'::public.volunteer_document_type
        and document.status = 'approved'::public.volunteer_document_status
    )
    union all
    select 'Carte de sécurité sociale'
    where not exists (
      select 1
      from public.volunteer_documents document
      where document.user_id = requested_user_id
        and document.document_type =
          'social_security'::public.volunteer_document_type
        and document.status = 'approved'::public.volunteer_document_status
    )
    union all
    select document.label
    from public.volunteer_documents document
    where document.user_id = requested_user_id
      and document.document_type = 'other'::public.volunteer_document_type
      and document.status <> 'approved'::public.volunteer_document_status
  ) missing;

  if missing_labels is null or array_length(missing_labels, 1) = 0 then
    raise exception 'Tous les documents de ce bénévole sont validés'
      using errcode = '22023';
  end if;

  perform private.notify_user(
    requested_user_id, null, 'volunteer_documents_missing',
    'Documents manquants',
    format(
      'Merci de déposer ou corriger les documents suivants : %s.',
      array_to_string(missing_labels, ', ')
    )
  );
end;
$$;

revoke all on function public.notify_missing_volunteer_documents(uuid)
from public, anon;
grant execute on function public.notify_missing_volunteer_documents(uuid)
to authenticated;

create or replace function public.get_my_volunteer_documents()
returns table (
  id uuid,
  document_type public.volunteer_document_type,
  label text,
  status public.volunteer_document_status,
  storage_path text,
  rejection_reason text,
  uploaded_at timestamptz,
  reviewed_at timestamptz
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    document.id, document.document_type, document.label, document.status,
    document.storage_path, document.rejection_reason,
    document.uploaded_at, document.reviewed_at
  from public.volunteer_documents document
  where document.user_id = (select auth.uid())
  order by document.document_type, document.created_at;
$$;

revoke all on function public.get_my_volunteer_documents() from public, anon;
grant execute on function public.get_my_volunteer_documents() to authenticated;

create or replace function public.get_volunteer_documents(
  requested_user_id uuid
)
returns table (
  id uuid,
  document_type public.volunteer_document_type,
  label text,
  status public.volunteer_document_status,
  storage_path text,
  rejection_reason text,
  uploaded_at timestamptz,
  reviewed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Accès administrateur requis' using errcode = '42501';
  end if;

  return query
  select
    document.id, document.document_type, document.label, document.status,
    document.storage_path, document.rejection_reason,
    document.uploaded_at, document.reviewed_at
  from public.volunteer_documents document
  where document.user_id = requested_user_id
  order by document.document_type, document.created_at;
end;
$$;

revoke all on function public.get_volunteer_documents(uuid) from public, anon;
grant execute on function public.get_volunteer_documents(uuid) to authenticated;

create or replace function public.get_pending_volunteer_documents()
returns table (
  id uuid,
  user_id uuid,
  first_name text,
  last_name text,
  document_type public.volunteer_document_type,
  label text,
  storage_path text,
  uploaded_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Accès administrateur requis' using errcode = '42501';
  end if;

  return query
  select
    document.id, document.user_id, profile.first_name, profile.last_name,
    document.document_type, document.label, document.storage_path,
    document.uploaded_at
  from public.volunteer_documents document
  join public.profiles profile on profile.id = document.user_id
  where document.status = 'pending'::public.volunteer_document_status
    and document.storage_path is not null
  order by document.uploaded_at;
end;
$$;

revoke all on function public.get_pending_volunteer_documents()
from public, anon;
grant execute on function public.get_pending_volunteer_documents()
to authenticated;
