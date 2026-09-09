begin;

create extension if not exists pgtap with schema extensions;

select plan(17);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    'ca000000-0000-0000-0000-000000000001',
    'cancel-admin@example.test',
    '{"first_name":"Admin","last_name":"Cancel"}'::jsonb
  ),
  (
    'ca000000-0000-0000-0000-000000000002',
    'cancel-promoter@example.test',
    '{"first_name":"Tourneur","last_name":"Cancel"}'::jsonb
  ),
  (
    'ca000000-0000-0000-0000-000000000003',
    'cancel-volunteer1@example.test',
    '{"first_name":"Membre1","last_name":"Cancel"}'::jsonb
  ),
  (
    'ca000000-0000-0000-0000-000000000004',
    'cancel-volunteer2@example.test',
    '{"first_name":"Membre2","last_name":"Cancel"}'::jsonb
  ),
  (
    'ca000000-0000-0000-0000-000000000005',
    'cancel-volunteer3@example.test',
    '{"first_name":"Membre3","last_name":"Cancel"}'::jsonb
  ),
  (
    'ca000000-0000-0000-0000-000000000006',
    'cancel-outsider@example.test',
    '{"first_name":"Exterieur","last_name":"Cancel"}'::jsonb
  );

insert into public.organizations (id, name, slug, kind)
values (
  'cb000000-0000-0000-0000-000000000001',
  'Cancel Test Tourneur',
  'cancel-test-tourneur',
  'producer'
);

insert into public.memberships (organization_id, profile_id, role)
select o.id, 'ca000000-0000-0000-0000-000000000001'::uuid, 'admin'::public.app_role
from public.organizations o
where o.slug = 'club-sandwich';

insert into public.user_accounts (
  profile_id, role, organization_id, status, activated_at
)
values
  (
    'ca000000-0000-0000-0000-000000000001',
    'admin', null, 'active', now()
  ),
  (
    'ca000000-0000-0000-0000-000000000002',
    'promoter', 'cb000000-0000-0000-0000-000000000001', 'active', now()
  ),
  (
    'ca000000-0000-0000-0000-000000000003',
    'volunteer', null, 'active', now()
  ),
  (
    'ca000000-0000-0000-0000-000000000004',
    'volunteer', null, 'active', now()
  ),
  (
    'ca000000-0000-0000-0000-000000000005',
    'volunteer', null, 'active', now()
  ),
  (
    'ca000000-0000-0000-0000-000000000006',
    'volunteer', null, 'active', now()
  );

-- Une maraude créée sans statut explicite est "À confirmer" (draft).
insert into public.concerts (
  id, organization_id, promoter_organization_id, artist,
  concert_date, venue_id, created_by
)
select
  'cc000000-0000-0000-0000-000000000001'::uuid,
  club.id,
  'cb000000-0000-0000-0000-000000000001'::uuid,
  'Défaut au brouillon',
  current_date + 30,
  venue.id,
  'ca000000-0000-0000-0000-000000000001'::uuid
from public.organizations club
cross join lateral (
  select id from public.venues where is_active order by name limit 1
) venue
where club.slug = 'club-sandwich';

select results_eq(
  $$
    select maraude_status::text from public.concerts
    where id = 'cc000000-0000-0000-0000-000000000001'
  $$,
  array['draft'::text],
  'Une maraude créée sans statut explicite est "À confirmer" (draft)'
);

-- Maraude ouverte, lointaine, pour tester l'annulation manuelle.
insert into public.concerts (
  id, organization_id, promoter_organization_id, artist,
  concert_date, venue_id, created_by, maraude_status
)
select
  'cc000000-0000-0000-0000-000000000002'::uuid,
  club.id,
  'cb000000-0000-0000-0000-000000000001'::uuid,
  'Annulation manuelle',
  current_date + 30,
  venue.id,
  'ca000000-0000-0000-0000-000000000001'::uuid,
  'open'::public.maraude_status
from public.organizations club
cross join lateral (
  select id from public.venues where is_active order by name limit 1
) venue
where club.slug = 'club-sandwich';

insert into public.concert_volunteers (concert_id, user_id, status)
values (
  'cc000000-0000-0000-0000-000000000002',
  'ca000000-0000-0000-0000-000000000003',
  'pending'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'ca000000-0000-0000-0000-000000000006', true
);

