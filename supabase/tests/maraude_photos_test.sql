begin;

create extension if not exists pgtap with schema extensions;

select plan(12);

select has_table(
  'public',
  'maraude_photos',
  'La galerie de photos par maraude existe'
);
select has_function(
  'public',
  'add_maraude_photo',
  array['uuid', 'text'],
  'L’ajout d’une photo à la galerie existe'
);
select has_function(
  'public',
  'delete_maraude_photo',
  array['uuid'],
  'La suppression d’une photo de la galerie existe'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    'f5000000-0000-0000-0000-000000000001',
    'photos-admin@example.test',
    '{"first_name":"Admin","last_name":"Photos"}'::jsonb
  ),
  (
    'f5000000-0000-0000-0000-000000000002',
    'photos-leader@example.test',
    '{"first_name":"Chef","last_name":"Equipe"}'::jsonb
  ),
  (
    'f5000000-0000-0000-0000-000000000003',
    'photos-com@example.test',
    '{"first_name":"Chargee","last_name":"Com"}'::jsonb
  ),
  (
    'f5000000-0000-0000-0000-000000000004',
    'photos-other-com@example.test',
    '{"first_name":"Autre","last_name":"Com"}'::jsonb
  );

insert into public.memberships (organization_id, profile_id, role)
select
  organization.id,
  member.profile_id,
  member.role::public.app_role
from public.organizations organization
cross join (
  values
    ('f5000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('f5000000-0000-0000-0000-000000000002'::uuid, 'volunteer'),
    ('f5000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('f5000000-0000-0000-0000-000000000004'::uuid, 'volunteer')
) as member(profile_id, role)
where organization.slug = 'club-sandwich';

insert into public.concerts (
  id,
  organization_id,
  artist,
  concert_date,
  venue_id,
  created_by
)
select
  'f6000000-0000-0000-0000-000000000001',
  organization.id,
  'Artiste galerie photos',
  '2026-12-08',
  venue.id,
  'f5000000-0000-0000-0000-000000000001'
from public.organizations organization
cross join lateral (
  select id from public.venues order by name limit 1
) venue
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (
  id,
  concert_id,
  user_id,
  status,
  team_role
)
values
  (
    'f7000000-0000-0000-0000-000000000001',
    'f6000000-0000-0000-0000-000000000001',
    'f5000000-0000-0000-0000-000000000002',
    'selected',
    'team_leader'
  ),
  (
    'f7000000-0000-0000-0000-000000000002',
    'f6000000-0000-0000-0000-000000000001',
    'f5000000-0000-0000-0000-000000000003',
    'selected',
    'communication'
  ),
  (
    'f7000000-0000-0000-0000-000000000003',
    'f6000000-0000-0000-0000-000000000001',
    'f5000000-0000-0000-0000-000000000004',
    'selected',
    'communication'
  );

update public.concert_volunteers
set
  role_acknowledged_at = clock_timestamp(),
  confirmation_status = 'confirmed'
where concert_id = 'f6000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f5000000-0000-0000-0000-000000000002',
  true
);

select throws_ok(
  $$
    select public.add_maraude_photo(
      'f6000000-0000-0000-0000-000000000001',
      'f6000000-0000-0000-0000-000000000001/'
        'f5000000-0000-0000-0000-000000000002/1.jpg'
    )
  $$,
  '42501',
  'Vous ne pouvez pas ajouter de photo à cette maraude',
  'Le chef d’équipe ne peut pas ajouter de photo'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f5000000-0000-0000-0000-000000000003',
  true
);

select lives_ok(
  $$
    select public.add_maraude_photo(
      'f6000000-0000-0000-0000-000000000001',
      'f6000000-0000-0000-0000-000000000001/'
        'f5000000-0000-0000-0000-000000000003/1.jpg'
    )
  $$,
  'La personne chargée de communication ajoute une photo'
);

do $$
begin
  for i in 2..5 loop
    perform public.add_maraude_photo(
      'f6000000-0000-0000-0000-000000000001',
      'f6000000-0000-0000-0000-000000000001/'
        'f5000000-0000-0000-0000-000000000003/' || i || '.jpg'
    );
  end loop;
end;
$$;

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_photos
    where concert_id = 'f6000000-0000-0000-0000-000000000001'
  $$,
  array[5::bigint],
  'Cinq photos ont été ajoutées'
);

select throws_ok(
  $$
    select public.add_maraude_photo(
      'f6000000-0000-0000-0000-000000000001',
      'f6000000-0000-0000-0000-000000000001/'
        'f5000000-0000-0000-0000-000000000003/6.jpg'
    )
  $$,
  '22023',
  'Cinq photos au maximum par maraude',
  'La sixième photo est refusée'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f5000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_photos
    where concert_id = 'f6000000-0000-0000-0000-000000000001'
  $$,
  array[5::bigint],
  'Le chef d’équipe (membre confirmé) peut consulter la galerie'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f5000000-0000-0000-0000-000000000004',
  true
);

select throws_ok(
  $$
    select public.delete_maraude_photo(
      (
        select id from public.maraude_photos
        where storage_path = 'f6000000-0000-0000-0000-000000000001/'
          'f5000000-0000-0000-0000-000000000003/1.jpg'
      )
    )
  $$,
  '42501',
  'Vous ne pouvez pas supprimer cette photo',
  'Un autre chargé de communication ne supprime pas la photo d’un tiers'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f5000000-0000-0000-0000-000000000003',
  true
);

select lives_ok(
  $$
    select public.delete_maraude_photo(
      (
        select id from public.maraude_photos
        where storage_path = 'f6000000-0000-0000-0000-000000000001/'
          'f5000000-0000-0000-0000-000000000003/1.jpg'
      )
    )
  $$,
  'L’auteur supprime sa propre photo'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f5000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.delete_maraude_photo(
      (
        select id from public.maraude_photos
        where storage_path = 'f6000000-0000-0000-0000-000000000001/'
          'f5000000-0000-0000-0000-000000000003/2.jpg'
      )
    )
  $$,
  'Un administrateur supprime n’importe quelle photo'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_photos
    where concert_id = 'f6000000-0000-0000-0000-000000000001'
  $$,
  array[3::bigint],
  'Deux suppressions ramènent la galerie à trois photos'
);

select * from finish();

rollback;
