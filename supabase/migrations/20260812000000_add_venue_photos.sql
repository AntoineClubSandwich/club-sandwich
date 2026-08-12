alter table public.venues
  add column if not exists photo_url text;

-- Public bucket (unlike maraude-photos/documents, which are private with
-- signed URLs): venue photos are non-sensitive marketing/exterior shots
-- shown on every maraude card across list screens, so a stable public URL
-- avoids re-fetching a signed URL per card on every render.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'venue-photos',
  'venue-photos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Club Sandwich admins upload venue photos"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'venue-photos'
  and private.is_club_sandwich_admin((select auth.uid()))
);

create policy "Club Sandwich admins replace venue photos"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'venue-photos'
  and private.is_club_sandwich_admin((select auth.uid()))
)
with check (
  bucket_id = 'venue-photos'
  and private.is_club_sandwich_admin((select auth.uid()))
);

create policy "Anyone authenticated can view venue photos"
on storage.objects
for select
to authenticated
using (bucket_id = 'venue-photos');