select throws_ok(
  $$ select public.cancel_maraude('cc000000-0000-0000-0000-000000000002', 'test') $$,
  '42501',
  'Seul un administrateur ou le tourneur responsable peut annuler cette maraude',
  'Un bénévole extérieur ne peut pas annuler une maraude'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'ca000000-0000-0000-0000-000000000001', true
);

select lives_ok(
  $$ select public.cancel_maraude(
    'cc000000-0000-0000-0000-000000000002', 'Motif de test admin'
  ) $$,
  'Un administrateur peut annuler une maraude'
);

select results_eq(
  $$
    select maraude_status::text, cancellation_reason, cancellation_origin,
      cancelled_by::text, cancelled_at is not null
    from public.concerts
    where id = 'cc000000-0000-0000-0000-000000000002'
  $$,
  $$
    values (
      'cancelled'::text, 'Motif de test admin'::text, 'admin'::text,
      'ca000000-0000-0000-0000-000000000001'::text, true
    )
  $$,
  'L’annulation admin enregistre motif, origine, auteur et horodatage'
);

select results_eq(
  $$
    select status::text from public.concert_volunteers
    where concert_id = 'cc000000-0000-0000-0000-000000000002'
  $$,
  array['withdrawn'::text],
  'Les candidatures sont désinscrites lors de l’annulation'
);

select results_eq(
  $$
    select count(*)::bigint from public.maraude_workflow_events
    where concert_id = 'cc000000-0000-0000-0000-000000000002'
      and event_type = 'maraude_cancelled'
  $$,
  array[1::bigint],
  'L’annulation est journalisée'
);

select throws_ok(
  $$ select public.cancel_maraude('cc000000-0000-0000-0000-000000000002', 'again') $$,
  '22023',
  'Cette maraude est déjà terminée ou annulée',
  'Une maraude déjà annulée ne peut pas l’être une seconde fois'
);

select throws_ok(
  $$
    select public.set_maraude_status(
      'cc000000-0000-0000-0000-000000000002',
      'cancelled'::public.maraude_status,
      null
    )
  $$,
  '22023',
  'Utilisez cancel_maraude pour annuler une maraude',
  'set_maraude_status n’accepte plus "cancelled" directement'
);

-- Le tourneur peut annuler sa propre maraude (mais pas en ouvrir une).
insert into public.concerts (
  id, organization_id, promoter_organization_id, artist,
  concert_date, venue_id, created_by, maraude_status
)
select
  'cc000000-0000-0000-0000-000000000003'::uuid,
  club.id,
  'cb000000-0000-0000-0000-000000000001'::uuid,
  'Annulation tourneur',
  current_date + 30,
  venue.id,
  'ca000000-0000-0000-0000-000000000001'::uuid,
  'draft'::public.maraude_status
from public.organizations club
cross join lateral (
  select id from public.venues where is_active order by name limit 1
) venue
where club.slug = 'club-sandwich';

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'ca000000-0000-0000-0000-000000000002', true
);

select throws_ok(
  $$
    select public.set_maraude_status(
      'cc000000-0000-0000-0000-000000000003',
      'open'::public.maraude_status,
      null
    )
  $$,
  '42501',
  'Concert inaccessible',
  'Le tourneur ne peut plus ouvrir lui-même les inscriptions'
);

select lives_ok(
  $$ select public.cancel_maraude(
    'cc000000-0000-0000-0000-000000000003', 'Annulé par le tourneur'
  ) $$,
  'Le tourneur peut annuler sa propre maraude'
);

select results_eq(
  $$
    select cancellation_origin from public.concerts
    where id = 'cc000000-0000-0000-0000-000000000003'
  $$,
  array['promoter'::text],
  'L’origine de l’annulation par le tourneur est enregistrée'
);

-- Tâche J-3 : sous-effectif -> annulation automatique.
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'ca000000-0000-0000-0000-000000000001', true
);

insert into public.concerts (
  id, organization_id, promoter_organization_id, artist,
  concert_date, concert_time, venue_id, created_by, maraude_status
)
select
  'cc000000-0000-0000-0000-000000000004'::uuid,
  club.id,
  'cb000000-0000-0000-0000-000000000001'::uuid,
  'J-3 sous-effectif',
  current_date + 2,
  '20:00'::time,
  venue.id,
  'ca000000-0000-0000-0000-000000000001'::uuid,
  'open'::public.maraude_status
