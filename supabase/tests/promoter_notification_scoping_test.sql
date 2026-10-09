begin;

create extension if not exists pgtap with schema extensions;

select plan(11);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    'f0000000-0000-0000-0000-000000000001',
    'promonotif-admin@example.test',
    '{"first_name":"Admin","last_name":"Notif"}'::jsonb
  ),
  (
    'f0000000-0000-0000-0000-000000000002',
    'promonotif-creator@example.test',
    '{"first_name":"Tourneur","last_name":"Createur"}'::jsonb
  ),
  (
    'f0000000-0000-0000-0000-000000000003',
    'promonotif-other@example.test',
    '{"first_name":"Tourneur","last_name":"Autre"}'::jsonb
  ),
  (
    'f0000000-0000-0000-0000-000000000004',
    'promonotif-leader@example.test',
    '{"first_name":"Chef","last_name":"Notif"}'::jsonb
  ),
  (
    'f0000000-0000-0000-0000-000000000005',
    'promonotif-member1@example.test',
    '{"first_name":"Membre1","last_name":"Notif"}'::jsonb
  ),
  (
    'f0000000-0000-0000-0000-000000000006',
    'promonotif-member2@example.test',
    '{"first_name":"Membre2","last_name":"Notif"}'::jsonb
  );

insert into public.organizations (id, name, slug, kind)
values (
  'f1000000-0000-0000-0000-000000000001',
  'Promo Notif Tourneur',
  'promo-notif-tourneur',
  'producer'
);

insert into public.memberships (organization_id, profile_id, role)
select o.id, m.profile_id, m.role::public.app_role
from public.organizations o
cross join (
  values
    ('f0000000-0000-0000-0000-000000000001'::uuid, 'admin'),
    ('f0000000-0000-0000-0000-000000000004'::uuid, 'volunteer'),
    ('f0000000-0000-0000-0000-000000000005'::uuid, 'volunteer'),
    ('f0000000-0000-0000-0000-000000000006'::uuid, 'volunteer')
) as m(profile_id, role)
where o.slug = 'club-sandwich';

insert into public.user_accounts (
  profile_id, role, organization_id, status, activated_at
)
values
  (
    'f0000000-0000-0000-0000-000000000001',
    'admin', null, 'active', now()
  ),
  (
    'f0000000-0000-0000-0000-000000000002',
    'promoter', 'f1000000-0000-0000-0000-000000000001', 'active', now()
  ),
  (
    'f0000000-0000-0000-0000-000000000003',
    'promoter', 'f1000000-0000-0000-0000-000000000001', 'active', now()
  );

-- Concert 1: created by a tourneur -> only they should hear about the
-- report, in-app only.
insert into public.concerts (
  id, organization_id, promoter_organization_id, artist,
  concert_date, venue_id, created_by, maraude_status
)
select
  'f2000000-0000-0000-0000-000000000001'::uuid,
  club.id,
  'f1000000-0000-0000-0000-000000000001'::uuid,
  'Bilan créateur tourneur',
  current_date + 40,
  venue.id,
  'f0000000-0000-0000-0000-000000000002'::uuid,
  'in_progress'::public.maraude_status
from public.organizations club
cross join lateral (
  select id from public.venues where is_active order by name limit 1
) venue
where club.slug = 'club-sandwich';

-- Concert 2: created by an admin on the org's behalf -> no single
-- tourneur to target, every active tourneur of the org hears about it.
insert into public.concerts (
  id, organization_id, promoter_organization_id, artist,
  concert_date, venue_id, created_by, maraude_status
)
select
  'f2000000-0000-0000-0000-000000000002'::uuid,
  club.id,
  'f1000000-0000-0000-0000-000000000001'::uuid,
  'Bilan créé par admin',
  current_date + 41,
  venue.id,
  'f0000000-0000-0000-0000-000000000001'::uuid,
  'in_progress'::public.maraude_status
