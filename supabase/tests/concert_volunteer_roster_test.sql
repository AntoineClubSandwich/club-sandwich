begin;

create extension if not exists pgtap with schema extensions;

select plan(8);

select has_function(
  'public',
  'get_concert_volunteer_roster',
  array['uuid'],
  'La liste restreinte des candidatures existe'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    'e0000000-0000-0000-0000-000000000001',
    'roster-admin@example.test',
    '{"first_name":"Admin","last_name":"Roster"}'::jsonb
  ),
  (
    'e0000000-0000-0000-0000-000000000002',
    'roster-vol-a@example.test',
    '{"first_name":"Alex","last_name":"Un"}'::jsonb
  ),
  (
    'e0000000-0000-0000-0000-000000000003',
    'roster-vol-b@example.test',
    '{"first_name":"Blaise","last_name":"Deux"}'::jsonb
  ),
  (
    'e0000000-0000-0000-0000-000000000004',
    'roster-vol-c@example.test',
    '{"first_name":"Camille","last_name":"Trois"}'::jsonb
  );

insert into public.memberships (organization_id, profile_id, role)
select
  organization.id,
  member.profile_id,
  member.role::public.app_role
from public.organizations organization
cross join (
  values
    ('e0000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('e0000000-0000-0000-0000-000000000002'::uuid, 'volunteer'),
    ('e0000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('e0000000-0000-0000-0000-000000000004'::uuid, 'volunteer')
) as member(profile_id, role)
where organization.slug = 'club-sandwich';

insert into public.concerts (
  id,
  organization_id,
  artist,
  concert_date,
  venue_id,
  created_by,
  maraude_status
)
select
  'e1000000-0000-0000-0000-000000000001',
  organization.id,
  'Artiste roster ouvert',
  '2026-12-05',
  venue.id,
  'e0000000-0000-0000-0000-000000000001',
  'open'
from public.organizations organization
cross join lateral (
  select id from public.venues order by name limit 1
) venue
where organization.slug = 'club-sandwich';

insert into public.concerts (
  id,
  organization_id,
  artist,
  concert_date,
  venue_id,
  created_by,
  maraude_status
)
select
  'e1000000-0000-0000-0000-000000000002',
  organization.id,
  'Artiste roster fermé',
  '2026-12-06',
  venue.id,
  'e0000000-0000-0000-0000-000000000001',
  'draft'
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
    'e2000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000001',
    'e0000000-0000-0000-0000-000000000002',
    'selected',
    'team_leader'
  ),
  (
    'e2000000-0000-0000-0000-000000000002',
    'e1000000-0000-0000-0000-000000000001',
    'e0000000-0000-0000-0000-000000000003',
    'pending',
    null
  ),
  (
    'e2000000-0000-0000-0000-000000000003',
    'e1000000-0000-0000-0000-000000000001',
    'e0000000-0000-0000-0000-000000000004',
    'withdrawn',
    null
  ),
  (
    'e2000000-0000-0000-0000-000000000004',
    'e1000000-0000-0000-0000-000000000002',
    'e0000000-0000-0000-0000-000000000004',
    'pending',
    null
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e0000000-0000-0000-0000-000000000004',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.get_concert_volunteer_roster(
      'e1000000-0000-0000-0000-000000000001'
    )
  $$,
  array[2::bigint],
  'Un bénévole voit les candidatures actives d’une maraude ouverte, hors désistements'
);

select results_eq(
  $$
    select first_name, last_name, status::text, team_role::text
    from public.get_concert_volunteer_roster(
      'e1000000-0000-0000-0000-000000000001'
    )
    order by first_name
    limit 1
  $$,
  $$ values ('Alex'::text, 'Un'::text, 'selected'::text, 'team_leader'::text) $$,
  'La ligne restituée ne contient que prénom, nom, statut et rôle'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e0000000-0000-0000-0000-000000000003',
  true
);

select throws_ok(
  $$
    select * from public.get_concert_volunteer_roster(
      'e1000000-0000-0000-0000-000000000002'
    )
  $$,
  '42501',
  'Maraude inaccessible',
  'Un bénévole sans candidature ne voit pas le roster d’une maraude non ouverte'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e0000000-0000-0000-0000-000000000004',
  true
);

select lives_ok(
  $$
    select * from public.get_concert_volunteer_roster(
      'e1000000-0000-0000-0000-000000000002'
    )
  $$,
  'Un bénévole déjà candidat voit le roster même si la maraude n’est pas ouverte'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e0000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select * from public.get_concert_volunteer_roster(
      'e1000000-0000-0000-0000-000000000002'
    )
  $$,
  'Un administrateur voit toujours le roster'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e0000000-0000-0000-0000-000000000002',
  true
);

select throws_ok(
  $$
    select * from public.get_concert_volunteer_roster(
      'e1000000-0000-0000-0000-000000000002'
    )
  $$,
  '42501',
  'Maraude inaccessible',
  'Un autre bénévole non candidat ne voit pas le roster d’une maraude non ouverte'
);

select results_eq(
  $$
    select status::text
    from public.get_concert_volunteer_roster(
      'e1000000-0000-0000-0000-000000000001'
    )
    where user_id = 'e0000000-0000-0000-0000-000000000004'
  $$,
  cast(array[]::text[] as text[]),
  'Les désistements n’apparaissent pas dans le roster'
);

select * from finish();

rollback;
