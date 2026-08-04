begin;

create extension if not exists pgtap with schema extensions;

select plan(13);

select has_column(
  'public',
  'volunteer_credits',
  'consumed_by_invitation_application_id',
  'Un crédit consommé référence l’invitation qui l’a utilisé'
);

select has_column(
  'public',
  'volunteer_credits',
  'consumed_at',
  'La date de consommation est tracée'
);

select has_function(
  'public',
  'get_my_volunteer_credit_summary',
  array[]::text[],
  'Le bénévole peut consulter son solde gagné/consommé/disponible'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '81000000-0000-0000-0000-000000000001',
    'credit-admin@example.test',
    '{"first_name":"Credit","last_name":"Admin"}'::jsonb
  ),
  (
    '81000000-0000-0000-0000-000000000002',
    'credit-volunteer@example.test',
    '{"first_name":"Credit","last_name":"Bénévole"}'::jsonb
  ),
  (
    '81000000-0000-0000-0000-000000000003',
    'credit-short@example.test',
    '{"first_name":"Solde","last_name":"Insuffisant"}'::jsonb
  );

insert into public.user_accounts (
  profile_id, role, organization_id, status, activated_at
)
values
  (
    '81000000-0000-0000-0000-000000000001',
    'admin', null, 'active', now()
  ),
  (
    '81000000-0000-0000-0000-000000000002',
    'volunteer', null, 'active', now()
  ),
  (
    '81000000-0000-0000-0000-000000000003',
    'volunteer', null, 'active', now()
  );

insert into public.organizations (id, name, slug, kind)
values (
  '82000000-0000-0000-0000-000000000001',
  'Tourneur crédits',
  'tourneur-credits',
  'producer'
);

