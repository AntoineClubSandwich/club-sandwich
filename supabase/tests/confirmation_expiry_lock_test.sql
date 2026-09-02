begin;

create extension if not exists pgtap with schema extensions;

select plan(4);

-- Live crash on preprod: an overdue, still-pending, locked selection
-- made expire_overdue_volunteer_confirmations() abort mid-loop (the
-- update it issues hit protect_locked_team_role's guard), breaking
-- every caller - including fetchSection(), called on every load of the
-- "Équipe" tab, and the */5 * * * * cron job.

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    'a1000000-0000-0000-0000-000000000001',
    'expiry-admin@example.test',
    '{"first_name":"Admin","last_name":"Expiry"}'::jsonb
  ),
  (
    'a1000000-0000-0000-0000-000000000002',
    'expiry-locked@example.test',
    '{"first_name":"Locked","last_name":"Expiry"}'::jsonb
  ),
  (
    'a1000000-0000-0000-0000-000000000003',
    'expiry-unlocked@example.test',
    '{"first_name":"Unlocked","last_name":"Expiry"}'::jsonb
  );

insert into public.memberships (organization_id, profile_id, role)
select o.id, m.profile_id, m.role::public.app_role
from public.organizations o
cross join (
  values
    ('a1000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('a1000000-0000-0000-0000-000000000002'::uuid, 'volunteer'),
    ('a1000000-0000-0000-0000-000000000003'::uuid, 'volunteer')
) as m(profile_id, role)
where o.slug = 'club-sandwich';

insert into public.concerts (
  id, organization_id, artist, concert_date, venue_id, created_by
)
select
  'a2000000-0000-0000-0000-000000000001'::uuid,
  o.id,
  'Test expiration verrouillée',
  '2026-11-21'::date,
  v.id,
  'a1000000-0000-0000-0000-000000000001'::uuid
from public.organizations o
cross join lateral (
  select id from public.venues order by name limit 1
) v
where o.slug = 'club-sandwich';

insert into public.concert_volunteers (
  id, concert_id, user_id, status, team_role, team_role_locked
)
values
  (
    'a3000000-0000-0000-0000-000000000001',
    'a2000000-0000-0000-0000-000000000001',
    'a1000000-0000-0000-0000-000000000002',
    'selected',
    'team_leader',
    true
  ),
  (
    'a3000000-0000-0000-0000-000000000002',
    'a2000000-0000-0000-0000-000000000001',
    'a1000000-0000-0000-0000-000000000003',
    'selected',
    'logistics',
    false
  );

update public.concert_volunteers
set confirmation_due_at = clock_timestamp() - interval '1 hour'
where concert_id = 'a2000000-0000-0000-0000-000000000001';

select lives_ok(
  $$ select private.expire_overdue_volunteer_confirmations() $$,
  'L’expiration ne plante plus sur une place verrouillée en retard'
);

select results_eq(
  $$
    select status::text, confirmation_status::text
    from public.concert_volunteers
    where id = 'a3000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('selected'::text, 'pending'::text) $$,
  'La place verrouillée n’est pas libérée automatiquement'
);

select results_eq(
  $$
    select status::text
    from public.concert_volunteers
    where id = 'a3000000-0000-0000-0000-000000000002'
  $$,
  array['pending'::text],
  'La place non verrouillée expire normalement'
);

select is(
  (
    select count(*)::bigint
    from public.maraude_workflow_events
    where application_id = 'a3000000-0000-0000-0000-000000000001'
      and event_type = 'confirmation_expired'
  ),
  0::bigint,
  'Aucun événement d’expiration n’est journalisé pour la place verrouillée'
);

select * from finish();

rollback;
