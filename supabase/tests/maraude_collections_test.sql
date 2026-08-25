begin;

create extension if not exists pgtap with schema extensions;

select plan(29);

select has_table(
  'public',
  'maraude_collections',
  'La table des lots collectés existe'
);

select col_type_is(
  'public',
  'maraude_collections',
  'category',
  'public.collection_category',
  'La catégorie utilise un enum PostgreSQL'
);

select col_type_is(
  'public',
  'maraude_collections',
  'unit',
  'public.collection_unit',
  'L’unité utilise un enum PostgreSQL'
);

select col_type_is(
  'public',
  'maraude_collections',
  'quantity',
  'numeric',
  'La quantité utilise un type numérique'
);

insert into auth.users (
  id,
  email,
  raw_user_meta_data
)
values
  (
    'a0000000-0000-0000-0000-000000000001',
    'collection-member@example.test',
    '{"first_name":"Julie","last_name":"Martin"}'::jsonb
  ),
  (
    'a0000000-0000-0000-0000-000000000002',
    'collection-outsider@example.test',
    '{"first_name":"Alex","last_name":"Durand"}'::jsonb
  ),
  (
    'a0000000-0000-0000-0000-000000000003',
    'collection-admin@example.test',
    '{"first_name":"Admin","last_name":"Collecte"}'::jsonb
  ),
  (
    'a0000000-0000-0000-0000-000000000004',
    'collection-member2@example.test',
    '{"first_name":"Nour","last_name":"Petit"}'::jsonb
  );

insert into public.memberships (
  organization_id,
  profile_id,
  role
)
select
  o.id,
  member_data.profile_id,
  member_data.role::public.app_role
from public.organizations o
cross join (
  values
    (
      'a0000000-0000-0000-0000-000000000001'::uuid,
      'volunteer'
    ),
    (
      'a0000000-0000-0000-0000-000000000002'::uuid,
      'volunteer'
    ),
    (
      'a0000000-0000-0000-0000-000000000003'::uuid,
      'admin'
    ),
    (
      'a0000000-0000-0000-0000-000000000004'::uuid,
      'volunteer'
    )
) as member_data(profile_id, role)
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
  'a1000000-0000-0000-0000-000000000001'::uuid,
  o.id,
  'Artiste collecte',
  '2026-12-15'::date,
  v.id,
  'a0000000-0000-0000-0000-000000000003'::uuid
from public.organizations o
cross join lateral (
  select id
  from public.venues
  order by name
  limit 1
) v
where o.slug = 'club-sandwich';

insert into public.concert_volunteers (
  concert_id,
  user_id,
  status,
  attendance_status
)
values (
  'a1000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000001',
  'selected',
  'present'
);

update public.concert_volunteers
set team_role = 'collection_distribution'
where concert_id = 'a1000000-0000-0000-0000-000000000001';

update public.concert_volunteers
set
  role_acknowledged_at = clock_timestamp(),
  confirmation_status = 'confirmed'
where concert_id = 'a1000000-0000-0000-0000-000000000001';

update public.concert_volunteers
set attendance_status = 'present'
where concert_id = 'a1000000-0000-0000-0000-000000000001';

insert into public.concert_volunteers (
  concert_id,
  user_id,
  status,
  team_role
)
values (
  'a1000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000003',
  'selected',
  'team_leader'
);

update public.concert_volunteers
set
  role_acknowledged_at = clock_timestamp(),
  confirmation_status = 'confirmed'
where concert_id = 'a1000000-0000-0000-0000-000000000001'
  and user_id = 'a0000000-0000-0000-0000-000000000003';

update public.concert_volunteers
set attendance_status = 'present'
where concert_id = 'a1000000-0000-0000-0000-000000000001'
  and user_id = 'a0000000-0000-0000-0000-000000000003';

insert into public.concert_volunteers (
  concert_id,
  user_id,
  status,
  team_role
)
values (
  'a1000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000004',
  'selected',
  'logistics'
);

update public.concert_volunteers
set
  role_acknowledged_at = clock_timestamp(),
  confirmation_status = 'confirmed'
where concert_id = 'a1000000-0000-0000-0000-000000000001'
  and user_id = 'a0000000-0000-0000-0000-000000000004';

update public.concert_volunteers
set attendance_status = 'present'
where concert_id = 'a1000000-0000-0000-0000-000000000001'
  and user_id = 'a0000000-0000-0000-0000-000000000004';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a0000000-0000-0000-0000-000000000003',
  true
);

select lives_ok(
  $$
    select public.start_maraude(
      'a1000000-0000-0000-0000-000000000001'
    )
  $$,
  'L’administrateur démarre la maraude avant la collecte'
);

select lives_ok(
  $$
    insert into public.maraude_collections (
      id,
      concert_id,
      category,
      description,
      quantity,
      unit,
      weight_kg,
      comment
    )
    values (
      'a2000000-0000-0000-0000-000000000001',
      'a1000000-0000-0000-0000-000000000001',
      'prepared_meals',
      'Plateaux repas',
      25,
      'piece',
      12.5,
      'Collecte complète'
    )
  $$,
  'Un administrateur crée un lot pendant la maraude'
);

select results_eq(
  $$
    select
      category::text,
      quantity::text,
      unit::text,
      weight_kg::text
    from public.maraude_collections
    where id = 'a2000000-0000-0000-0000-000000000001'
  $$,
  $$
    values ('prepared_meals', '25', 'piece', '12.5')
  $$,
  'Le lot conserve sa catégorie, sa quantité, son unité et son poids'
);

