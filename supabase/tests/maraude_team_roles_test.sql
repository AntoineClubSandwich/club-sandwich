begin;

create extension if not exists pgtap with schema extensions;

select plan(16);

select has_column(
  'public',
  'concert_volunteers',
  'team_role',
  'La relation concert-bénévole porte le rôle de maraude'
);

select col_type_is(
  'public',
  'concert_volunteers',
  'team_role',
  'public.maraude_role',
  'Le rôle utilise l’enum maraude_role'
);

select enum_has_labels(
  'public',
  'maraude_role',
  array[
    'team_leader',
    'logistics',
    'communication',
    'collection_distribution'
  ],
  'Les quatre rôles de maraude sont disponibles'
);

insert into auth.users (
  id,
  email,
  raw_user_meta_data
)
values
  (
    '30000000-0000-0000-0000-000000000001',
    'team-volunteer-one@example.test',
    '{"first_name":"Camille","last_name":"Martin"}'::jsonb
  ),
  (
    '30000000-0000-0000-0000-000000000002',
    'team-volunteer-two@example.test',
    '{"first_name":"Alex","last_name":"Durand"}'::jsonb
  ),
  (
    '30000000-0000-0000-0000-000000000003',
    'team-admin@example.test',
    '{"first_name":"Admin","last_name":"Equipe"}'::jsonb
  );

insert into public.memberships (
  organization_id,
  profile_id,
  role
)
select
  o.id,
  member_data.profile_id,
  member_data.role::public.app_role
from public.organizations o
cross join (
  values
    (
      '30000000-0000-0000-0000-000000000001'::uuid,
      'volunteer'
    ),
    (
      '30000000-0000-0000-0000-000000000002'::uuid,
      'volunteer'
    ),
    (
      '30000000-0000-0000-0000-000000000003'::uuid,
      'admin'
    )
) as member_data(profile_id, role)
where o.slug = 'club-sandwich';

insert into public.concerts (
  id,
  organization_id,
  artist,
  concert_date,
  venue_id,
  created_by
)
select
  '40000000-0000-0000-0000-000000000001'::uuid,
  o.id,
  'Artiste équipe',
  '2026-10-15'::date,
  v.id,
  '30000000-0000-0000-0000-000000000003'::uuid
from public.organizations o
cross join lateral (
  select id
  from public.venues
  order by name
  limit 1
) v
where o.slug = 'club-sandwich';

insert into public.concert_volunteers (
  id,
  concert_id,
  user_id,
  status
)
values
  (
    '50000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'pending'
  ),
  (
    '50000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    'pending'
  ),
  (
    '50000000-0000-0000-0000-000000000003',
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000003',
    'selected'
  );

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where id = '50000000-0000-0000-0000-000000000003'
      and status = 'selected'
      and team_role is null
  $$,
  array[1::bigint],
  'Une candidature déjà sélectionnée conserve un rôle NULL'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '30000000-0000-0000-0000-000000000003',
  true
);

select lives_ok(
  $$
    select public.select_concert_volunteers(
      '40000000-0000-0000-0000-000000000001',
      array[
        '50000000-0000-0000-0000-000000000001'::uuid,
        '50000000-0000-0000-0000-000000000002'::uuid
      ]
    )
  $$,
  'Un administrateur sélectionne plusieurs bénévoles en une action'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where status = 'selected'
      and team_role = 'collection_distribution'
  $$,
  array[2::bigint],
  'La sélection groupée affecte le rôle Récolte et distribution par défaut'
);

select lives_ok(
  $$
    update public.concert_volunteers
    set team_role = 'team_leader'
    where id = '50000000-0000-0000-0000-000000000001'
  $$,
  'Un administrateur peut désigner un chef d’équipe'
);

select lives_ok(
  $$
    update public.concert_volunteers
    set team_role = 'team_leader'
    where id = '50000000-0000-0000-0000-000000000002'
  $$,
  'Un concert peut avoir plusieurs chefs d’équipe'
);

select lives_ok(
  $$
    update public.concert_volunteers
    set team_role = 'logistics'
    where id = '50000000-0000-0000-0000-000000000002'
  $$,
  'Un administrateur peut désigner un responsable logistique'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '30000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$
    select team_role::text
    from public.concert_volunteers
  $$,
  array['team_leader'::text],
  'Un bénévole sélectionné voit uniquement son propre rôle'
);

select throws_ok(
  $$
    update public.concert_volunteers
    set team_role = 'logistics'
    where id = '50000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  'new row violates row-level security policy for table "concert_volunteers"',
  'Un bénévole ne peut pas modifier son rôle'
);

select lives_ok(
  $$
    update public.concert_volunteers
    set status = 'withdrawn'
    where id = '50000000-0000-0000-0000-000000000001'
  $$,
  'Un bénévole sélectionné peut se désister'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where id = '50000000-0000-0000-0000-000000000001'
      and status = 'withdrawn'
      and team_role is null
  $$,
  array[1::bigint],
  'Le désistement retire automatiquement le rôle'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '30000000-0000-0000-0000-000000000003',
  true
);

select lives_ok(
  $$
    update public.concert_volunteers
    set status = 'not_selected'
    where id = '50000000-0000-0000-0000-000000000002'
  $$,
  'Un administrateur peut ne pas sélectionner un bénévole'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where id = '50000000-0000-0000-0000-000000000002'
      and status = 'not_selected'
      and team_role is null
  $$,
  array[1::bigint],
  'La non-sélection retire automatiquement le rôle'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.get_concert_volunteer_team_details(
      '40000000-0000-0000-0000-000000000001'
    )
    where team_role is not null
  $$,
  array[0::bigint],
  'La lecture groupée reflète les rôles retirés'
);

select * from finish();

rollback;
