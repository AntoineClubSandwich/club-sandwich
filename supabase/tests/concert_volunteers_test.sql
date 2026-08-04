begin;

create extension if not exists pgtap with schema extensions;

select plan(23);

select has_table(
  'public',
  'concert_volunteers',
  'La table concert_volunteers existe'
);

select has_table(
  'public',
  'volunteer_profiles',
  'La table volunteer_profiles existe'
);

insert into auth.users (
  id,
  email,
  raw_user_meta_data
)
values
  (
    '10000000-0000-0000-0000-000000000001',
    'volunteer-one@example.test',
    '{"first_name":"Camille","last_name":"Martin"}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    'volunteer-two@example.test',
    '{"first_name":"Alex","last_name":"Durand"}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000003',
    'admin@example.test',
    '{"first_name":"Admin","last_name":"Club Sandwich"}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000004',
    'volunteer-without-application@example.test',
    '{"first_name":"Sans","last_name":"Candidature"}'::jsonb
  );

insert into public.memberships (
  organization_id,
  profile_id,
  role
)
select
  o.id,
  user_data.profile_id,
  user_data.role::public.app_role
from public.organizations o
cross join (
  values
    (
      '10000000-0000-0000-0000-000000000001'::uuid,
      'volunteer'
    ),
    (
      '10000000-0000-0000-0000-000000000002'::uuid,
      'volunteer'
    ),
    (
      '10000000-0000-0000-0000-000000000003'::uuid,
      'admin'
    ),
    (
      '10000000-0000-0000-0000-000000000004'::uuid,
      'volunteer'
    )
) as user_data(profile_id, role)
where o.slug = 'club-sandwich';

insert into public.volunteer_profiles (
  user_id,
  birth_date,
  has_driving_license,
  can_lift_heavy_loads,
  emergency_contact_name,
  emergency_contact_phone
)
values
  (
    '10000000-0000-0000-0000-000000000001',
    '1992-04-12',
    true,
    true,
    'Sophie Martin',
    '+33 6 99 99 99 99'
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    null,
    null,
    null,
    null,
    null
  ),
  (
    '10000000-0000-0000-0000-000000000004',
    null,
    false,
    null,
    null,
    null
  );

insert into public.concerts (
  id,
  organization_id,
  artist,
  concert_date,
  venue_id,
  created_by
)
select
  '20000000-0000-0000-0000-000000000001'::uuid,
  o.id,
  'Artiste test',
  '2026-09-15'::date,
  v.id,
  '10000000-0000-0000-0000-000000000003'::uuid
from public.organizations o
cross join lateral (
  select id
  from public.venues
  order by name
  limit 1
) v
where o.slug = 'club-sandwich';

insert into public.concerts (
  id,
  organization_id,
  artist,
  concert_date,
  venue_id,
  created_by
)
select
  history_data.id,
  o.id,
  history_data.artist,
  history_data.concert_date,
  v.id,
  '10000000-0000-0000-0000-000000000003'::uuid
from public.organizations o
cross join lateral (
  select id
  from public.venues
  order by name
  limit 1
) v
cross join (
  values
    (
      '20000000-0000-0000-0000-000000000002'::uuid,
      '2026-07-15'::date,
      'The Blaze'
    ),
    (
      '20000000-0000-0000-0000-000000000003'::uuid,
      '2026-07-02'::date,
      'Aupinard'
    ),
    (
      '20000000-0000-0000-0000-000000000004'::uuid,
      '2026-06-01'::date,
      'Artiste non sélectionné'
    )
) as history_data(id, concert_date, artist)
where o.slug = 'club-sandwich';

insert into public.concerts (
  id,
  organization_id,
  artist,
  concert_date,
  venue_id,
  created_by
)
select
  md5('archived-concert-' || series.value)::uuid,
  o.id,
  'Archive ' || series.value,
  '2025-01-01'::date + series.value,
  v.id,
  '10000000-0000-0000-0000-000000000003'::uuid
from public.organizations o
cross join lateral (
  select id
  from public.venues
  order by name
  limit 1
) v
cross join generate_series(1, 21) as series(value)
where o.slug = 'club-sandwich';

insert into public.concert_volunteers (
  concert_id,
  user_id,
  status
)
values (
  '20000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
  'pending'
);

insert into public.concert_volunteers (
  concert_id,
  user_id,
  status
)
values
  (
    '20000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000002',
    'selected'
  ),
  (
    '20000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000002',
    'withdrawn'
  ),
  (
    '20000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000002',
    'not_selected'
  );

insert into public.concert_volunteers (
  concert_id,
  user_id,
  status
)
select
  md5('archived-concert-' || series.value)::uuid,
  '10000000-0000-0000-0000-000000000002'::uuid,
  'pending'::public.concert_volunteer_status
from generate_series(1, 21) as series(value);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    insert into public.concert_volunteers (
      concert_id,
      user_id,
      status
    )
    values (
      '20000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      'pending'
    )
  $$,
  'Un bénévole peut créer sa propre candidature en attente'
);

