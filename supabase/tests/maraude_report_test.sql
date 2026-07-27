begin;

create extension if not exists pgtap with schema extensions;

select plan(15);

select has_column(
  'public',
  'concerts',
  'closing_comment',
  'Le commentaire de fin est porté par le concert'
);

insert into auth.users (
  id,
  email,
  raw_user_meta_data
)
values
  (
    'c0000000-0000-0000-0000-000000000001',
    'report-present@example.test',
    '{"first_name":"Julie","last_name":"Martin"}'::jsonb
  ),
  (
    'c0000000-0000-0000-0000-000000000002',
    'report-absent@example.test',
    '{"first_name":"Alex","last_name":"Durand"}'::jsonb
  ),
  (
    'c0000000-0000-0000-0000-000000000003',
    'report-outsider@example.test',
    '{"first_name":"Sam","last_name":"Bernard"}'::jsonb
  ),
  (
    'c0000000-0000-0000-0000-000000000004',
    'report-admin@example.test',
    '{"first_name":"Admin","last_name":"Bilan"}'::jsonb
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
      'c0000000-0000-0000-0000-000000000001'::uuid,
      'volunteer'
    ),
    (
      'c0000000-0000-0000-0000-000000000002'::uuid,
      'volunteer'
    ),
    (
      'c0000000-0000-0000-0000-000000000003'::uuid,
      'volunteer'
    ),
    (
      'c0000000-0000-0000-0000-000000000004'::uuid,
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
  'c1000000-0000-0000-0000-000000000001'::uuid,
  o.id,
  'Artiste bilan',
  '2026-12-17'::date,
  v.id,
  'c0000000-0000-0000-0000-000000000004'::uuid
from public.organizations o
cross join lateral (
  select id
  from public.venues
  order by name
  limit 1
) v
where o.slug = 'club-sandwich';

insert into public.concert_volunteers (
  concert_id,
  user_id,
  status,
  attendance_status
)
values
  (
    'c1000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    'selected',
    'present'
  ),
  (
    'c1000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000002',
    'selected',
    'absent'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c0000000-0000-0000-0000-000000000003',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = 'c1000000-0000-0000-0000-000000000001'
  $$,
  array[1::bigint],
  'Un membre voit le concert tant que la maraude est en préparation'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c0000000-0000-0000-0000-000000000004',
  true
);

select throws_ok(
  $$
    update public.concerts
    set closing_comment = 'Trop tôt'
    where id = 'c1000000-0000-0000-0000-000000000001'
  $$,
  '22023',
  'Le commentaire de fin est modifiable uniquement après la clôture',
  'Le commentaire est refusé avant la clôture'
);

select lives_ok(
  $$
    select public.start_maraude(
      'c1000000-0000-0000-0000-000000000001'
    )
  $$,
  'L’administrateur démarre la maraude'
);

select lives_ok(
  $$
    select public.complete_maraude(
      'c1000000-0000-0000-0000-000000000001'
    )
  $$,
  'L’administrateur termine la maraude'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = 'c1000000-0000-0000-0000-000000000001'
      and maraude_status = 'completed'
  $$,
  array[1::bigint],
  'L’administrateur consulte le bilan terminé'
);

select lives_ok(
  $$
    update public.concerts
    set closing_comment = '  Belle maraude.  '
    where id = 'c1000000-0000-0000-0000-000000000001'
  $$,
  'L’administrateur enregistre le commentaire de fin'
);

select results_eq(
  $$
    select closing_comment
    from public.concerts
    where id = 'c1000000-0000-0000-0000-000000000001'
  $$,
  array['Belle maraude.'::text],
  'Le commentaire de fin est normalisé'
);

select results_eq(
  $$
    select
      selected_count,
      present_count,
      absent_count
    from public.get_concert_volunteer_counts(
      'c1000000-0000-0000-0000-000000000001'
    )
  $$,
  $$
    values (2::bigint, 1::bigint, 1::bigint)
  $$,
  'Les compteurs du bilan sont calculés depuis les candidatures'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c0000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$
    select closing_comment
    from public.concerts
    where id = 'c1000000-0000-0000-0000-000000000001'
  $$,
  array['Belle maraude.'::text],
  'Le bénévole présent consulte le bilan'
);

select throws_ok(
  $$
    update public.concerts
    set closing_comment = 'Modification bénévole'
    where id = 'c1000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  'Seul un administrateur peut modifier le commentaire de fin',
  'Le bénévole présent ne peut pas modifier le commentaire'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c0000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = 'c1000000-0000-0000-0000-000000000001'
  $$,
  array[0::bigint],
  'Un bénévole absent ne consulte pas le bilan'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c0000000-0000-0000-0000-000000000003',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = 'c1000000-0000-0000-0000-000000000001'
  $$,
  array[0::bigint],
  'Un bénévole extérieur à l’équipe ne consulte pas le bilan'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c0000000-0000-0000-0000-000000000004',
  true
);

select lives_ok(
  $$
    update public.concerts
    set closing_comment = '   '
    where id = 'c1000000-0000-0000-0000-000000000001'
  $$,
  'L’administrateur peut effacer le commentaire'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = 'c1000000-0000-0000-0000-000000000001'
      and closing_comment is null
  $$,
  array[1::bigint],
  'Un commentaire vide est enregistré comme NULL'
);

select * from finish();

rollback;
