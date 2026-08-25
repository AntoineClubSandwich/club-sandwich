begin;

create extension if not exists pgtap with schema extensions;

select plan(19);

select has_table(
  'public',
  'encounters',
  'Les rencontres géolocalisées ont une table dédiée'
);
select has_column(
  'public',
  'encounters',
  'maraude_id',
  'Une rencontre appartient à une maraude'
);
select has_column(
  'public',
  'encounters',
  'accuracy',
  'La précision GPS est conservée'
);
select has_function(
  'public',
  'record_maraude_encounter',
  array['uuid', 'double precision', 'double precision', 'double precision'],
  'L’enregistrement terrain utilise une RPC dédiée'
);
select has_function(
  'public',
  'get_admin_encounter_map',
  array['timestamp with time zone', 'timestamp with time zone', 'uuid', 'uuid', 'uuid'],
  'La carte Admin est alimentée par une RPC groupée'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '94000000-0000-0000-0000-000000000001',
    'encounter-admin@example.test',
    '{"first_name":"Admin","last_name":"Carte"}'
  ),
  (
    '94000000-0000-0000-0000-000000000002',
    'encounter-member@example.test',
    '{"first_name":"Hugo","last_name":"Terrain"}'
  ),
  (
    '94000000-0000-0000-0000-000000000003',
    'encounter-outsider@example.test',
    '{"first_name":"Externe","last_name":"Terrain"}'
  );

insert into public.memberships (organization_id, profile_id, role)
select
  organization.id,
  account.profile_id,
  account.role::public.app_role
from public.organizations organization
cross join (
  values
    ('94000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('94000000-0000-0000-0000-000000000002'::uuid, 'volunteer'),
    ('94000000-0000-0000-0000-000000000003'::uuid, 'volunteer')
) account(profile_id, role)
where organization.slug = 'club-sandwich';

insert into public.venues (
  id,
  name,
  public_address_line1,
  postal_code,
  city
)
values (
  '95000000-0000-0000-0000-000000000001',
  'Salle carte rencontres',
  '1 rue de la Distribution',
  '75001',
  'Paris'
);

insert into public.concerts (
  id,
  organization_id,
  artist,
  concert_date,
  venue_id,
  maraude_status,
  actual_start_at,
  created_by
)
select
  '96000000-0000-0000-0000-000000000001',
  organization.id,
  'Rencontres test',
  current_date,
  '95000000-0000-0000-0000-000000000001',
  'in_progress',
  clock_timestamp(),
  '94000000-0000-0000-0000-000000000001'
from public.organizations organization
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (
  concert_id,
  user_id,
  status,
  team_role,
  confirmation_status,
  attendance_status
)
values (
  '96000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000002',
  'selected',
  'collection_distribution',
  'confirmed',
  'present'
);

insert into public.maraude_operations (concert_id, current_step)
values (
  '96000000-0000-0000-0000-000000000001',
  'distribution'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '94000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.record_maraude_encounter(
      '96000000-0000-0000-0000-000000000001',
      48.856614,
      2.3522219,
      18.456
    )
  $$,
  'Un bénévole affecté enregistre une rencontre pendant la distribution'
);

select results_eq(
  $$
    select latitude, longitude, accuracy
    from public.encounters
    where maraude_id = '96000000-0000-0000-0000-000000000001'
  $$,
  $$ values (48.856614::double precision, 2.3522219::double precision, 18.46::numeric) $$,
  'La base conserve les coordonnées GPS sans arrondi volontaire'
);

select results_eq(
  $$
    select created_by
    from public.encounters
    where maraude_id = '96000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('94000000-0000-0000-0000-000000000002'::uuid) $$,
  'L’auteur authentifié est enregistré automatiquement'
);

select results_eq(
  $$
    select (public.get_maraude_operation_bundle(
      '96000000-0000-0000-0000-000000000001'
    ) ->> 'encounter_count')::integer
  $$,
  array[1],
  'Le bundle opérationnel précharge le compteur de rencontres'
);

select throws_ok(
  $$
    select public.record_maraude_encounter(
      '96000000-0000-0000-0000-000000000001',
      48.8566,
      2.3522,
      30
    )
  $$,
  '22023',
  'Précision GPS insuffisante',
  'Une position trop imprécise est refusée'
);

select set_config(
  'request.jwt.claim.sub',
  '94000000-0000-0000-0000-000000000003',
  true
);

select is(
  (select count(*) from public.encounters),
  0::bigint,
  'Un bénévole extérieur ne consulte pas les rencontres'
);

select throws_ok(
  $$
    select public.record_maraude_encounter(
      '96000000-0000-0000-0000-000000000001',
      48.8566,
      2.3522,
      20
    )
  $$,
  '42501',
  null,
  'Un bénévole extérieur ne peut pas enregistrer de rencontre'
);

select set_config(
  'request.jwt.claim.sub',
  '94000000-0000-0000-0000-000000000001',
  true
);

select is(
  (
    select count(*)
    from public.encounters
    where maraude_id = '96000000-0000-0000-0000-000000000001'
  ),
  1::bigint,
  'Un administrateur consulte la rencontre créée par le scénario'
);

select results_eq(
  $$
    select artist, venue_name, created_by_name, cardinality(team_names)
    from public.get_admin_encounter_map(
      clock_timestamp() - interval '1 day',
      clock_timestamp() + interval '1 day',
      '96000000-0000-0000-0000-000000000001'
    )
  $$,
  $$ values ('Rencontres test'::text, 'Salle carte rencontres'::text, 'Hugo Terrain'::text, 1) $$,
  'La carte Admin précharge la maraude, la salle, l’auteur et l’équipe'
);

select set_config(
  'request.jwt.claim.sub',
  '94000000-0000-0000-0000-000000000002',
  true
);

select throws_ok(
  $$
    select *
    from public.get_admin_encounter_map(
      clock_timestamp() - interval '1 day',
      clock_timestamp() + interval '1 day'
    )
  $$,
  '42501',
  'Carte des rencontres inaccessible',
  'Un bénévole ne peut pas appeler la carte globale'
);

reset role;
update public.maraude_operations
set current_step = 'equipment_return'
where concert_id = '96000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '94000000-0000-0000-0000-000000000002',
  true
);

select throws_ok(
  $$
    select public.record_maraude_encounter(
      '96000000-0000-0000-0000-000000000001',
      48.8566,
      2.3522,
      20
    )
  $$,
  '42501',
  null,
  'Une rencontre ne peut plus être créée après la distribution'
);

select results_eq(
  $$
    select count(*)::integer
    from public.encounters
    where maraude_id = '96000000-0000-0000-0000-000000000001'
  $$,
  array[1],
  'Le refus ne crée aucune rencontre supplémentaire'
);

select col_type_is(
  'public',
  'encounters',
  'latitude',
  'double precision',
  'La latitude conserve toute la précision transmise'
);

select col_type_is(
  'public',
  'encounters',
  'longitude',
  'double precision',
  'La longitude conserve toute la précision transmise'
);

select * from finish();

rollback;
