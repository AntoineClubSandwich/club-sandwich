begin;

create extension if not exists pgtap with schema extensions;

select plan(9);

select has_function(
  'private',
  'maraude_role_mission_email_body',
  array['public.maraude_role'],
  'Le contenu de la fiche de mission est disponible par rôle'
);

select has_function(
  'private',
  'notify_mission_sheet_email',
  array[]::text[],
  'La fiche de mission peut être envoyée automatiquement par e-mail'
);

select results_eq(
  $$
    select count(*)::bigint
    from pg_trigger
    where tgname = 'concert_volunteers_mission_sheet_email'
      and not tgisinternal
  $$,
  array[1::bigint],
  'L’envoi de la fiche de mission est automatique à la confirmation'
);

select ok(
  private.maraude_role_mission_email_body('collection_distribution') like '%Check-list%',
  'Le contenu envoyé par e-mail détaille la check-list du rôle'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '38000000-0000-0000-0000-000000000001',
    'mission-volunteer@example.test',
    '{"first_name":"Mission","last_name":"Bénévole"}'::jsonb
  ),
  (
    '38000000-0000-0000-0000-000000000002',
    'mission-admin@example.test',
    '{"first_name":"Mission","last_name":"Admin"}'::jsonb
  ),
  (
    '38000000-0000-0000-0000-000000000003',
    'mission-member2@example.test',
    '{"first_name":"Sacha","last_name":"Membre"}'::jsonb
  ),
  (
    '38000000-0000-0000-0000-000000000004',
    'mission-member3@example.test',
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
    ('38000000-0000-0000-0000-000000000001'::uuid, 'volunteer'),
    ('38000000-0000-0000-0000-000000000002'::uuid, 'admin'),
    ('38000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('38000000-0000-0000-0000-000000000004'::uuid, 'volunteer')
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
  '38000000-0000-0000-0000-000000000002'::uuid,
  now()
from (
  values
    ('38000000-0000-0000-0000-000000000001'::uuid),
    ('38000000-0000-0000-0000-000000000003'::uuid),
    ('38000000-0000-0000-0000-000000000004'::uuid)
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
  '48000000-0000-0000-0000-000000000001'::uuid,
  organization.id,
  'Fiche de mission',
  '2026-12-11'::date,
  venue.id,
  '38000000-0000-0000-0000-000000000002'::uuid
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
    '58000000-0000-0000-0000-000000000001',
    '48000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000001',
    'pending'
  ),
  (
    '58000000-0000-0000-0000-000000000003',
    '48000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000003',
    'pending'
  ),
  (
    '58000000-0000-0000-0000-000000000004',
    '48000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000004',
    'pending'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '38000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.save_maraude_team(
      '48000000-0000-0000-0000-000000000001',
      '[
        {
          "application_id": "58000000-0000-0000-0000-000000000001",
          "team_role": "collection_distribution"
        },
        {
          "application_id": "58000000-0000-0000-0000-000000000003",
          "team_role": "team_leader"
        },
        {
          "application_id": "58000000-0000-0000-0000-000000000004",
          "team_role": "logistics"
        }
      ]'::jsonb
    )
  $$,
  'L’équipe est constituée avant la confirmation du bénévole'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '38000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.user_notifications
    where user_id = '38000000-0000-0000-0000-000000000001'
      and notification_type = 'mission_sheet'
  $$,
  array[0::bigint],
  'Aucune fiche de mission n’est envoyée avant la confirmation'
);

select lives_ok(
  $$
    select public.confirm_concert_participation(
      '48000000-0000-0000-0000-000000000001',
      true
    )
  $$,
  'Le bénévole confirme sa participation'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.user_notifications
    where user_id = '38000000-0000-0000-0000-000000000001'
      and notification_type = 'mission_sheet'
      and body like '%récolte%'
  $$,
  array[1::bigint],
  'La confirmation déclenche l’envoi de la fiche de mission par e-mail'
);

reset role;

select results_eq(
  $$
    select count(*)::bigint
    from public.workflow_email_deliveries delivery
    join public.user_notifications notification
      on notification.id = delivery.notification_id
    where notification.user_id = '38000000-0000-0000-0000-000000000001'
      and notification.notification_type = 'mission_sheet'
  $$,
  array[1::bigint],
  'La fiche de mission est mise en file d’envoi e-mail'
);

select * from finish();

rollback;
