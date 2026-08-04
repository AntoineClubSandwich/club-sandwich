begin;

create extension if not exists pgtap with schema extensions;

select plan(24);

select has_table(
  'public',
  'volunteer_documents',
  'Les documents bénévoles sont stockés dans une table dédiée'
);

select has_function(
  'public',
  'submit_my_volunteer_document',
  array['volunteer_document_type', 'text', 'uuid'],
  'Le bénévole peut déposer son propre document'
);

select has_function(
  'public',
  'admin_set_volunteer_document',
  array['uuid', 'volunteer_document_type', 'text', 'text', 'uuid'],
  'L’administrateur peut déposer un document pour un bénévole'
);

select has_function(
  'public',
  'review_volunteer_document',
  array['uuid', 'volunteer_document_status', 'text'],
  'L’administrateur peut valider ou refuser un document'
);

select has_function(
  'public',
  'notify_missing_volunteer_documents',
  array['uuid'],
  'L’administrateur peut relancer un bénévole pour ses documents manquants'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '51000000-0000-0000-0000-000000000001',
    'doc-admin@example.test',
    '{"first_name":"Doc","last_name":"Admin"}'::jsonb
  ),
  (
    '51000000-0000-0000-0000-000000000002',
    'doc-volunteer@example.test',
    '{"first_name":"Doc","last_name":"Bénévole"}'::jsonb
  ),
  (
    '51000000-0000-0000-0000-000000000003',
    'doc-other@example.test',
    '{"first_name":"Autre","last_name":"Bénévole"}'::jsonb
  );

insert into public.user_accounts (
  profile_id, role, organization_id, status, activated_at
)
values
  ('51000000-0000-0000-0000-000000000001', 'admin', null, 'active', now()),
  ('51000000-0000-0000-0000-000000000002', 'volunteer', null, 'active', now()),
  ('51000000-0000-0000-0000-000000000003', 'volunteer', null, 'active', now());

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '51000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.submit_my_volunteer_document(
      'identity'::public.volunteer_document_type,
      'volunteer-documents/51000000-0000-0000-0000-000000000002/identity.pdf'
    )
  $$,
  'Le bénévole dépose sa pièce d’identité'
);

select results_eq(
  $$
    select status::text
    from public.volunteer_documents
    where user_id = '51000000-0000-0000-0000-000000000002'
      and document_type = 'identity'
  $$,
  array['pending'::text],
  'Le document déposé par le bénévole attend une validation'
);

select throws_ok(
  $$
    select public.submit_my_volunteer_document(
      'other'::public.volunteer_document_type,
      'volunteer-documents/51000000-0000-0000-0000-000000000002/other.pdf'
    )
  $$,
  'P0002',
  'Document demandé introuvable',
  'Un bénévole ne peut pas créer lui-même un document libre non demandé'
);

reset role;
select ok(
  not private.volunteer_has_required_documents(
    '51000000-0000-0000-0000-000000000002'
  ),
  'Un document en attente ne suffit pas à remplir les prérequis'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '51000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.review_volunteer_document(
      (
        select id from public.volunteer_documents
        where user_id = '51000000-0000-0000-0000-000000000002'
          and document_type = 'identity'
      ),
      'approved'::public.volunteer_document_status
    )
  $$,
  'L’administrateur valide la pièce d’identité'
);

select lives_ok(
  $$
    select public.admin_set_volunteer_document(
      '51000000-0000-0000-0000-000000000002',
      'social_security'::public.volunteer_document_type,
      'volunteer-documents/51000000-0000-0000-0000-000000000002/cpam.pdf'
    )
  $$,
  'L’administrateur dépose directement la carte de sécurité sociale'
);

select results_eq(
  $$
    select status::text
    from public.volunteer_documents
    where user_id = '51000000-0000-0000-0000-000000000002'
      and document_type = 'social_security'
  $$,
  array['approved'::text],
  'Un document déposé par l’administrateur est validé immédiatement'
);

reset role;
select ok(
  private.volunteer_has_required_documents(
    '51000000-0000-0000-0000-000000000002'
  ),
  'Les deux documents fixes validés suffisent en l’absence de document libre'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '51000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.admin_set_volunteer_document(
      '51000000-0000-0000-0000-000000000002',
      'other'::public.volunteer_document_type,
      null,
      'Certificat médical'
    )
  $$,
  'L’administrateur demande un document libre sans le déposer'
);

reset role;
select ok(
  not private.volunteer_has_required_documents(
    '51000000-0000-0000-0000-000000000002'
  ),
  'Un document libre demandé mais non fourni bloque l’éligibilité'
);

select is(
  (
    select count(*)::bigint
    from public.user_notifications
    where user_id = '51000000-0000-0000-0000-000000000002'
      and notification_type = 'volunteer_document_requested'
  ),
  1::bigint,
  'Le bénévole est notifié qu’un document libre lui est demandé'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '51000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.submit_my_volunteer_document(
      'other'::public.volunteer_document_type,
      'volunteer-documents/51000000-0000-0000-0000-000000000002/certificat.pdf',
      (
        select id from public.volunteer_documents
        where user_id = '51000000-0000-0000-0000-000000000002'
          and document_type = 'other'
      )
    )
  $$,
  'Le bénévole dépose le document libre demandé'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '51000000-0000-0000-0000-000000000001',
  true
);

