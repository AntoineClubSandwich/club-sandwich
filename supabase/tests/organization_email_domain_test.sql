begin;

create extension if not exists pgtap with schema extensions;

select plan(11);

select has_column(
  'public',
  'organizations',
  'email_domain',
  'L’organisation porte un domaine e-mail optionnel'
);

insert into public.organizations (id, name, slug, kind, email_domain)
values (
  'd5000000-0000-0000-0000-000000000001',
  'Domaine Tourneur A',
  'domaine-tourneur-a',
  'producer',
  'auguri-test.fr'
);

select throws_ok(
  $$
    insert into public.organizations (id, name, slug, kind, email_domain)
    values (
      'd5000000-0000-0000-0000-000000000002',
      'Domaine Tourneur B',
      'domaine-tourneur-b',
      'producer',
      'auguri-test.fr'
    )
  $$,
  '23505',
  null,
  'Deux organisations ne peuvent pas partager le même domaine e-mail'
);

select throws_ok(
  $$
    insert into public.organizations (id, name, slug, kind, email_domain)
    values (
      'd5000000-0000-0000-0000-000000000003',
      'Club Sandwich Bis',
      'club-sandwich-bis',
      'club_sandwich',
      'club-sandwich-test.fr'
    )
  $$,
  '23514',
  null,
  'Le domaine e-mail n’est autorisé que pour une organisation Tourneur'
);

select throws_ok(
  $$
    insert into public.organizations (id, name, slug, kind, email_domain)
    values (
      'd5000000-0000-0000-0000-000000000004',
      'Domaine Invalide',
      'domaine-invalide',
      'producer',
      'contact@invalide.fr'
    )
  $$,
  '23514',
  null,
  'Un domaine contenant une arobase est refusé'
);

select throws_ok(
  $$
    insert into public.organizations (id, name, slug, kind, email_domain)
    values (
      'd5000000-0000-0000-0000-000000000005',
      'Domaine Majuscules',
      'domaine-majuscules',
      'producer',
      'Auguri-Test.fr'
    )
  $$,
  '23514',
  null,
  'Un domaine non normalisé en minuscules est refusé'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    'd6000000-0000-0000-0000-000000000001',
    'nouvelle-recrue@auguri-test.fr',
    '{"first_name":"Nouvelle","last_name":"Recrue"}'::jsonb
  ),
  (
    'd6000000-0000-0000-0000-000000000002',
    'contact-existant@auguri-test.fr',
    '{"first_name":"Contact","last_name":"Existant"}'::jsonb
  ),
  (
    'd6000000-0000-0000-0000-000000000003',
    'benevole-invite@example.test',
    '{"first_name":"Bénévole","last_name":"Invité"}'::jsonb
  );

insert into public.user_accounts (
  profile_id,
  role,
  organization_id,
  status
)
values
  (
    'd6000000-0000-0000-0000-000000000001',
    'promoter',
    'd5000000-0000-0000-0000-000000000001',
    'invited'
  ),
  (
    'd6000000-0000-0000-0000-000000000002',
    'promoter',
    'd5000000-0000-0000-0000-000000000001',
    'invited'
  ),
  (
    'd6000000-0000-0000-0000-000000000003',
    'volunteer',
    null,
    'invited'
  );

-- Un contact existe déjà pour ce Tourneur, avec l’adresse de la deuxième
-- personne invitée : son activation ne doit pas en créer un doublon.
insert into public.organization_contacts (
  organization_id,
  first_name,
  last_name,
  email
)
values (
  'd5000000-0000-0000-0000-000000000001',
  'Contact',
  'Existant',
  'contact-existant@auguri-test.fr'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd6000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.activate_current_user('Nouvelle', 'Recrue', '0600000001')
  $$,
  'La nouvelle recrue active son compte'
);

select results_eq(
  $$
    select first_name, last_name, phone
    from public.organization_contacts
    where organization_id = 'd5000000-0000-0000-0000-000000000001'
      and email = 'nouvelle-recrue@auguri-test.fr'
  $$,
  $$ values ('Nouvelle'::text, 'Recrue'::text, '0600000001'::text) $$,
  'L’activation crée automatiquement la fiche contact manquante'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd6000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.activate_current_user('Contact', 'Existant', null)
  $$,
  'La personne déjà en fiche contact active aussi son compte'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.organization_contacts
    where organization_id = 'd5000000-0000-0000-0000-000000000001'
      and email = 'contact-existant@auguri-test.fr'
  $$,
  array[1::bigint],
  'Aucun doublon n’est créé quand la fiche contact existe déjà'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd6000000-0000-0000-0000-000000000003',
  true
);

select lives_ok(
  $$
    select public.activate_current_user('Bénévole', 'Invité', null)
  $$,
  'Un bénévole (sans organisation) active normalement son compte'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.organization_contacts
    where email = 'benevole-invite@example.test'
  $$,
  array[0::bigint],
  'Un bénévole n’a pas d’organisation : aucune fiche contact créée'
);

select * from finish();

rollback;
