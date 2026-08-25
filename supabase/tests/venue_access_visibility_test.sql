begin;

create extension if not exists pgtap with schema extensions;

select plan(4);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '91000000-0000-0000-0000-000000000001',
    'venue-promoter@example.test',
    '{"first_name":"Tourneur","last_name":"Salle"}'
  ),
  (
    '91000000-0000-0000-0000-000000000002',
    'venue-volunteer@example.test',
    '{"first_name":"Bénévole","last_name":"Salle"}'
  ),
  (
    '91000000-0000-0000-0000-000000000003',
    'venue-invited-promoter@example.test',
    '{"first_name":"Tourneur","last_name":"Invité"}'
  );

insert into public.organizations (id, name, slug, kind)
values (
  '92000000-0000-0000-0000-000000000001',
  'Tourneur accès salle',
  'tourneur-acces-salle',
  'producer'
);

insert into public.user_accounts (
  profile_id,
  role,
  organization_id,
  status,
  activated_at
)
values
  (
    '91000000-0000-0000-0000-000000000001',
    'promoter',
    '92000000-0000-0000-0000-000000000001',
    'active',
    now()
  ),
  (
    '91000000-0000-0000-0000-000000000002',
    'volunteer',
    null,
    'active',
    now()
  ),
  (
    '91000000-0000-0000-0000-000000000003',
    'promoter',
    '92000000-0000-0000-0000-000000000001',
    'invited',
    null
  );

insert into public.venues (
  id,
  name,
  public_address_line1,
  postal_code,
  city,
  is_active
)
values
  (
    '93000000-0000-0000-0000-000000000001',
    'Salle active accès artistes',
    '1 rue Publique',
    '75001',
    'Paris',
    true
  ),
  (
    '93000000-0000-0000-0000-000000000002',
    'Salle inactive accès artistes',
    '2 rue Publique',
    '75002',
    'Paris',
    false
  );

insert into public.venue_access_details (
  venue_id,
  artist_entrance_address_line1,
  artist_entrance_city,
  access_instructions
)
values
  (
    '93000000-0000-0000-0000-000000000001',
    '10 passage des Artistes',
    'Paris',
    'Interphone artistes'
  ),
  (
    '93000000-0000-0000-0000-000000000002',
    '20 passage des Artistes',
    'Paris',
    'Accès historique'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$
    select artist_entrance_address_line1
    from public.venue_access_details
    order by artist_entrance_address_line1
  $$,
  $$ values ('10 passage des Artistes'::text) $$,
  'Un tourneur actif lit l’entrée artistes d’une salle active avant toute maraude'
);

select is(
  (
    select count(*)
    from public.venue_access_details
    where venue_id = '93000000-0000-0000-0000-000000000002'
  ),
  0::bigint,
  'Un tourneur sans maraude liée ne lit pas les accès d’une salle inactive'
);

select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000002',
  true
);

select is(
  (select count(*) from public.venue_access_details),
  0::bigint,
  'Un bénévole non affecté ne lit aucun accès artistes'
);

select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000003',
  true
);

select is(
  (select count(*) from public.venue_access_details),
  0::bigint,
  'Un compte tourneur non activé ne lit aucun accès artistes'
);

select * from finish();

rollback;
