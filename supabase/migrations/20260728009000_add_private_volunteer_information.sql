alter table public.volunteer_profiles
  add column if not exists additional_information text,
  add column if not exists certifications text[] not null default '{}',
  add column if not exists identity_document_path text,
  add column if not exists social_security_document_path text;

drop policy if exists
  "Club Sandwich admins can view candidate volunteer profiles"
  on public.volunteer_profiles;

create policy "Club Sandwich admins can view volunteer profiles"
on public.volunteer_profiles
for select
to authenticated
using (private.is_club_sandwich_admin((select auth.uid())));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'volunteer-private-documents',
  'volunteer-private-documents',
  false,
  10485760,
  array['application/pdf', 'image/jpeg', 'image/png']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Volunteers upload their private documents"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'volunteer-private-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Volunteers update their private documents"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'volunteer-private-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'volunteer-private-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Owners and admins read private volunteer documents"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'volunteer-private-documents'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or private.is_club_sandwich_admin((select auth.uid()))
  )
);

create or replace function public.get_volunteer_private_information(
  requested_user_id uuid
)
returns table (
  additional_information text,
  emergency_contact_name text,
  emergency_contact_phone text,
  certifications text[],
  identity_document_path text,
  social_security_document_path text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    volunteer_profiles.additional_information,
    volunteer_profiles.emergency_contact_name,
    volunteer_profiles.emergency_contact_phone,
    volunteer_profiles.certifications,
    volunteer_profiles.identity_document_path,
    volunteer_profiles.social_security_document_path
  from public.volunteer_profiles
  where volunteer_profiles.user_id = requested_user_id
    and private.is_club_sandwich_admin((select auth.uid()));
$$;

revoke all on function public.get_volunteer_private_information(uuid)
  from public, anon;
grant execute on function public.get_volunteer_private_information(uuid)
  to authenticated;