insert into public.venues (
  id, name, public_address_line1, postal_code, city
)
values (
  '87000000-0000-0000-0000-000000000001',
  'Salle crédits',
  '1 rue des crédits',
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
  '87000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000001'
from public.organizations organization
cross join (
  values
    ('88000000-0000-0000-0000-000000000001'::uuid, 'C1', '2026-02-01'::date),
    ('88000000-0000-0000-0000-000000000002'::uuid, 'C2', '2026-02-02'::date),
    ('88000000-0000-0000-0000-000000000003'::uuid, 'C3', '2026-02-03'::date)
) as credit_concert(id, artist, concert_date)
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (id, concert_id, user_id, status)
values
  (
    '89000000-0000-0000-0000-000000000001',
    '88000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000002',
    'pending'
  ),
  (
    '89000000-0000-0000-0000-000000000002',
    '88000000-0000-0000-0000-000000000002',
    '81000000-0000-0000-0000-000000000002',
    'pending'
  ),
  (
    '89000000-0000-0000-0000-000000000003',
    '88000000-0000-0000-0000-000000000003',
    '81000000-0000-0000-0000-000000000002',
    'pending'
  ),
  (
    '89000000-0000-0000-0000-000000000004',
    '88000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000003',
    'pending'
  ),
  (
    '89000000-0000-0000-0000-000000000005',
    '88000000-0000-0000-0000-000000000002',
    '81000000-0000-0000-0000-000000000003',
    'pending'
  ),
  (
    '89000000-0000-0000-0000-000000000006',
    '88000000-0000-0000-0000-000000000003',
    '81000000-0000-0000-0000-000000000003',
    'pending'
  );

insert into public.volunteer_credits (
  concert_id, application_id, user_id, awarded_by
)
values
  (
    '88000000-0000-0000-0000-000000000001',
    '89000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000002',
    '81000000-0000-0000-0000-000000000001'
  ),
  (
    '88000000-0000-0000-0000-000000000002',
    '89000000-0000-0000-0000-000000000002',
    '81000000-0000-0000-0000-000000000002',
    '81000000-0000-0000-0000-000000000001'
  ),
  (
    '88000000-0000-0000-0000-000000000003',
    '89000000-0000-0000-0000-000000000003',
    '81000000-0000-0000-0000-000000000002',
    '81000000-0000-0000-0000-000000000001'
  ),
  (
    '88000000-0000-0000-0000-000000000001',
    '89000000-0000-0000-0000-000000000004',
    '81000000-0000-0000-0000-000000000003',
    '81000000-0000-0000-0000-000000000001'
  ),
  (
    '88000000-0000-0000-0000-000000000002',
    '89000000-0000-0000-0000-000000000005',
    '81000000-0000-0000-0000-000000000003',
    '81000000-0000-0000-0000-000000000001'
  ),
  (
    '88000000-0000-0000-0000-000000000003',
    '89000000-0000-0000-0000-000000000006',
    '81000000-0000-0000-0000-000000000003',
    '81000000-0000-0000-0000-000000000001'
  );

insert into public.invitation_campaigns (
  id, organization_id, venue_id, title, available_places, status, created_by
)
values (
  '84000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  '87000000-0000-0000-0000-000000000001',
  'Campagne crédits',
  5,
  'open',
  '81000000-0000-0000-0000-000000000001'
);

insert into public.invitation_applications (id, campaign_id, user_id)
values
  (
    '85000000-0000-0000-0000-000000000001',
    '84000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000002'
  ),
  (
    '85000000-0000-0000-0000-000000000002',
    '84000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000003'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.set_invitation_application_status(
      '85000000-0000-0000-0000-000000000001',
      'selected'
    )
  $$,
  'L’administrateur attribue l’invitation à un bénévole disposant de 3 crédits'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.volunteer_credits
    where user_id = '81000000-0000-0000-0000-000000000002'
      and status = 'consumed'
  $$,
  array[0::bigint],
  'Aucun crédit n’est consommé avant la confirmation du bénévole'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000002',
  true
);

select lives_ok(
  $$
    select public.confirm_invitation_application(
      '85000000-0000-0000-0000-000000000001'
    )
  $$,
  'Le bénévole confirme son invitation attribuée'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.volunteer_credits
    where user_id = '81000000-0000-0000-0000-000000000002'
      and status = 'consumed'
      and consumed_by_invitation_application_id =
        '85000000-0000-0000-0000-000000000001'
  $$,
  array[3::bigint],
  'Les trois crédits sont consommés à la confirmation de l’invitation'
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
    select public.set_invitation_application_status(
      '85000000-0000-0000-0000-000000000002',
      'selected'
    )
  $$,
  'L’administrateur attribue l’invitation à un bénévole disposant alors de 3 crédits'
);

reset role;
delete from public.volunteer_credits
where user_id = '81000000-0000-0000-0000-000000000003'
  and concert_id = '88000000-0000-0000-0000-000000000002';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000003',
  true
);

select throws_ok(
  $$
    select public.confirm_invitation_application(
      '85000000-0000-0000-0000-000000000002'
    )
  $$,
  '22023',
  'Crédits insuffisants pour confirmer cette invitation',
  'Un solde de crédits insuffisant bloque la confirmation même après attribution'
);

select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.set_invitation_application_status(
      '85000000-0000-0000-0000-000000000001',
      'not_selected'
    )
  $$,
  'L’administrateur revient sur une attribution déjà confirmée'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.volunteer_credits
    where user_id = '81000000-0000-0000-0000-000000000002'
      and status = 'active'
  $$,
  array[3::bigint],
  'Les crédits consommés sont restitués quand l’attribution est annulée'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.volunteer_credits
    where user_id = '81000000-0000-0000-0000-000000000002'
      and consumed_by_invitation_application_id is not null
  $$,
  array[0::bigint],
  'La référence à l’invitation est nettoyée après restitution'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$
    select earned, consumed, available
    from public.get_my_volunteer_credit_summary()
  $$,
  $$ values (3::bigint, 0::bigint, 3::bigint) $$,
  'Le résumé reflète le solde restitué du bénévole'
);

select * from finish();

rollback;
