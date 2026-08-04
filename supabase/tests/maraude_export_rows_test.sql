begin;

create extension if not exists pgtap with schema extensions;

select plan(10);

select has_function(
  'public',
  'get_maraude_export_rows',
  array['date', 'date', 'uuid'],
  'L’export multi-maraudes est disponible'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '41000000-0000-0000-0000-000000000001',
    'export-admin@example.test',
    '{"first_name":"Export","last_name":"Admin"}'::jsonb
  ),
  (
    '41000000-0000-0000-0000-000000000002',
    'export-promoter@example.test',
    '{"first_name":"Export","last_name":"Tourneur"}'::jsonb
  ),
  (
    '41000000-0000-0000-0000-000000000003',
    'export-other-promoter@example.test',
    '{"first_name":"Autre","last_name":"Tourneur"}'::jsonb
  ),
  (
    '41000000-0000-0000-0000-000000000004',
    'export-volunteer@example.test',
    '{"first_name":"Export","last_name":"Bénévole"}'::jsonb
  );

insert into public.organizations (id, name, slug, kind)
values
  (
    '42000000-0000-0000-0000-000000000001',
    'Tourneur export A',
    'tourneur-export-a',
    'producer'
  ),
  (
    '42000000-0000-0000-0000-000000000002',
    'Tourneur export B',
    'tourneur-export-b',
    'producer'
  );

insert into public.user_accounts (
  profile_id, role, organization_id, status, activated_at
)
values
  (
    '41000000-0000-0000-0000-000000000001',
    'admin', null, 'active', now()
  ),
  (
    '41000000-0000-0000-0000-000000000002',
    'promoter', '42000000-0000-0000-0000-000000000001', 'active', now()
  ),
  (
    '41000000-0000-0000-0000-000000000003',
    'promoter', '42000000-0000-0000-0000-000000000002', 'active', now()
  ),
  (
    '41000000-0000-0000-0000-000000000004',
    'volunteer', null, 'active', now()
  );

insert into public.venues (
  id, name, public_address_line1, postal_code, city
)
values (
  '47000000-0000-0000-0000-000000000001',
  'Salle export',
  '1 rue de l’export',
  '75001',
  'Paris'
);

insert into public.concerts (
  id, organization_id, promoter_organization_id, artist, concert_date,
  venue_id, created_by, maraude_status, actual_start_at, actual_end_at
)
select
  '48000000-0000-0000-0000-000000000001'::uuid,
  club.id,
  '42000000-0000-0000-0000-000000000001'::uuid,
  'Maraude A',
  '2026-02-10'::date,
  '47000000-0000-0000-0000-000000000001'::uuid,
  '41000000-0000-0000-0000-000000000001'::uuid,
  'in_progress'::public.maraude_status,
  '2026-02-10 19:00:00+01'::timestamptz,
  '2026-02-10 22:00:00+01'::timestamptz
from public.organizations club
where club.slug = 'club-sandwich';

insert into public.concerts (
  id, organization_id, promoter_organization_id, artist, concert_date,
  venue_id, created_by, maraude_status, actual_start_at, actual_end_at
)
select
  '48000000-0000-0000-0000-000000000002'::uuid,
  club.id,
  '42000000-0000-0000-0000-000000000002'::uuid,
  'Maraude B (autre tourneur)',
  '2026-02-11'::date,
  '47000000-0000-0000-0000-000000000001'::uuid,
  '41000000-0000-0000-0000-000000000001'::uuid,
  'completed'::public.maraude_status,
  '2026-02-11 19:00:00+01'::timestamptz,
  '2026-02-11 21:00:00+01'::timestamptz
from public.organizations club
where club.slug = 'club-sandwich';

insert into public.concerts (
  id, organization_id, promoter_organization_id, artist, concert_date,
  venue_id, created_by, maraude_status
)
select
  '48000000-0000-0000-0000-000000000003'::uuid,
  club.id,
  '42000000-0000-0000-0000-000000000001'::uuid,
  'Maraude C (hors période)',
  '2026-05-01'::date,
  '47000000-0000-0000-0000-000000000001'::uuid,
  '41000000-0000-0000-0000-000000000001'::uuid,
  'completed'::public.maraude_status
from public.organizations club
where club.slug = 'club-sandwich';

