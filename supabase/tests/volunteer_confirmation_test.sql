begin;

create extension if not exists pgtap with schema extensions;

select plan(15);

select has_column(
  'public',
  'concert_volunteers',
  'confirmation_status',
  'La candidature porte un statut de confirmation distinct'
);

select has_function(
  'public',
  'confirm_concert_participation',
  array['uuid', 'boolean'],
  'Le bénévole dispose d’une action sécurisée de confirmation'
);

select ok(
  has_function_privilege(
    'authenticated',
    'private.is_selected_maraude_member(uuid, uuid)',
    'EXECUTE'
  ),
  'Les politiques RLS peuvent vérifier les maraudes du bénévole sélectionné'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '37000000-0000-0000-0000-000000000001',
    'confirmation-volunteer@example.test',
    '{"first_name":"Confirmation","last_name":"Bénévole"}'::jsonb
  ),
  (
    '37000000-0000-0000-0000-000000000002',
    'confirmation-admin@example.test',
    '{"first_name":"Confirmation","last_name":"Admin"}'::jsonb
  ),
  (
    '37000000-0000-0000-0000-000000000003',
    'confirmation-other@example.test',
    '{"first_name":"Autre","last_name":"Bénévole"}'::jsonb
  ),
  (
    '37000000-0000-0000-0000-000000000004',
    'confirmation-member2@example.test',
    '{"first_name":"Sacha","last_name":"Membre"}'::jsonb
  ),
  (
    '37000000-0000-0000-0000-000000000005',
    'confirmation-member3@example.test',
    '{"first_name":"Lou","last_name":"Membre"}'::jsonb
  );

insert into public.memberships (organization_id, profile_id, role)
select
  organization.id,
  member_data.profile_id,
  member_data.role::public.app_role
from public.organizations organization
cross join (
  values
    ('37000000-0000-0000-0000-000000000001'::uuid, 'volunteer'),
    ('37000000-0000-0000-0000-000000000002'::uuid, 'admin'),
    ('37000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('37000000-0000-0000-0000-000000000004'::uuid, 'volunteer'),
    ('37000000-0000-0000-0000-000000000005'::uuid, 'volunteer')
) as member_data(profile_id, role)
where organization.slug = 'club-sandwich';

insert into public.volunteer_documents (
  user_id, document_type, storage_path, status, reviewed_by, reviewed_at
)
select
  volunteer.profile_id,
  document_type.value,
  'seed/' || volunteer.profile_id || '/' || document_type.value,
  'approved'::public.volunteer_document_status,
  '37000000-0000-0000-0000-000000000002'::uuid,
  now()
from (
  values
    ('37000000-0000-0000-0000-000000000001'::uuid),
    ('37000000-0000-0000-0000-000000000003'::uuid),
    ('37000000-0000-0000-0000-000000000004'::uuid),
    ('37000000-0000-0000-0000-000000000005'::uuid)
) as volunteer(profile_id)
cross join (
  values
    ('identity'::public.volunteer_document_type),
    ('social_security'::public.volunteer_document_type)
) as document_type(value);

insert into public.concerts (
  id,
  organization_id,
  artist,
  concert_date,
  venue_id,
  created_by
)
select
  '47000000-0000-0000-0000-000000000001'::uuid,
  organization.id,
  'Double validation',
  '2026-12-10'::date,
  venue.id,
  '37000000-0000-0000-0000-000000000002'::uuid
from public.organizations organization
cross join lateral (
  select id from public.venues order by name limit 1
) venue
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (
  id,
  concert_id,
  user_id,
  status
)
values
  (
    '57000000-0000-0000-0000-000000000001',
    '47000000-0000-0000-0000-000000000001',
    '37000000-0000-0000-0000-000000000001',
    'pending'
  ),
  (
    '57000000-0000-0000-0000-000000000004',
    '47000000-0000-0000-0000-000000000001',
    '37000000-0000-0000-0000-000000000004',
    'pending'
  ),
  (
    '57000000-0000-0000-0000-000000000005',
    '47000000-0000-0000-0000-000000000001',
    '37000000-0000-0000-0000-000000000005',
    'pending'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '37000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.save_maraude_team(
      '47000000-0000-0000-0000-000000000001',
      '[
        {
          "application_id": "57000000-0000-0000-0000-000000000001",
          "team_role": "team_leader"
        },
        {
          "application_id": "57000000-0000-0000-0000-000000000004",
          "team_role": "logistics"
        },
        {
          "application_id": "57000000-0000-0000-0000-000000000005",
          "team_role": "communication"
        }
      ]'::jsonb
    )
  $$,
  'La sélection déclenche une demande de confirmation'
);

