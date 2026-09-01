begin;

create extension if not exists pgtap with schema extensions;

select plan(10);

select has_trigger(
  'public',
  'concerts',
  'concerts_reset_team_on_schedule_change',
  'Un changement de date/heure de la maraude déclenche une remise à zéro de l’équipe'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '91000000-0000-0000-0000-000000000001',
    'sched-admin@example.test',
    '{"first_name":"Admin","last_name":"Sched"}'::jsonb
  ),
  (
    '91000000-0000-0000-0000-000000000002',
    'sched-vol-pending@example.test',
    '{"first_name":"Vol","last_name":"Pending"}'::jsonb
  ),
  (
    '91000000-0000-0000-0000-000000000003',
    'sched-vol-confirmed@example.test',
    '{"first_name":"Vol","last_name":"Confirmed"}'::jsonb
  ),
  (
    '91000000-0000-0000-0000-000000000004',
    'sched-vol-locked@example.test',
    '{"first_name":"Vol","last_name":"Locked"}'::jsonb
  );

insert into public.memberships (organization_id, profile_id, role)
select o.id, member_data.profile_id, member_data.role::public.app_role
from public.organizations o
cross join (
  values
    ('91000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('91000000-0000-0000-0000-000000000002'::uuid, 'volunteer'),
    ('91000000-0000-0000-0000-000000000003'::uuid, 'volunteer'),
    ('91000000-0000-0000-0000-000000000004'::uuid, 'volunteer')
) as member_data(profile_id, role)
where o.slug = 'club-sandwich';

insert into public.concerts (
  id, organization_id, artist, concert_date, venue_id, created_by,
  maraude_status
)
select
  '92000000-0000-0000-0000-000000000001'::uuid,
  o.id,
  'Test changement de date',
  '2026-10-15'::date,
  v.id,
  '91000000-0000-0000-0000-000000000001'::uuid,
  'open'::public.maraude_status
from public.organizations o
cross join lateral (
  select id from public.venues order by name limit 1
) v
where o.slug = 'club-sandwich';

insert into public.concert_volunteers (id, concert_id, user_id, status, team_role)
values
  (
    '93000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000001',
    '91000000-0000-0000-0000-000000000002',
    'selected',
    'logistics'
  ),
  (
    '93000000-0000-0000-0000-000000000002',
    '92000000-0000-0000-0000-000000000001',
    '91000000-0000-0000-0000-000000000003',
    'selected',
    'communication'
  ),
  (
    '93000000-0000-0000-0000-000000000003',
    '92000000-0000-0000-0000-000000000001',
    '91000000-0000-0000-0000-000000000004',
    'selected',
    'team_leader'
  );

-- The second volunteer already confirmed their participation.
update public.concert_volunteers
set role_acknowledged_at = clock_timestamp(), confirmation_status = 'confirmed'
where id = '93000000-0000-0000-0000-000000000002';

-- The third volunteer's role was locked by an admin (20260828009000) to
-- protect it from accidental bulk changes.
update public.concert_volunteers
set team_role_locked = true
where id = '93000000-0000-0000-0000-000000000003';

-- Changing the maraude's date is exactly the bug reported on preprod:
-- volunteers were left "selected" (some already confirmed) for a date
-- that no longer exists.
update public.concerts
set concert_date = '2026-11-01'
where id = '92000000-0000-0000-0000-000000000001';

select results_eq(
  $$
    select status::text, team_role, confirmation_status::text
    from public.concert_volunteers
    where id = '93000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('pending'::text, null::public.maraude_role, null::text) $$,
  'La sélection en attente de confirmation est annulée par le changement de date'
);

select results_eq(
  $$
    select status::text, team_role, confirmation_status::text
    from public.concert_volunteers
    where id = '93000000-0000-0000-0000-000000000002'
  $$,
  $$ values ('pending'::text, null::public.maraude_role, null::text) $$,
  'La sélection déjà confirmée est elle aussi annulée par le changement de date'
);

select results_eq(
  $$
    select status::text, team_role, confirmation_status::text, team_role_locked
    from public.concert_volunteers
    where id = '93000000-0000-0000-0000-000000000003'
  $$,
  $$ values ('selected'::text, 'team_leader'::public.maraude_role, 'pending'::text, true) $$,
  'Un rôle verrouillé n’est pas touché par le changement de date'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_workflow_events
    where concert_id = '92000000-0000-0000-0000-000000000001'
      and event_type = 'schedule_changed'
  $$,
  array[2::bigint],
  'Un événement schedule_changed est journalisé pour chaque bénévole désélectionné'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.user_notifications
    where concert_id = '92000000-0000-0000-0000-000000000001'
      and notification_type = 'schedule_changed'
      and user_id in (
        '91000000-0000-0000-0000-000000000002',
        '91000000-0000-0000-0000-000000000003'
      )
  $$,
  array[2::bigint],
  'Les bénévoles désélectionnés sont notifiés du changement de date'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.user_notifications
    where concert_id = '92000000-0000-0000-0000-000000000001'
      and notification_type = 'schedule_changed'
      and user_id = '91000000-0000-0000-0000-000000000004'
  $$,
  array[0::bigint],
  'Le bénévole au rôle verrouillé n’est pas notifié puisqu’il n’a pas été désélectionné'
);

-- A field unrelated to the schedule must not touch anyone.
update public.concerts
set notes = 'note administrative'
where id = '92000000-0000-0000-0000-000000000001';

select results_eq(
  $$
    select status::text
    from public.concert_volunteers
    where id = '93000000-0000-0000-0000-000000000003'
  $$,
  array['selected'::text],
  'Modifier un champ sans lien avec la date ne touche pas l’équipe'
);

-- Once the maraude has started, a (theoretical) date correction must not
-- retroactively unselect an active team. Created directly as in_progress
-- since the transition itself is separately guarded (require_complete_
-- team_before_start) and irrelevant to what's under test here.
insert into public.concerts (
  id, organization_id, artist, concert_date, venue_id, created_by,
  maraude_status
)
select
  '92000000-0000-0000-0000-000000000002'::uuid,
  o.id,
  'Test maraude déjà démarrée',
  '2026-10-20'::date,
  v.id,
  '91000000-0000-0000-0000-000000000001'::uuid,
  'in_progress'::public.maraude_status
from public.organizations o
cross join lateral (
  select id from public.venues order by name limit 1
) v
where o.slug = 'club-sandwich';

insert into public.concert_volunteers (id, concert_id, user_id, status, team_role)
values (
  '93000000-0000-0000-0000-000000000004',
  '92000000-0000-0000-0000-000000000002',
  '91000000-0000-0000-0000-000000000002',
  'selected',
  'logistics'
);

update public.concerts
set concert_date = '2026-10-21'
where id = '92000000-0000-0000-0000-000000000002';

select results_eq(
  $$
    select status::text
    from public.concert_volunteers
    where id = '93000000-0000-0000-0000-000000000004'
  $$,
  array['selected'::text],
  'Une maraude déjà démarrée n’a plus son équipe réinitialisée par un changement de date'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_workflow_events
    where concert_id = '92000000-0000-0000-0000-000000000002'
      and event_type = 'schedule_changed'
  $$,
  array[0::bigint],
  'Aucun événement schedule_changed n’est journalisé une fois la maraude démarrée'
);

select * from finish();

rollback;
