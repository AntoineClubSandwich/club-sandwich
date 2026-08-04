create table public.document_templates (
  key text primary key
    check (key in ('volunteer_contract', 'organization_convention')),
  storage_path text not null,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.document_templates enable row level security;

create policy "Authenticated users read document templates"
on public.document_templates
for select
to authenticated
using (true);

revoke all on public.document_templates from anon, authenticated;
grant select on public.document_templates to authenticated;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'document-templates',
  'document-templates',
  false,
  10485760,
  array['application/pdf']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Authenticated users read document template files"
on storage.objects
for select
to authenticated
using (bucket_id = 'document-templates');

create policy "Admins upload document template files"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'document-templates'
  and private.is_club_sandwich_admin((select auth.uid()))
);

create policy "Admins update document template files"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'document-templates'
  and private.is_club_sandwich_admin((select auth.uid()))
)
with check (
  bucket_id = 'document-templates'
  and private.is_club_sandwich_admin((select auth.uid()))
);

create or replace function public.admin_set_document_template(
  requested_key text,
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

  if requested_key not in ('volunteer_contract', 'organization_convention') then
    raise exception 'Modèle de document inconnu' using errcode = '22023';
  end if;

  if requested_storage_path is null
    or char_length(btrim(requested_storage_path)) = 0
  then
    raise exception 'Le fichier est requis' using errcode = '22023';
  end if;

  insert into public.document_templates (key, storage_path, updated_by, updated_at)
  values (
    requested_key, requested_storage_path, (select auth.uid()), clock_timestamp()
  )
  on conflict (key) do update set
    storage_path = excluded.storage_path,
    updated_by = excluded.updated_by,
    updated_at = excluded.updated_at;
end;
$$;

revoke all on function public.admin_set_document_template(text, text)
  from public, anon;
grant execute on function public.admin_set_document_template(text, text)
  to authenticated;
