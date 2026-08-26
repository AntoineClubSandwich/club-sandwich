-- Jeu de données pour la session de test en direct du 2026-08-26.
-- Utilise les VRAIS comptes bénévoles/tourneurs déjà présents en préprod
-- (Alexis, Macéo, Ines, Barth, Hugo côté bénévole ; Mélissa/Apa côté tourneur).
-- Les triggers d'e-mail sont suspendus pendant l'insertion pour ne jamais
-- notifier ces vraies adresses e-mail à partir de données de test.

begin;

do $seed$
declare
  club_id uuid;
  tourneur1_id uuid;
  tourneur2_id uuid;
  admin_id uuid;
  melissa_id uuid;
  apa_id uuid;
  alexis_id uuid;
  maceo_id uuid;
  ines_id uuid;
  barth_id uuid;
  hugo_id uuid;
  cigale_id uuid;
  bataclan_id uuid;
  petit_bain_id uuid;
  alhambra_id uuid;
  trianon_id uuid;
  concert_invitation uuid := 'df100001-0000-4000-8000-000000000001';
  concert_operational uuid := 'df100002-0000-4000-8000-000000000002';
  concert_credit_1 uuid := 'df100003-0000-4000-8000-000000000003';
  concert_credit_2 uuid := 'df100004-0000-4000-8000-000000000004';
  concert_credit_3 uuid := 'df100005-0000-4000-8000-000000000005';
