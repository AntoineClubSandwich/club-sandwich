begin;

create extension if not exists pgtap with schema extensions;

select plan(21);

select has_column(
  'public',
  'concerts',
  'maraude_status',
  'Le concert porte l’état opérationnel de la maraude'
);

select has_column(
  'public',
  'concerts',
  'actual_start_at',
  'Le concert porte l’heure réelle de début'
);

select has_column(
  'public',
  'concerts',
  'actual_end_at',
  'Le concert porte l’heure réelle de fin'
);

select col_type_is(
  'public',
  'concerts',
  'maraude_status',
  'public.maraude_status',
  'Le cycle de vie utilise l’enum maraude_status'
);

insert into auth.users (
  id,
  email,
  raw_user_meta_data
)
values
  (
    '90000000-0000-0000-0000-000000000001',
    'lifecycle-volunteer@example.test',
    '{"first_name":"Julie","last_name":"Martin"}'::jsonb
  ),
  (
    '90000000-0000-0000-0000-000000000002',
    'lifecycle-admin@example.test',
    '{"first_name":"Admin","last_name":"Maraude"}'::jsonb
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
      '90000000-0000-0000-0000-000000000001'::uuid,
      'volunteer'
    ),
    (
      '90000000-0000-0000-0000-000000000002'::uuid,
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
  concert_data.id,
  o.id,
  concert_data.artist,
  concert_data.concert_date,
  v.id,
  '90000000-0000-0000-0000-000000000002'::uuid
from public.organizations o
cross join lateral (
  select id
  from public.venues
  order by name
  limit 1
) v
cross join (
  values
    (
      '91000000-0000-0000-0000-000000000001'::uuid,
      'Maraude sans présence',
      '2026-12-10'::date
    ),
    (
      '91000000-0000-0000-0000-000000000002'::uuid,
      'Maraude prête',
      '2026-12-11'::date
    )
) as concert_data(id, artist, concert_date)
where o.slug = 'club-sandwich';

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id in (
      '91000000-0000-0000-0000-000000000001',
      '91000000-0000-0000-0000-000000000002'
    )
      and maraude_status = 'planned'
      and actual_start_at is null
      and actual_end_at is null
  $$,
  array[2::bigint],
  'Toute nouvelle maraude est créée en préparation'
);

insert into public.concert_volunteers (
  id,
  concert_id,
  user_id,
  status,
  attendance_status
)
values (
  '92000000-0000-0000-0000-000000000001',
  '91000000-0000-0000-0000-000000000002',
  '90000000-0000-0000-0000-000000000001',
  'selected',
  'present'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

select throws_ok(
  $$
    select public.start_maraude(
      '91000000-0000-0000-0000-000000000002'
    )
  $$,
  '42501',
  'Seul un administrateur peut démarrer une maraude',
  'Un bénévole ne peut pas démarrer une maraude'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002',
  true
);

select throws_ok(
  $$
    select public.complete_maraude(
      '91000000-0000-0000-0000-000000000001'
    )
  $$,
  '22023',
  'Seule une maraude en cours peut être terminée',
  'Une maraude en préparation ne peut pas être terminée'
);

select throws_ok(
  $$
    select public.start_maraude(
      '91000000-0000-0000-0000-000000000001'
    )
  $$,
  '22023',
  'Au moins un bénévole sélectionné doit être présent',
  'Le démarrage est refusé sans bénévole sélectionné présent'
);

select lives_ok(
  $$
    select public.start_maraude(
      '91000000-0000-0000-0000-000000000002'
    )
  $$,
  'Une maraude prête peut démarrer'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = '91000000-0000-0000-0000-000000000002'
      and maraude_status = 'started'
      and actual_start_at is not null
      and actual_end_at is null
  $$,
  array[1::bigint],
  'Le démarrage enregistre une date réelle cohérente'
);

select throws_ok(
  $$
    select public.start_maraude(
      '91000000-0000-0000-0000-000000000002'
    )
  $$,
  '22023',
  'La maraude n’est pas en préparation',
  'Une maraude en cours ne peut pas être redémarrée'
);

select lives_ok(
  $$
    select public.complete_maraude(
      '91000000-0000-0000-0000-000000000002'
    )
  $$,
  'Une maraude en cours peut être terminée'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = '91000000-0000-0000-0000-000000000002'
      and maraude_status = 'completed'
      and actual_start_at is not null
      and actual_end_at is not null
      and actual_end_at >= actual_start_at
  $$,
  array[1::bigint],
  'La fin enregistre des dates réelles chronologiques'
);

select throws_ok(
  $$
    select public.complete_maraude(
      '91000000-0000-0000-0000-000000000002'
    )
  $$,
  '22023',
  'Seule une maraude en cours peut être terminée',
  'Une maraude terminée ne peut pas être terminée une seconde fois'
);

reset role;

select throws_ok(
  $$
    update public.concerts
    set
      maraude_status = 'started',
      actual_end_at = null
    where id = '91000000-0000-0000-0000-000000000002'
  $$,
  '22023',
  'Transition de maraude interdite : completed vers started',
  'Une maraude terminée ne peut pas revenir en cours'
);

select throws_ok(
  $$
    update public.concerts
    set
      maraude_status = 'planned',
      actual_start_at = null,
      actual_end_at = null
    where id = '91000000-0000-0000-0000-000000000002'
  $$,
  '22023',
  'Transition de maraude interdite : completed vers planned',
  'Une maraude terminée ne peut pas revenir en préparation'
);

select throws_ok(
  $$
    update public.concerts
    set actual_start_at = clock_timestamp()
    where id = '91000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'new row for relation "concerts" violates check constraint "concerts_maraude_dates_match_status"',
  'Une maraude en préparation ne peut avoir de date réelle de début'
);

insert into public.concert_volunteers (
  id,
  concert_id,
  user_id,
  status,
  attendance_status
)
values (
  '92000000-0000-0000-0000-000000000002',
  '91000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000001',
  'selected',
  'present'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.start_maraude(
      '91000000-0000-0000-0000-000000000001'
    )
  $$,
  'La seconde maraude démarre après enregistrement d’une présence'
);

reset role;

select throws_ok(
  $$
    update public.concerts
    set
      maraude_status = 'planned',
      actual_start_at = null
    where id = '91000000-0000-0000-0000-000000000001'
  $$,
  '22023',
  'Transition de maraude interdite : started vers planned',
  'Une maraude en cours ne peut pas revenir en préparation'
);

select throws_ok(
  $$
    update public.concerts
    set
      maraude_status = 'completed',
      actual_end_at = actual_start_at - interval '1 minute'
    where id = '91000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'new row for relation "concerts" violates check constraint "concerts_maraude_dates_chronological"',
  'La fin réelle ne peut pas précéder le début réel'
);

select throws_ok(
  $$
    insert into public.concerts (
      organization_id,
      artist,
      concert_date,
      venue_id,
      created_by,
      maraude_status,
      actual_start_at
    )
    select
      o.id,
      'Création invalide',
      '2026-12-12'::date,
      v.id,
      '90000000-0000-0000-0000-000000000002'::uuid,
      'started'::public.maraude_status,
      clock_timestamp()
    from public.organizations o
    cross join lateral (
      select id
      from public.venues
      order by name
      limit 1
    ) v
    where o.slug = 'club-sandwich'
  $$,
  '22023',
  'Une maraude doit être créée en préparation',
  'Une maraude ne peut pas être créée dans un état avancé'
);

select * from finish();

rollback;