select results_eq(
  $$
    select confirmation_status::text
    from public.concert_volunteers
    where id = '57000000-0000-0000-0000-000000000001'
  $$,
  array['pending'::text],
  'La participation sélectionnée attend la réponse du bénévole'
);

select isnt_empty(
  $$
    select confirmation_requested_at
    from public.concert_volunteers
    where id = '57000000-0000-0000-0000-000000000001'
      and confirmation_requested_at is not null
  $$,
  'La date de demande est enregistrée'
);

select results_eq(
  $$
    select pending_confirmation_count
    from public.get_maraude_overview()
    where concert_id = '47000000-0000-0000-0000-000000000001'
  $$,
  array[3::bigint],
  'Le tableau de bord admin remonte la confirmation attendue'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '37000000-0000-0000-0000-000000000001',
  true
);

select throws_ok(
  $$
    select public.set_volunteer_attendance(
      '57000000-0000-0000-0000-000000000001',
      'present'::public.volunteer_attendance_status
    )
  $$,
  '42501',
  'Validation administrateur requise',
  'Un bénévole ne peut pas renseigner une présence'
);

select lives_ok(
  $$
    select public.confirm_concert_participation(
      '47000000-0000-0000-0000-000000000001',
      true
    )
  $$,
  'Le bénévole sélectionné confirme sa participation'
);

select results_eq(
  $$
    select confirmation_status::text
    from public.concert_volunteers
    where id = '57000000-0000-0000-0000-000000000001'
  $$,
  array['confirmed'::text],
  'La participation devient confirmée'
);

select isnt_empty(
  $$
    select confirmation_responded_at
    from public.concert_volunteers
    where id = '57000000-0000-0000-0000-000000000001'
      and confirmation_responded_at is not null
  $$,
  'La date de réponse est enregistrée'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '37000000-0000-0000-0000-000000000001',
  true
);

select throws_ok(
  $$
    select public.set_volunteer_attendance(
      '57000000-0000-0000-0000-000000000001',
      'present'::public.volunteer_attendance_status
    )
  $$,
  '42501',
  'Validation administrateur requise',
  'La confirmation ne permet pas au chef de saisir une présence'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '37000000-0000-0000-0000-000000000003',
  true
);

select throws_ok(
  $$
    select public.confirm_concert_participation(
      '47000000-0000-0000-0000-000000000001',
      true
    )
  $$,
  '22023',
  'Aucune participation à confirmer',
  'Un autre bénévole ne peut pas confirmer cette place'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '37000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    update public.concert_volunteers
    set status = 'withdrawn'
    where id = '57000000-0000-0000-0000-000000000001'
  $$,
  'Un bénévole confirmé peut encore signaler son désistement'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where id = '57000000-0000-0000-0000-000000000001'
      and status = 'withdrawn'::public.concert_volunteer_status
      and confirmation_status is null
      and confirmation_requested_at is null
      and confirmation_due_at is null
      and confirmation_responded_at is null
      and role_acknowledged_at is null
  $$,
  array[1::bigint],
  'Le désistement efface la confirmation active'
);

select * from finish();

rollback;
