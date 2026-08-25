begin;

create extension if not exists pgtap with schema extensions;

select plan(36);

select has_table('public', 'consumables', 'La table des consommables existe');
select has_table('public', 'consumable_movements', 'L’historique de stock existe');
select has_table('public', 'equipment_assets', 'La table du parc matériel existe');
select has_table('public', 'equipment_events', 'L’historique du matériel existe');
select has_table('public', 'maraude_consumable_allocations', 'Les consommables sont affectables aux maraudes');
select has_table('public', 'maraude_equipment_allocations', 'Le matériel est affectable aux maraudes');
select has_table('public', 'maraude_operations', 'Le parcours guidé existe');
select has_table('public', 'maraude_step_events', 'L’historique des étapes existe');

select enum_has_labels(
  'public',
  'maraude_operational_step',
  array['preparation', 'collection', 'distribution', 'equipment_return', 'summary'],
  'Les cinq étapes sont strictement définies'
);
select enum_has_labels(
  'public',
  'equipment_status',
  array['available', 'assigned', 'in_use', 'needs_check', 'needs_cleaning', 'damaged', 'lost', 'out_of_service'],
  'Les états du parc sont strictement définis'
);
select has_function('public', 'validate_maraude_preparation', array['uuid', 'jsonb', 'jsonb'], 'La validation de préparation est transactionnelle');
select has_function('public', 'validate_maraude_step', array['uuid', 'maraude_operational_step'], 'La progression est transactionnelle');
select has_function('public', 'complete_guided_maraude', array['uuid'], 'La clôture guidée est transactionnelle');

insert into auth.users (id, email, raw_user_meta_data)
values
  ('b0000000-0000-0000-0000-000000000001', 'resources-admin@example.test', '{"first_name":"Admin","last_name":"Stock"}'::jsonb),
  ('b0000000-0000-0000-0000-000000000002', 'resources-leader@example.test', '{"first_name":"Lea","last_name":"Leader"}'::jsonb),
  ('b0000000-0000-0000-0000-000000000003', 'resources-member@example.test', '{"first_name":"Marc","last_name":"Membre"}'::jsonb),
  ('b0000000-0000-0000-0000-000000000004', 'resources-member2@example.test', '{"first_name":"Nina","last_name":"Membre"}'::jsonb),
  ('b0000000-0000-0000-0000-000000000005', 'resources-outsider@example.test', '{"first_name":"Olive","last_name":"Externe"}'::jsonb);

