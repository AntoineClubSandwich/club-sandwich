begin;

create extension if not exists pgtap with schema extensions;

select plan(38);

select has_table(
  'public',
  'maraude_workflow_events',
  'Le journal opérationnel existe'
);
select has_table(
  'public',
  'user_notifications',
  'Les notifications persistées existent'
);
select has_table(
  'public',
  'volunteer_credits',
  'Les crédits bénévoles existent'
);
select has_column(
  'public',
  'concert_volunteers',
  'confirmation_due_at',
  'La date limite de confirmation est stockée'
);
select has_column(
  'public',
  'concert_volunteers',
  'role_acknowledged_at',
  'La prise de connaissance du rôle est traçable'
);
select has_column(
  'public',
  'concert_volunteers',
  'attendance_validated_at',
  'La validation administrative des présences est traçable'
);
select has_function(
  'public',
  'confirm_concert_participation',
  array['uuid', 'boolean'],
  'La confirmation exige explicitement la lecture du rôle'
);
select has_function(
  'public',
  'validate_maraude_attendance',
  array['uuid'],
  'La validation des présences est transactionnelle'
);
select has_function(
  'private',
  'expire_overdue_volunteer_confirmations',
  array[]::text[],
  'L’expiration autonome existe côté base'
);
select results_eq(
  $$
    select count(*)::bigint
    from cron.job
    where jobname = 'expire-volunteer-confirmations'
      and schedule = '*/5 * * * *'
  $$,
  array[1::bigint],
  'L’expiration est planifiée toutes les cinq minutes'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '81000000-0000-0000-0000-000000000001',
    'workflow-admin@example.test',
    '{"first_name":"Antoine","last_name":"Admin"}'::jsonb
  ),
  (
    '81000000-0000-0000-0000-000000000002',
    'workflow-leader@example.test',
    '{"first_name":"Camille","last_name":"Leader"}'::jsonb
  ),
  (
    '81000000-0000-0000-0000-000000000003',
    'workflow-member@example.test',
    '{"first_name":"Hugo","last_name":"Membre"}'::jsonb
  ),
  (
    '81000000-0000-0000-0000-000000000004',
    'workflow-member-2@example.test',
    '{"first_name":"Inès","last_name":"Membre"}'::jsonb
  ),
  (
    '81000000-0000-0000-0000-000000000005',
    'workflow-member-3@example.test',
    '{"first_name":"Lina","last_name":"Membre"}'::jsonb
  );

insert into public.memberships (organization_id, profile_id, role)
select
  organization.id,
  member.profile_id,
  member.role::public.app_role
