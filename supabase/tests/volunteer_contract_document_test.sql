begin;

create extension if not exists pgtap with schema extensions;

select plan(9);

select has_type(
  'public',
  'volunteer_document_type',
  'Le type de document bénévole existe'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '52000000-0000-0000-0000-000000000001',
    'contract-admin@example.test',
    '{"first_name":"Contrat","last_name":"Admin"}'::jsonb
  ),
  (
    '52000000-0000-0000-0000-000000000002',
    'contract-volunteer@example.test',
    '{"first_name":"Contrat","last_name":"Bénévole"}'::jsonb
  );

insert into public.user_accounts (
  profile_id, role, organization_id, status, activated_at
)
values
  ('52000000-0000-0000-0000-000000000001', 'admin', null, 'active', now()),
  ('52000000-0000-0000-0000-000000000002', 'volunteer', null, 'active', now());

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '52000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.submit_my_volunteer_document(
      'contract'::public.volunteer_document_type,
      'volunteer-private-documents/52000000-0000-0000-0000-000000000002/contract-signed.pdf'
    )
  $$,
  'Le bénévole dépose son contrat signé'
);

select results_eq(
  $$
    select status::text
    from public.volunteer_documents
    where user_id = '52000000-0000-0000-0000-000000000002'
      and document_type = 'contract'
  $$,
  array['pending'::text],
  'Le contrat déposé par le bénévole attend la contre-signature de l’admin'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '52000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.admin_set_volunteer_document(
      '52000000-0000-0000-0000-000000000002',
      'contract'::public.volunteer_document_type,
      'volunteer-private-documents/52000000-0000-0000-0000-000000000002/contract-countersigned.pdf',
      null,
      (
        select id from public.volunteer_documents
        where user_id = '52000000-0000-0000-0000-000000000002'
          and document_type = 'contract'
      )
    )
  $$,
  'L’administrateur dépose la version contresignée du contrat'
);

select results_eq(
  $$
    select status::text, storage_path
    from public.volunteer_documents
    where user_id = '52000000-0000-0000-0000-000000000002'
      and document_type = 'contract'
  $$,
  $$
    values (
      'approved'::text,
      'volunteer-private-documents/52000000-0000-0000-0000-000000000002/contract-countersigned.pdf'
    )
  $$,
  'Le contrat contresigné remplace le fichier et passe au statut validé'
);

select throws_ok(
  $$
    select public.review_volunteer_document(
      (
        select id from public.volunteer_documents
        where user_id = '52000000-0000-0000-0000-000000000002'
          and document_type = 'contract'
      ),
      'rejected'::public.volunteer_document_status
    )
  $$,
  '22023',
  'Un motif de refus est requis',
  'Un refus du contrat exige toujours un motif, comme les autres documents'
);

select lives_ok(
  $$
    select public.review_volunteer_document(
      (
        select id from public.volunteer_documents
        where user_id = '52000000-0000-0000-0000-000000000002'
          and document_type = 'contract'
      ),
      'rejected'::public.volunteer_document_status,
      'Signature manquante côté bénévole'
    )
  $$,
  'L’administrateur peut rejeter un contrat avec motif pour redemander un envoi'
);

reset role;
select ok(
  not private.volunteer_has_required_documents(
    '52000000-0000-0000-0000-000000000002'
  ),
  'Le contrat n’entre pas dans les documents requis pour la constitution d’équipe'
);

select is(
  (
    select count(*)::bigint
    from public.volunteer_documents
    where user_id = '52000000-0000-0000-0000-000000000002'
      and document_type = 'contract'
  ),
  1::bigint,
  'Un seul contrat par bénévole (contrainte d’unicité héritée du type non-libre)'
);

select * from finish();

rollback;
