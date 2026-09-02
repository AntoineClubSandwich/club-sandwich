begin;

create extension if not exists pgtap with schema extensions;

select plan(6);

-- Bug reported live on preprod: every volunteer got "Votre rôle a
-- changé" the first time an admin assigned their role, because
-- select_concert_volunteers used to default team_role to
-- 'collection_distribution' - so the admin's real first choice always
-- looked like a change away from that phantom default.

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '97000000-0000-0000-0000-000000000001',
    'role-notif-admin@example.test',
    '{"first_name":"Admin","last_name":"Notif"}'::jsonb
  ),
  (
    '97000000-0000-0000-0000-000000000002',
    'role-notif-volunteer@example.test',
    '{"first_name":"Volontaire","last_name":"Notif"}'::jsonb
  );

insert into public.memberships (organization_id, profile_id, role)
select o.id, m.profile_id, m.role::public.app_role
from public.organizations o
cross join (
  values
    ('97000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('97000000-0000-0000-0000-000000000002'::uuid, 'volunteer')
) as m(profile_id, role)
where o.slug = 'club-sandwich';

insert into public.concerts (
  id, organization_id, artist, concert_date, venue_id, created_by
)
select
  '98000000-0000-0000-0000-000000000001'::uuid,
  o.id,
  'Test notification rôle',
  '2026-11-10'::date,
  v.id,
  '97000000-0000-0000-0000-000000000001'::uuid
from public.organizations o
cross join lateral (
  select id from public.venues order by name limit 1
) v
where o.slug = 'club-sandwich';

insert into public.concert_volunteers (id, concert_id, user_id, status)
values (
  '99000000-0000-0000-0000-000000000001',
  '98000000-0000-0000-0000-000000000001',
  '97000000-0000-0000-0000-000000000002',
  'pending'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '97000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.select_concert_volunteers(
      '98000000-0000-0000-0000-000000000001',
      array['99000000-0000-0000-0000-000000000001'::uuid]
    )
  $$,
  'L’administrateur sélectionne le bénévole'
);

select results_eq(
  $$
    select team_role
    from public.concert_volunteers
    where id = '99000000-0000-0000-0000-000000000001'
  $$,
  $$ values (null::public.maraude_role) $$,
  'La sélection n’invente aucun rôle par défaut'
);

select lives_ok(
  $$
    select public.set_volunteer_team_role(
      '99000000-0000-0000-0000-000000000001',
      'team_leader'::public.maraude_role
    )
  $$,
  'L’administrateur attribue un premier rôle'
);

select is(
  (
    select count(*)::bigint
    from public.maraude_workflow_events
    where application_id = '99000000-0000-0000-0000-000000000001'
      and event_type = 'role_changed'
  ),
  0::bigint,
  'La toute première attribution de rôle n’est pas traitée comme un changement'
);

select lives_ok(
  $$
    select public.set_volunteer_team_role(
      '99000000-0000-0000-0000-000000000001',
      'communication'::public.maraude_role
    )
  $$,
  'L’administrateur change réellement le rôle par la suite'
);

select is(
  (
    select count(*)::bigint
    from public.maraude_workflow_events
    where application_id = '99000000-0000-0000-0000-000000000001'
      and event_type = 'role_changed'
  ),
  1::bigint,
  'Un vrai changement de rôle, lui, est bien journalisé et notifié'
);

select * from finish();

rollback;