begin
  select id into strict club_id from public.organizations where slug = 'club-sandwich';
  select id into strict tourneur1_id from public.organizations where slug = 'tourneur1';
  select id into strict tourneur2_id from public.organizations where slug = 'tourneur2';

  select id into strict admin_id from auth.users where lower(email) = 'antoine@clubsandwich-records.com';
  select id into strict melissa_id from auth.users where lower(email) = 'antoinevgnl+tourneur1@gmail.com';
  select id into strict apa_id from auth.users where lower(email) = 'antoinevgnl+tourneur2@gmail.com';

  select id into strict alexis_id from auth.users where lower(email) = 'alexisschipman@gmail.com';
  select id into strict maceo_id from auth.users where lower(email) = 'maceoteixeira@gmail.com';
  select id into strict ines_id from auth.users where lower(email) = 'ines.abdennebi@outlook.fr';
  select id into strict barth_id from auth.users where lower(email) = 'mbarthelemy99@gmail.com';
  select id into strict hugo_id from auth.users where lower(email) = 'hugoplommet99@gmail.com';

  select id into strict cigale_id from public.venues where name = 'La Cigale';
  select id into strict bataclan_id from public.venues where name = 'Bataclan';
  select id into strict petit_bain_id from public.venues where name = 'Petit Bain';
  select id into strict alhambra_id from public.venues where name = 'Alhambra';
  select id into strict trianon_id from public.venues where name = 'Le Trianon';

  alter table public.concert_volunteers disable trigger concert_volunteers_email_notifications;
  alter table public.concert_volunteers disable trigger concert_volunteers_mission_sheet_email;
  alter table public.user_notifications disable trigger user_notifications_enqueue_email;

  -- Repasse propre si le script est rejoué avant la session.
  delete from public.invitation_campaigns where id = 'df400001-0000-4000-8000-000000000001';
  delete from public.volunteer_credits where concert_id in (concert_credit_1, concert_credit_2, concert_credit_3);
  delete from public.concert_volunteers where concert_id in (
    concert_invitation, concert_operational, concert_credit_1, concert_credit_2, concert_credit_3
  );
  delete from public.concerts where id in (
    concert_invitation, concert_operational, concert_credit_1, concert_credit_2, concert_credit_3
  );

  -- Stock partagé, réutilisé par le script officiel de nettoyage démo.
  insert into public.equipment_locations (id, name) values
    ('de600001-0000-4000-8000-000000000001', '[DÉMO] Local principal'),
    ('de600002-0000-4000-8000-000000000002', '[DÉMO] Cave'),
    ('de600003-0000-4000-8000-000000000003', '[DÉMO] Véhicule 1')
  on conflict (id) do nothing;

  insert into public.consumables (
    id, name, category, current_quantity, unit, alert_threshold, storage_location
  ) values
    ('de500001-0000-4000-8000-000000000001', '[DÉMO] Boîtes alimentaires 750 ml', 'Conditionnement', 240, 'box', 80, '[DÉMO] Cave'),
    ('de500002-0000-4000-8000-000000000002', '[DÉMO] Gants nitrile', 'Hygiène', 35, 'pair', 50, '[DÉMO] Local principal'),
    ('de500003-0000-4000-8000-000000000003', '[DÉMO] Sacs-poubelle 100 L', 'Hygiène', 18, 'roll', 10, '[DÉMO] Local principal'),
    ('de500005-0000-4000-8000-000000000005', '[DÉMO] Bouteilles d’eau', 'Équipe', 48, 'bottle', 24, '[DÉMO] Cave'),
    ('de500006-0000-4000-8000-000000000006', '[DÉMO] Boîtes alimentaires 500 ml', 'Conditionnement', 180, 'box', 60, '[DÉMO] Cave')
  on conflict (id) do nothing;

  insert into public.equipment_assets (
    id, name, category, internal_code, quantity_total, location_id, status, condition, notes
  ) values
    ('de700001-0000-4000-8000-000000000001', '[DÉMO] Caisses pliantes', 'Transport', 'DEMO-CAISSES', 12, 'de600002-0000-4000-8000-000000000002', 'available', 'Bon état', 'Lot de caisses alimentaires.'),
    ('de700002-0000-4000-8000-000000000002', '[DÉMO] Balance 50 kg', 'Pesée', 'DEMO-BALANCE-01', 1, 'de600001-0000-4000-8000-000000000001', 'available', 'Bon état', 'Pile vérifiée.'),
    ('de700004-0000-4000-8000-000000000004', '[DÉMO] Gilets haute visibilité', 'Sécurité', 'DEMO-GILETS', 8, 'de600003-0000-4000-8000-000000000003', 'available', 'Bon état', null),
    ('de700005-0000-4000-8000-000000000005', '[DÉMO] Trousse de secours', 'Sécurité', 'DEMO-SECOURS-01', 1, 'de600003-0000-4000-8000-000000000003', 'available', 'Complète', null)
  on conflict (id) do nothing;

  -- Concert 1 : invitation ouverte, aucune équipe pré-sélectionnée.
  insert into public.concerts (
    id, organization_id, artist, concert_date, concert_time, status, notes,
    created_by, venue_id, catering_closes_at, promoter_organization_id,
    promoter_contact_name, promoter_contact_phone, maraude_status
  ) values (
    concert_invitation, club_id,
    '[CE SOIR] Ouverte aux candidatures',
    current_date, time '20:30', 'planned',
    'Test en direct du 2026-08-26 : candidature bénévole et invitation.',
    melissa_id, cigale_id, time '23:00', tourneur1_id,
    'Mélissa Boutiflore', '+33600000201', 'open'
  );

  insert into public.invitation_campaigns (
    id, organization_id, concert_id, title, description, available_places,
    application_deadline, status, created_by, venue_id, event_date
  ) values (
    'df400001-0000-4000-8000-000000000001', tourneur1_id, concert_invitation,
    '[CE SOIR] Invitation ouverte',
    'Test en direct : candidature à l’invitation avec crédits.', 5,
    clock_timestamp() + interval '1 day', 'open', melissa_id,
    cigale_id, current_date
  );

  -- Concert 2 : équipe prête pour dérouler la maraude en direct ce soir.
  insert into public.concerts (
    id, organization_id, artist, concert_date, concert_time, status, notes,
    created_by, venue_id, catering_closes_at, promoter_organization_id,
    promoter_contact_name, promoter_contact_phone, maraude_status
  ) values (
    concert_operational, club_id,
    '[CE SOIR] Maraude équipe prête',
    current_date, time '20:30', 'confirmed',
    'Test en direct du 2026-08-26 : parcours opérationnel complet.',
    apa_id, bataclan_id, time '23:00', tourneur2_id,
    'Apa Pagnan', '+33600000202', 'team_ready'
  );

  insert into public.concert_volunteers (id, concert_id, user_id, status, team_role, created_at)
  values
    ('df200001-0000-4000-8000-000000000001', concert_operational, alexis_id, 'selected', 'team_leader', clock_timestamp() - interval '2 days'),
    ('df200002-0000-4000-8000-000000000002', concert_operational, maceo_id, 'selected', 'logistics', clock_timestamp() - interval '2 days'),
    ('df200003-0000-4000-8000-000000000003', concert_operational, ines_id, 'selected', 'communication', clock_timestamp() - interval '2 days'),
    ('df200004-0000-4000-8000-000000000004', concert_operational, barth_id, 'selected', 'collection_distribution', clock_timestamp() - interval '2 days'),
    ('df200005-0000-4000-8000-000000000005', concert_operational, hugo_id, 'selected', 'logistics', clock_timestamp() - interval '2 days');

  update public.concert_volunteers
  set confirmation_status = 'confirmed', role_acknowledged_at = clock_timestamp() - interval '1 hour'
  where id in (
    'df200001-0000-4000-8000-000000000001', 'df200002-0000-4000-8000-000000000002',
    'df200003-0000-4000-8000-000000000003', 'df200004-0000-4000-8000-000000000004',
    'df200005-0000-4000-8000-000000000005'
  );

  -- Trois maraudes passées, uniquement pour créditer les 5 bénévoles
  -- (le seuil de candidature aux invitations est de 3 crédits actifs).
  insert into public.concerts (
    id, organization_id, artist, concert_date, concert_time, status,
    created_by, venue_id, promoter_organization_id,
    promoter_contact_name, promoter_contact_phone, maraude_status,
    actual_start_at, actual_end_at
  ) values
    (concert_credit_1, club_id, '[DÉMO] Maraude créditée 1', current_date - 10, time '20:00', 'completed', admin_id, petit_bain_id, tourneur1_id, 'Mélissa Boutiflore', '+33600000201', 'completed', ((current_date - 10) + time '20:15') at time zone 'Europe/Paris', ((current_date - 10) + time '22:00') at time zone 'Europe/Paris'),
    (concert_credit_2, club_id, '[DÉMO] Maraude créditée 2', current_date - 20, time '20:00', 'completed', admin_id, alhambra_id, tourneur1_id, 'Mélissa Boutiflore', '+33600000201', 'completed', ((current_date - 20) + time '20:15') at time zone 'Europe/Paris', ((current_date - 20) + time '22:00') at time zone 'Europe/Paris'),
    (concert_credit_3, club_id, '[DÉMO] Maraude créditée 3', current_date - 30, time '20:00', 'completed', admin_id, trianon_id, tourneur2_id, 'Apa Pagnan', '+33600000202', 'completed', ((current_date - 30) + time '20:15') at time zone 'Europe/Paris', ((current_date - 30) + time '22:00') at time zone 'Europe/Paris');

  insert into public.concert_volunteers (id, concert_id, user_id, status, created_at)
  select gen_random_uuid(), c.concert_id, c.user_id, 'selected', clock_timestamp() - interval '40 days'
  from (
    values
      (concert_credit_1, alexis_id), (concert_credit_1, maceo_id), (concert_credit_1, ines_id), (concert_credit_1, barth_id), (concert_credit_1, hugo_id),
      (concert_credit_2, alexis_id), (concert_credit_2, maceo_id), (concert_credit_2, ines_id), (concert_credit_2, barth_id), (concert_credit_2, hugo_id),
      (concert_credit_3, alexis_id), (concert_credit_3, maceo_id), (concert_credit_3, ines_id), (concert_credit_3, barth_id), (concert_credit_3, hugo_id)
  ) as c(concert_id, user_id);

  update public.concert_volunteers
  set confirmation_status = 'confirmed', role_acknowledged_at = clock_timestamp() - interval '35 days',
      attendance_status = 'present', attendance_validated_at = clock_timestamp() - interval '30 days',
      attendance_validated_by = admin_id
  where concert_id in (concert_credit_1, concert_credit_2, concert_credit_3) and status = 'selected';

  insert into public.volunteer_credits (id, concert_id, application_id, user_id, status, awarded_by, awarded_at)
  select gen_random_uuid(), cv.concert_id, cv.id, cv.user_id, 'active', admin_id, clock_timestamp() - interval '29 days'
  from public.concert_volunteers cv
  where cv.concert_id in (concert_credit_1, concert_credit_2, concert_credit_3);

  alter table public.concert_volunteers enable trigger concert_volunteers_mission_sheet_email;
  alter table public.concert_volunteers enable trigger concert_volunteers_email_notifications;
  alter table public.user_notifications enable trigger user_notifications_enqueue_email;

  raise notice 'Jeu de données de test en direct créé avec succès.';
end;
$seed$;

commit;

select
  (select count(*) from public.concerts where artist like '[CE SOIR]%' or artist like '[DÉMO] Maraude créditée%') as concerts,
  (select count(*) from public.concert_volunteers cv join public.concerts c on c.id = cv.concert_id where c.artist like '[CE SOIR]%' or c.artist like '[DÉMO] Maraude créditée%') as applications,
  (select count(*) from public.volunteer_credits) as credits,
  (select count(*) from public.invitation_campaigns where title like '[CE SOIR]%') as invitations;