from public.organizations organization
cross join (
  values
    ('81000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('81000000-0000-0000-0000-000000000002'::uuid, 'volunteer'),
    ('81000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('81000000-0000-0000-0000-000000000004'::uuid, 'volunteer'),
    ('81000000-0000-0000-0000-000000000005'::uuid, 'volunteer')
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
  '81000000-0000-0000-0000-000000000001'::uuid,
  now()
from (
  values
    ('81000000-0000-0000-0000-000000000002'::uuid),
    ('81000000-0000-0000-0000-000000000003'::uuid),
    ('81000000-0000-0000-0000-000000000004'::uuid),
    ('81000000-0000-0000-0000-000000000005'::uuid)
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
  '82000000-0000-0000-0000-000000000001',
  organization.id,
  'Workflow complet',
  '2026-12-20',
  venue.id,
  '81000000-0000-0000-0000-000000000001'
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
    '83000000-0000-0000-0000-000000000001',
    '82000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000002',
    'pending'
  ),
  (
    '83000000-0000-0000-0000-000000000002',
    '82000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000003',
    'pending'
  ),
  (
    '83000000-0000-0000-0000-000000000003',
    '82000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000004',
    'pending'
  ),
  (
    '83000000-0000-0000-0000-000000000004',
    '82000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000005',
    'pending'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.save_maraude_team(
      '82000000-0000-0000-0000-000000000001',
      '[
        {
          "application_id": "83000000-0000-0000-0000-000000000001",
          "team_role": "team_leader"
        },
        {
          "application_id": "83000000-0000-0000-0000-000000000002",
          "team_role": "collection_distribution"
        },
        {
          "application_id": "83000000-0000-0000-0000-000000000003",
          "team_role": "communication"
        },
        {
          "application_id": "83000000-0000-0000-0000-000000000004",
          "team_role": "logistics"
        }
      ]'::jsonb
    )
  $$,
  'L’administrateur constitue une équipe'
);

reset role;
select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
    where concert_id = '82000000-0000-0000-0000-000000000001'
      and confirmation_status = 'pending'
      and confirmation_due_at is not null
  $$,
  array[4::bigint],
  'Chaque sélection ouvre un délai de confirmation'
);

select throws_ok(
  $$
    select public.save_maraude_team(
      '82000000-0000-0000-0000-000000000001',
      '[
        {
          "application_id": "83000000-0000-0000-0000-000000000001",
          "team_role": "team_leader"
        },
        {
          "application_id": "83000000-0000-0000-0000-000000000002",
          "team_role": "team_leader"
        },
        {
          "application_id": "83000000-0000-0000-0000-000000000003",
          "team_role": "communication"
        },
        {
          "application_id": "83000000-0000-0000-0000-000000000004",
          "team_role": "logistics"
        }
      ]'::jsonb
    )
  $$,
  '23505',
  'Un seul chef d''équipe est autorisé',
  'Deux chefs sont refusés même dans une RPC atomique'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.user_notifications
    where concert_id = '82000000-0000-0000-0000-000000000001'
      and notification_type = 'selection_requested'
  $$,
  array[4::bigint],
  'La sélection notifie chaque bénévole'
);

update public.concert_volunteers
set confirmation_due_at = clock_timestamp() - interval '1 minute'
where id = '83000000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$ select public.expire_volunteer_confirmations() $$,
  array[1],
  'Une confirmation expirée libère automatiquement la place'
);

select results_eq(
  $$
    select status::text || ':' || coalesce(team_role::text, 'null')
    from public.concert_volunteers
    where id = '83000000-0000-0000-0000-000000000002'
  $$,
  array['pending:null'::text],
  'La place expirée revient en attente sans rôle'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000002',
  true
);

select throws_ok(
  $$
    select public.confirm_concert_participation(
      '82000000-0000-0000-0000-000000000001',
      false
    )
  $$,
  '22023',
  'La fiche de mission doit être reconnue',
  'La confirmation sans lecture du rôle est refusée'
);

select lives_ok(
  $$
    select public.confirm_concert_participation(
      '82000000-0000-0000-0000-000000000001',
      true
    )
  $$,
  'Le chef confirme en une seule action'
);

select isnt_empty(
  $$
    select role_acknowledged_at
    from public.concert_volunteers
    where id = '83000000-0000-0000-0000-000000000001'
      and role_acknowledged_at is not null
  $$,
  'La lecture de la fiche de mission est horodatée'
);

select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);
select throws_ok(
  $$
    select public.set_maraude_status(
      '82000000-0000-0000-0000-000000000001',
      'team_ready'::public.maraude_status,
      null
    )
  $$,
  '22023',
  'Trois bénévoles confirmés sont requis, dont exactement un chef d’équipe',
  'L’administrateur ne peut pas valider une équipe incomplète'
);

select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000004',
  true
);
select lives_ok(
  $$
    select public.confirm_concert_participation(
      '82000000-0000-0000-0000-000000000001',
      true
    )
  $$,
  'Le deuxième membre confirme sa participation'
);

select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000005',
  true
);
select lives_ok(
  $$
    select public.confirm_concert_participation(
      '82000000-0000-0000-0000-000000000001',
      true
    )
  $$,
  'Le troisième membre confirme sa participation'
);

select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000002',
  true
);
select throws_ok(
  $$
    select public.set_volunteer_attendance(
      '83000000-0000-0000-0000-000000000001',
      'present'::public.volunteer_attendance_status
    )
  $$,
  '42501',
  'Validation administrateur requise',
  'Le chef ne renseigne pas les présences'
);

