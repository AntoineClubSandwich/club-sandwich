begin;

create extension if not exists pgtap with schema extensions;

select plan(10);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '81000000-0000-0000-0000-000000000001',
    'overview-admin@example.test',
    '{"first_name":"Admin","last_name":"Overview"}'
  ),
  (
    '81000000-0000-0000-0000-000000000002',
    'overview-promoter-a@example.test',
    '{"first_name":"Tourneur","last_name":"A"}'
  ),
  (
    '81000000-0000-0000-0000-000000000003',
    'overview-promoter-b@example.test',
    '{"first_name":"Tourneur","last_name":"B"}'
  ),
  (
    '81000000-0000-0000-0000-000000000004',
    'overview-volunteer@example.test',
    '{"first_name":"Bénévole","last_name":"Overview"}'
  );

insert into public.organizations (id, name, slug, kind)
values
  (
    '82000000-0000-0000-0000-000000000001',
    'Overview Tourneur A',
    'overview-tourneur-a',
    'producer'
  ),
  (
    '82000000-0000-0000-0000-000000000002',
    'Overview Tourneur B',
    'overview-tourneur-b',
    'producer'
  );

insert into public.user_accounts (
  profile_id,
  role,
  organization_id,
  status,
  activated_at
)
values
  (
    '81000000-0000-0000-0000-000000000001',
    'admin',
    null,
    'active',
    now()
  ),
  (
    '81000000-0000-0000-0000-000000000002',
    'promoter',
    '82000000-0000-0000-0000-000000000001',
    'active',
    now()
  ),
  (
    '81000000-0000-0000-0000-000000000003',
    'promoter',
    '82000000-0000-0000-0000-000000000002',
    'active',
    now()
  ),
  (
    '81000000-0000-0000-0000-000000000004',
    'volunteer',
    null,
    'active',
    now()
  );

insert into public.concerts (
  id,
  organization_id,
  promoter_organization_id,
  artist,
  concert_date,
  venue_id,
  maraude_status,
  created_by
)
select
  concert_data.id,
  club.id,
  concert_data.promoter_organization_id,
  concert_data.artist,
  concert_data.concert_date,
  venue.id,
  concert_data.maraude_status::public.maraude_status,
  concert_data.created_by
from public.organizations club
cross join lateral (
  select id
  from public.venues
  where is_active
  order by name
  limit 1
) venue
cross join (
  values
    (
      '83000000-0000-0000-0000-000000000001'::uuid,
      '82000000-0000-0000-0000-000000000001'::uuid,
      'Ouverte A',
      '2026-10-01'::date,
      'open',
      '81000000-0000-0000-0000-000000000002'::uuid
    ),
    (
      '83000000-0000-0000-0000-000000000002'::uuid,
      '82000000-0000-0000-0000-000000000001'::uuid,
      'Brouillon A',
      '2026-10-02'::date,
      'draft',
      '81000000-0000-0000-0000-000000000002'::uuid
    ),
    (
      '83000000-0000-0000-0000-000000000003'::uuid,
      '82000000-0000-0000-0000-000000000002'::uuid,
      'Ouverte B',
      '2026-10-03'::date,
      'open',
      '81000000-0000-0000-0000-000000000003'::uuid
    )
) as concert_data(
  id,
  promoter_organization_id,
  artist,
  concert_date,
  maraude_status,
  created_by
)
where club.slug = 'club-sandwich';

insert into public.concert_volunteers (
  id,
  concert_id,
  user_id,
  status,
  team_role
)
values (
  '84000000-0000-0000-0000-000000000001',
  '83000000-0000-0000-0000-000000000002',
  '81000000-0000-0000-0000-000000000004',
  'selected',
  'logistics'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    insert into public.concerts (
      id,
      organization_id,
      promoter_organization_id,
      artist,
      concert_date,
      venue_id,
      created_by
    )
    select
      '83000000-0000-0000-0000-000000000004',
      club.id,
      '82000000-0000-0000-0000-000000000001',
      'Créée par admin pour A',
      '2026-10-04',
      venue.id,
      '81000000-0000-0000-0000-000000000001'
    from public.organizations club
    cross join lateral (
      select id
      from public.venues
      where is_active
      order by name
      limit 1
    ) venue
    where club.slug = 'club-sandwich'
  $$,
  'Un admin rattache une nouvelle maraude à une organisation tourneur'
);

select is(
  (select count(*) from public.get_maraude_overview(100)),
  4::bigint,
  'L’administrateur voit toutes les maraudes'
);

select is(
  (
    select count(*)
    from public.get_maraude_overview(100)
    where is_admin
  ),
  4::bigint,
  'La vue identifie correctement l’administrateur'
);

select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$
    select artist
    from public.get_maraude_overview(100)
    order by artist
  $$,
  $$
    values
      ('Brouillon A'::text),
      ('Créée par admin pour A'::text),
      ('Ouverte A'::text)
  $$,
  'Le tourneur voit aussi la maraude admin rattachée à son organisation'
);

select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000003',
  true
);

select results_eq(
  $$
    select artist
    from public.get_maraude_overview(100)
  $$,
  $$ values ('Ouverte B'::text) $$,
  'Le second tourneur ne voit que sa propre organisation'
);

select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000004',
  true
);

select is(
  (select count(*) from public.get_maraude_overview(100)),
  4::bigint,
  'Le bénévole voit toutes les maraudes ouvertes et son historique'
);

select results_eq(
  $$
    select artist
    from public.get_maraude_overview(100)
    where maraude_status = 'open'
    order by artist
  $$,
  $$
    values
      ('Créée par admin pour A'::text),
      ('Ouverte A'::text),
      ('Ouverte B'::text)
  $$,
  'Le bénévole voit les maraudes ouvertes sans candidature'
);

select results_eq(
  $$
    select own_status::text, own_team_role::text
    from public.get_maraude_overview(100)
    where concert_id = '83000000-0000-0000-0000-000000000002'
  $$,
  $$ values ('selected'::text, 'logistics'::text) $$,
  'La candidature existante conserve son statut et son rôle'
);

select is(
  (
    select count(*)
    from public.get_maraude_overview(100)
    where concert_id in (
      '83000000-0000-0000-0000-000000000001',
      '83000000-0000-0000-0000-000000000003'
    )
      and own_status is null
      and own_team_role is null
  ),
  2::bigint,
  'Les maraudes sans candidature renvoient des champs personnels nuls'
);

reset role;
update public.user_accounts
set status = 'disabled', disabled_at = now()
where profile_id = '81000000-0000-0000-0000-000000000004';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000004',
  true
);

select is(
  (select count(*) from public.get_maraude_overview(100)),
  0::bigint,
  'Un compte bénévole désactivé ne voit aucune maraude'
);

select * from finish();

rollback;
