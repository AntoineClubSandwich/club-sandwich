begin;

create extension if not exists pgtap with schema extensions;

select plan(47);

select has_table(
  'public',
  'user_accounts',
  'Le rôle unique et le cycle de vie des comptes sont stockés'
);
select has_table(
  'public',
  'invitation_campaigns',
  'Les campagnes d’invitations sont séparées des maraudes'
);
select has_table(
  'public',
  'invitation_applications',
  'Les candidatures aux invitations sont stockées'
);
select has_column(
  'public',
  'invitation_campaigns',
  'venue_id',
  'Une campagne référence sa salle'
);
select col_is_fk(
  'public',
  'invitation_campaigns',
  'venue_id',
  'La salle d’une campagne référence venues'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conname = 'invitation_campaigns_venue_required'
      and conrelid = 'public.invitation_campaigns'::regclass
      and contype = 'c'
  ),
  'Toute nouvelle campagne doit posséder une salle'
);
select has_table(
  'public',
  'organization_contacts',
  'Les contacts des organisations sont structurés'
);
select has_table(
  'public',
  'organization_documents',
  'Les documents des organisations sont structurés'
);
select has_function(
  'public',
  'get_current_user_context',
  'Le contexte utilisateur est chargé en une RPC'
);
select has_function(
  'public',
  'get_invitation_candidates',
  array['uuid'],
  'La liste agrégée des candidats existe'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '71000000-0000-0000-0000-000000000001',
    'v2-admin@example.test',
    '{"first_name":"Admin","last_name":"V2"}'
  ),
  (
    '71000000-0000-0000-0000-000000000002',
    'v2-promoter@example.test',
    '{"first_name":"Tourneur","last_name":"A"}'
  ),
  (
    '71000000-0000-0000-0000-000000000003',
    'v2-volunteer@example.test',
    '{"first_name":"Bénévole","last_name":"A"}'
  ),
  (
    '71000000-0000-0000-0000-000000000004',
    'v2-other@example.test',
    '{"first_name":"Tourneur","last_name":"B"}'
  ),
  (
    '71000000-0000-0000-0000-000000000005',
    'v2-invited@example.test',
    '{"first_name":"Compte","last_name":"Invité"}'
  );

insert into public.organizations (id, name, slug, kind)
values
  (
    '72000000-0000-0000-0000-000000000001',
    'Tourneur V2 A',
    'tourneur-v2-a',
    'producer'
  ),
  (
    '72000000-0000-0000-0000-000000000002',
    'Tourneur V2 B',
    'tourneur-v2-b',
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
    '71000000-0000-0000-0000-000000000001',
    'admin',
    null,
    'active',
    now()
  ),
  (
    '71000000-0000-0000-0000-000000000002',
    'promoter',
    '72000000-0000-0000-0000-000000000001',
    'active',
    now()
  ),
  (
    '71000000-0000-0000-0000-000000000003',
    'volunteer',
    null,
    'active',
    now()
  ),
  (
    '71000000-0000-0000-0000-000000000004',
    'promoter',
    '72000000-0000-0000-0000-000000000002',
    'active',
    now()
  ),
  (
    '71000000-0000-0000-0000-000000000005',
    'volunteer',
    null,
    'invited',
    null
  );

insert into public.organization_contacts (
  id,
  organization_id,
  first_name,
  last_name,
  email
)
values
  (
    '73000000-0000-0000-0000-000000000001',
    '72000000-0000-0000-0000-000000000001',
    'Contact',
    'A',
    'contact-a@example.test'
  ),
  (
    '73000000-0000-0000-0000-000000000002',
    '72000000-0000-0000-0000-000000000002',
    'Contact',
    'B',
    'contact-b@example.test'
  );

