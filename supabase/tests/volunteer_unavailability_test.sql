begin;

create extension if not exists pgtap with schema extensions;

select plan(12);

select has_table(
  'public',
  'concert_volunteer_unavailabilities',
  'Les indisponibilités sont stockées à part des candidatures'
);

select has_function(
  'public',
  'set_concert_unavailability',
  array['uuid', 'boolean'],
  'Le bénévole dispose d’une action sécurisée pour se dire indisponible'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '38000000-0000-0000-0000-000000000001',
    'unavailable-volunteer@example.test',
    '{"first_name":"Camille","last_name":"Occupée"}'::jsonb
  ),
  (
    '38000000-0000-0000-0000-000000000002',
    'unavailable-admin@example.test',
    '{"first_name":"Indispo","last_name":"Admin"}'::jsonb
  ),
  (
    '38000000-0000-0000-0000-000000000003',
    'unavailable-applicant@example.test',
    '{"first_name":"Déjà","last_name":"Candidat"}'::jsonb
  );

insert into public.memberships (organization_id, profile_id, role)
select
  organization.id,
  member_data.profile_id,
  member_data.role::public.app_role
from public.organizations organization
cross join (
  values
    ('38000000-0000-0000-0000-000000000001'::uuid, 'volunteer'),
    ('38000000-0000-0000-0000-000000000002'::uuid, 'admin'),
    ('38000000-0000-0000-0000-000000000003'::uuid, 'volunteer')
) as member_data(profile_id, role)
where organization.slug = 'club-sandwich';

insert into public.user_accounts (
  profile_id, role, organization_id, status, activated_at
)
values
  ('38000000-0000-0000-0000-000000000001', 'volunteer', null, 'active', now()),
  ('38000000-0000-0000-0000-000000000002', 'admin', null, 'active', now()),
  ('38000000-0000-0000-0000-000000000003', 'volunteer', null, 'active', now());

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
  maraude.id,
  organization.id,
  maraude.artist,
  '2026-12-12'::date,
  venue.id,
  '38000000-0000-0000-0000-000000000002'::uuid,
  maraude.status::public.maraude_status
from public.organizations organization
cross join lateral (
  select id from public.venues order by name limit 1
) venue
cross join (
  values
    ('48000000-0000-0000-0000-000000000001'::uuid, 'Indispo ouverte', 'open'),
    ('48000000-0000-0000-0000-000000000002'::uuid, 'Indispo brouillon', 'draft')
) as maraude(id, artist, status)
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (concert_id, user_id, status)
values (
  '48000000-0000-0000-0000-000000000001',
  '38000000-0000-0000-0000-000000000003',
  'pending'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '38000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.set_concert_unavailability(
      '48000000-0000-0000-0000-000000000001',
      true
    )
  $$,
  'Un bénévole sans candidature peut se dire indisponible'
);

select is(
  (
    public.get_concert_volunteer_bundle(
      '48000000-0000-0000-0000-000000000001'
    ) ->> 'is_unavailable'
  )::boolean,
  true,
  'Le bénévole retrouve son indisponibilité dans la section bénévoles'
);

select is(
  jsonb_array_length(
    public.get_concert_volunteer_bundle(
      '48000000-0000-0000-0000-000000000001'
    ) -> 'unavailable_volunteers'
  ),
  0,
  'Un bénévole ne voit pas la liste des indisponibles'
);

select results_eq(
  $$ select user_id from public.concert_volunteer_unavailabilities $$,
  array['38000000-0000-0000-0000-000000000001'::uuid],
  'Le bénévole ne lit que ses propres indisponibilités'
);

select throws_ok(
  $$
    select public.set_concert_unavailability(
      '48000000-0000-0000-0000-000000000002',
      true
    )
  $$,
  '22023',
  null,
  'Impossible de répondre à une maraude hors fenêtre de candidature'
);

select set_config(
  'request.jwt.claim.sub',
  '38000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$
    select volunteer ->> 'first_name'
    from jsonb_array_elements(
      public.get_concert_volunteer_bundle(
        '48000000-0000-0000-0000-000000000001'
      ) -> 'unavailable_volunteers'
    ) volunteer
  $$,
  array['Camille'::text],
  'L’admin voit qui est indisponible'
);

select throws_ok(
  $$
    select public.set_concert_unavailability(
      '48000000-0000-0000-0000-000000000001',
      true
    )
  $$,
  '42501',
  null,
  'Un admin ne peut pas se dire indisponible'
);

select set_config(
  'request.jwt.claim.sub',
  '38000000-0000-0000-0000-000000000003',
  true
);

select throws_ok(
  $$
    select public.set_concert_unavailability(
      '48000000-0000-0000-0000-000000000001',
      true
    )
  $$,
  '22023',
  null,
  'Un bénévole déjà positionné passe par le désistement'
);

select is_empty(
  $$ select 1 from public.concert_volunteer_unavailabilities $$,
  'Un bénévole ne lit pas les indisponibilités des autres'
);

select set_config(
  'request.jwt.claim.sub',
  '38000000-0000-0000-0000-000000000001',
  true
);

insert into public.concert_volunteers (concert_id, user_id, status)
values (
  '48000000-0000-0000-0000-000000000001',
  '38000000-0000-0000-0000-000000000001',
  'pending'
);

select is(
  (
    public.get_concert_volunteer_bundle(
      '48000000-0000-0000-0000-000000000001'
    ) ->> 'is_unavailable'
  )::boolean,
  false,
  'Se proposer efface l’indisponibilité'
);

select * from finish();

rollback;
