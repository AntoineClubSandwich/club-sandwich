begin;

create extension if not exists pgtap with schema extensions;

select plan(6);

select has_table(
  'public',
  'document_templates',
  'Les modèles de documents vierges sont stockés dans une table dédiée'
);

select has_function(
  'public',
  'admin_set_document_template',
  array['text', 'text'],
  'L’administrateur peut déposer ou remplacer un modèle de document'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '54000000-0000-0000-0000-000000000001',
    'template-admin@example.test',
    '{"first_name":"Template","last_name":"Admin"}'::jsonb
  ),
  (
    '54000000-0000-0000-0000-000000000002',
    'template-volunteer@example.test',
    '{"first_name":"Template","last_name":"Bénévole"}'::jsonb
  );

insert into public.user_accounts (
  profile_id, role, organization_id, status, activated_at
)
values
  ('54000000-0000-0000-0000-000000000001', 'admin', null, 'active', now()),
  ('54000000-0000-0000-0000-000000000002', 'volunteer', null, 'active', now());

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '54000000-0000-0000-0000-000000000002',
  true
);

select throws_ok(
  $$
    select public.admin_set_document_template(
      'volunteer_contract',
      'document-templates/volunteer_contract.pdf'
    )
  $$,
  '42501',
  'Accès administrateur requis',
  'Un bénévole ne peut pas déposer un modèle de document'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '54000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.admin_set_document_template(
      'volunteer_contract',
      'document-templates/volunteer_contract.pdf'
    )
  $$,
  'L’administrateur dépose le modèle de contrat bénévole'
);

select throws_ok(
  $$
    select public.admin_set_document_template(
      'unknown_key',
      'document-templates/unknown.pdf'
    )
  $$,
  '22023',
  'Modèle de document inconnu',
  'Une clé de modèle inconnue est rejetée'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '54000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$
    select storage_path
    from public.document_templates
    where key = 'volunteer_contract'
  $$,
  array['document-templates/volunteer_contract.pdf'],
  'Tout compte authentifié peut lire le modèle déposé, y compris un bénévole'
);

reset role;

select * from finish();

rollback;