from public.organizations club
cross join lateral (
  select id from public.venues where is_active order by name limit 1
) venue
where club.slug = 'club-sandwich';

-- Concert 3: team about to be validated, nothing filled in yet.
insert into public.concerts (
  id, organization_id, promoter_organization_id, artist,
  concert_date, venue_id, created_by, maraude_status
)
select
  'f2000000-0000-0000-0000-000000000003'::uuid,
  club.id,
  'f1000000-0000-0000-0000-000000000001'::uuid,
  'Équipe validée, rien de rempli',
  current_date + 42,
  venue.id,
  'f0000000-0000-0000-0000-000000000002'::uuid,
  'open'::public.maraude_status
from public.organizations club
cross join lateral (
  select id from public.venues where is_active order by name limit 1
) venue
where club.slug = 'club-sandwich';

-- Concert 4: same, but everything is already filled in.
insert into public.concerts (
  id, organization_id, promoter_organization_id, artist,
  concert_date, venue_id, created_by, maraude_status,
  catering_contact_name, catering_closes_at,
  promoter_contact_name, promoter_contact_phone
)
select
  'f2000000-0000-0000-0000-000000000004'::uuid,
  club.id,
  'f1000000-0000-0000-0000-000000000001'::uuid,
  'Équipe validée, tout est rempli',
  current_date + 43,
  venue.id,
  'f0000000-0000-0000-0000-000000000002'::uuid,
  'open'::public.maraude_status,
  'Traiteur Test',
  '22:00'::time,
  'Contact Test',
  '0600000000'
from public.organizations club
cross join lateral (
  select id from public.venues where is_active order by name limit 1
) venue
where club.slug = 'club-sandwich';

-- Concert 5: date change - tourneurs should no longer hear about it.
insert into public.concerts (
  id, organization_id, promoter_organization_id, artist,
  concert_date, venue_id, created_by, maraude_status
)
select
  'f2000000-0000-0000-0000-000000000005'::uuid,
  club.id,
  'f1000000-0000-0000-0000-000000000001'::uuid,
  'Changement de date',
  current_date + 44,
  venue.id,
  'f0000000-0000-0000-0000-000000000002'::uuid,
  'open'::public.maraude_status
from public.organizations club
cross join lateral (
  select id from public.venues where is_active order by name limit 1
) venue
where club.slug = 'club-sandwich';

insert into public.concert_volunteers (
  concert_id, user_id, status, team_role
)
select
  concert.id,
  volunteer.user_id,
  'selected'::public.concert_volunteer_status,
  volunteer.team_role::public.maraude_role
from (
  values
    ('f2000000-0000-0000-0000-000000000003'::uuid),
    ('f2000000-0000-0000-0000-000000000004'::uuid),
    ('f2000000-0000-0000-0000-000000000005'::uuid)
) as concert(id)
cross join (
  values
    ('f0000000-0000-0000-0000-000000000004'::uuid, 'team_leader'),
    ('f0000000-0000-0000-0000-000000000005'::uuid, 'logistics'),
    ('f0000000-0000-0000-0000-000000000006'::uuid, 'communication')
) as volunteer(user_id, team_role);

update public.concert_volunteers
set role_acknowledged_at = clock_timestamp(), confirmation_status = 'confirmed'
where concert_id in (
  'f2000000-0000-0000-0000-000000000003',
  'f2000000-0000-0000-0000-000000000004',
  'f2000000-0000-0000-0000-000000000005'
);

-- Concert 1 & 2: complète la maraude (déclenche
-- notify_completed_maraude_promoters).
update public.concerts
set maraude_status = 'completed'::public.maraude_status
where id in (
  'f2000000-0000-0000-0000-000000000001',
  'f2000000-0000-0000-0000-000000000002'
);