from public.organizations club
cross join lateral (
  select id from public.venues where is_active order by name limit 1
) venue
where club.slug = 'club-sandwich';

-- L'insertion directe passe par normalize_volunteer_confirmation, qui
-- force confirmation_status à 'pending' sur tout INSERT (comportement
-- existant, pas propre à ce test) - il faut donc confirmer en deux
-- temps comme le fait réellement l'app (confirm_concert_participation).
insert into public.concert_volunteers (
  concert_id, user_id, status, team_role
)
values (
  'cc000000-0000-0000-0000-000000000004',
  'ca000000-0000-0000-0000-000000000003',
  'selected', 'logistics'
);
update public.concert_volunteers
set
  confirmation_status = 'confirmed',
  role_acknowledged_at = clock_timestamp(),
  confirmation_responded_at = clock_timestamp()
where concert_id = 'cc000000-0000-0000-0000-000000000004';

reset role;
select is(
  private.auto_cancel_understaffed_maraudes(),
  1,
  'La tâche J-3 annule une maraude sous-effectif dans la fenêtre'
);

select results_eq(
  $$
    select maraude_status::text, cancellation_reason, cancellation_origin
    from public.concerts
    where id = 'cc000000-0000-0000-0000-000000000004'
  $$,
  $$
    values (
      'cancelled'::text,
      'Nombre insuffisant de bénévoles à J-3'::text,
      'automatic'::text
    )
  $$,
  'La maraude sous-effectif est annulée avec le bon motif et la bonne origine'
);

select is(
  private.auto_cancel_understaffed_maraudes(),
  0,
  'Relancer la tâche J-3 ne retraite pas une maraude déjà annulée (idempotence)'
);

-- Tâche J-3 : effectif suffisant -> pas d'annulation.
insert into public.concerts (
  id, organization_id, promoter_organization_id, artist,
  concert_date, concert_time, venue_id, created_by, maraude_status
)
select
  'cc000000-0000-0000-0000-000000000005'::uuid,
  club.id,
  'cb000000-0000-0000-0000-000000000001'::uuid,
  'J-3 effectif suffisant',
  current_date + 2,
  '20:00'::time,
  venue.id,
  'ca000000-0000-0000-0000-000000000001'::uuid,
  'open'::public.maraude_status
from public.organizations club
cross join lateral (
  select id from public.venues where is_active order by name limit 1
) venue
where club.slug = 'club-sandwich';

insert into public.concert_volunteers (
  concert_id, user_id, status, team_role
)
values
  (
    'cc000000-0000-0000-0000-000000000005',
    'ca000000-0000-0000-0000-000000000003',
    'selected', 'communication'
  ),
  (
    'cc000000-0000-0000-0000-000000000005',
    'ca000000-0000-0000-0000-000000000004',
    'selected', 'logistics'
  ),
  (
    'cc000000-0000-0000-0000-000000000005',
    'ca000000-0000-0000-0000-000000000005',
    'selected', 'collection_distribution'
  );
update public.concert_volunteers
set
  confirmation_status = 'confirmed',
  role_acknowledged_at = clock_timestamp(),
  confirmation_responded_at = clock_timestamp()
where concert_id = 'cc000000-0000-0000-0000-000000000005';

select results_eq(
  $$
    select maraude_status::text from public.concerts
    where id = 'cc000000-0000-0000-0000-000000000005'
  $$,
  array['open'::text],
  'Une maraude à 3 bénévoles confirmés n’est pas encore annulée avant le passage de la tâche'
);

select is(
  private.auto_cancel_understaffed_maraudes(),
  0,
  'La tâche J-3 n’annule rien quand la maraude a déjà 3 bénévoles confirmés'
);

select results_eq(
  $$
    select maraude_status::text from public.concerts
    where id = 'cc000000-0000-0000-0000-000000000005'
  $$,
  array['open'::text],
  'Une maraude à 3 bénévoles confirmés n’est pas annulée par la tâche J-3'
);

select * from finish();

rollback;
