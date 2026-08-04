begin;

create extension if not exists pgtap with schema extensions;

select plan(11);

select has_table(
  'public',
  'organization_conventions',
  'Les conventions de partenariat sont stockées dans une table dédiée'
);

select has_function(
  'public',
  'submit_my_organization_convention',
  array['uuid', 'text'],
  'Le tourneur peut déposer sa convention signée'
);

select has_function(
  'public',
  'admin_set_organization_convention',
  array['uuid', 'text'],
  'L’administrateur peut déposer la convention contresignée'
);

select has_function(
  'public',
  'review_organization_convention',
  array['uuid', 'volunteer_document_status', 'text'],
  'L’administrateur peut refuser une convention déposée'
);

insert into public.organizations (id, name, slug, kind, email_domain)
values
  (
    '53000000-0000-0000-0000-000000000001',
    'Tourneur Convention',
    'tourneur-convention',
    'producer',
    'tourneur-convention-test.fr'
  ),
  (
    '53000000-0000-0000-0000-000000000005',
    'Tourneur Autre',
    'tourneur-autre',
    'producer',
    'tourneur-autre-test.fr'
  );

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '53000000-0000-0000-0000-000000000002',
    'convention-admin@example.test',
    '{"first_name":"Convention","last_name":"Admin"}'::jsonb
  ),
  (
    '53000000-0000-0000-0000-000000000003',
    'convention-promoter@example.test',
    '{"first_name":"Convention","last_name":"Tourneur"}'::jsonb
  ),
  (
    '53000000-0000-0000-0000-000000000004',
    'convention-outsider@example.test',
    '{"first_name":"Autre","last_name":"Tourneur"}'::jsonb
  );

insert into public.user_accounts (
  profile_id, role, organization_id, status, activated_at
)
values
  (
    '53000000-0000-0000-0000-000000000002', 'admin', null, 'active', now()
  ),
  (
    '53000000-0000-0000-0000-000000000003', 'promoter',
    '53000000-0000-0000-0000-000000000001', 'active', now()
  ),
  (
    '53000000-0000-0000-0000-000000000004', 'promoter',
    '53000000-0000-0000-0000-000000000005', 'active', now()
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '53000000-0000-0000-0000-000000000004',
  true
);

select throws_ok(
  $$
    select public.submit_my_organization_convention(
      '53000000-0000-0000-0000-000000000001',
      'organization-private-documents/53000000-0000-0000-0000-000000000001/convention.pdf'
    )
  $$,
  '42501',
  'Compte tourneur actif requis pour cette organisation',
  'Un tourneur d’une autre organisation ne peut pas déposer cette convention'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '53000000-0000-0000-0000-000000000003',
  true
);

select lives_ok(
  $$
    select public.submit_my_organization_convention(
      '53000000-0000-0000-0000-000000000001',
      'organization-private-documents/53000000-0000-0000-0000-000000000001/convention.pdf'
    )
  $$,
  'Le tourneur dépose sa convention signée'
);

select results_eq(
  $$
    select status::text
    from public.organization_conventions
    where organization_id = '53000000-0000-0000-0000-000000000001'
  $$,
  array['pending'::text],
  'La convention déposée attend la contre-signature de l’admin'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '53000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.admin_set_organization_convention(
      '53000000-0000-0000-0000-000000000001',
      'organization-private-documents/53000000-0000-0000-0000-000000000001/convention-countersigned.pdf'
    )
  $$,
  'L’administrateur dépose la convention contresignée'
);

select results_eq(
  $$
    select status::text
    from public.organization_conventions
    where organization_id = '53000000-0000-0000-0000-000000000001'
  $$,
  array['approved'::text],
  'La convention contresignée passe au statut validé'
);

select throws_ok(
  $$
    select public.review_organization_convention(
      '53000000-0000-0000-0000-000000000001',
      'rejected'::public.volunteer_document_status
    )
  $$,
  '22023',
  'Un motif de refus est requis',
  'Un rejet exige toujours un motif'
);

select lives_ok(
  $$
    select public.review_organization_convention(
      '53000000-0000-0000-0000-000000000001',
      'rejected'::public.volunteer_document_status,
      'Signature du tourneur manquante'
    )
  $$,
  'L’administrateur peut rejeter la convention pour redemander un envoi'
);

reset role;

select * from finish();

rollback;