select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);
select lives_ok(
  $$
    select public.set_maraude_status(
      '82000000-0000-0000-0000-000000000001',
      'team_ready'::public.maraude_status,
      null
    )
  $$,
  'L’administrateur valide l’équipe désormais complète'
);

select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000002',
  true
);
select lives_ok(
  $$
    select public.set_maraude_status(
      '82000000-0000-0000-0000-000000000001',
      'in_progress'::public.maraude_status,
      null
    )
  $$,
  'Le chef confirmé démarre une fois l’équipe validée par l’admin'
);

select lives_ok(
  $$
    select public.set_maraude_status(
      '82000000-0000-0000-0000-000000000001',
      'completed'::public.maraude_status,
      null
    )
  $$,
  'Le chef clôture la maraude'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.volunteer_credits
    where concert_id = '82000000-0000-0000-0000-000000000001'
  $$,
  array[0::bigint],
  'La clôture seule n’attribue aucun crédit'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.set_volunteer_attendance(
      '83000000-0000-0000-0000-000000000001',
      'present'::public.volunteer_attendance_status
    )
  $$,
  'L’administrateur renseigne la présence après la clôture'
);

select public.set_volunteer_attendance(
  '83000000-0000-0000-0000-000000000003',
  'absent'::public.volunteer_attendance_status
);

select public.set_volunteer_attendance(
  '83000000-0000-0000-0000-000000000004',
  'absent'::public.volunteer_attendance_status
);

select results_eq(
  $$
    select public.validate_maraude_attendance(
      '82000000-0000-0000-0000-000000000001'
    )
  $$,
  array[1],
  'La validation admin attribue le crédit de présence'
);

select results_eq(
  $$
    select status
    from public.volunteer_credits
    where concert_id = '82000000-0000-0000-0000-000000000001'
      and user_id = '81000000-0000-0000-0000-000000000002'
  $$,
  array['active'::text],
  'Le crédit attribué est actif'
);

select results_eq(
  $$
    select public.validate_maraude_attendance(
      '82000000-0000-0000-0000-000000000001'
    )
  $$,
  array[0],
  'Une seconde validation n’attribue pas un second crédit'
);

select lives_ok(
  $$
    select public.set_volunteer_attendance(
      '83000000-0000-0000-0000-000000000001',
      'absent'::public.volunteer_attendance_status
    )
  $$,
  'L’administrateur peut corriger une présence après clôture'
);

select results_eq(
  $$
    select status
    from public.volunteer_credits
    where concert_id = '82000000-0000-0000-0000-000000000001'
      and user_id = '81000000-0000-0000-0000-000000000002'
  $$,
  array['revoked'::text],
  'Une correction d’absence révoque le crédit'
);

select isnt_empty(
  $$
    select actor_id
    from public.maraude_workflow_events
    where concert_id = '82000000-0000-0000-0000-000000000001'
      and event_type = 'attendance_corrected'
      and actor_id = '81000000-0000-0000-0000-000000000001'
  $$,
  'La correction admin est historisée avec son auteur'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_workflow_events
    where concert_id = '82000000-0000-0000-0000-000000000001'
      and event_type in ('maraude_started', 'maraude_completed')
  $$,
  array[2::bigint],
  'Le démarrage et la clôture sont journalisés'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000002',
  true
);

select isnt_empty(
  $$
    select id
    from public.user_notifications
    where user_id = '81000000-0000-0000-0000-000000000002'
  $$,
  'Le bénévole consulte ses propres notifications'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.volunteer_credits
    where user_id = '81000000-0000-0000-0000-000000000002'
  $$,
  array[1::bigint],
  'Le bénévole consulte son propre historique de crédit'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000003',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.volunteer_credits
    where user_id = '81000000-0000-0000-0000-000000000002'
  $$,
  array[0::bigint],
  'Un bénévole ne consulte jamais les crédits d’un autre'
);

select * from finish();

rollback;