select results_eq(
  $$
    select user_id, send_email
    from public.user_notifications
    where concert_id = 'f2000000-0000-0000-0000-000000000001'
      and notification_type = 'maraude_report_available'
    order by user_id
  $$,
  $$ values ('f0000000-0000-0000-0000-000000000002'::uuid, false) $$,
  'Le bilan de la maraude créée par un tourneur ne va qu’à ce tourneur, sans e-mail'
);

select results_eq(
  $$
    select user_id, send_email
    from public.user_notifications
    where concert_id = 'f2000000-0000-0000-0000-000000000002'
      and notification_type = 'maraude_report_available'
    order by user_id
  $$,
  $$
    values
      ('f0000000-0000-0000-0000-000000000002'::uuid, false),
      ('f0000000-0000-0000-0000-000000000003'::uuid, false)
  $$,
  'Le bilan d’une maraude créée par un admin va à tous les tourneurs actifs de l’organisation, sans e-mail'
);

-- Concert 3 & 4: valide l'équipe (déclenche
-- notify_promoter_missing_maraude_details).
update public.concerts
set maraude_status = 'team_ready'::public.maraude_status
where id in (
  'f2000000-0000-0000-0000-000000000003',
  'f2000000-0000-0000-0000-000000000004'
);

select results_eq(
  $$
    select user_id
    from public.user_notifications
    where concert_id = 'f2000000-0000-0000-0000-000000000003'
      and notification_type = 'maraude_details_missing'
  $$,
  array['f0000000-0000-0000-0000-000000000002'::uuid],
  'Le tourneur concerné est rappelé si des informations manquent à la validation de l’équipe'
);

select matches(
  (
    select body
    from public.user_notifications
    where concert_id = 'f2000000-0000-0000-0000-000000000003'
      and notification_type = 'maraude_details_missing'
  ),
  'catering',
  'Le rappel mentionne le catering manquant'
);

select matches(
  (
    select body
    from public.user_notifications
    where concert_id = 'f2000000-0000-0000-0000-000000000003'
      and notification_type = 'maraude_details_missing'
  ),
  'contact tourneur',
  'Le rappel mentionne le contact tourneur manquant'
);

select matches(
  (
    select body
    from public.user_notifications
    where concert_id = 'f2000000-0000-0000-0000-000000000003'
      and notification_type = 'maraude_details_missing'
  ),
  'horaire',
  'Le rappel mentionne l’horaire manquant'
);

select is_empty(
  $$
    select user_id
    from public.user_notifications
    where concert_id = 'f2000000-0000-0000-0000-000000000004'
      and notification_type = 'maraude_details_missing'
  $$,
  'Aucun rappel si tout est déjà renseigné à la validation de l’équipe'
);

-- Concert 5: changement de date.
update public.concerts
set concert_date = current_date + 90
where id = 'f2000000-0000-0000-0000-000000000005';

select is_empty(
  $$
    select user_id
    from public.user_notifications
    where concert_id = 'f2000000-0000-0000-0000-000000000005'
      and notification_type = 'schedule_changed'
      and user_id in (
        'f0000000-0000-0000-0000-000000000002',
        'f0000000-0000-0000-0000-000000000003'
      )
  $$,
  'Les tourneurs ne sont plus notifiés d’un changement de date/heure/lieu'
);

-- Convention : approbation puis refus ne notifient plus les tourneurs.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f0000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.admin_set_organization_convention(
      'f1000000-0000-0000-0000-000000000001',
      'conventions/promo-notif-tourneur.pdf'
    )
  $$,
  'L’admin contresigne la convention'
);

select lives_ok(
  $$
    select public.review_organization_convention(
      'f1000000-0000-0000-0000-000000000001',
      'rejected'::public.volunteer_document_status,
      'Document illisible'
    )
  $$,
  'L’admin peut ensuite la refuser'
);

reset role;

select is_empty(
  $$
    select user_id
    from public.user_notifications
    where notification_type = 'organization_convention_reviewed'
  $$,
  'La contresignature/le refus d’une convention ne notifie plus les tourneurs'
);

select * from finish();

rollback;
