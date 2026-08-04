create table public.organization_conventions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null unique
    references public.organizations(id) on delete cascade,
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
    status <> 'rejected'::public.volunteer_document_status
    or rejection_reason is not null
  ),
  check (storage_path is not null or status = 'pending'::public.volunteer_document_status)
);

alter table public.organization_conventions enable row level security;

create policy "Promoters and admins view organization conventions"
on public.organization_conventions
for select
to authenticated
using (
  private.is_promoter_account_member(organization_id, (select auth.uid()))
  or private.is_club_sandwich_admin((select auth.uid()))
);

revoke all on public.organization_conventions from anon, authenticated;
grant select on public.organization_conventions to authenticated;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'organization-private-documents',
  'organization-private-documents',
  false,
  10485760,
  array['application/pdf', 'image/jpeg', 'image/png']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Promoters upload their organization private documents"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'organization-private-documents'
  and private.is_promoter_account_member(
    ((storage.foldername(name))[1])::uuid, (select auth.uid())
  )
);

create policy "Promoters update their organization private documents"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'organization-private-documents'
  and private.is_promoter_account_member(
    ((storage.foldername(name))[1])::uuid, (select auth.uid())
  )
)
with check (
  bucket_id = 'organization-private-documents'
  and private.is_promoter_account_member(
    ((storage.foldername(name))[1])::uuid, (select auth.uid())
  )
);

create policy "Members and admins read organization private documents"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'organization-private-documents'
  and (
    private.is_promoter_account_member(
      ((storage.foldername(name))[1])::uuid, (select auth.uid())
    )
    or private.is_club_sandwich_admin((select auth.uid()))
  )
);

create policy "Admins upload organization private documents"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'organization-private-documents'
  and private.is_club_sandwich_admin((select auth.uid()))
);

create policy "Admins update organization private documents"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'organization-private-documents'
  and private.is_club_sandwich_admin((select auth.uid()))
)
with check (
  bucket_id = 'organization-private-documents'
  and private.is_club_sandwich_admin((select auth.uid()))
);

create or replace function private.notify_organization_promoters(
  requested_organization_id uuid,
  requested_type text,
  requested_title text,
  requested_body text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  promoter_account record;
begin
  for promoter_account in
    select account.profile_id
    from public.user_accounts account
    where account.role = 'promoter'::public.app_role
      and account.status = 'active'::public.user_account_status
      and account.organization_id = requested_organization_id
  loop
    perform private.notify_user(
      promoter_account.profile_id,
      null,
      requested_type,
      requested_title,
      requested_body
    );
  end loop;
end;
$$;

revoke all on function private.notify_organization_promoters(
  uuid, text, text, text
) from public, anon, authenticated;

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
    'Un tourneur a déposé une convention de partenariat en attente de contre-signature.'
  );
end;
$$;

revoke all on function public.submit_my_organization_convention(uuid, text)
  from public, anon;
grant execute on function public.submit_my_organization_convention(uuid, text)
  to authenticated;

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

  perform private.notify_organization_promoters(
    requested_organization_id,
    'organization_convention_reviewed',
    'Convention contresignée',
    'La convention de partenariat contresignée est disponible.'
  );
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

  perform private.notify_organization_promoters(
    requested_organization_id,
    'organization_convention_reviewed',
    'Convention refusée',
    format(
      'La convention déposée a été refusée : %s. Merci de la déposer à nouveau.',
      btrim(requested_rejection_reason)
    )
  );
end;
$$;

revoke all on function public.review_organization_convention(
  uuid, public.volunteer_document_status, text
) from public, anon;
grant execute on function public.review_organization_convention(
  uuid, public.volunteer_document_status, text
) to authenticated;

create or replace function public.get_organization_convention(
  requested_organization_id uuid
)
returns table (
  storage_path text,
  status public.volunteer_document_status,
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
    convention.storage_path, convention.status, convention.rejection_reason,
    convention.uploaded_at, convention.reviewed_at
  from public.organization_conventions convention
  where convention.organization_id = requested_organization_id
    and (
      private.is_promoter_account_member(
        requested_organization_id, (select auth.uid())
      )
      or private.is_club_sandwich_admin((select auth.uid()))
    );
$$;

revoke all on function public.get_organization_convention(uuid)
  from public, anon;
grant execute on function public.get_organization_convention(uuid)
  to authenticated;
