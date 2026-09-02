begin;

create extension if not exists pgtap with schema extensions;

select plan(8);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '9a000000-0000-0000-0000-000000000001',
    'stale-admin@example.test',
    '{"first_name":"Admin","last_name":"Stale"}'::jsonb
  ),
  (
    '9a000000-0000-0000-0000-000000000002',
    'stale-leader@example.test',
    '{"first_name":"Chef","last_name":"Stale"}'::jsonb
  ),
  (
    '9a000000-0000-0000-0000-000000000003',
    'stale-member1@example.test',
    '{"first_name":"Membre1","last_name":"Stale"}'::jsonb
  ),
  (
    '9a000000-0000-0000-0000-000000000004',
    'stale-member2@example.test',
    '{"first_name":"Membre2","last_name":"Stale"}'::jsonb
  );

insert into public.memberships (organization_id, profile_id, role)
select o.id, m.profile_id, m.role::public.app_role
from public.organizations o
cross join (
  values
    ('9a000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('9a000000-0000-0000-0000-000000000002'::uuid, 'volunteer'),
    ('9a000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('9a000000-0000-0000-0000-000000000004'::uuid, 'volunteer')
) as m(profile_id, role)
where o.slug = 'club-sandwich';

-- Maraude 1: validated team, then a member withdraws.
insert into public.concerts (
  id, organization_id, artist, concert_date, venue_id, created_by,
  maraude_status
)
select
  '9b000000-0000-0000-0000-000000000001'::uuid,
  o.id,
  'Test désistement post-validation',
  '2026-11-15'::date,
  v.id,
  '9a000000-0000-0000-0000-000000000001'::uuid,
  'open'::public.maraude_status
from public.organizations o
cross join lateral (
  select id from public.venues order by name limit 1
) v
where o.slug = 'club-sandwich';

insert into public.concert_volunteers (id, concert_id, user_id, status, team_role)
values
  (
    '9c000000-0000-0000-0000-000000000001',
    '9b000000-0000-0000-0000-000000000001',
    '9a000000-0000-0000-0000-000000000002',
    'selected',
    'team_leader'
  ),
  (
    '9c000000-0000-0000-0000-000000000002',
    '9b000000-0000-0000-0000-000000000001',
    '9a000000-0000-0000-0000-000000000003',
    'selected',
    'logistics'
  ),
  (
    '9c000000-0000-0000-0000-000000000003',
    '9b000000-0000-0000-0000-000000000001',
    '9a000000-0000-0000-0000-000000000004',
    'selected',
    'communication'
  );

update public.concert_volunteers
set role_acknowledged_at = clock_timestamp(), confirmation_status = 'confirmed'
where concert_id = '9b000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '9a000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.set_maraude_status(
      '9b000000-0000-0000-0000-000000000001',
      'team_ready'::public.maraude_status,
      null
    )
  $$,
  'L’administrateur valide l’équipe complète'
);

-- One confirmed, non-leader member withdraws by their own hand.
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '9a000000-0000-0000-0000-000000000003',
  true
);

update public.concert_volunteers
set status = 'withdrawn'::public.concert_volunteer_status
where id = '9c000000-0000-0000-0000-000000000002'
  and user_id = '9a000000-0000-0000-0000-000000000003';

select results_eq(
  $$
    select maraude_status::text
    from public.concerts
    where id = '9b000000-0000-0000-0000-000000000001'
  $$,
  array['open'::text],
  'Un désistement après validation repasse la maraude en "planifiée"'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '9a000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_workflow_events
    where concert_id = '9b000000-0000-0000-0000-000000000001'
      and event_type = 'status_changed'
      and new_value ->> 'reason' = 'team_no_longer_complete'
  $$,
  array[1::bigint],
  'La rétrogradation est journalisée avec sa raison'
);

-- The team leader's "Démarrer" self-service must be blocked again now
-- that the maraude reverted to "open" (needs re-validation first).
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '9a000000-0000-0000-0000-000000000002',
  true
);

select throws_ok(
  $$
    select public.set_maraude_status(
      '9b000000-0000-0000-0000-000000000001',
      'in_progress'::public.maraude_status,
      null
    )
  $$,
  '42501',
  'Action réservée au chef d''équipe',
  'Le chef ne peut plus démarrer tant que l’équipe n’est pas re-validée'
);

-- Maraude 2: validated team, an unrelated field changes elsewhere on
-- the same volunteer (no completeness lost) - must NOT be downgraded.
reset role;
insert into public.concerts (
  id, organization_id, artist, concert_date, venue_id, created_by
)
select
  '9b000000-0000-0000-0000-000000000002'::uuid,
  o.id,
  'Test faux positif',
  '2026-11-16'::date,
  v.id,
  '9a000000-0000-0000-0000-000000000001'::uuid
from public.organizations o
cross join lateral (
  select id from public.venues order by name limit 1
) v
where o.slug = 'club-sandwich';

insert into public.concert_volunteers (id, concert_id, user_id, status, team_role)
values
  (
    '9c000000-0000-0000-0000-000000000004',
    '9b000000-0000-0000-0000-000000000002',
    '9a000000-0000-0000-0000-000000000002',
    'selected',
    'team_leader'
  ),
  (
    '9c000000-0000-0000-0000-000000000005',
    '9b000000-0000-0000-0000-000000000002',
    '9a000000-0000-0000-0000-000000000003',
    'selected',
    'logistics'
  ),
  (
    '9c000000-0000-0000-0000-000000000006',
    '9b000000-0000-0000-0000-000000000002',
    '9a000000-0000-0000-0000-000000000004',
    'selected',
    'communication'
  );

-- Selection above lands confirmation_status at 'pending' (the before-
-- insert trigger enforces this regardless of what's inserted) - actually
-- confirm each member the same way confirm_concert_participation would.
update public.concert_volunteers
set role_acknowledged_at = clock_timestamp(), confirmation_status = 'confirmed'
where concert_id = '9b000000-0000-0000-0000-000000000002';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '9a000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.set_maraude_status(
      '9b000000-0000-0000-0000-000000000002',
      'team_ready'::public.maraude_status,
      null
    )
  $$,
  'L’équipe de la seconde maraude est réellement validée'
);

select lives_ok(
  $$
    select public.set_volunteer_team_role(
      '9c000000-0000-0000-0000-000000000005',
      'logistics'::public.maraude_role
    )
  $$,
  'L’admin réattribue le même rôle (aucune perte de complétude)'
);

select results_eq(
  $$
    select maraude_status::text
    from public.concerts
    where id = '9b000000-0000-0000-0000-000000000002'
  $$,
  array['team_ready'::text],
  'Une équipe toujours complète n’est jamais rétrogradée par erreur'
);

select lives_ok(
  $$
    select public.set_maraude_status(
      '9b000000-0000-0000-0000-000000000002',
      'in_progress'::public.maraude_status,
      null
    )
  $$,
  'Une maraude restée réellement validée démarre normalement'
);

select * from finish();

rollback;
