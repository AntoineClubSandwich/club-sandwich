begin;

create extension if not exists pgtap with schema extensions;

select plan(17);

select has_function(
  'public',
  'save_maraude_team',
  array['uuid', 'jsonb'],
  'La sauvegarde atomique d’une équipe est disponible'
);

select results_eq(
  $$
    select count(*)::bigint
    from pg_indexes
    where schemaname = 'public'
      and indexname in (
        'concert_volunteers_one_communication_idx',
        'concert_volunteers_one_logistics_idx'
      )
  $$,
  array[0::bigint],
  'Aucun index unique ne limite Communication ou Logistique'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '31000000-0000-0000-0000-000000000001',
    'builder-admin@example.test',
    '{"first_name":"Admin","last_name":"Equipe"}'::jsonb
  ),
  (
    '31000000-0000-0000-0000-000000000002',
    'builder-one@example.test',
    '{"first_name":"Camille","last_name":"Martin"}'::jsonb
  ),
  (
    '31000000-0000-0000-0000-000000000003',
    'builder-two@example.test',
    '{"first_name":"Hugo","last_name":"Durand"}'::jsonb
  ),
  (
    '31000000-0000-0000-0000-000000000004',
    'builder-three@example.test',
    '{"first_name":"Inès","last_name":"Robert"}'::jsonb
  ),
  (
    '31000000-0000-0000-0000-000000000005',
    'builder-four@example.test',
    '{"first_name":"Alex","last_name":"Bernard"}'::jsonb
  ),
  (
    '31000000-0000-0000-0000-000000000006',
    'builder-five@example.test',
    '{"first_name":"Zoé","last_name":"Petit"}'::jsonb
  );

insert into public.memberships (organization_id, profile_id, role)
select
  organization.id,
  member_data.profile_id,
  member_data.role::public.app_role
from public.organizations organization
cross join (
  values
    ('31000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('31000000-0000-0000-0000-000000000002'::uuid, 'volunteer'),
    ('31000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('31000000-0000-0000-0000-000000000004'::uuid, 'volunteer'),
    ('31000000-0000-0000-0000-000000000005'::uuid, 'volunteer'),
    ('31000000-0000-0000-0000-000000000006'::uuid, 'volunteer')
) as member_data(profile_id, role)
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
  '41000000-0000-0000-0000-000000000001'::uuid,
  organization.id,
  'Artiste constructeur équipe',
  '2026-11-12'::date,
  venue.id,
  '31000000-0000-0000-0000-000000000001'::uuid
from public.organizations organization
cross join lateral (
  select id
  from public.venues
  order by name
  limit 1
) venue
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (
  id,
  concert_id,
  user_id,
  status
)
values
  (
    '51000000-0000-0000-0000-000000000001',
    '41000000-0000-0000-0000-000000000001',
    '31000000-0000-0000-0000-000000000002',
    'pending'
  ),
  (
    '51000000-0000-0000-0000-000000000002',
    '41000000-0000-0000-0000-000000000001',
    '31000000-0000-0000-0000-000000000003',
    'pending'
  ),
  (
    '51000000-0000-0000-0000-000000000003',
    '41000000-0000-0000-0000-000000000001',
    '31000000-0000-0000-0000-000000000004',
    'pending'
  ),
  (
    '51000000-0000-0000-0000-000000000004',
    '41000000-0000-0000-0000-000000000001',
    '31000000-0000-0000-0000-000000000005',
    'pending'
  ),
  (
    '51000000-0000-0000-0000-000000000005',
    '41000000-0000-0000-0000-000000000001',
    '31000000-0000-0000-0000-000000000006',
    'pending'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '31000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.save_maraude_team(
      '41000000-0000-0000-0000-000000000001',
      '[
        {
          "application_id": "51000000-0000-0000-0000-000000000001",
          "team_role": "team_leader"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000002",
          "team_role": "communication"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000003",
          "team_role": "logistics"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000004",
          "team_role": "collection_distribution"
        }
      ]'::jsonb
    )
  $$,
  'Un administrateur enregistre quatre bénévoles et leurs rôles atomiquement'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where concert_id = '41000000-0000-0000-0000-000000000001'
      and status = 'selected'
      and team_role is not null
  $$,
  array[4::bigint],
  'Les quatre candidatures deviennent sélectionnées avec un rôle'
);

