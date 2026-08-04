begin;

create extension if not exists pgtap with schema extensions;

select plan(7);

select has_trigger(
  'public',
  'concert_volunteers',
  'protect_started_maraude_team_changes',
  'La composition de l’équipe est protégée après le démarrage'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '84000000-0000-0000-0000-000000000001',
    'snapshot-admin@example.test',
    '{"first_name":"Antoine","last_name":"Admin"}'::jsonb
  ),
  (
    '84000000-0000-0000-0000-000000000002',
    'snapshot-leader@example.test',
    '{"first_name":"Camille","last_name":"Leader"}'::jsonb
  ),
  (
    '84000000-0000-0000-0000-000000000003',
    'snapshot-member2@example.test',
    '{"first_name":"Sacha","last_name":"Membre"}'::jsonb
  ),
  (
    '84000000-0000-0000-0000-000000000004',
    'snapshot-member3@example.test',
    '{"first_name":"Lou","last_name":"Membre"}'::jsonb
  );

insert into public.memberships (organization_id, profile_id, role)
select
  organization.id,
  member.profile_id,
  member.role::public.app_role
from public.organizations organization
cross join (
  values
    ('84000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('84000000-0000-0000-0000-000000000002'::uuid, 'volunteer'),
    ('84000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('84000000-0000-0000-0000-000000000004'::uuid, 'volunteer')
) as member(profile_id, role)
where organization.slug = 'club-sandwich';

insert into public.volunteer_documents (
  user_id, document_type, storage_path, status, reviewed_by, reviewed_at
)
select
  volunteer.profile_id,
  document_type.value,
  'seed/' || volunteer.profile_id || '/' || document_type.value,
  'approved'::public.volunteer_document_status,
  '84000000-0000-0000-0000-000000000001'::uuid,
  now()
from (
  values
    ('84000000-0000-0000-0000-000000000002'::uuid),
    ('84000000-0000-0000-0000-000000000003'::uuid),
    ('84000000-0000-0000-0000-000000000004'::uuid)
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
  created_by,
  maraude_status,
  actual_start_at
)
select
  '85000000-0000-0000-0000-000000000001',
  organization.id,
  'Snapshot terminé',
  '2026-12-29',
  venue.id,
  '84000000-0000-0000-0000-000000000001',
  'in_progress',
  clock_timestamp() - interval '1 hour'
from public.organizations organization
cross join lateral (
  select id from public.venues order by name limit 1
) venue
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (
  id,
  concert_id,
  user_id,
  status,
  team_role
)
values
  (
    '86000000-0000-0000-0000-000000000001',
    '85000000-0000-0000-0000-000000000001',
    '84000000-0000-0000-0000-000000000002',
    'selected',
    'team_leader'
  ),
  (
    '86000000-0000-0000-0000-000000000002',
    '85000000-0000-0000-0000-000000000001',
    '84000000-0000-0000-0000-000000000003',
    'selected',
    'logistics'
  ),
  (
    '86000000-0000-0000-0000-000000000003',
    '85000000-0000-0000-0000-000000000001',
    '84000000-0000-0000-0000-000000000004',
    'selected',
    'communication'
  );

insert into public.maraude_collections (
  concert_id,
  category,
  quantity,
  unit,
  weight_kg
)
values (
  '85000000-0000-0000-0000-000000000001',
  'prepared_meals',
  14,
  'piece',
  4.9
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '84000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.complete_maraude_flexible(
      '85000000-0000-0000-0000-000000000001'
    )
  $$,
  'La maraude avec une collecte est clôturée'
);

select results_eq(
  $$
    select
      quantities_unavailable,
      total_weight_kg is null,
      distance_km is null
    from public.maraude_operational_reports
    where concert_id = '85000000-0000-0000-0000-000000000001'
  $$,
  $$ values (false, true, true) $$,
  'Le compte rendu automatique reconnaît la collecte sans inventer de valeurs'
);

select results_eq(
  $$
    select maraude_status::text
    from public.concerts
    where id = '85000000-0000-0000-0000-000000000001'
  $$,
  array['completed'::text],
  'La maraude est terminée'
);

select throws_ok(
  $$
    select public.save_maraude_team(
      '85000000-0000-0000-0000-000000000001',
      '[
        {
          "application_id": "86000000-0000-0000-0000-000000000001",
          "team_role": "logistics"
        },
        {
          "application_id": "86000000-0000-0000-0000-000000000002",
          "team_role": "team_leader"
        },
        {
          "application_id": "86000000-0000-0000-0000-000000000003",
          "team_role": "communication"
        }
      ]'::jsonb
    )
  $$,
  '55000',
  'La composition de l’équipe est verrouillée après le démarrage',
  'La RPC ne change pas un rôle après la clôture'
);

select throws_ok(
  $$
    update public.concert_volunteers
    set status = 'not_selected'
    where id = '86000000-0000-0000-0000-000000000001'
  $$,
  '55000',
  'La composition de l’équipe est verrouillée après le démarrage',
  'Une mise à jour directe ne retire pas un membre après la clôture'
);

select results_eq(
  $$
    select status::text, team_role::text
    from public.concert_volunteers
    where id = '86000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('selected'::text, 'team_leader'::text) $$,
  'Le snapshot de l’équipe terminée reste intact'
);

select * from finish();

rollback;
