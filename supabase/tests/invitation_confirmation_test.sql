begin;

create extension if not exists pgtap with schema extensions;

select plan(16);

select has_column(
  'public',
  'invitation_applications',
  'confirmation_status',
  'La candidature retenue porte un statut de confirmation distinct'
);

select has_column(
  'public',
  'invitation_applications',
  'confirmation_due_at',
  'Un délai de confirmation est attribué'
);

select has_function(
  'public',
  'confirm_invitation_application',
  array['uuid'],
  'Le bénévole dispose d’une action sécurisée de confirmation'
);

select has_function(
  'private',
  'expire_overdue_invitation_confirmations',
  array[]::text[],
  'Les invitations non confirmées à temps peuvent expirer automatiquement'
);

select results_eq(
  $$
    select count(*)::bigint
    from cron.job
    where jobname = 'expire-invitation-confirmations'
      and schedule = '*/5 * * * *'
  $$,
  array[1::bigint],
  'L’expiration des confirmations est planifiée automatiquement'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '91000000-0000-0000-0000-000000000001',
    'invite-confirm-admin@example.test',
    '{"first_name":"Confirm","last_name":"Admin"}'::jsonb
  ),
  (
    '91000000-0000-0000-0000-000000000002',
    'invite-confirm-volunteer@example.test',
    '{"first_name":"Confirm","last_name":"Bénévole"}'::jsonb
  ),
  (
    '91000000-0000-0000-0000-000000000003',
    'invite-confirm-other@example.test',
    '{"first_name":"Autre","last_name":"Bénévole"}'::jsonb
  );

insert into public.user_accounts (
  profile_id, role, organization_id, status, activated_at
)
values
  (
    '91000000-0000-0000-0000-000000000001',
    'admin', null, 'active', now()
  ),
  (
    '91000000-0000-0000-0000-000000000002',
    'volunteer', null, 'active', now()
  ),
  (
    '91000000-0000-0000-0000-000000000003',
    'volunteer', null, 'active', now()
  );

insert into public.organizations (id, name, slug, kind)
values (
  '92000000-0000-0000-0000-000000000001',
  'Tourneur confirmation',
  'tourneur-confirmation',
  'producer'
);

insert into public.venues (
  id, name, public_address_line1, postal_code, city
)
values (
  '97000000-0000-0000-0000-000000000001',
  'Salle confirmation',
  '1 rue de la confirmation',
  '75001',
  'Paris'
);

insert into public.concerts (
  id, organization_id, artist, concert_date, venue_id, created_by
)
select
  credit_concert.id,
  organization.id,
  credit_concert.artist,
  credit_concert.concert_date,
  '97000000-0000-0000-0000-000000000001',
  '91000000-0000-0000-0000-000000000001'
from public.organizations organization
cross join (
  values
    ('98000000-0000-0000-0000-000000000001'::uuid, 'C1', '2026-03-01'::date),
    ('98000000-0000-0000-0000-000000000002'::uuid, 'C2', '2026-03-02'::date),
    ('98000000-0000-0000-0000-000000000003'::uuid, 'C3', '2026-03-03'::date)
) as credit_concert(id, artist, concert_date)
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (id, concert_id, user_id, status)
select
  gen_random_uuid(),
  concert.id,
  '91000000-0000-0000-0000-000000000002',
  'pending'
from public.concerts concert
where concert.id in (
  '98000000-0000-0000-0000-000000000001',
  '98000000-0000-0000-0000-000000000002',
  '98000000-0000-0000-0000-000000000003'
);

insert into public.volunteer_credits (
  concert_id, application_id, user_id, awarded_by
)
select
  application.concert_id,
  application.id,
  application.user_id,
  '91000000-0000-0000-0000-000000000001'
from public.concert_volunteers application
where application.user_id = '91000000-0000-0000-0000-000000000002';

insert into public.invitation_campaigns (
  id, organization_id, venue_id, title, available_places, status, created_by
)
values (
  '94000000-0000-0000-0000-000000000001',
  '92000000-0000-0000-0000-000000000001',
  '97000000-0000-0000-0000-000000000001',
  'Campagne confirmation',
  5,
  'open',
  '91000000-0000-0000-0000-000000000001'
);

insert into public.invitation_applications (id, campaign_id, user_id)
values (
  '95000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000001',
  '91000000-0000-0000-0000-000000000002'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000002',
  true
);

select throws_ok(
  $$
    select public.confirm_invitation_application(
      '95000000-0000-0000-0000-000000000001'
    )
  $$,
  '22023',
  'Aucune invitation à confirmer',
  'Une candidature encore en attente ne peut pas être confirmée'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.set_invitation_application_status(
      '95000000-0000-0000-0000-000000000001',
      'selected'
    )
  $$,
  'L’administrateur attribue l’invitation, ouvrant la fenêtre de confirmation'
);

select results_eq(
  $$
    select confirmation_status::text
    from public.invitation_applications
    where id = '95000000-0000-0000-0000-000000000001'
  $$,
  array['pending'::text],
  'La candidature attend la confirmation du bénévole'
);

select isnt_empty(
  $$
    select confirmation_due_at
    from public.invitation_applications
    where id = '95000000-0000-0000-0000-000000000001'
      and confirmation_due_at is not null
  $$,
  'Un délai de confirmation est enregistré'
);

reset role;

select is(
  (
    select count(*)::bigint
    from public.user_notifications
    where user_id = '91000000-0000-0000-0000-000000000002'
      and notification_type = 'invitation_selected'
  ),
  1::bigint,
  'Le bénévole est notifié qu’il doit confirmer son invitation'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000003',
  true
);

select throws_ok(
  $$
    select public.confirm_invitation_application(
      '95000000-0000-0000-0000-000000000001'
    )
  $$,
  '22023',
  'Aucune invitation à confirmer',
  'Un autre bénévole ne peut pas confirmer cette invitation'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.confirm_invitation_application(
      '95000000-0000-0000-0000-000000000001'
    )
  $$,
  'Le bénévole confirme sa participation'
);

select results_eq(
  $$
    select status::text, confirmation_status::text
    from public.invitation_applications
    where id = '95000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('selected'::text, 'confirmed'::text) $$,
  'L’invitation est validée après confirmation'
);

reset role;
update public.invitation_applications
set confirmation_status = 'pending'::public.volunteer_confirmation_status,
  confirmation_responded_at = null,
  confirmation_due_at = clock_timestamp() - interval '1 minute'
where id = '95000000-0000-0000-0000-000000000001';

select is(
  private.expire_overdue_invitation_confirmations(),
  1,
  'L’expiration automatique traite l’invitation en retard'
);

select results_eq(
  $$
    select status::text, confirmation_status
    from public.invitation_applications
    where id = '95000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('not_selected'::text, null::public.volunteer_confirmation_status) $$,
  'La place est libérée faute de confirmation dans les temps'
);

select is(
  (
    select count(*)::bigint
    from public.user_notifications
    where user_id = '91000000-0000-0000-0000-000000000002'
      and notification_type = 'invitation_not_selected'
  ),
  1::bigint,
  'Le bénévole est informé de la perte de son invitation non confirmée'
);

select * from finish();

rollback;
