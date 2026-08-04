insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'maraude-photos',
  'maraude-photos',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Authorized maraude members upload photos"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'maraude-photos'
  and (
    private.is_club_sandwich_admin((select auth.uid()))
    or exists (
      select 1
      from public.concert_volunteers cv
      where cv.concert_id::text = (storage.foldername(name))[1]
        and cv.user_id = (select auth.uid())
        and cv.status = 'selected'::public.concert_volunteer_status
        and cv.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
    )
  )
);

create policy "Authorized maraude members read photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'maraude-photos'
  and (
    private.is_club_sandwich_admin((select auth.uid()))
    or exists (
      select 1
      from public.concert_volunteers cv
      where cv.concert_id::text = (storage.foldername(name))[1]
        and cv.user_id = (select auth.uid())
        and cv.status = 'selected'::public.concert_volunteer_status
        and cv.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
    )
  )
);

