begin;

create extension if not exists pgtap with schema extensions;

select plan(7);

select has_column(
  'public',
  'invitation_applications',
  'plus_one',
  'Une candidature peut indiquer la venue d’un accompagnant'
);

select has_column(
  'public',
  'invitation_applications',
  'plus_one_name',
  'Le nom de l’accompagnant peut être renseigné'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '61000000-0000-0000-0000-000000000001',
    'plusone-admin@example.test',
    '{"first_name":"PlusOne","last_name":"Admin"}'::jsonb
  ),
  (
    '61000000-0000-0000-0000-000000000002',
    'plusone-volunteer-a@example.test',
    '{"first_name":"PlusOne","last_name":"A"}'::jsonb
  ),
  (
    '61000000-0000-0000-0000-000000000003',
    'plusone-volunteer-b@example.test',
    '{"first_name":"PlusOne","last_name":"B"}'::jsonb
  );

insert into public.user_accounts (
  profile_id, role, organization_id, status, activated_at
)
values
  (
    '61000000-0000-0000-0000-000000000001',
    'admin', null, 'active', now()
  ),
  (
    '61000000-0000-0000-0000-000000000002',
    'volunteer', null, 'active', now()
  ),
  (
    '61000000-0000-0000-0000-000000000003',
    'volunteer', null, 'active', now()
  );

insert into public.organizations (id, name, slug, kind)
values (
  '62000000-0000-0000-0000-000000000001',
  'Tourneur plus one',
  'tourneur-plus-one',
  'producer'
);

insert into public.venues (
  id, name, public_address_line1, postal_code, city
)
values (
  '67000000-0000-0000-0000-000000000001',
  'Salle plus one',
  '1 rue du plus one',
  '75001',
  'Paris'
);

-- Both applicants earn exactly 3 active credits.
insert into public.concerts (
  id, organization_id, artist, concert_date, venue_id, created_by
)
select
  credit_concert.id,
  organization.id,
  credit_concert.artist,
  credit_concert.concert_date,
  '67000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
from public.organizations organization
cross join (
  values
    ('68000000-0000-0000-0000-000000000001'::uuid, 'C1', '2026-04-01'::date),
    ('68000000-0000-0000-0000-000000000002'::uuid, 'C2', '2026-04-02'::date),
    ('68000000-0000-0000-0000-000000000003'::uuid, 'C3', '2026-04-03'::date)
) as credit_concert(id, artist, concert_date)
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (id, concert_id, user_id, status)
select
  gen_random_uuid(),
  concert.id,
  applicant.user_id,
  'pending'
from public.concerts concert
cross join (
  values
    ('61000000-0000-0000-0000-000000000002'::uuid),
    ('61000000-0000-0000-0000-000000000003'::uuid)
) as applicant(user_id)
where concert.id in (
  '68000000-0000-0000-0000-000000000001',
  '68000000-0000-0000-0000-000000000002',
  '68000000-0000-0000-0000-000000000003'
);

insert into public.volunteer_credits (
  concert_id, application_id, user_id, awarded_by
)
select
  application.concert_id,
  application.id,
  application.user_id,
  '61000000-0000-0000-0000-000000000001'
from public.concert_volunteers application;

insert into public.invitation_campaigns (
  id, organization_id, venue_id, title, available_places, status, created_by
)
values (
  '64000000-0000-0000-0000-000000000001',
  '62000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  'Campagne plus one',
  2,
  'open',
  '61000000-0000-0000-0000-000000000001'
);

insert into public.invitation_applications (
  id, campaign_id, user_id, plus_one, plus_one_name
)
values
  (
    '65000000-0000-0000-0000-000000000001',
    '64000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000002',
    true,
    'Invité de A'
  ),
  (
    '65000000-0000-0000-0000-000000000002',
    '64000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000003',
    false,
    null
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '61000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.set_invitation_application_status(
      '65000000-0000-0000-0000-000000000001',
      'selected'
    )
  $$,
  'L’administrateur attribue une invitation avec +1, consommant deux places'
);

select throws_ok(
  $$
    select public.set_invitation_application_status(
      '65000000-0000-0000-0000-000000000002',
      'selected'
    )
  $$,
  '22023',
  'Toutes les places ont déjà été attribuées',
  'Le +1 a saturé le quota de 2 places, aucune attribution supplémentaire n’est possible'
);

update public.invitation_campaigns
set available_places = 3
where id = '64000000-0000-0000-0000-000000000001';

select lives_ok(
  $$
    select public.set_invitation_application_status(
      '65000000-0000-0000-0000-000000000002',
      'selected'
    )
  $$,
  'Une place supplémentaire permet d’attribuer un second bénévole sans +1'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '61000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.confirm_invitation_application(
      '65000000-0000-0000-0000-000000000001'
    )
  $$,
  'Le +1 ne bloque pas la confirmation du bénévole titulaire'
);

reset role;

select results_eq(
  $$
    select count(*)::bigint
    from public.volunteer_credits
    where user_id = '61000000-0000-0000-0000-000000000002'
      and status = 'consumed'
  $$,
  array[3::bigint],
  'Le +1 ne coûte aucun crédit supplémentaire : trois crédits sont consommés, pas six'
);

select * from finish();

rollback;