select lives_ok(
  $$
    insert into public.maraude_collections (
      id,
      concert_id,
      category,
      quantity,
      unit
    )
    values (
      'a2000000-0000-0000-0000-000000000002',
      'a1000000-0000-0000-0000-000000000001',
      'fruits_vegetables',
      3,
      'crate'
    )
  $$,
  'Un second lot peut être créé pour la même maraude'
);

select lives_ok(
  $$
    update public.maraude_collections
    set
      quantity = 30,
      comment = 'Quantité corrigée'
    where id = 'a2000000-0000-0000-0000-000000000001'
  $$,
  'Un administrateur modifie un lot pendant la maraude'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_collections
    where id = 'a2000000-0000-0000-0000-000000000001'
      and quantity = 30
      and comment = 'Quantité corrigée'
  $$,
  array[1::bigint],
  'La modification du lot est enregistrée'
);

select lives_ok(
  $$
    delete from public.maraude_collections
    where id = 'a2000000-0000-0000-0000-000000000002'
  $$,
  'Un administrateur supprime un lot pendant la maraude'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_collections
    where id = 'a2000000-0000-0000-0000-000000000002'
  $$,
  array[0::bigint],
  'Le lot supprimé n’existe plus'
);

select throws_ok(
  $$
    insert into public.maraude_collections (
      concert_id,
      category,
      quantity,
      unit
    )
    values (
      'a1000000-0000-0000-0000-000000000001',
      'bakery',
      0,
      'piece'
    )
  $$,
  '23514',
  'new row for relation "maraude_collections" violates check constraint "maraude_collections_quantity_check"',
  'Une quantité nulle est refusée'
);

select throws_ok(
  $$
    insert into public.maraude_collections (
      concert_id,
      category,
      quantity,
      unit,
      weight_kg
    )
    values (
      'a1000000-0000-0000-0000-000000000001',
      'bakery',
      1,
      'bag',
      -1
    )
  $$,
  '23514',
  'new row for relation "maraude_collections" violates check constraint "maraude_collections_weight_kg_check"',
  'Un poids négatif est refusé'
);

select throws_ok(
  $$
    insert into public.maraude_collections (
      concert_id,
      category,
      quantity,
      unit
    )
    values (
      'a1000000-0000-0000-0000-000000000001',
      'unknown',
      1,
      'box'
    )
  $$,
  '22P02',
  'invalid input value for enum collection_category: "unknown"',
  'Une catégorie hors enum est refusée'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a0000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_collections
  $$,
  array[1::bigint],
  'Un bénévole sélectionné peut lire la collecte de sa maraude'
);

select lives_ok(
  $$
    insert into public.maraude_collections (
      concert_id,
      category,
      quantity,
      unit
    )
    values (
      'a1000000-0000-0000-0000-000000000001',
      'drinks',
      2,
      'box'
    )
  $$,
  'Un bénévole affecté peut ajouter un lot pendant la maraude'
);

select lives_ok(
  $$
    update public.maraude_collections
    set quantity = 99
    where id = 'a2000000-0000-0000-0000-000000000001'
  $$,
  'Un bénévole affecté peut corriger un lot'
);

select results_eq(
  $$
    select quantity::text
    from public.maraude_collections
    where id = 'a2000000-0000-0000-0000-000000000001'
  $$,
  array['99'::text],
  'La correction collaborative est enregistrée'
);

select lives_ok(
  $$
    delete from public.maraude_collections
    where id = 'a2000000-0000-0000-0000-000000000001'
  $$,
  'Un bénévole affecté peut retirer une ligne erronée'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_collections
  $$,
  array[1::bigint],
  'Le second lot reste présent après la suppression collaborative'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a0000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_collections
  $$,
  array[0::bigint],
  'Un bénévole extérieur à l’équipe ne voit aucun lot'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a0000000-0000-0000-0000-000000000003',
  true
);

select lives_ok(
  $$
    select public.complete_maraude(
      'a1000000-0000-0000-0000-000000000001'
    )
  $$,
  'L’administrateur termine la maraude'
);

select lives_ok(
  $$
    insert into public.maraude_collections (
      concert_id,
      category,
      quantity,
      unit
    )
    values (
      'a1000000-0000-0000-0000-000000000001',
      'dairy',
      2,
      'crate'
    )
  $$,
  'Un administrateur peut ajouter une correction après la clôture'
);

select lives_ok(
  $$
    update public.maraude_collections
    set quantity = 31
    where id = 'a2000000-0000-0000-0000-000000000001'
  $$,
  'Un administrateur corrige un lot après la clôture'
);

select lives_ok(
  $$
    delete from public.maraude_collections
    where id = 'a2000000-0000-0000-0000-000000000001'
  $$,
  'Un administrateur supprime un lot après la clôture'
);

select results_eq(
  $$
    select count(*)::bigint
    from public.maraude_collections
    where concert_id = 'a1000000-0000-0000-0000-000000000001'
      and category = 'dairy'
  $$,
  array[1::bigint],
  'La correction ajoutée après clôture reste lisible'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);

select throws_ok(
  $$
    update public.maraude_collections
    set quantity = 31
    where concert_id = 'a1000000-0000-0000-0000-000000000001'
  $$,
  '22023',
  'La collecte n’est plus modifiable',
  'Le trigger interdit une modification anonyme après la clôture'
);

select throws_ok(
  $$
    delete from public.maraude_collections
    where concert_id = 'a1000000-0000-0000-0000-000000000001'
  $$,
  '22023',
  'La collecte n’est plus modifiable',
  'Le trigger interdit une suppression anonyme après la clôture'
);

select * from finish();

rollback;