select throws_ok(
  $$
    select public.review_volunteer_document(
      (
        select id from public.volunteer_documents
        where user_id = '51000000-0000-0000-0000-000000000002'
          and document_type = 'other'
      ),
      'rejected'::public.volunteer_document_status
    )
  $$,
  '22023',
  'Un motif de refus est requis',
  'Un refus exige un motif'
);

select lives_ok(
  $$
    select public.review_volunteer_document(
      (
        select id from public.volunteer_documents
        where user_id = '51000000-0000-0000-0000-000000000002'
          and document_type = 'other'
      ),
      'rejected'::public.volunteer_document_status,
      'Document illisible'
    )
  $$,
  'L’administrateur refuse le document libre avec un motif'
);

reset role;
select ok(
  not private.volunteer_has_required_documents(
    '51000000-0000-0000-0000-000000000002'
  ),
  'Un document refusé bloque toujours l’éligibilité'
);

select is(
  (
    select count(*)::bigint
    from public.user_notifications
    where user_id = '51000000-0000-0000-0000-000000000002'
      and notification_type = 'volunteer_document_reviewed'
  ),
  2::bigint,
  'Le bénévole est notifié de chaque décision de validation (approbation puis refus)'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '51000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.notify_missing_volunteer_documents(
      '51000000-0000-0000-0000-000000000003'
    )
  $$,
  'L’administrateur relance un bénévole n’ayant fourni aucun document'
);

reset role;

select is(
  (
    select count(*)::bigint
    from public.user_notifications
    where user_id = '51000000-0000-0000-0000-000000000003'
      and notification_type = 'volunteer_documents_missing'
  ),
  1::bigint,
  'Un bénévole sans aucun document reçoit un rappel listant ce qui manque'
);

insert into auth.users (id, email, raw_user_meta_data)
values (
  '51000000-0000-0000-0000-000000000004',
  'doc-leader@example.test',
  '{"first_name":"Chef","last_name":"Équipe"}'::jsonb
);

insert into public.user_accounts (
  profile_id, role, organization_id, status, activated_at
)
values (
  '51000000-0000-0000-0000-000000000004', 'volunteer', null, 'active', now()
);

insert into public.volunteer_documents (
  user_id, document_type, storage_path, status, reviewed_by, reviewed_at
)
select
  '51000000-0000-0000-0000-000000000004'::uuid,
  document_type.value,
  'seed/51000000-0000-0000-0000-000000000004/' || document_type.value,
  'approved'::public.volunteer_document_status,
  '51000000-0000-0000-0000-000000000001'::uuid,
  now()
from (
  values
    ('identity'::public.volunteer_document_type),
    ('social_security'::public.volunteer_document_type)
) as document_type(value);

insert into public.venues (
  id, name, public_address_line1, postal_code, city
)
values (
  '51000000-0000-0000-0000-000000000005',
  'Salle documents',
  '1 rue des documents',
  '75001',
  'Paris'
);

insert into public.concerts (
  id, organization_id, artist, concert_date, venue_id, created_by
)
select
  '51000000-0000-0000-0000-000000000006'::uuid,
  organization.id,
  'Artiste documents',
  '2026-12-25'::date,
  '51000000-0000-0000-0000-000000000005'::uuid,
  '51000000-0000-0000-0000-000000000001'::uuid
from public.organizations organization
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (id, concert_id, user_id, status)
values
  (
    '51000000-0000-0000-0000-000000000007',
    '51000000-0000-0000-0000-000000000006',
    '51000000-0000-0000-0000-000000000004',
    'pending'
  ),
  (
    '51000000-0000-0000-0000-000000000008',
    '51000000-0000-0000-0000-000000000006',
    '51000000-0000-0000-0000-000000000002',
    'pending'
  ),
  (
    '51000000-0000-0000-0000-000000000009',
    '51000000-0000-0000-0000-000000000006',
    '51000000-0000-0000-0000-000000000003',
    'pending'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '51000000-0000-0000-0000-000000000001',
  true
);

select throws_ok(
  $$
    select public.save_maraude_team(
      '51000000-0000-0000-0000-000000000006',
      '[
        {
          "application_id": "51000000-0000-0000-0000-000000000007",
          "team_role": "team_leader"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000008",
          "team_role": "logistics"
        },
        {
          "application_id": "51000000-0000-0000-0000-000000000009",
          "team_role": "communication"
        }
      ]'::jsonb
    )
  $$,
  '22023',
  'Un bénévole sélectionné n’a pas tous ses documents validés',
  'L’administrateur ne peut pas sélectionner des bénévoles aux documents non validés'
);

reset role;

select * from finish();

rollback;
