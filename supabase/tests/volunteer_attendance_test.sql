begin;

create extension if not exists pgtap with schema extensions;

select plan(20);

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
  ),
  (
    '60000000-0000-0000-0000-000000000005',
    'attendance-leader@example.test',
    '{"first_name":"Lou","last_name":"Chef"}'::jsonb
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
    ),
    (
      '60000000-0000-0000-0000-000000000005'::uuid,
      'volunteer'
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
    'selected'
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

update public.concert_volunteers
set team_role = 'collection_distribution'
where status = 'selected';

update public.concert_volunteers
set
  role_acknowledged_at = clock_timestamp(),
  confirmation_status = 'confirmed'
where status = 'selected';

insert into public.concert_volunteers (
  concert_id,
  user_id,
  status,
  team_role
)
values (
  '70000000-0000-0000-0000-000000000001',
  '60000000-0000-0000-0000-000000000005',
  'selected',
  'team_leader'
);

update public.concert_volunteers
set
  role_acknowledged_at = clock_timestamp(),
  confirmation_status = 'confirmed'
where concert_id = '70000000-0000-0000-0000-000000000001'
  and user_id = '60000000-0000-0000-0000-000000000005';

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
    select public.start_maraude(
      '70000000-0000-0000-0000-000000000001'
    )
  $$,
  'L’administrateur démarre la maraude avant de saisir les présences'
);

select lives_ok(
  $$
    select public.complete_maraude(
      '70000000-0000-0000-0000-000000000001'
    )
  $$,
  'L’administrateur termine la maraude avant de saisir les présences'
);

select lives_ok(
  $$
    select public.set_volunteer_attendance(
      '80000000-0000-0000-0000-000000000001',
      'present'::public.volunteer_attendance_status
    )
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
    select public.set_volunteer_attendance(
      '80000000-0000-0000-0000-000000000002',
      'absent'::public.volunteer_attendance_status
    )
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
    select public.set_volunteer_attendance(
      '80000000-0000-0000-0000-000000000003',
      'present'::public.volunteer_attendance_status
    )
  $$,
  '22023',
  'La présence exige une participation confirmée',
  'Un bénévole non sélectionné ne peut recevoir aucune présence'
);

select throws_ok(
  $$
    update public.concert_volunteers
    set status = 'not_selected'
    where id = '80000000-0000-0000-0000-000000000001'
  $$,
  '55000',
  'La composition de l’équipe est verrouillée après le démarrage',
  'Un bénévole présent ne peut plus être désélectionné après la clôture'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where id = '80000000-0000-0000-0000-000000000001'
      and status = 'selected'
      and attendance_status = 'present'
  $$,
  array[1::bigint],
  'La présence reste inchangée après la tentative bloquée'
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
    select public.set_volunteer_attendance(
      '80000000-0000-0000-0000-000000000002',
      'present'::public.volunteer_attendance_status
    )
  $$,
  '42501',
  'Validation administrateur requise',
  'Un bénévole ne peut pas modifier sa présence'
);

reset role;

select lives_ok(
  $$
    update public.concert_volunteers
    set attendance_status = null
    where id = '80000000-0000-0000-0000-000000000002'
  $$,
  'Une sélection peut conserver une présence NULL pour la rétrocompatibilité'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '60000000-0000-0000-0000-000000000004',
  true
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
  array[2::bigint],
  'Les anciennes présences NULL sont comptées comme en attente'
);

select * from finish();

rollback;
