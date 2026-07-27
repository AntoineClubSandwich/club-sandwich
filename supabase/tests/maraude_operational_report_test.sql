begin;

create extension if not exists pgtap with schema extensions;

select plan(17);

select has_table(
  'public',
  'maraude_operational_reports',
  'Le compte rendu opérationnel est stocké en relation un-à-un'
);

select has_function(
  'public',
  'save_maraude_report',
  array['uuid', 'numeric', 'integer', 'text', 'text', 'boolean'],
  'La sauvegarde transactionnelle du compte rendu existe'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  ('33000000-0000-0000-0000-000000000001', 'report-admin@example.test', '{}'),
  ('33000000-0000-0000-0000-000000000002', 'report-leader@example.test', '{}'),
  ('33000000-0000-0000-0000-000000000003', 'report-com@example.test', '{}'),
  ('33000000-0000-0000-0000-000000000004', 'report-pending@example.test', '{}'),
  ('33000000-0000-0000-0000-000000000005', 'report-other@example.test', '{}');

insert into public.memberships (organization_id, profile_id, role)
select
  organization.id,
  member_data.profile_id,
  member_data.role::public.app_role
from public.organizations organization
cross join (
  values
    ('33000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('33000000-0000-0000-0000-000000000002'::uuid, 'volunteer'),
    ('33000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('33000000-0000-0000-0000-000000000004'::uuid, 'volunteer'),
    ('33000000-0000-0000-0000-000000000005'::uuid, 'volunteer')
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
  concert_data.id,
  organization.id,
  concert_data.artist,
  concert_data.concert_date,
  venue.id,
  '33000000-0000-0000-0000-000000000001'::uuid
from public.organizations organization
cross join lateral (
  select id from public.venues order by name limit 1
) venue
cross join (
  values
    (
      '43000000-0000-0000-0000-000000000001'::uuid,
      'Compte rendu principal',
      '2026-11-21'::date
    ),
    (
      '43000000-0000-0000-0000-000000000002'::uuid,
      'Autre maraude',
      '2026-11-22'::date
    )
) as concert_data(id, artist, concert_date)
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (
  id,
  concert_id,
  user_id,
  status,
  team_role
)
values
  (
    '53000000-0000-0000-0000-000000000001',
    '43000000-0000-0000-0000-000000000001',
    '33000000-0000-0000-0000-000000000002',
    'selected',
    'team_leader'
  ),
  (
    '53000000-0000-0000-0000-000000000002',
    '43000000-0000-0000-0000-000000000001',
    '33000000-0000-0000-0000-000000000003',
    'selected',
    'communication'
  ),
  (
    '53000000-0000-0000-0000-000000000003',
    '43000000-0000-0000-0000-000000000001',
    '33000000-0000-0000-0000-000000000004',
    'pending',
    null
  ),
  (
    '53000000-0000-0000-0000-000000000004',
    '43000000-0000-0000-0000-000000000002',
    '33000000-0000-0000-0000-000000000005',
    'selected',
    'team_leader'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '33000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.save_maraude_report(
      '43000000-0000-0000-0000-000000000001',
      0,
      0,
      'Aucune collecte',
      null,
      true
    )
  $$,
  'L’administrateur clôture avec un poids et zéro repas'
);

select results_eq(
  $$
    select total_weight_kg::text, estimated_meals, comment
    from public.maraude_operational_reports
    where concert_id = '43000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('0'::text, 0, 'Aucune collecte'::text) $$,
  'Les valeurs nulles métier sont conservées'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = '43000000-0000-0000-0000-000000000001'
      and maraude_status = 'completed'
      and actual_end_at >= actual_start_at
  $$,
  array[1::bigint],
  'Le compte rendu et la clôture sont atomiques'
);

select lives_ok(
  $$
    select public.save_maraude_report(
      '43000000-0000-0000-0000-000000000001',
      12.5,
      30,
      'Correction administrative',
      'https://example.test/photos',
      true
    )
  $$,
  'L’administrateur corrige un compte rendu clôturé'
);

select results_eq(
  $$
    select total_weight_kg::text, estimated_meals
    from public.maraude_operational_reports
    where concert_id = '43000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('12.5'::text, 30) $$,
  'La correction administrative est enregistrée'
);

select lives_ok(
  $$
    select public.set_maraude_status(
      '43000000-0000-0000-0000-000000000001',
      'in_progress',
      null
    )
  $$,
  'L’administrateur rouvre la maraude'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '33000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.save_maraude_report(
      '43000000-0000-0000-0000-000000000001',
      8.75,
      18,
      'Saisi sur le terrain',
      null,
      false
    )
  $$,
  'Un chef d’équipe sélectionné saisit le compte rendu'
);

select results_eq(
  $$
    select total_weight_kg::text, estimated_meals
    from public.maraude_operational_reports
    where concert_id = '43000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('8.75'::text, 18) $$,
  'La saisie du chef est enregistrée'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '33000000-0000-0000-0000-000000000004',
  true
);

select throws_ok(
  $$
    select public.save_maraude_report(
      '43000000-0000-0000-0000-000000000001',
      1,
      1,
      null,
      null,
      false
    )
  $$,
  '42501',
  'Vous ne pouvez pas modifier ce compte rendu',
  'Un bénévole non sélectionné est refusé'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '33000000-0000-0000-0000-000000000005',
  true
);

select throws_ok(
  $$
    select public.save_maraude_report(
      '43000000-0000-0000-0000-000000000001',
      1,
      1,
      null,
      null,
      false
    )
  $$,
  '42501',
  'Vous ne pouvez pas modifier ce compte rendu',
  'Le chef d’une autre maraude est refusé'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '33000000-0000-0000-0000-000000000003',
  true
);

select lives_ok(
  $$
    select public.update_maraude_photo_link(
      '43000000-0000-0000-0000-000000000001',
      'https://example.test/communication'
    )
  $$,
  'La personne chargée de communication enregistre le lien photo'
);

select results_eq(
  $$
    select photo_folder_url
    from public.maraude_operational_reports
    where concert_id = '43000000-0000-0000-0000-000000000001'
  $$,
  array['https://example.test/communication'::text],
  'Le lien photo est mis à jour sans modifier le reste'
);

select throws_ok(
  $$
    select public.save_maraude_report(
      '43000000-0000-0000-0000-000000000001',
      -1,
      0,
      null,
      null,
      false
    )
  $$,
  '22023',
  'Le poids doit être positif ou nul',
  'Un poids négatif est refusé'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '33000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.get_maraude_overview(100)
    where concert_id in (
      '43000000-0000-0000-0000-000000000001',
      '43000000-0000-0000-0000-000000000002'
    )
  $$,
  array[2::bigint],
  'L’aperçu précharge les maraudes en une requête'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_operational_reports
    where concert_id = '43000000-0000-0000-0000-000000000001'
  $$,
  array[1::bigint],
  'Le compte rendu reste unique par maraude'
);

select * from finish();

rollback;
