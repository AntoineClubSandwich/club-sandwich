-- Supprime exclusivement le jeu de données créé par seed_preprod_demo.sql.
-- À exécuter uniquement sur la préproduction.

begin;

alter table public.maraude_collections
  disable trigger maraude_collections_enforce_active_maraude;

delete from public.invitation_campaigns
where id in (
  'de400001-0000-4000-8000-000000000001'::uuid,
  'de400002-0000-4000-8000-000000000002'::uuid
);

delete from public.concerts
where id in (
  'de100001-0000-4000-8000-000000000001'::uuid,
  'de100002-0000-4000-8000-000000000002'::uuid,
  'de100003-0000-4000-8000-000000000003'::uuid,
  'de100004-0000-4000-8000-000000000004'::uuid,
  'de100005-0000-4000-8000-000000000005'::uuid,
  'de100006-0000-4000-8000-000000000006'::uuid,
  'de100007-0000-4000-8000-000000000007'::uuid,
  'de100008-0000-4000-8000-000000000008'::uuid
);

delete from public.consumable_movements
where consumable_id in (
  'de500001-0000-4000-8000-000000000001'::uuid,
  'de500002-0000-4000-8000-000000000002'::uuid,
  'de500003-0000-4000-8000-000000000003'::uuid,
  'de500004-0000-4000-8000-000000000004'::uuid,
  'de500005-0000-4000-8000-000000000005'::uuid
);

delete from public.consumables
where id in (
  'de500001-0000-4000-8000-000000000001'::uuid,
  'de500002-0000-4000-8000-000000000002'::uuid,
  'de500003-0000-4000-8000-000000000003'::uuid,
  'de500004-0000-4000-8000-000000000004'::uuid,
  'de500005-0000-4000-8000-000000000005'::uuid
);

delete from public.equipment_events
where equipment_id in (
  'de700001-0000-4000-8000-000000000001'::uuid,
  'de700002-0000-4000-8000-000000000002'::uuid,
  'de700003-0000-4000-8000-000000000003'::uuid,
  'de700004-0000-4000-8000-000000000004'::uuid,
  'de700005-0000-4000-8000-000000000005'::uuid
);

delete from public.equipment_assets
where id in (
  'de700001-0000-4000-8000-000000000001'::uuid,
  'de700002-0000-4000-8000-000000000002'::uuid,
  'de700003-0000-4000-8000-000000000003'::uuid,
  'de700004-0000-4000-8000-000000000004'::uuid,
  'de700005-0000-4000-8000-000000000005'::uuid
);

delete from public.equipment_locations
where id in (
  'de600001-0000-4000-8000-000000000001'::uuid,
  'de600002-0000-4000-8000-000000000002'::uuid,
  'de600003-0000-4000-8000-000000000003'::uuid
);

alter table public.maraude_collections
  enable trigger maraude_collections_enforce_active_maraude;

commit;