select throws_ok(
  $$
    insert into public.concert_volunteers (
      concert_id,
      user_id,
      status
    )
    values (
      '20000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      'pending'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "concert_volunteers_concert_id_user_id_key"',
  'Un bénévole ne peut pas créer une deuxième candidature'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
  $$,
  array[1::bigint],
  'Un bénévole ne voit que sa propre candidature'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers cv
    join public.concerts c on c.id = cv.concert_id
    join public.venues v on v.id = c.venue_id
  $$,
  array[1::bigint],
  'Un bénévole ne voit que les lignes de son propre historique'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.get_concert_volunteer_details(
      '20000000-0000-0000-0000-000000000001'
    )
  $$,
  array[1::bigint],
  'Un bénévole peut lire uniquement son propre historique agrégé'
);

select results_eq(
  $$
    select email
    from public.get_concert_volunteer_team_details(
      '20000000-0000-0000-0000-000000000001'
    )
  $$,
  array['volunteer-one@example.test'::text],
  'Un bénévole accède uniquement à son propre e-mail dans la lecture groupée'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.profiles
    where id = '10000000-0000-0000-0000-000000000002'
  $$,
  array[0::bigint],
  'Un bénévole ne voit pas le profil des autres candidats'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.volunteer_profiles
  $$,
  array[1::bigint],
  'Un bénévole voit uniquement son propre profil bénévole'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.volunteer_profiles
    where user_id = '10000000-0000-0000-0000-000000000002'
  $$,
  array[0::bigint],
  'Un bénévole ne voit pas le profil bénévole d’un autre candidat'
);

select throws_ok(
  $$
    update public.concert_volunteers
    set status = 'selected'
    where user_id = '10000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  'new row violates row-level security policy for table "concert_volunteers"',
  'Un bénévole ne peut pas se sélectionner'
);

select lives_ok(
  $$
    update public.concert_volunteers
    set status = 'withdrawn'
    where user_id = '10000000-0000-0000-0000-000000000001'
  $$,
  'Un bénévole peut se désister sans supprimer sa candidature'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000003',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.concert_volunteers
  $$,
  array[26::bigint],
  'Un administrateur voit les candidatures du concert'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.profiles
    where id in (
      '10000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000002'
    )
  $$,
  array[2::bigint],
  'Un administrateur voit les profils des candidats'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.volunteer_profiles
  $$,
  array[3::bigint],
  'Un administrateur voit les profils bénévoles gérés'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.volunteer_profiles
    where user_id = '10000000-0000-0000-0000-000000000004'
  $$,
  array[1::bigint],
  'Un administrateur voit aussi un profil sans candidature'
);

select lives_ok(
  $$
    update public.concert_volunteers
    set status = 'selected'
    where user_id = '10000000-0000-0000-0000-000000000002'
      and concert_id = '20000000-0000-0000-0000-000000000001'
  $$,
  'Un administrateur peut sélectionner un bénévole'
);

select results_eq(
  $$
    select
      user_id,
      total_applications,
      selected_applications,
      not_selected_applications,
      withdrawn_applications
    from public.get_concert_volunteer_details(
      '20000000-0000-0000-0000-000000000001'
    )
    order by user_id
  $$,
  $$
    values
      (
        '10000000-0000-0000-0000-000000000001'::uuid,
        1::bigint,
        0::bigint,
        0::bigint,
        1::bigint
      ),
      (
        '10000000-0000-0000-0000-000000000002'::uuid,
        25::bigint,
        2::bigint,
        1::bigint,
        1::bigint
      )
  $$,
  'Les statistiques bénévoles sont calculées sans être stockées'
);

select results_eq(
  $$
    select email
    from public.get_concert_volunteer_team_details(
      '20000000-0000-0000-0000-000000000001'
    )
    where user_id = '10000000-0000-0000-0000-000000000002'
  $$,
  array['volunteer-two@example.test'::text],
  'Un administrateur peut rechercher un candidat par son e-mail'
);

select results_eq(
  $$
    select
      jsonb_array_length(history)::bigint,
      last_selected_date
    from public.get_concert_volunteer_details(
      '20000000-0000-0000-0000-000000000001'
    )
    where user_id = '10000000-0000-0000-0000-000000000002'
  $$,
  $$
    values (20::bigint, '2026-09-15'::date)
  $$,
  'L’historique est limité à vingt lignes et la dernière sélection est calculée'
);

select results_eq(
  $$
    select
      history -> 0 ->> 'concert_date',
      history -> 0 ->> 'artist',
      history -> 19 ->> 'concert_date'
    from public.get_concert_volunteer_details(
      '20000000-0000-0000-0000-000000000001'
    )
    where user_id = '10000000-0000-0000-0000-000000000002'
  $$,
  $$
    values ('2026-09-15', 'Artiste test', '2025-01-07')
  $$,
  'L’historique est trié du plus récent au plus ancien'
);

select results_eq(
  $$
    select application_count, selected_count
    from public.get_concert_volunteer_counts(
      '20000000-0000-0000-0000-000000000001'
    )
  $$,
  $$
    values (1::bigint, 1::bigint)
  $$,
  'Les compteurs excluent les désistements et comptent les sélections'
);

select * from finish();

rollback;
