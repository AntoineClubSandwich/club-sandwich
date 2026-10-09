begin;

create extension if not exists pgtap with schema extensions;

select plan(26);

select has_function(
  'public',
  'save_maraude_distribution_v5',
  array['uuid', 'jsonb', 'integer', 'text'],
  'La distribution enregistre les boîtes remises au stock'
);
select has_column(
  'public',
  'maraude_consumable_allocations',
  'returned_to_stock_quantity',
  'Ce qui a été remis en stock est mémorisé par référence'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  ('c0000000-0000-0000-0000-000000000001', 'return-admin@example.test', '{"first_name":"Admin","last_name":"Retour"}'::jsonb),
  ('c0000000-0000-0000-0000-000000000002', 'return-member@example.test', '{"first_name":"Marc","last_name":"Membre"}'::jsonb),
  ('c0000000-0000-0000-0000-000000000003', 'return-outsider@example.test', '{"first_name":"Olive","last_name":"Externe"}'::jsonb),
  ('c0000000-0000-0000-0000-000000000004', 'return-leader@example.test', '{"first_name":"Lea","last_name":"Leader"}'::jsonb),
  ('c0000000-0000-0000-0000-000000000005', 'return-member2@example.test', '{"first_name":"Nina","last_name":"Membre"}'::jsonb);

insert into public.memberships (organization_id, profile_id, role)
select organization.id, user_data.profile_id, user_data.role::public.app_role
from public.organizations organization
cross join (
  values
    ('c0000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('c0000000-0000-0000-0000-000000000002'::uuid, 'volunteer'),
    ('c0000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('c0000000-0000-0000-0000-000000000004'::uuid, 'volunteer'),
    ('c0000000-0000-0000-0000-000000000005'::uuid, 'volunteer')
) as user_data(profile_id, role)
where organization.slug = 'club-sandwich';

insert into public.concerts (
  id, organization_id, artist, concert_date, venue_id, created_by,
  maraude_status
)
select
  'c1000000-0000-0000-0000-000000000001'::uuid,
  organization.id,
  'Retour en stock',
  '2026-12-21'::date,
  venue.id,
  'c0000000-0000-0000-0000-000000000001'::uuid,
  'open'::public.maraude_status
from public.organizations organization
cross join lateral (select id from public.venues order by name limit 1) venue
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (concert_id, user_id, status, team_role)
values
  ('c1000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000004', 'selected', 'team_leader'),
  ('c1000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'selected', 'logistics'),
  ('c1000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000005', 'selected', 'communication');

update public.concert_volunteers
set
  role_acknowledged_at = clock_timestamp(),
  confirmation_status = 'confirmed',
  attendance_status = 'present'
where concert_id = 'c1000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-000000000001', true);

select lives_ok(
  $$ select public.create_consumable('Boîtes A retour', 'Conditionnement', 'box', 10, 2, 'Local') $$,
  'Un admin crée une première référence de boîtes (stock 10)'
);
select lives_ok(
  $$ select public.create_consumable('Boîtes B retour', 'Conditionnement', 'box', 12, 2, 'Local') $$,
  'Un admin crée une seconde référence de boîtes (stock 12)'
);
select lives_ok(
  format(
    $$ select public.plan_maraude_resources(
      'c1000000-0000-0000-0000-000000000001',
      '[{"consumable_id":"%s","planned_quantity":4},{"consumable_id":"%s","planned_quantity":5}]'::jsonb,
      '[]'::jsonb
    ) $$,
    (select id from public.consumables where name = 'Boîtes A retour'),
    (select id from public.consumables where name = 'Boîtes B retour')
  ),
  'Un admin planifie les deux références'
);
select lives_ok(
  $$ select public.set_maraude_status('c1000000-0000-0000-0000-000000000001', 'in_progress', null) $$,
  'L’admin démarre la maraude'
);

select set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-000000000002', true);
select lives_ok(
  format(
    $$ select public.validate_maraude_preparation(
      'c1000000-0000-0000-0000-000000000001',
      '[{"allocation_id":"%s","actual_quantity":4},{"allocation_id":"%s","actual_quantity":5}]'::jsonb,
      '[]'::jsonb
    ) $$,
    (select allocation.id from public.maraude_consumable_allocations allocation where allocation.concert_id = 'c1000000-0000-0000-0000-000000000001' and allocation.planned_quantity = 4),
    (select allocation.id from public.maraude_consumable_allocations allocation where allocation.concert_id = 'c1000000-0000-0000-0000-000000000001' and allocation.planned_quantity = 5)
  ),
  'Un membre valide la préparation (sortie du stock vers les sacs)'
);
select set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-000000000001', true);
select results_eq(
  $$ select current_quantity::integer from public.consumables where name = 'Boîtes A retour' $$,
  array[6],
  'La préparation débite le stock de la référence A'
);
select results_eq(
  $$ select current_quantity::integer from public.consumables where name = 'Boîtes B retour' $$,
  array[7],
  'La préparation débite le stock de la référence B'
);

select set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$ select public.save_maraude_collection_v2('c1000000-0000-0000-0000-000000000001', null, 'Curry', 8, 6.2, null) $$,
  'Un membre ajoute une ligne de collecte'
);
select lives_ok(
  $$ select public.validate_maraude_step('c1000000-0000-0000-0000-000000000001', 'collection') $$,
  'La collecte est validée'
);

select lives_ok(
  format(
    $$ select public.save_maraude_distribution_v5(
      'c1000000-0000-0000-0000-000000000001',
      '[{"allocation_id":"%s","returned_quantity":1},{"allocation_id":"%s","returned_quantity":3}]'::jsonb,
      6,
      null
    ) $$,
    (select allocation.id from public.maraude_consumable_allocations allocation where allocation.concert_id = 'c1000000-0000-0000-0000-000000000001' and allocation.planned_quantity = 4),
    (select allocation.id from public.maraude_consumable_allocations allocation where allocation.concert_id = 'c1000000-0000-0000-0000-000000000001' and allocation.planned_quantity = 5)
  ),
  'Un membre enregistre les boîtes remises au stock'
);
select set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-000000000001', true);
select results_eq(
  $$ select current_quantity::integer from public.consumables where name = 'Boîtes A retour' $$,
  array[7],
  'La référence A récupère la boîte remise en stock'
);
select results_eq(
  $$ select current_quantity::integer from public.consumables where name = 'Boîtes B retour' $$,
  array[10],
  'La référence B récupère les 3 boîtes remises en stock'
);
select results_eq(
  $$ select distributed_boxes from public.maraude_distributions where concert_id = 'c1000000-0000-0000-0000-000000000001' $$,
  array[5],
  'Les boîtes distribuées se déduisent (emportées - remises au stock)'
);
select results_eq(
  $$ select remaining_boxes from public.maraude_distributions where concert_id = 'c1000000-0000-0000-0000-000000000001' $$,
  array[4],
  'Les boîtes restantes correspondent aux boîtes remises au stock'
);
select results_eq(
  $$ select count(*)::integer from public.consumable_movements where note like 'Boîtes remises en stock%' $$,
  array[2],
  'Chaque remise en stock est historisée'
);

select set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-000000000002', true);
select lives_ok(
  format(
    $$ select public.save_maraude_distribution_v5(
      'c1000000-0000-0000-0000-000000000001',
      '[{"allocation_id":"%s","returned_quantity":2},{"allocation_id":"%s","returned_quantity":3}]'::jsonb,
      6,
      null
    ) $$,
    (select allocation.id from public.maraude_consumable_allocations allocation where allocation.concert_id = 'c1000000-0000-0000-0000-000000000001' and allocation.planned_quantity = 4),
    (select allocation.id from public.maraude_consumable_allocations allocation where allocation.concert_id = 'c1000000-0000-0000-0000-000000000001' and allocation.planned_quantity = 5)
  ),
  'Une correction ne change que la référence modifiée'
);
select set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-000000000001', true);
select results_eq(
  $$ select current_quantity::integer from public.consumables where name = 'Boîtes A retour' $$,
  array[8],
  'La correction n’ajoute que la différence à la référence A'
);
select results_eq(
  $$ select current_quantity::integer from public.consumables where name = 'Boîtes B retour' $$,
  array[10],
  'Une référence inchangée ne rebouge pas le stock'
);
select results_eq(
  $$ select count(*)::integer from public.consumable_movements where note like 'Correction de la remise en stock%' $$,
  array[0],
  'Une correction à la hausse n’est pas historisée comme une reprise de stock'
);

select set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-000000000002', true);
select throws_ok(
  format(
    $$ select public.save_maraude_distribution_v5(
      'c1000000-0000-0000-0000-000000000001',
      '[{"allocation_id":"%s","returned_quantity":5},{"allocation_id":"%s","returned_quantity":3}]'::jsonb,
      6,
      null
    ) $$,
    (select allocation.id from public.maraude_consumable_allocations allocation where allocation.concert_id = 'c1000000-0000-0000-0000-000000000001' and allocation.planned_quantity = 4),
    (select allocation.id from public.maraude_consumable_allocations allocation where allocation.concert_id = 'c1000000-0000-0000-0000-000000000001' and allocation.planned_quantity = 5)
  ),
  '22023',
  'Quantité remise en stock invalide pour une référence de boîtes',
  'On ne peut pas remettre plus de boîtes que celles emportées'
);
select lives_ok(
  format(
    $$ select public.save_maraude_distribution_v5(
      'c1000000-0000-0000-0000-000000000001',
      '[{"allocation_id":"%s","returned_quantity":2},{"allocation_id":"%s","returned_quantity":3}]'::jsonb,
      6,
      null
    ) $$,
    (select allocation.id from public.maraude_consumable_allocations allocation where allocation.concert_id = 'c1000000-0000-0000-0000-000000000001' and allocation.planned_quantity = 4),
    (select allocation.id from public.maraude_consumable_allocations allocation where allocation.concert_id = 'c1000000-0000-0000-0000-000000000001' and allocation.planned_quantity = 5)
  ),
  'Réenregistrer les mêmes valeurs est possible'
);
select set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-000000000001', true);
select results_eq(
  $$ select current_quantity::integer from public.consumables where name = 'Boîtes A retour' $$,
  array[8],
  'Réenregistrer les mêmes valeurs ne recrédite jamais le stock'
);

select set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$ select public.validate_maraude_step('c1000000-0000-0000-0000-000000000001', 'distribution') $$,
  'La distribution est validée'
);

select set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-000000000003', true);
select throws_ok(
  format(
    $$ select public.save_maraude_distribution_v5(
      'c1000000-0000-0000-0000-000000000001',
      '[{"allocation_id":"%s","returned_quantity":0},{"allocation_id":"%s","returned_quantity":0}]'::jsonb,
      6,
      null
    ) $$,
    (select allocation.id from public.maraude_consumable_allocations allocation where allocation.concert_id = 'c1000000-0000-0000-0000-000000000001' and allocation.planned_quantity = 4),
    (select allocation.id from public.maraude_consumable_allocations allocation where allocation.concert_id = 'c1000000-0000-0000-0000-000000000001' and allocation.planned_quantity = 5)
  ),
  '42501',
  'Vous ne pouvez pas modifier cette distribution',
  'Un bénévole hors équipe ne touche pas au stock'
);

select * from finish();
rollback;
