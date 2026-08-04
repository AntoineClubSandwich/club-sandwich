begin;

create extension if not exists pgtap with schema extensions;

select plan(21);

select has_column(
  'public',
  'concerts',
  'maraude_status',
  'Le concert porte le statut de maraude'
);
select has_column(
  'public',
  'concerts',
  'actual_start_at',
  'Le concert porte l’heure réelle de début'
);
select has_column(
  'public',
  'concerts',
  'actual_end_at',
  'Le concert porte l’heure réelle de fin'
);
select has_column(
  'public',
  'concerts',
  'cancellation_reason',
  'Le concert peut conserver un motif d’annulation'
);

select col_type_is(
  'public',
  'concerts',
  'maraude_status',
  'public.maraude_status',
  'Le cycle utilise l’enum maraude_status'
);

select enum_has_labels(
  'public',
  'maraude_status',
  array['draft', 'open', 'team_ready', 'in_progress', 'completed', 'cancelled'],
  'Les six états fonctionnels sont disponibles'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '90000000-0000-0000-0000-000000000001',
    'lifecycle-volunteer@example.test',
    '{"first_name":"Julie","last_name":"Martin"}'::jsonb
  ),
  (
    '90000000-0000-0000-0000-000000000002',
    'lifecycle-admin@example.test',
    '{"first_name":"Admin","last_name":"Maraude"}'::jsonb
  ),
  (
    '90000000-0000-0000-0000-000000000003',
    'lifecycle-leader@example.test',
    '{"first_name":"Camille","last_name":"Leader"}'::jsonb
  ),
  (
    '90000000-0000-0000-0000-000000000004',
    'lifecycle-member2@example.test',
    '{"first_name":"Sacha","last_name":"Membre"}'::jsonb
  ),
  (
    '90000000-0000-0000-0000-000000000005',
    'lifecycle-member3@example.test',
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
    ('90000000-0000-0000-0000-000000000001'::uuid, 'volunteer'),
    ('90000000-0000-0000-0000-000000000002'::uuid, 'admin'),
    ('90000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('90000000-0000-0000-0000-000000000004'::uuid, 'volunteer'),
    ('90000000-0000-0000-0000-000000000005'::uuid, 'volunteer')
) as member_data(profile_id, role)
where organization.slug = 'club-sandwich';

insert into public.concerts (
  id,
  organization_id,
  artist,
  concert_date,
  venue_id,
  created_by
)
select
  '91000000-0000-0000-0000-000000000001'::uuid,
  organization.id,
  'Cycle flexible',
  '2026-12-10'::date,
  venue.id,
  '90000000-0000-0000-0000-000000000002'::uuid
from public.organizations organization
cross join lateral (
  select id from public.venues order by name limit 1
) venue
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (
  concert_id,
  user_id,
  status,
  team_role
)
values
  (
    '91000000-0000-0000-0000-000000000001',
    '90000000-0000-0000-0000-000000000003',
    'selected',
    'team_leader'
  ),
  (
    '91000000-0000-0000-0000-000000000001',
    '90000000-0000-0000-0000-000000000004',
    'selected',
    'logistics'
  ),
  (
    '91000000-0000-0000-0000-000000000001',
    '90000000-0000-0000-0000-000000000005',
    'selected',
    'communication'
  );

update public.concert_volunteers
set
  role_acknowledged_at = clock_timestamp(),
  confirmation_status = 'confirmed'
where concert_id = '91000000-0000-0000-0000-000000000001';

update public.concert_volunteers
set attendance_status = 'present'
where concert_id = '91000000-0000-0000-0000-000000000001';

select results_eq(
  $$
    select maraude_status::text
    from public.concerts
    where id = '91000000-0000-0000-0000-000000000001'
  $$,
  array['open'::text],
  'Une maraude existante est ouverte par défaut'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

select throws_ok(
  $$
    select public.set_maraude_status(
      '91000000-0000-0000-0000-000000000001',
      'in_progress',
      null
    )
  $$,
  '42501',
  'Concert inaccessible',
  'Un bénévole ne modifie pas le cycle'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.start_maraude(
      '91000000-0000-0000-0000-000000000001'
    )
  $$,
  'L’administrateur démarre avec un chef confirmé et présent'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = '91000000-0000-0000-0000-000000000001'
      and maraude_status = 'in_progress'
      and actual_start_at is not null
      and actual_end_at is null
  $$,
  array[1::bigint],
  'Le démarrage renseigne l’heure réelle'
);

select lives_ok(
  $$
    select public.complete_maraude(
      '91000000-0000-0000-0000-000000000001'
    )
  $$,
  'La maraude peut être clôturée'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = '91000000-0000-0000-0000-000000000001'
      and maraude_status = 'completed'
      and actual_start_at is not null
      and actual_end_at >= actual_start_at
  $$,
  array[1::bigint],
  'La clôture conserve des dates chronologiques'
);

select throws_ok(
  $$
    select public.set_maraude_status(
      '91000000-0000-0000-0000-000000000001',
      'in_progress',
      null
    )
  $$,
  '22023',
  'Cette maraude ne peut pas être démarrée',
  'Une maraude clôturée ne peut pas être rouverte'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = '91000000-0000-0000-0000-000000000001'
      and maraude_status = 'completed'
      and actual_start_at is not null
      and actual_end_at is not null
  $$,
  array[1::bigint],
  'Le refus de réouverture conserve la clôture'
);

select throws_ok(
  $$
    select public.set_maraude_status(
      '91000000-0000-0000-0000-000000000001',
      'open',
      null
    )
  $$,
  '22023',
  'Une maraude archivée ne peut plus changer d''état',
  'Une maraude clôturée ne revient pas à Ouverte'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = '91000000-0000-0000-0000-000000000001'
      and maraude_status = 'completed'
      and actual_start_at is not null
      and actual_end_at is not null
  $$,
  array[1::bigint],
  'Les dates réelles restent conservées'
);

select throws_ok(
  $$
    select public.set_maraude_status(
      '91000000-0000-0000-0000-000000000001',
      'team_ready',
      null
    )
  $$,
  '22023',
  'Une maraude archivée ne peut plus changer d''état',
  'Une maraude clôturée ne revient pas à Équipe prête'
);

select throws_ok(
  $$
    select public.set_maraude_status(
      '91000000-0000-0000-0000-000000000001',
      'cancelled',
      'Concert annulé'
    )
  $$,
  '22023',
  'Une maraude archivée ne peut plus changer d''état',
  'Une maraude clôturée ne peut plus être annulée'
);

select results_eq(
  $$
    select maraude_status::text, cancellation_reason
    from public.concerts
    where id = '91000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('completed'::text, null::text) $$,
  'La clôture reste la source de vérité'
);

reset role;

select throws_ok(
  $$
    update public.concerts
    set
      actual_start_at = '2026-12-10 22:00:00+01',
      actual_end_at = '2026-12-10 21:00:00+01'
    where id = '91000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'new row for relation "concerts" violates check constraint "concerts_maraude_dates_are_coherent"',
  'La fin ne peut pas précéder le début'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = '91000000-0000-0000-0000-000000000001'
  $$,
  array[1::bigint],
  'Le cycle ne supprime jamais la maraude'
);

select * from finish();

rollback;