select ok(
  (
    select
      count(*) filter (where team_role = 'team_leader') = 1
      and count(*) filter (where team_role = 'communication') = 1
      and count(*) filter (where team_role = 'logistics') = 1
      and count(*) filter (
        where team_role = 'collection_distribution'
      ) = 1
    from public.concert_volunteers
    where concert_id = '41000000-0000-0000-0000-000000000001'
  ),
  'Chaque rôle demandé est enregistré'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where concert_id = '41000000-0000-0000-0000-000000000001'
      and status = 'selected'
      and attendance_status = 'pending'
  $$,
  array[4::bigint],
  'Une nouvelle sélection reçoit une présence En attente'
);

select lives_ok(
  $$
    update public.concert_volunteers
    set team_role = 'communication'
    where id = '51000000-0000-0000-0000-000000000004'
  $$,
  'Plusieurs responsables Communication sont autorisés'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where concert_id = '41000000-0000-0000-0000-000000000001'
      and team_role = 'communication'
  $$,
  array[2::bigint],
  'Plusieurs rôles Communication sont conservés'
);

select lives_ok(
  $$
    update public.concert_volunteers
    set team_role = 'logistics'
    where id = '51000000-0000-0000-0000-000000000004'
  $$,
  'Plusieurs responsables Logistique sont autorisés'
);

select lives_ok(
  $$
    select public.save_maraude_team(
      '41000000-0000-0000-0000-000000000001',
      '[
        {
          "application_id": "51000000-0000-0000-0000-000000000001",
          "team_role": "team_leader"
        }
      ]'::jsonb
    )
  $$,
  'Une équipe d’un bénévole est autorisée'
);

select lives_ok(
  $$
    select public.save_maraude_team(
      '41000000-0000-0000-0000-000000000001',
      '[]'::jsonb
    )
  $$,
  'Une équipe vide peut être enregistrée'
);

select lives_ok(
  $$
    select public.save_maraude_team(
      '41000000-0000-0000-0000-000000000001',
      '[
        {
          "application_id": "51000000-0000-0000-0000-000000000001",
          "team_role": "collection_distribution"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000002",
          "team_role": "communication"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000003",
          "team_role": "logistics"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000004",
          "team_role": "collection_distribution"
        }
      ]'::jsonb
    )
  $$,
  'Une équipe sans chef est autorisée'
);

select throws_ok(
  $$
    select public.save_maraude_team(
      '41000000-0000-0000-0000-000000000001',
      '[
        {
          "application_id": "51000000-0000-0000-0000-000000000001",
          "team_role": "team_leader"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000001",
          "team_role": "collection_distribution"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000003",
          "team_role": "logistics"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000004",
          "team_role": "collection_distribution"
        }
      ]'::jsonb
    )
  $$,
  '22023',
  'Une candidature ne peut apparaître qu’une seule fois',
  'La base refuse une candidature dupliquée dans l’équipe'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '31000000-0000-0000-0000-000000000002',
  true
);

select throws_ok(
  $$
    select public.save_maraude_team(
      '41000000-0000-0000-0000-000000000001',
      '[
        {
          "application_id": "51000000-0000-0000-0000-000000000001",
          "team_role": "team_leader"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000002",
          "team_role": "communication"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000003",
          "team_role": "logistics"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000004",
          "team_role": "collection_distribution"
        }
      ]'::jsonb
    )
  $$,
  '42501',
  'Seul un administrateur peut constituer une équipe',
  'Un bénévole ne peut pas enregistrer l’équipe'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '31000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.save_maraude_team(
      '41000000-0000-0000-0000-000000000001',
      '[
        {
          "application_id": "51000000-0000-0000-0000-000000000001",
          "team_role": "team_leader"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000002",
          "team_role": "communication"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000003",
          "team_role": "logistics"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000005",
          "team_role": "collection_distribution"
        }
      ]'::jsonb
    )
  $$,
  'La sauvegarde atomique peut remplacer un membre de l’équipe'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where id = '51000000-0000-0000-0000-000000000004'
      and status = 'not_selected'
      and team_role is null
      and attendance_status is null
  $$,
  array[1::bigint],
  'Retirer un membre efface automatiquement son rôle et sa présence'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where id = '51000000-0000-0000-0000-000000000005'
      and status = 'selected'
      and team_role = 'collection_distribution'
      and attendance_status = 'pending'
  $$,
  array[1::bigint],
  'Le remplaçant est sélectionné avec son rôle et sa présence initiale'
);

select * from finish();

rollback;
