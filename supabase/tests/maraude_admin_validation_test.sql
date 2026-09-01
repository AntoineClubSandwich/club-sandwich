begin;

create extension if not exists pgtap with schema extensions;

select plan(8);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '94000000-0000-0000-0000-000000000001',
    'validate-admin@example.test',
    '{"first_name":"Admin","last_name":"Validate"}'::jsonb
  ),
  (
    '94000000-0000-0000-0000-000000000002',
    'validate-leader@example.test',
    '{"first_name":"Chef","last_name":"Validate"}'::jsonb
  ),
  (
    '94000000-0000-0000-0000-000000000003',
    'validate-member1@example.test',
    '{"first_name":"Membre1","last_name":"Validate"}'::jsonb
  ),
  (
    '94000000-0000-0000-0000-000000000004',
    'validate-member2@example.test',
    '{"first_name":"Membre2","last_name":"Validate"}'::jsonb
  );

insert into public.memberships (organization_id, profile_id, role)
select o.id, m.profile_id, m.role::public.app_role
from public.organizations o
cross join (
  values
    ('94000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('94000000-0000-0000-0000-000000000002'::uuid, 'volunteer'),
    ('94000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('94000000-0000-0000-0000-000000000004'::uuid, 'volunteer')
) as m(profile_id, role)
where o.slug = 'club-sandwich';

insert into public.concerts (
  id, organization_id, artist, concert_date, venue_id, created_by,
  maraude_status
)
select
  '95000000-0000-0000-0000-000000000001'::uuid,
  o.id,
  'Test validation admin',
  '2026-10-25'::date,
  v.id,
  '94000000-0000-0000-0000-000000000001'::uuid,
  'open'::public.maraude_status
from public.organizations o
cross join lateral (
  select id from public.venues order by name limit 1
) v
where o.slug = 'club-sandwich';

insert into public.concert_volunteers (id, concert_id, user_id, status, team_role)
values
  (
    '96000000-0000-0000-0000-000000000001',
    '95000000-0000-0000-0000-000000000001',
    '94000000-0000-0000-0000-000000000002',
    'selected',
    'team_leader'
  ),
  (
    '96000000-0000-0000-0000-000000000002',
    '95000000-0000-0000-0000-000000000001',
    '94000000-0000-0000-0000-000000000003',
    'selected',
    'logistics'
  ),
  (
    '96000000-0000-0000-0000-000000000003',
    '95000000-0000-0000-0000-000000000001',
    '94000000-0000-0000-0000-000000000004',
    'selected',
    'communication'
  );

update public.concert_volunteers
set role_acknowledged_at = clock_timestamp(), confirmation_status = 'confirmed'
where concert_id = '95000000-0000-0000-0000-000000000001';

select results_eq(
  $$
    select confirmed_count, confirmed_leader_count
    from public.get_maraude_overview()
    where concert_id = '95000000-0000-0000-0000-000000000001'
  $$,
  $$ values (3::bigint, 1::bigint) $$,
  'L’aperçu expose le nombre de bénévoles confirmés et de chefs confirmés'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '94000000-0000-0000-0000-000000000002',
  true
);

select throws_ok(
  $$
    select public.set_maraude_status(
      '95000000-0000-0000-0000-000000000001',
      'in_progress'::public.maraude_status,
      null
    )
  $$,
  '42501',
  'Action réservée au chef d''équipe',
  'Le chef ne peut plus démarrer directement depuis "planifiée", même équipe complète'
);

select throws_ok(
  $$
    select public.set_maraude_status(
      '95000000-0000-0000-0000-000000000001',
      'team_ready'::public.maraude_status,
      null
    )
  $$,
  '42501',
  'Action réservée au chef d''équipe',
  'Le chef d’équipe ne peut pas valider l’équipe lui-même'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '94000000-0000-0000-0000-000000000003',
  true
);

select throws_ok(
  $$
    select public.set_maraude_status(
      '95000000-0000-0000-0000-000000000001',
      'team_ready'::public.maraude_status,
      null
    )
  $$,
  '42501',
  'Concert inaccessible',
  'Un bénévole simple, ni admin ni chef confirmé, ne voit même pas la maraude'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '94000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.set_maraude_status(
      '95000000-0000-0000-0000-000000000001',
      'team_ready'::public.maraude_status,
      null
    )
  $$,
  'L’administrateur valide une équipe complète et confirmée'
);

select results_eq(
  $$
    select maraude_status::text
    from public.concerts
    where id = '95000000-0000-0000-0000-000000000001'
  $$,
  array['team_ready'::text],
  'La maraude passe à l’état "équipe validée"'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '94000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.set_maraude_status(
      '95000000-0000-0000-0000-000000000001',
      'in_progress'::public.maraude_status,
      null
    )
  $$,
  'Le chef d’équipe démarre une fois l’équipe validée par l’admin'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '94000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_workflow_events
    where concert_id = '95000000-0000-0000-0000-000000000001'
      and event_type = 'status_changed'
  $$,
  array[1::bigint],
  'La validation admin est journalisée'
);

select * from finish();

rollback;
