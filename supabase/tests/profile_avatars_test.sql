begin;

create extension if not exists pgtap with schema extensions;

select plan(6);

select results_eq(
  $$
    select public, file_size_limit
    from storage.buckets
    where id = 'profile-avatars'
  $$,
  $$ values (true, 5242880::bigint) $$,
  'Le bucket des photos de profil est public et limité à 5 Mo'
);

select results_eq(
  $$
    select allowed_mime_types
    from storage.buckets
    where id = 'profile-avatars'
  $$,
  $$ values (array['image/jpeg', 'image/png', 'image/webp']::text[]) $$,
  'Le bucket accepte uniquement les formats image pris en charge'
);

select results_eq(
  $$
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in (
        'Users upload their own profile avatar',
        'Users replace their own profile avatar',
        'Users delete their own profile avatar',
        'Authenticated users view profile avatars'
      )
  $$,
  $$ values (4::bigint) $$,
  'Les quatre règles de stockage des avatars sont installées'
);

select ok(
  position(
    'avatar_url' in pg_get_function_result('public.get_admin_users()'::regprocedure)
  ) > 0,
  'L’annuaire administrateur précharge les avatars'
);

select ok(
  position(
    'avatar_url' in pg_get_function_result(
      'public.get_concert_volunteer_roster(uuid)'::regprocedure
    )
  ) > 0,
  'L’aperçu des candidatures précharge les avatars'
);

select ok(
  position(
    'avatar_url' in pg_get_function_result(
      'public.get_maraude_attendance(uuid)'::regprocedure
    )
  ) > 0,
  'La liste des présences précharge les avatars'
);

select * from finish();

rollback;
