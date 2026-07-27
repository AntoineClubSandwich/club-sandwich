begin;

create extension if not exists pgtap with schema extensions;

select plan(18);

select has_column(
  'public',
  'concert_volunteers',
  'attendance_status',
  'La relation concert-bénévole porte la présence'
);

select col_type_is(
  'public',
  'concert_volunteers',
  'attendance_status',
  'public.volunteer_attendance_status',
  'La présence utilise l’enum volunteer_attendance_status'
);

select results_eq(
  $$
    select count(*)::bigint
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'concert_volunteers'
      and column_name = 'attendance_status'
      and is_nullable = 'YES'
      and column_default is null
  $$,
  array[1::bigint],
  'La présence reste nullable et sans valeur par défaut pour les anciennes lignes'
);

insert into auth.users (
  id,
  email,
  raw_user_meta_data
)
values
  (
    '60000000-0000-0000-0000-000000000001',
    'attendance-volunteer-one@example.test',
    '{"first_name":"Julie","last_name":"Martin"}'::jsonb
  ),
  (
    '60000000-0000-0000-0000-000000000002',
    'attendance-volunteer-two@example.test',
    '{"first_name":"Paul","last_name":"Durand"}'::jsonb
  ),
  (
    '60000000-0000-0000-0000-000000000003',
    'attendance-volunteer-three@example.test',
    '{"first_name":"Camille","last_name":"Bernard"}'::jsonb
  ),
  (
    '60000000-0000-0000-0000-000000000004',
    'attendance-admin@example.test',
    '{"first_name":"Admin","last_name":"Présences"}'::jsonb
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
      '60000000-0000-0000-0000-000000000001'::uuid,
      'volunteer'
    ),
    (
      '60000000-0000-0000-0000-000000000002'::uuid,
      'volunteer'
    ),
    (
      '60000000-0000-0000-0000-000000000003'::uuid,
      'volunteer'
    ),
    (
      '60000000-0000-0000-0000-000000000004'::uuid,
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
  '70000000-0000-0000-0000-000000000001'::uuid,
  o.id,
  'Artiste présences',
  '2026-11-12'::date,
  v.id,
  '60000000-0000-0000-0000-000000000004'::uuid
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
    '80000000-0000-0000-0000-000000000001',
    '70000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000001',
    'pending'
  ),
  (
    '80000000-0000-0000-0000-000000000002',
    '70000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000002',
    'selected'
  ),
  (
    '80000000-0000-0000-0000-000000000003',
    '70000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000003',
    'pending'
  );

select results_eq(
  $$
    select attendance_status::text
    from public.concert_volunteers
    where id = '80000000-0000-0000-0000-000000000002'
  $$,
  array['pending'::text],
  'Une nouvelle sélection commence avec une présence en attente'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '60000000-0000-0000-0000-000000000004',
  true
);

select lives_ok(
  $$
    select public.select_concert_volunteers(
      '70000000-0000-0000-0000-000000000001',
      array['80000000-0000-0000-0000-000000000001'::uuid]
    )
  $$,
  'La sélection groupée initialise la présence'
);

select results_eq(
  $$
    select attendance_status::text
    from public.concert_volunteers
    where id = '80000000-0000-0000-0000-000000000001'
  $$,
  array['pending'::text],
  'La présence issue de la sélection groupée est en attente'
);

select lives_ok(
  $$
    update public.concert_volunteers
    set attendance_status = 'present'
    where id = '80000000-0000-0000-0000-000000000001'
  $$,
  'Un administrateur marque un bénévole présent'
);

select results_eq(
  $$
    select attendance_status::text
    from public.concert_volunteers
    where id = '80000000-0000-0000-0000-000000000001'
  $$,
  array['present'::text],
  'La présence enregistrée vaut present'
);

select lives_ok(
  $$
    update public.concert_volunteers
    set attendance_status = 'absent'
    where id = '80000000-0000-0000-0000-000000000002'
  $$,
  'Un administrateur marque un bénévole absent'
);

select results_eq(
  $$
    select attendance_status::text
    from public.concert_volunteers
    where id = '80000000-0000-0000-0000-000000000002'
  $$,
  array['absent'::text],
  'La présence enregistrée vaut absent'
);

select throws_ok(
  $$
    update public.concert_volunteers
    set attendance_status = 'present'
    where id = '80000000-0000-0000-0000-000000000003'
  $$,
  '23514',
  'new row for relation "concert_volunteers" violates check constraint "concert_volunteers_attendance_requires_selection"',
  'Un bénévole non sélectionné ne peut recevoir aucune présence'
);

select lives_ok(
  $$
    update public.concert_volunteers
    set status = 'not_selected'
    where id = '80000000-0000-0000-0000-000000000001'
  $$,
  'Un administrateur peut désélectionner un bénévole présent'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where id = '80000000-0000-0000-0000-000000000001'
      and status = 'not_selected'
      and attendance_status is null
  $$,
  array[1::bigint],
  'La désélection retire automatiquement la présence'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '60000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$
    select attendance_status::text
    from public.concert_volunteers
  $$,
  array['absent'::text],
  'Un bénévole sélectionné voit uniquement sa propre présence'
);

select throws_ok(
  $$
    update public.concert_volunteers
    set attendance_status = 'present'
    where id = '80000000-0000-0000-0000-000000000002'
  $$,
  '42501',
  'new row violates row-level security policy for table "concert_volunteers"',
  'Un bénévole ne peut pas modifier sa présence'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '60000000-0000-0000-0000-000000000004',
  true
);

select lives_ok(
  $$
    update public.concert_volunteers
    set attendance_status = null
    where id = '80000000-0000-0000-0000-000000000002'
  $$,
  'Une sélection peut conserver une présence NULL pour la rétrocompatibilité'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.get_concert_volunteer_team_details(
      '70000000-0000-0000-0000-000000000001'
    )
    where id = '80000000-0000-0000-0000-000000000002'
      and attendance_status is null
  $$,
  array[1::bigint],
  'La lecture groupée précharge la présence nullable'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where concert_id = '70000000-0000-0000-0000-000000000001'
      and status = 'selected'
      and coalesce(attendance_status, 'pending') = 'pending'
  $$,
  array[1::bigint],
  'Les anciennes présences NULL sont comptées comme en attente'
);

select * from finish();

rollback;
