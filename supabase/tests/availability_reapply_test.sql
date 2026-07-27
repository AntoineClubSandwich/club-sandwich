begin;

create extension if not exists pgtap with schema extensions;

select plan(9);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '32000000-0000-0000-0000-000000000001',
    'reapply-volunteer@example.test',
    '{"first_name":"Retour","last_name":"Bénévole"}'::jsonb
  ),
  (
    '32000000-0000-0000-0000-000000000002',
    'reapply-admin@example.test',
    '{"first_name":"Admin","last_name":"Retour"}'::jsonb
  );

insert into public.memberships (organization_id, profile_id, role)
select
  organization.id,
  member_data.profile_id,
  member_data.role::public.app_role
from public.organizations organization
cross join (
  values
    ('32000000-0000-0000-0000-000000000001'::uuid, 'volunteer'),
    ('32000000-0000-0000-0000-000000000002'::uuid, 'admin')
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
  '42000000-0000-0000-0000-000000000001'::uuid,
  organization.id,
  'Retour disponibilité',
  '2026-11-20'::date,
  venue.id,
  '32000000-0000-0000-0000-000000000002'::uuid
from public.organizations organization
cross join lateral (
  select id from public.venues order by name limit 1
) venue
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (
  id,
  concert_id,
  user_id,
  status
)
values (
  '52000000-0000-0000-0000-000000000001',
  '42000000-0000-0000-0000-000000000001',
  '32000000-0000-0000-0000-000000000001',
  'pending'
);

select has_table(
  'public',
  'concert_volunteer_events',
  'L’historique de disponibilité existe'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '32000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    update public.concert_volunteers
    set status = 'withdrawn'
    where id = '52000000-0000-0000-0000-000000000001'
  $$,
  'Le bénévole se désiste'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteer_events
    where application_id = '52000000-0000-0000-0000-000000000001'
      and status = 'withdrawn'
  $$,
  array[1::bigint],
  'Le désistement est conservé dans l’historique'
);

select lives_ok(
  $$
    select public.reapply_to_concert(
      '42000000-0000-0000-0000-000000000001'
    )
  $$,
  'Le bénévole renouvelle explicitement sa disponibilité'
);

select results_eq(
  $$
    select status::text
    from public.concert_volunteers
    where id = '52000000-0000-0000-0000-000000000001'
  $$,
  array['pending'::text],
  'La disponibilité active revient en attente'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteer_events
    where application_id = '52000000-0000-0000-0000-000000000001'
      and status = 'withdrawn'
  $$,
  array[1::bigint],
  'Le renouvellement ne supprime pas le désistement passé'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '32000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$
    select withdrawn_applications
    from public.get_concert_volunteer_team_details(
      '42000000-0000-0000-0000-000000000001'
    )
    where user_id = '32000000-0000-0000-0000-000000000001'
  $$,
  array[1::bigint],
  'Le désistement passé reste visible dans les statistiques administrateur'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '32000000-0000-0000-0000-000000000001',
  true
);

select throws_ok(
  $$
    select public.reapply_to_concert(
      '42000000-0000-0000-0000-000000000001'
    )
  $$,
  '22023',
  'Cette disponibilité ne peut pas être renouvelée',
  'Une disponibilité active n’est pas réactivée silencieusement'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where concert_id = '42000000-0000-0000-0000-000000000001'
      and user_id = '32000000-0000-0000-0000-000000000001'
  $$,
  array[1::bigint],
  'Une seule disponibilité active existe par bénévole et concert'
);

select * from finish();

rollback;