insert into public.venues (
  id,
  name,
  public_address_line1,
  postal_code,
  city
)
values (
  '77000000-0000-0000-0000-000000000001',
  'Salle invitations V2',
  '1 rue de la Recette',
  '75001',
  'Paris'
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
  credit_concert.id,
  organization.id,
  credit_concert.artist,
  credit_concert.concert_date,
  '77000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000001'
from public.organizations organization
cross join (
  values
    (
      '78000000-0000-0000-0000-000000000001'::uuid,
      'Crédit 1',
      '2026-01-01'::date
    ),
    (
      '78000000-0000-0000-0000-000000000002'::uuid,
      'Crédit 2',
      '2026-01-02'::date
    ),
    (
      '78000000-0000-0000-0000-000000000003'::uuid,
      'Crédit 3',
      '2026-01-03'::date
    )
) as credit_concert(id, artist, concert_date)
where organization.slug = 'club-sandwich';

insert into public.concert_volunteers (
  id,
  concert_id,
  user_id,
  status
)
values
  (
    '79000000-0000-0000-0000-000000000001',
    '78000000-0000-0000-0000-000000000001',
    '71000000-0000-0000-0000-000000000003',
    'pending'
  ),
  (
    '79000000-0000-0000-0000-000000000002',
    '78000000-0000-0000-0000-000000000002',
    '71000000-0000-0000-0000-000000000003',
    'pending'
  ),
  (
    '79000000-0000-0000-0000-000000000003',
    '78000000-0000-0000-0000-000000000003',
    '71000000-0000-0000-0000-000000000003',
    'pending'
  );

insert into public.volunteer_credits (
  concert_id,
  application_id,
  user_id,
  awarded_by
)
values
  (
    '78000000-0000-0000-0000-000000000001',
    '79000000-0000-0000-0000-000000000001',
    '71000000-0000-0000-0000-000000000003',
    '71000000-0000-0000-0000-000000000001'
  ),
  (
    '78000000-0000-0000-0000-000000000002',
    '79000000-0000-0000-0000-000000000002',
    '71000000-0000-0000-0000-000000000003',
    '71000000-0000-0000-0000-000000000001'
  ),
  (
    '78000000-0000-0000-0000-000000000003',
    '79000000-0000-0000-0000-000000000003',
    '71000000-0000-0000-0000-000000000003',
    '71000000-0000-0000-0000-000000000001'
  );

select is(
  (
    select string_agg(enumlabel::text, ',' order by enumsortorder)
    from pg_enum
    join pg_type on pg_type.oid = pg_enum.enumtypid
    where pg_type.typname = 'user_account_status'
  ),
  'invited,active,disabled',
  'Les trois statuts utilisateur attendus sont les seuls disponibles'
);

select is(
  (
    select count(*)
    from public.memberships
    where profile_id = '71000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'Le compte tourneur possède exactement une organisation'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '71000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$
    select role::text, organization_id
    from public.get_current_user_context()
  $$,
  $$
    values (
      'promoter'::text,
      '72000000-0000-0000-0000-000000000001'::uuid
    )
  $$,
  'Le contexte du tourneur contient son rôle et son organisation'
);

select is(
  (select count(*) from public.organizations),
  1::bigint,
  'Le tourneur ne voit que son organisation'
);

select is(
  (select count(*) from public.organization_contacts),
  1::bigint,
  'Le tourneur ne voit que les contacts de son organisation'
);

select lives_ok(
  $$
    insert into public.invitation_campaigns (
      id,
      organization_id,
      venue_id,
      title,
      available_places,
      status,
      created_by
    )
    values (
      '74000000-0000-0000-0000-000000000001',
      '72000000-0000-0000-0000-000000000001',
      '77000000-0000-0000-0000-000000000001',
      'Invitations ouvertes',
      2,
      'open',
      '71000000-0000-0000-0000-000000000002'
    )
  $$,
  'Le tourneur crée une campagne pour sa propre organisation'
);

select lives_ok(
  $$
    insert into public.invitation_campaigns (
      id,
      organization_id,
      venue_id,
      title,
      status,
      created_by
    )
    values (
      '74000000-0000-0000-0000-000000000002',
      '72000000-0000-0000-0000-000000000001',
      '77000000-0000-0000-0000-000000000001',
      'Brouillon privé',
      'draft',
      '71000000-0000-0000-0000-000000000002'
    )
  $$,
  'Le tourneur peut conserver une campagne en brouillon'
);

select throws_ok(
  $$
    insert into public.invitation_campaigns (
      organization_id,
      title,
      status,
      created_by
    )
    values (
      '72000000-0000-0000-0000-000000000001',
      'Campagne sans salle',
      'open',
      '71000000-0000-0000-0000-000000000002'
    )
  $$,
  '23514',
  'new row for relation "invitation_campaigns" violates check constraint "invitation_campaigns_venue_required"',
  'Une nouvelle campagne sans salle est refusée'
);

select throws_ok(
  $$
    insert into public.invitation_campaigns (
      organization_id,
      venue_id,
      title,
      status,
      created_by
    )
    values (
      '72000000-0000-0000-0000-000000000002',
      '77000000-0000-0000-0000-000000000001',
      'Campagne interdite',
      'open',
      '71000000-0000-0000-0000-000000000002'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "invitation_campaigns"',
  'Le tourneur ne crée jamais une campagne pour une autre organisation'
);

select is(
  (select count(*) from public.invitation_campaigns),
  2::bigint,
  'Le tourneur voit ses campagnes ouvertes et brouillons'
);

select results_eq(
  $$
    select
      context.organization_id = context.promoter_organization_id,
      context.promoter_organization_id
    from public.get_concert_creation_context() context
  $$,
  $$
    values (
      false,
      '72000000-0000-0000-0000-000000000001'::uuid
    )
  $$,
  'La création conserve Club Sandwich comme tenant et le tourneur comme partenaire'
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
      '76000000-0000-0000-0000-000000000001',
      context.organization_id,
      context.promoter_organization_id,
      'Artiste V2',
      '2026-10-15',
      venue.id,
      context.user_id
    from public.get_concert_creation_context() context
    cross join lateral (
      select id from public.venues where is_active order by name limit 1
    ) venue
  $$,
  'Le tourneur ouvre une maraude rattachée automatiquement à son organisation'
);

select results_eq(
  $$
    select
      concert.organization_id = concert.promoter_organization_id,
      concert.promoter_organization_id
    from public.concerts concert
    where concert.id = '76000000-0000-0000-0000-000000000001'
  $$,
  $$
    values (
      false,
      '72000000-0000-0000-0000-000000000001'::uuid
    )
  $$,
  'La maraude créée reste visible dans le tenant Club Sandwich'
);

select lives_ok(
  $$
    update public.concerts
    set artist = 'Artiste V2 modifié'
    where id = '76000000-0000-0000-0000-000000000001'
  $$,
  'Le tourneur modifie sa propre maraude'
);

select set_config(
  'request.jwt.claim.sub',
  '71000000-0000-0000-0000-000000000003',
  true
);

select is(
  (select count(*) from public.invitation_campaigns),
  1::bigint,
  'Le bénévole voit uniquement les campagnes ouvertes'
);

select is(
  (
    select count(*)
    from public.invitation_campaigns campaign
    join public.venues venue on venue.id = campaign.venue_id
    where venue.name = 'Salle invitations V2'
  ),
  1::bigint,
  'Le bénévole voit la salle de la campagne ouverte'
);

select is(
  (
    select count(*)
    from public.concerts
    where id = '76000000-0000-0000-0000-000000000001'
  ),
  1::bigint,
  'Le bénévole voit la maraude ouverte par le tourneur'
);

select lives_ok(
  $$
    update public.concerts
    set artist = 'Modification bénévole interdite'
    where id = '76000000-0000-0000-0000-000000000001'
  $$,
  'La tentative de modification bénévole ne cible aucune ligne'
);

select is(
  (
    select artist
    from public.concerts
    where id = '76000000-0000-0000-0000-000000000001'
  ),
  'Artiste V2 modifié',
  'Le bénévole ne peut effectivement pas modifier une maraude'
);

select lives_ok(
  $$
    insert into public.invitation_applications (
      id,
      campaign_id,
      user_id
    )
    values (
      '75000000-0000-0000-0000-000000000001',
      '74000000-0000-0000-0000-000000000001',
      '71000000-0000-0000-0000-000000000003'
    )
  $$,
  'Le bénévole candidate à une campagne ouverte'
);

select throws_ok(
  $$
    insert into public.invitation_applications (campaign_id, user_id)
    values (
      '74000000-0000-0000-0000-000000000001',
      '71000000-0000-0000-0000-000000000003'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "invitation_applications_campaign_id_user_id_key"',
  'Une seconde candidature à la même campagne est impossible'
);

select set_config(
  'request.jwt.claim.sub',
  '71000000-0000-0000-0000-000000000002',
  true
);

select is(
  (
    select count(*)
    from public.get_invitation_candidates(
      '74000000-0000-0000-0000-000000000001'
    )
  ),
  1::bigint,
  'Le tourneur consulte les candidats à sa campagne en une requête'
);

select is(
  (
    select can_manage
    from public.get_invitation_candidates(
      '74000000-0000-0000-0000-000000000001'
    )
  ),
  false,
  'Le tourneur ne peut pas attribuer une invitation'
);

select set_config(
  'request.jwt.claim.sub',
  '71000000-0000-0000-0000-000000000004',
  true
);

select is(
  (
    select count(*)
    from public.concerts
    where id = '76000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'Un autre tourneur ne voit pas la maraude'
);

select set_config(
  'request.jwt.claim.sub',
  '71000000-0000-0000-0000-000000000002',
  true
);

select throws_ok(
  $$
    select public.set_invitation_application_status(
      '75000000-0000-0000-0000-000000000001',
      'selected'
    )
  $$,
  '42501',
  'Seul un administrateur attribue les invitations',
  'La RPC refuse toute attribution par un tourneur'
);

select set_config(
  'request.jwt.claim.sub',
  '71000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$
    select public.set_invitation_application_status(
      '75000000-0000-0000-0000-000000000001',
      'selected'
    )
  $$,
  'L’administrateur attribue une invitation'
);

update public.invitation_campaigns
set available_places = 1
where id = '74000000-0000-0000-0000-000000000001';

insert into public.invitation_applications (
  id,
  campaign_id,
  user_id
)
values (
  '75000000-0000-0000-0000-000000000002',
  '74000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000005'
);

select throws_ok(
  $$
    select public.set_invitation_application_status(
      '75000000-0000-0000-0000-000000000002',
      'selected'
    )
  $$,
  '22023',
  'Toutes les places ont déjà été attribuées',
  'Le quota interdit une attribution supplémentaire'
);

update public.invitation_campaigns
set status = 'closed'::public.invitation_campaign_status
where id = '74000000-0000-0000-0000-000000000001';

select is(
  (
    select count(*)
    from public.get_admin_users()
    where email like 'v2-%@example.test'
  ),
  5::bigint,
  'L’administration centralise les cinq comptes de test'
);

select set_config(
  'request.jwt.claim.sub',
  '71000000-0000-0000-0000-000000000003',
  true
);

select is(
  (
    select count(*)
    from public.invitation_campaigns
    where id = '74000000-0000-0000-0000-000000000001'
  ),
  1::bigint,
  'Le bénévole conserve l’accès à son invitation après la clôture'
);

select results_eq(
  $$
    select status::text
    from public.invitation_applications
    where campaign_id = '74000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('selected'::text) $$,
  'Le bénévole consulte le résultat de sa propre candidature'
);

select throws_ok(
  $$ select * from public.get_admin_users() $$,
  '42501',
  'Accès administrateur requis',
  'Un bénévole ne peut pas consulter l’administration'
);

select set_config(
  'request.jwt.claim.sub',
  '71000000-0000-0000-0000-000000000005',
  true
);

select lives_ok(
  $$
    select public.activate_current_user(
      ' Camille ',
      ' Martin ',
      ' 0600000000 '
    )
  $$,
  'Le lien active le compte et complète son profil atomiquement'
);

select results_eq(
  $$
    select
      account.status::text,
      profile.first_name,
      profile.last_name,
      profile.phone
    from public.user_accounts account
    join public.profiles profile on profile.id = account.profile_id
    where account.profile_id =
      '71000000-0000-0000-0000-000000000005'
  $$,
  $$ values ('active', 'Camille', 'Martin', '0600000000') $$,
  'L’activation normalise le profil et passe le compte à Actif'
);

select throws_ok(
  $$
    select public.activate_current_user(
      'Camille',
      'Martin',
      '0600000000'
    )
  $$,
  'P0002',
  'Invitation introuvable ou déjà utilisée',
  'Un lien déjà utilisé ne réactive pas le compte'
);

reset role;
update public.user_accounts
set
  status = 'disabled',
  disabled_at = now()
where profile_id = '71000000-0000-0000-0000-000000000003';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '71000000-0000-0000-0000-000000000003',
  true
);

select is(
  (select count(*) from public.invitation_campaigns),
  0::bigint,
  'Un compte désactivé n’accède plus aux campagnes'
);

select is(
  (select count(*) from public.invitation_applications),
  0::bigint,
  'Un compte désactivé n’accède plus à ses candidatures'
);

select throws_ok(
  $$
    insert into public.invitation_applications (
      campaign_id,
      user_id
    )
    values (
      '74000000-0000-0000-0000-000000000001',
      '71000000-0000-0000-0000-000000000003'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "invitation_applications"',
  'Un compte désactivé ne peut pas candidater'
);

select * from finish();

rollback;
