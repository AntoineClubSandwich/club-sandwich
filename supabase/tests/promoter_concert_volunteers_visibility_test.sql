begin;

create extension if not exists pgtap with schema extensions;

select plan(3);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    'f5000000-0000-0000-0000-000000000001',
    'pv-promoter-a@example.test',
    '{"first_name":"Tourneur","last_name":"A"}'::jsonb
  ),
  (
    'f5000000-0000-0000-0000-000000000002',
    'pv-promoter-b@example.test',
    '{"first_name":"Tourneur","last_name":"B"}'::jsonb
  ),
  (
    'f5000000-0000-0000-0000-000000000003',
    'pv-volunteer@example.test',
    '{"first_name":"Membre","last_name":"PV"}'::jsonb
  );

insert into public.organizations (id, name, slug, kind)
values
  (
    'f6000000-0000-0000-0000-000000000001',
    'PV Tourneur A',
    'pv-tourneur-a',
    'producer'
  ),
  (
    'f6000000-0000-0000-0000-000000000002',
    'PV Tourneur B',
    'pv-tourneur-b',
    'producer'
  );

insert into public.user_accounts (
  profile_id, role, organization_id, status, activated_at
)
values
  (
    'f5000000-0000-0000-0000-000000000001',
    'promoter', 'f6000000-0000-0000-0000-000000000001', 'active', now()
  ),
  (
    'f5000000-0000-0000-0000-000000000002',
    'promoter', 'f6000000-0000-0000-0000-000000000002', 'active', now()
  );

insert into public.concerts (
  id, organization_id, promoter_organization_id, artist,
  concert_date, venue_id, created_by
)
select
  'f7000000-0000-0000-0000-000000000001'::uuid,
  club.id,
  'f6000000-0000-0000-0000-000000000001'::uuid,
  'Maraude tourneur A',
  current_date + 30,
  venue.id,
  'f5000000-0000-0000-0000-000000000001'::uuid
from public.organizations club
cross join lateral (
  select id from public.venues where is_active order by name limit 1
) venue
where club.slug = 'club-sandwich';

insert into public.concert_volunteers (
  id, concert_id, user_id, status, team_role
)
values (
  'f8000000-0000-0000-0000-000000000001',
  'f7000000-0000-0000-0000-000000000001',
  'f5000000-0000-0000-0000-000000000003',
  'selected',
  'logistics'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f5000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where concert_id = 'f7000000-0000-0000-0000-000000000001'
  $$,
  array[1::bigint],
  'Le tourneur de la maraude voit la candidature sélectionnée'
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
    from public.concert_volunteers
    where concert_id = 'f7000000-0000-0000-0000-000000000001'
  $$,
  array[0::bigint],
  'Un tourneur d’une autre organisation ne voit rien'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f5000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts concert
    left join public.concert_volunteers application
      on application.concert_id = concert.id
      and application.status = 'selected'
    where concert.id = 'f7000000-0000-0000-0000-000000000001'
  $$,
  array[1::bigint],
  'L’embed liste maraudes + bénévoles sélectionnés fonctionne pour le tourneur'
);

select * from finish();

rollback;