insert into public.memberships (organization_id, profile_id, role)
select organization.id, user_data.profile_id, user_data.role::public.app_role
from public.organizations organization
cross join (
  values
    ('b0000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('b0000000-0000-0000-0000-000000000002'::uuid, 'volunteer'),
    ('b0000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('b0000000-0000-0000-0000-000000000004'::uuid, 'volunteer'),
    ('b0000000-0000-0000-0000-000000000005'::uuid, 'volunteer')
) as user_data(profile_id, role)
where organization.slug = 'club-sandwich';

insert into public.concerts (
  id, organization_id, artist, concert_date, venue_id, created_by
)
select
  'b1000000-0000-0000-0000-000000000001'::uuid,
  organization.id,
  'Workflow ressources',
  '2026-12-20'::date,
  venue.id,
  'b0000000-0000-0000-0000-000000000001'::uuid
from public.organizations organization
cross join lateral (select id from public.venues order by name limit 1) venue
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (concert_id, user_id, status, team_role)
values
  ('b1000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'selected', 'team_leader'),
  ('b1000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003', 'selected', 'logistics'),
  ('b1000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000004', 'selected', 'communication');

update public.concert_volunteers
set
  role_acknowledged_at = clock_timestamp(),
  confirmation_status = 'confirmed',
  attendance_status = 'present'
where concert_id = 'b1000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-000000000001', true);

select lives_ok(
  $$ select public.create_consumable('Gants test', 'Hygiène', 'box', 10, 2, 'Local') $$,
  'Un admin crée un consommable avec son stock initial'
);

insert into public.equipment_locations (id, name)
values ('b2000000-0000-0000-0000-000000000001', 'Local test');
insert into public.equipment_assets (
  id, name, category, quantity_total, location_id
)
values (
  'b3000000-0000-0000-0000-000000000001',
  'Balance test',
  'Pesée',
  1,
  'b2000000-0000-0000-0000-000000000001'
);

select lives_ok(
  format(
    $$ select public.plan_maraude_resources(
      'b1000000-0000-0000-0000-000000000001',
      '[{"consumable_id":"%s","planned_quantity":2}]'::jsonb,
      '[{"equipment_id":"b3000000-0000-0000-0000-000000000001","planned_quantity":1}]'::jsonb
    ) $$,
    (select id from public.consumables where name = 'Gants test')
  ),
  'Un admin planifie toutes les ressources en une transaction'
);

select results_eq(
  $$ select status::text from public.equipment_assets where id = 'b3000000-0000-0000-0000-000000000001' $$,
  array['assigned'::text],
  'Le matériel planifié passe à Affecté'
);
select results_eq(
  $$ select count(*)::integer from public.consumable_movements where consumable_id = (select id from public.consumables where name = 'Gants test') $$,
  array[1],
  'Le stock initial est historisé'
);

select lives_ok(
  $$ select public.set_maraude_status('b1000000-0000-0000-0000-000000000001', 'in_progress', null) $$,
  'L’admin démarre la maraude'
);
select results_eq(
  $$ select current_step::text from public.maraude_operations where concert_id = 'b1000000-0000-0000-0000-000000000001' $$,
  array['preparation'::text],
  'Le parcours débute à la préparation'
);

select set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-000000000003', true);
select results_eq(
  $$ select count(*)::integer from public.maraude_operations where concert_id = 'b1000000-0000-0000-0000-000000000001' $$,
  array[1],
  'Un membre affecté voit le parcours'
);
select lives_ok(
  format(
    $$ select public.validate_maraude_preparation(
      'b1000000-0000-0000-0000-000000000001',
      '[{"allocation_id":"%s","actual_quantity":2}]'::jsonb,
      '[{"allocation_id":"%s","taken_quantity":1}]'::jsonb
    ) $$,
    (select id from public.maraude_consumable_allocations where concert_id = 'b1000000-0000-0000-0000-000000000001'),
    (select id from public.maraude_equipment_allocations where concert_id = 'b1000000-0000-0000-0000-000000000001')
  ),
  'Un membre confirmé valide la préparation'
);
select set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-000000000001', true);
select results_eq(
  $$ select current_quantity::integer from public.consumables where name = 'Gants test' $$,
  array[8],
  'La sortie de consommables décrémente le stock'
);
select results_eq(
  $$ select count(*)::integer from public.consumable_movements where reason = 'maraude' $$,
  array[1],
  'La sortie liée à la maraude est historisée'
);
select results_eq(
  $$ select status::text from public.equipment_assets where id = 'b3000000-0000-0000-0000-000000000001' $$,
  array['in_use'::text],
  'Le matériel emporté passe En utilisation'
);
select set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-000000000003', true);

select lives_ok(
  $$ select public.save_maraude_collection_v2('b1000000-0000-0000-0000-000000000001', null, 'Curry', 8, 6.2, null) $$,
  'Un membre ajoute une ligne de collecte en boîtes'
);
select lives_ok(
  $$ select public.validate_maraude_step('b1000000-0000-0000-0000-000000000001', 'collection') $$,
  'La collecte complète est validée'
);
select lives_ok(
  $$ select public.save_maraude_distribution_v2('b1000000-0000-0000-0000-000000000001', 8, 7, 1, 6, null) $$,
  'Un membre enregistre la distribution'
);
select lives_ok(
  $$ select public.validate_maraude_step('b1000000-0000-0000-0000-000000000001', 'distribution') $$,
  'La distribution complète est validée'
);
select lives_ok(
  format(
    $$ select public.record_maraude_equipment_return(
      'b1000000-0000-0000-0000-000000000001',
      '[{"allocation_id":"%s","returned_quantity":1}]'::jsonb
    ) $$,
    (select id from public.maraude_equipment_allocations where concert_id = 'b1000000-0000-0000-0000-000000000001')
  ),
  'Un membre confirme le retour du matériel'
);
select lives_ok(
  $$ select public.validate_maraude_step('b1000000-0000-0000-0000-000000000001', 'equipment_return') $$,
  'Le retour complet est validé'
);
select set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-000000000001', true);
select results_eq(
  $$ select status::text from public.equipment_assets where id = 'b3000000-0000-0000-0000-000000000001' $$,
  array['available'::text],
  'Le matériel sans incident redevient Disponible'
);

select set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$ select public.complete_guided_maraude('b1000000-0000-0000-0000-000000000001') $$,
  'Le Chef d’équipe clôture le parcours'
);
select results_eq(
  $$ select maraude_status::text from public.concerts where id = 'b1000000-0000-0000-0000-000000000001' $$,
  array['completed'::text],
  'La maraude est terminée'
);
select results_eq(
  $$ select total_weight_kg from public.maraude_operational_reports where concert_id = 'b1000000-0000-0000-0000-000000000001' $$,
  array[6.2::numeric],
  'Le poids alimente le bilan existant sans seconde saisie'
);

select set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-000000000005', true);
select results_eq(
  $$ select count(*)::integer from public.maraude_operations where concert_id = 'b1000000-0000-0000-0000-000000000001' $$,
  array[0],
  'Un bénévole extérieur ne voit pas le parcours'
);
select throws_ok(
  $$ select public.get_maraude_operation_bundle('b1000000-0000-0000-0000-000000000001') $$,
  '42501',
  'Maraude inaccessible',
  'Un bénévole extérieur ne contourne pas la RLS via la RPC'
);

select * from finish();
rollback;