insert into public.maraude_operational_reports (
  concert_id, total_weight_kg, estimated_meals, distance_km
)
values (
  '48000000-0000-0000-0000-000000000001',
  42.5,
  30,
  12.3
);

insert into public.maraude_distributions (
  concert_id, distributed_meals, estimated_beneficiaries
)
values (
  '48000000-0000-0000-0000-000000000001',
  28,
  25
);

insert into public.maraude_collections (
  concert_id, category, quantity, unit
)
values
  (
    '48000000-0000-0000-0000-000000000001',
    'prepared_meals',
    30,
    'piece'
  ),
  (
    '48000000-0000-0000-0000-000000000001',
    'drinks',
    5,
    'kg'
  );

update public.concerts
set maraude_status = 'completed'::public.maraude_status
where id = '48000000-0000-0000-0000-000000000001';

insert into public.concert_volunteers (
  id, concert_id, user_id, status
)
values (
  '49000000-0000-0000-0000-000000000001',
  '48000000-0000-0000-0000-000000000001',
  '41000000-0000-0000-0000-000000000004',
  'selected'
);

update public.concert_volunteers
set
  confirmation_status = 'confirmed'::public.volunteer_confirmation_status,
  role_acknowledged_at = now()
where id = '49000000-0000-0000-0000-000000000001';

update public.concert_volunteers
set
  attendance_status = 'present'::public.volunteer_attendance_status,
  attendance_validated_at = now(),
  attendance_validated_by = '41000000-0000-0000-0000-000000000001'
where id = '49000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '41000000-0000-0000-0000-000000000001',
  true
);

select is(
  (
    select count(*)::bigint
    from public.get_maraude_export_rows(null, null, null)
  ),
  3::bigint,
  'L’administrateur voit toutes les maraudes terminées, toutes organisations'
);

select is(
  (
    select count(*)::bigint
    from public.get_maraude_export_rows('2026-02-01', '2026-02-28', null)
  ),
  2::bigint,
  'Le filtre de période restreint le jeu de données'
);

select is(
  (
    select count(*)::bigint
    from public.get_maraude_export_rows(
      null, null, '42000000-0000-0000-0000-000000000001'
    )
  ),
  2::bigint,
  'Le filtre d’organisation restreint aux maraudes du tourneur choisi'
);

select results_eq(
  $$
    select
      duration_hours,
      distance_km,
      total_weight_kg,
      estimated_meals,
      distributed_meals,
      estimated_beneficiaries,
      volunteer_count,
      volunteer_hours
    from public.get_maraude_export_rows(null, null, null)
    where concert_id = '48000000-0000-0000-0000-000000000001'
  $$,
  $$
    values (
      3.00::numeric,
      12.3::numeric,
      42.5::numeric,
      30,
      28,
      25,
      1::bigint,
      3.00::numeric
    )
  $$,
  'Les indicateurs calculés correspondent aux données saisies'
);

select is(
  (
    select collection_summary
    from public.get_maraude_export_rows(null, null, null)
    where concert_id = '48000000-0000-0000-0000-000000000001'
  ),
  'Plats préparés: 30 pièce(s); Boissons: 5 kg',
  'Le résumé des collectes agrège les quantités par catégorie'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '41000000-0000-0000-0000-000000000002',
  true
);

select is(
  (
    select count(*)::bigint
    from public.get_maraude_export_rows(null, null, null)
  ),
  2::bigint,
  'Un tourneur ne voit que ses propres maraudes, quel que soit le filtre'
);

select is(
  (
    select bool_and(
      organization_name = 'Tourneur export A'
    )
    from public.get_maraude_export_rows(null, null, null)
  ),
  true,
  'Toutes les lignes retournées appartiennent au tourneur appelant'
);

select is(
  (
    select count(*)::bigint
    from public.get_maraude_export_rows(
      null, null, '42000000-0000-0000-0000-000000000002'
    )
  ),
  0::bigint,
  'Un tourneur ne peut pas obtenir les maraudes d’une autre organisation via le filtre'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '41000000-0000-0000-0000-000000000004',
  true
);

select throws_ok(
  $$ select * from public.get_maraude_export_rows(null, null, null) $$,
  '42501',
  'Accès réservé aux administrateurs et tourneurs',
  'Un bénévole ne peut pas exporter les indicateurs'
);

select * from finish();

rollback;
