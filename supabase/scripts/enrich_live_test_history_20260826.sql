-- Complète les 3 maraudes passées créées par seed_live_test_20260826.sql
-- avec un déroulé opérationnel complet et réaliste : matériel/consommables
-- sortis, collecte, distribution, bilan et rencontres GPS. Objectif :
-- que l'historique des 5 bénévoles ressemble à une vraie activité passée,
-- pas seulement à des crédits vides.

begin;

do $enrich$
declare
  admin_id uuid;
  alexis_id uuid;
  maceo_id uuid;
  ines_id uuid;
  barth_id uuid;
  hugo_id uuid;
  c1 uuid := 'df100003-0000-4000-8000-000000000003'; -- Petit Bain, -10j, Alexis pilote
  c2 uuid := 'df100004-0000-4000-8000-000000000004'; -- Alhambra, -20j, Ines pilote
  c3 uuid := 'df100005-0000-4000-8000-000000000005'; -- Trianon, -30j, Hugo pilote
begin
  select id into strict admin_id from auth.users where lower(email) = 'antoine@clubsandwich-records.com';
  select id into strict alexis_id from auth.users where lower(email) = 'alexisschipman@gmail.com';
  select id into strict maceo_id from auth.users where lower(email) = 'maceoteixeira@gmail.com';
  select id into strict ines_id from auth.users where lower(email) = 'ines.abdennebi@outlook.fr';
  select id into strict barth_id from auth.users where lower(email) = 'mbarthelemy99@gmail.com';
  select id into strict hugo_id from auth.users where lower(email) = 'hugoplommet99@gmail.com';

  alter table public.maraude_collections disable trigger maraude_collections_enforce_active_maraude;
  alter table public.maraude_distributions disable trigger maraude_distributions_enforce_active_maraude;

  -- Repasse propre si le script est rejoué.
  delete from public.encounters where maraude_id in (c1, c2, c3);
  delete from public.maraude_operational_reports where concert_id in (c1, c2, c3);
  delete from public.maraude_distributions where concert_id in (c1, c2, c3);
  delete from public.maraude_collections where concert_id in (c1, c2, c3);
  delete from public.maraude_equipment_allocations where concert_id in (c1, c2, c3);
  delete from public.maraude_consumable_allocations where concert_id in (c1, c2, c3);
  delete from public.maraude_operations where concert_id in (c1, c2, c3);

  insert into public.consumable_movements (id, consumable_id, previous_quantity, new_quantity, reason, note, actor_id)
  values
    (gen_random_uuid(), 'de500001-0000-4000-8000-000000000001', 0, 240, 'restock', 'Stock initial', admin_id),
    (gen_random_uuid(), 'de500002-0000-4000-8000-000000000002', 0, 35, 'restock', 'Stock initial', admin_id),
    (gen_random_uuid(), 'de500003-0000-4000-8000-000000000003', 0, 18, 'restock', 'Stock initial', admin_id),
    (gen_random_uuid(), 'de500005-0000-4000-8000-000000000005', 0, 48, 'restock', 'Stock initial', admin_id),
    (gen_random_uuid(), 'de500006-0000-4000-8000-000000000006', 0, 180, 'restock', 'Stock initial', admin_id);

  insert into public.maraude_operations (
    concert_id, current_step,
    preparation_completed_at, preparation_completed_by,
    collection_completed_at, collection_completed_by,
    distribution_completed_at, distribution_completed_by,
    equipment_return_completed_at, equipment_return_completed_by,
    summary_completed_at, summary_completed_by, last_modified_by
  ) values
    (c1, 'summary',
      ((current_date - 10) + time '19:45') at time zone 'Europe/Paris', alexis_id,
      ((current_date - 10) + time '20:30') at time zone 'Europe/Paris', alexis_id,
      ((current_date - 10) + time '22:00') at time zone 'Europe/Paris', alexis_id,
      ((current_date - 10) + time '22:15') at time zone 'Europe/Paris', alexis_id,
      ((current_date - 10) + time '22:25') at time zone 'Europe/Paris', admin_id, admin_id),
    (c2, 'summary',
      ((current_date - 20) + time '19:40') at time zone 'Europe/Paris', ines_id,
      ((current_date - 20) + time '20:25') at time zone 'Europe/Paris', ines_id,
      ((current_date - 20) + time '21:55') at time zone 'Europe/Paris', ines_id,
      ((current_date - 20) + time '22:10') at time zone 'Europe/Paris', ines_id,
      ((current_date - 20) + time '22:20') at time zone 'Europe/Paris', admin_id, admin_id),
    (c3, 'summary',
      ((current_date - 30) + time '19:50') at time zone 'Europe/Paris', hugo_id,
      ((current_date - 30) + time '20:35') at time zone 'Europe/Paris', hugo_id,
      ((current_date - 30) + time '22:05') at time zone 'Europe/Paris', hugo_id,
      ((current_date - 30) + time '22:20') at time zone 'Europe/Paris', hugo_id,
      ((current_date - 30) + time '22:30') at time zone 'Europe/Paris', admin_id, admin_id);

  insert into public.maraude_consumable_allocations (
    id, concert_id, consumable_id, planned_quantity, actual_quantity, validated_by, validated_at
  ) values
    (gen_random_uuid(), c1, 'de500001-0000-4000-8000-000000000001', 30, 28, alexis_id, ((current_date - 10) + time '19:45') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c1, 'de500002-0000-4000-8000-000000000002', 6, 6, alexis_id, ((current_date - 10) + time '19:45') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c1, 'de500005-0000-4000-8000-000000000005', 24, 22, alexis_id, ((current_date - 10) + time '19:45') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c2, 'de500006-0000-4000-8000-000000000006', 26, 26, ines_id, ((current_date - 20) + time '19:40') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c2, 'de500002-0000-4000-8000-000000000002', 6, 5, ines_id, ((current_date - 20) + time '19:40') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c2, 'de500003-0000-4000-8000-000000000003', 3, 3, ines_id, ((current_date - 20) + time '19:40') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c3, 'de500001-0000-4000-8000-000000000001', 34, 33, hugo_id, ((current_date - 30) + time '19:50') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c3, 'de500005-0000-4000-8000-000000000005', 30, 27, hugo_id, ((current_date - 30) + time '19:50') at time zone 'Europe/Paris');

  insert into public.maraude_equipment_allocations (
    id, concert_id, equipment_id, planned_quantity, taken_quantity,
    checkout_validated_by, checkout_validated_at,
    returned_quantity, return_validated_by, return_validated_at
  ) values
    (gen_random_uuid(), c1, 'de700001-0000-4000-8000-000000000001', 4, 4, alexis_id, ((current_date - 10) + time '19:45') at time zone 'Europe/Paris', 4, alexis_id, ((current_date - 10) + time '22:15') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c1, 'de700004-0000-4000-8000-000000000004', 5, 5, alexis_id, ((current_date - 10) + time '19:45') at time zone 'Europe/Paris', 5, alexis_id, ((current_date - 10) + time '22:15') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c2, 'de700002-0000-4000-8000-000000000002', 1, 1, ines_id, ((current_date - 20) + time '19:40') at time zone 'Europe/Paris', 1, ines_id, ((current_date - 20) + time '22:10') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c2, 'de700004-0000-4000-8000-000000000004', 5, 5, ines_id, ((current_date - 20) + time '19:40') at time zone 'Europe/Paris', 5, ines_id, ((current_date - 20) + time '22:10') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c3, 'de700001-0000-4000-8000-000000000001', 5, 5, hugo_id, ((current_date - 30) + time '19:50') at time zone 'Europe/Paris', 5, hugo_id, ((current_date - 30) + time '22:20') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c3, 'de700005-0000-4000-8000-000000000005', 1, 1, hugo_id, ((current_date - 30) + time '19:50') at time zone 'Europe/Paris', 1, hugo_id, ((current_date - 30) + time '22:20') at time zone 'Europe/Paris');

  insert into public.maraude_collections (
    id, concert_id, category, description, quantity, unit, weight_kg, average_weight_kg, comment
  ) values
    (gen_random_uuid(), c1, 'prepared_meals', 'Plats préparés', 28, 'piece', null, 0.40, null),
    (gen_random_uuid(), c1, 'bakery', 'Pains et viennoiseries', 2, 'crate', 6.0, null, null),
    (gen_random_uuid(), c2, 'prepared_meals', 'Plateaux repas', 26, 'piece', null, 0.43, null),
    (gen_random_uuid(), c2, 'fruits_vegetables', 'Fruits frais', 2, 'crate', 9.5, null, '[TEST] Récupérés en fin de marché.'),
    (gen_random_uuid(), c3, 'prepared_meals', 'Repas complets', 33, 'piece', null, 0.39, null),
    (gen_random_uuid(), c3, 'dairy', 'Produits laitiers', 1, 'box', 3.6, null, null);

  insert into public.maraude_distributions (
    id, concert_id, distribution_location, estimated_beneficiaries,
    distributed_meals, remaining_weight_kg,
    distribution_started_at, distribution_completed_at,
    incident_comment, collected_boxes, distributed_boxes, remaining_boxes,
    last_modified_by
  ) values
    (gen_random_uuid(), c1, 'Gare du Nord', 30, 28, 1.2,
      ((current_date - 10) + time '20:35') at time zone 'Europe/Paris',
      ((current_date - 10) + time '22:00') at time zone 'Europe/Paris',
      null, 6, 5, 1, alexis_id),
    (gen_random_uuid(), c2, 'Château d’Eau', 28, 26, 0.8,
      ((current_date - 20) + time '20:30') at time zone 'Europe/Paris',
      ((current_date - 20) + time '21:55') at time zone 'Europe/Paris',
      null, 5, 5, 0, ines_id),
    (gen_random_uuid(), c3, 'Boulevard Rochechouart', 35, 33, 1.5,
      ((current_date - 30) + time '20:40') at time zone 'Europe/Paris',
      ((current_date - 30) + time '22:05') at time zone 'Europe/Paris',
      '[TEST] Forte affluence en fin de distribution.', 7, 6, 1, hugo_id);

  insert into public.maraude_operational_reports (
    concert_id, total_weight_kg, estimated_meals, comment, last_modified_by,
    distance_km, quantities_unavailable
  ) values
    (c1, 11.2, 28, '[TEST] Maraude fluide, aucun incident.', admin_id, 5.4, false),
    (c2, 12.1, 26, '[TEST] Bonne collecte, météo clémente.', admin_id, 4.9, false),
    (c3, 13.4, 33, '[TEST] Forte affluence, équipe efficace.', admin_id, 6.1, false);

  insert into public.encounters (id, maraude_id, created_by, latitude, longitude, accuracy, created_at)
  values
    (gen_random_uuid(), c1, alexis_id, 48.8725, 2.3708, 16, ((current_date - 10) + time '20:45') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c1, maceo_id, 48.8709, 2.3691, 21, ((current_date - 10) + time '21:05') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c2, ines_id, 48.8716, 2.3534, 19, ((current_date - 20) + time '20:50') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c2, barth_id, 48.8701, 2.3549, 24, ((current_date - 20) + time '21:15') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c3, hugo_id, 48.8839, 2.3442, 18, ((current_date - 30) + time '20:55') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c3, maceo_id, 48.8822, 2.3417, 22, ((current_date - 30) + time '21:20') at time zone 'Europe/Paris');

  alter table public.maraude_distributions enable trigger maraude_distributions_enforce_active_maraude;
  alter table public.maraude_collections enable trigger maraude_collections_enforce_active_maraude;

  raise notice 'Historique enrichi pour les 3 maraudes créditées.';
end;
$enrich$;

commit;

select
  (select count(*) from public.maraude_operations where concert_id::text like 'df1000%') as operations,
  (select count(*) from public.maraude_collections mc join public.concerts c on c.id = mc.concert_id where c.artist like '[DÉMO]%') as collections,
  (select count(*) from public.maraude_distributions where concert_id::text like 'df1000%') as distributions,
  (select count(*) from public.encounters where maraude_id::text like 'df1000%') as rencontres;
