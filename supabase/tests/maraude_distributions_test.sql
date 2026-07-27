begin;

create extension if not exists pgtap with schema extensions;

select plan(23);

select has_table(
  'public',
  'maraude_distributions',
  'La table de distribution existe'
);

insert into auth.users (
  id,
  email,
  raw_user_meta_data
)
values
  (
    'b0000000-0000-0000-0000-000000000001',
    'distribution-present@example.test',
    '{"first_name":"Julie","last_name":"Martin"}'::jsonb
  ),
  (
    'b0000000-0000-0000-0000-000000000002',
    'distribution-outsider@example.test',
    '{"first_name":"Alex","last_name":"Durand"}'::jsonb
  ),
  (
    'b0000000-0000-0000-0000-000000000003',
    'distribution-admin@example.test',
    '{"first_name":"Admin","last_name":"Distribution"}'::jsonb
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
      'b0000000-0000-0000-0000-000000000001'::uuid,
      'volunteer'
    ),
    (
      'b0000000-0000-0000-0000-000000000002'::uuid,
      'volunteer'
    ),
    (
      'b0000000-0000-0000-0000-000000000003'::uuid,
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
  'b1000000-0000-0000-0000-000000000001'::uuid,
  o.id,
  'Artiste distribution',
  '2026-12-16'::date,
  v.id,
  'b0000000-0000-0000-0000-000000000003'::uuid
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
values (
  'b1000000-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000001',
  'selected',
  'present'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b0000000-0000-0000-0000-000000000003',
  true
);

select lives_ok(
  $$
    select public.start_maraude(
      'b1000000-0000-0000-0000-000000000001'
    )
  $$,
  'L’administrateur démarre la maraude avant la distribution'
);

select lives_ok(
  $$
    insert into public.maraude_distributions (
      id,
      concert_id,
      distribution_location,
      estimated_beneficiaries,
      distributed_meals,
      remaining_weight_kg,
      distribution_started_at,
      distribution_completed_at,
      incident_comment
    )
    values (
      'b2000000-0000-0000-0000-000000000001',
      'b1000000-0000-0000-0000-000000000001',
      'Place de la République',
      42,
      35,
      7.5,
      '2026-12-16 22:00:00+01',
      '2026-12-16 23:00:00+01',
      'RAS'
    )
  $$,
  'Un administrateur crée la distribution pendant la maraude'
);

select results_eq(
  $$
    select
      distribution_location,
      estimated_beneficiaries,
      distributed_meals,
      remaining_weight_kg::text
    from public.maraude_distributions
    where id = 'b2000000-0000-0000-0000-000000000001'
  $$,
  $$
    values ('Place de la République', 42, 35, '7.5')
  $$,
  'La fiche conserve les informations saisies'
);

select throws_ok(
  $$
    insert into public.maraude_distributions (
      concert_id,
      distributed_meals
    )
    values (
      'b1000000-0000-0000-0000-000000000001',
      10
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "maraude_distributions_concert_id_key"',
  'Une seule distribution est autorisée par maraude'
);

select lives_ok(
  $$
    update public.maraude_distributions
    set
      estimated_beneficiaries = 45,
      distributed_meals = 40
    where id = 'b2000000-0000-0000-0000-000000000001'
  $$,
  'Un administrateur modifie la distribution pendant la maraude'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_distributions
    where id = 'b2000000-0000-0000-0000-000000000001'
      and estimated_beneficiaries = 45
      and distributed_meals = 40
  $$,
  array[1::bigint],
  'La modification de la distribution est enregistrée'
);

select throws_ok(
  $$
    update public.maraude_distributions
    set estimated_beneficiaries = -1
    where id = 'b2000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'new row for relation "maraude_distributions" violates check constraint "maraude_distributions_estimated_beneficiaries_check"',
  'Un nombre négatif de bénéficiaires est refusé'
);

select throws_ok(
  $$
    update public.maraude_distributions
    set distributed_meals = -1
    where id = 'b2000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'new row for relation "maraude_distributions" violates check constraint "maraude_distributions_distributed_meals_check"',
  'Un nombre négatif de repas est refusé'
);

select throws_ok(
  $$
    update public.maraude_distributions
    set remaining_weight_kg = -0.1
    where id = 'b2000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'new row for relation "maraude_distributions" violates check constraint "maraude_distributions_remaining_weight_kg_check"',
  'Un poids restant négatif est refusé'
);

select throws_ok(
  $$
    update public.maraude_distributions
    set
      distribution_started_at = '2026-12-16 23:30:00+01',
      distribution_completed_at = '2026-12-16 23:00:00+01'
    where id = 'b2000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'new row for relation "maraude_distributions" violates check constraint "maraude_distributions_check"',
  'La fin de distribution ne peut pas précéder le début'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b0000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_distributions
  $$,
  array[1::bigint],
  'Un bénévole présent peut lire la distribution'
);

select throws_ok(
  $$
    insert into public.maraude_distributions (
      concert_id,
      distributed_meals
    )
    values (
      'b1000000-0000-0000-0000-000000000001',
      10
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "maraude_distributions"',
  'Un bénévole présent ne peut pas créer de distribution'
);

select lives_ok(
  $$
    update public.maraude_distributions
    set distributed_meals = 99
    where id = 'b2000000-0000-0000-0000-000000000001'
  $$,
  'La modification bénévole est filtrée par la RLS'
);

select results_eq(
  $$
    select distributed_meals::text
    from public.maraude_distributions
    where id = 'b2000000-0000-0000-0000-000000000001'
  $$,
  array['40'::text],
  'Le bénévole n’a pas modifié la distribution'
);

select throws_ok(
  $$
    delete from public.maraude_distributions
    where id = 'b2000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  'permission denied for table maraude_distributions',
  'Aucun bénévole ne peut supprimer la distribution'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b0000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_distributions
  $$,
  array[0::bigint],
  'Un bénévole extérieur à l’équipe ne voit pas la distribution'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b0000000-0000-0000-0000-000000000003',
  true
);

select lives_ok(
  $$
    select public.complete_maraude(
      'b1000000-0000-0000-0000-000000000001'
    )
  $$,
  'L’administrateur termine la maraude'
);

select throws_ok(
  $$
    insert into public.maraude_distributions (
      concert_id,
      distributed_meals
    )
    select
      id,
      1
    from public.concerts
    where id = 'b1000000-0000-0000-0000-000000000001'
  $$,
  '22023',
  'La distribution est modifiable uniquement pendant la maraude',
  'La création est refusée après la clôture'
);

select lives_ok(
  $$
    update public.maraude_distributions
    set distributed_meals = 41
    where id = 'b2000000-0000-0000-0000-000000000001'
  $$,
  'La RLS filtre la modification administrateur après la clôture'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_distributions
    where id = 'b2000000-0000-0000-0000-000000000001'
      and distributed_meals = 40
  $$,
  array[1::bigint],
  'La distribution clôturée reste lisible et inchangée'
);

select throws_ok(
  $$
    delete from public.maraude_distributions
    where id = 'b2000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  'permission denied for table maraude_distributions',
  'L’administrateur ne peut pas supprimer une distribution'
);

reset role;

select throws_ok(
  $$
    update public.maraude_distributions
    set distributed_meals = 41
    where id = 'b2000000-0000-0000-0000-000000000001'
  $$,
  '22023',
  'La distribution est modifiable uniquement pendant la maraude',
  'Le trigger interdit toute modification après la clôture'
);

select * from finish();

rollback;
