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
    ('90000000-0000-0000-0000-000000000002'::uuid, 'admin')
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
  'Seul un administrateur peut modifier la maraude',
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
  'Une maraude démarre sans condition opérationnelle bloquante'
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

select lives_ok(
  $$
    select public.set_maraude_status(
      '91000000-0000-0000-0000-000000000001',
      'in_progress',
      null
    )
  $$,
  'Une maraude clôturée peut être rouverte'
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
  'La réouverture conserve le début et efface la fin'
);

select lives_ok(
  $$
    select public.set_maraude_status(
      '91000000-0000-0000-0000-000000000001',
      'open',
      null
    )
  $$,
  'L’administrateur peut corriger le statut vers Ouverte'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concerts
    where id = '91000000-0000-0000-0000-000000000001'
      and maraude_status = 'open'
      and actual_start_at is null
      and actual_end_at is null
  $$,
  array[1::bigint],
  'Revenir à Ouverte nettoie les dates réelles'
);

select lives_ok(
  $$
    select public.set_maraude_status(
      '91000000-0000-0000-0000-000000000001',
      'team_ready',
      null
    )
  $$,
  'Une équipe peut être déclarée validée sans composition imposée'
);

select lives_ok(
  $$
    select public.set_maraude_status(
      '91000000-0000-0000-0000-000000000001',
      'cancelled',
      'Concert annulé'
    )
  $$,
  'Une maraude peut être annulée sans suppression'
);

select results_eq(
  $$
    select maraude_status::text, cancellation_reason
    from public.concerts
    where id = '91000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('cancelled'::text, 'Concert annulé'::text) $$,
  'L’annulation et son motif facultatif sont conservés'
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
