-- Jeu de données de démonstration Club Sandwich.
--
-- À exécuter uniquement sur la préproduction. Le script est réexécutable :
-- il remplace exclusivement les lignes portant les UUID réservés ci-dessous.
-- Aucun compte Auth n'est créé et aucun mot de passe n'est manipulé.

begin;

do $seed$
declare
  club_id uuid;
  promoter_id uuid;
  admin_id uuid;
  promoter_user_id uuid;
  volunteer_1 uuid;
  volunteer_2 uuid;
  volunteer_3 uuid;
  volunteer_4 uuid;
  olympia_id uuid;
  bataclan_id uuid;
  point_ephemere_id uuid;
  cigale_id uuid;
  trianon_id uuid;
  belle_villoise_id uuid;
  accor_arena_id uuid;
begin
  select id into strict club_id
  from public.organizations
  where slug = 'club-sandwich';

  select id into strict promoter_id
  from public.organizations
  where slug = 'aeg';

  select id into strict admin_id
  from auth.users
  where lower(email) = 'antoine@clubsandwich-records.com';

  select id into strict promoter_user_id
  from auth.users
  where lower(email) = 'tourneurtest@gmail.com';

  select id into strict volunteer_1
  from auth.users
  where lower(email) = 'antoinevgnl@gmail.com';

  select id into strict volunteer_2
  from auth.users
  where lower(email) = 'antoinevgnl+benevole2@gmail.com';

  select id into strict volunteer_3
  from auth.users
  where lower(email) = 'antoinevgnl+benevole3@gmail.com';

  select id into strict volunteer_4
  from auth.users
  where lower(email) = 'antoinevgnl+benevole4@gmail.com';

  select id into strict olympia_id from public.venues where name = 'L’Olympia';
  select id into strict bataclan_id from public.venues where name = 'Bataclan';
  select id into strict point_ephemere_id
  from public.venues where name = 'Point Éphémère';
  select id into strict cigale_id from public.venues where name = 'La Cigale';
  select id into strict trianon_id from public.venues where name = 'Le Trianon';
  select id into strict belle_villoise_id
  from public.venues where name = 'La Bellevilloise';
  select id into strict accor_arena_id
  from public.venues where name = 'Accor Arena';

  -- Les triggers d'e-mail ne doivent jamais expédier de messages à partir du
  -- seed. Le trigger de collecte est suspendu le temps de remplacer les
  -- anciennes lignes de démonstration, y compris celles déjà clôturées.
  alter table public.concert_volunteers
    disable trigger concert_volunteers_email_notifications;
  alter table public.concert_volunteers
    disable trigger concert_volunteers_mission_sheet_email;
  alter table public.concerts
    disable trigger concerts_email_completion_notification;
  alter table public.maraude_collections
    disable trigger maraude_collections_enforce_active_maraude;

  delete from public.invitation_campaigns
  where id in (
    'de400001-0000-4000-8000-000000000001'::uuid,
    'de400002-0000-4000-8000-000000000002'::uuid
  );

  delete from public.concerts
  where id in (
    'de100001-0000-4000-8000-000000000001'::uuid,
    'de100002-0000-4000-8000-000000000002'::uuid,
    'de100003-0000-4000-8000-000000000003'::uuid,
    'de100004-0000-4000-8000-000000000004'::uuid,
    'de100005-0000-4000-8000-000000000005'::uuid,
    'de100006-0000-4000-8000-000000000006'::uuid,
    'de100007-0000-4000-8000-000000000007'::uuid,
    'de100008-0000-4000-8000-000000000008'::uuid
  );

  delete from public.consumable_movements
  where consumable_id in (
    'de500001-0000-4000-8000-000000000001'::uuid,
    'de500002-0000-4000-8000-000000000002'::uuid,
    'de500003-0000-4000-8000-000000000003'::uuid,
    'de500004-0000-4000-8000-000000000004'::uuid,
    'de500005-0000-4000-8000-000000000005'::uuid,
    'de500006-0000-4000-8000-000000000006'::uuid
  );
  delete from public.consumables
  where id in (
    'de500001-0000-4000-8000-000000000001'::uuid,
    'de500002-0000-4000-8000-000000000002'::uuid,
    'de500003-0000-4000-8000-000000000003'::uuid,
    'de500004-0000-4000-8000-000000000004'::uuid,
    'de500005-0000-4000-8000-000000000005'::uuid,
    'de500006-0000-4000-8000-000000000006'::uuid
  );

  delete from public.equipment_events
  where equipment_id in (
    'de700001-0000-4000-8000-000000000001'::uuid,
    'de700002-0000-4000-8000-000000000002'::uuid,
    'de700003-0000-4000-8000-000000000003'::uuid,
    'de700004-0000-4000-8000-000000000004'::uuid,
    'de700005-0000-4000-8000-000000000005'::uuid
  );
  delete from public.equipment_assets
  where id in (
    'de700001-0000-4000-8000-000000000001'::uuid,
    'de700002-0000-4000-8000-000000000002'::uuid,
    'de700003-0000-4000-8000-000000000003'::uuid,
    'de700004-0000-4000-8000-000000000004'::uuid,
    'de700005-0000-4000-8000-000000000005'::uuid
  );
  delete from public.equipment_locations
  where id in (
    'de600001-0000-4000-8000-000000000001'::uuid,
    'de600002-0000-4000-8000-000000000002'::uuid,
    'de600003-0000-4000-8000-000000000003'::uuid
  );

  insert into public.volunteer_profiles (
    user_id,
    birth_date,
    has_driving_license,
    can_lift_heavy_loads,
    emergency_contact_name,
    emergency_contact_phone,
    additional_information,
    certifications
  ) values
    (
      volunteer_1, date '1992-04-12', true, true,
      'Contact test 1', '+33600000101',
      'Disponible en soirée.', array['Permis B']::text[]
    ),
    (
      volunteer_2, date '1997-09-03', false, true,
      'Contact test 2', '+33600000102',
      'Préfère les missions de collecte.', array[]::text[]
    ),
    (
      volunteer_3, date '1989-01-26', true, false,
      'Contact test 3', '+33600000103',
      'Expérience en logistique.', array['Premiers secours']::text[]
    ),
    (
      volunteer_4, date '2000-06-18', null, null,
      null, null, null, array[]::text[]
    )
  on conflict (user_id) do nothing;

  insert into public.equipment_locations (id, name)
  values
    ('de600001-0000-4000-8000-000000000001', '[DÉMO] Local principal'),
    ('de600002-0000-4000-8000-000000000002', '[DÉMO] Cave'),
    ('de600003-0000-4000-8000-000000000003', '[DÉMO] Véhicule 1');

  insert into public.consumables (
    id, name, category, current_quantity, unit, alert_threshold,
    storage_location
  ) values
    (
      'de500001-0000-4000-8000-000000000001',
      '[DÉMO] Boîtes alimentaires 750 ml', 'Conditionnement', 240,
      'box', 80, '[DÉMO] Cave'
    ),
    (
      'de500002-0000-4000-8000-000000000002',
      '[DÉMO] Gants nitrile', 'Hygiène', 35,
      'pair', 50, '[DÉMO] Local principal'
    ),
    (
      'de500003-0000-4000-8000-000000000003',
      '[DÉMO] Sacs-poubelle 100 L', 'Hygiène', 18,
      'roll', 10, '[DÉMO] Local principal'
    ),
    (
      'de500004-0000-4000-8000-000000000004',
      '[DÉMO] Lingettes désinfectantes', 'Hygiène', 8,
      'pack', 12, '[DÉMO] Véhicule 1'
    ),
    (
      'de500005-0000-4000-8000-000000000005',
      '[DÉMO] Bouteilles d’eau', 'Équipe', 48,
      'bottle', 24, '[DÉMO] Cave'
    ),
    (
      'de500006-0000-4000-8000-000000000006',
      '[DÉMO] Boîtes alimentaires 500 ml', 'Conditionnement', 180,
      'box', 60, '[DÉMO] Cave'
    );

  insert into public.consumable_movements (
    id, consumable_id, previous_quantity, new_quantity, reason, note, actor_id
  ) values
    (
      'de510001-0000-4000-8000-000000000001',
      'de500001-0000-4000-8000-000000000001', 0, 240, 'restock',
      '[DÉMO] Stock initial', admin_id
    ),
    (
      'de510002-0000-4000-8000-000000000002',
      'de500002-0000-4000-8000-000000000002', 0, 35, 'restock',
      '[DÉMO] Stock initial', admin_id
    ),
    (
      'de510003-0000-4000-8000-000000000003',
      'de500003-0000-4000-8000-000000000003', 0, 18, 'restock',
      '[DÉMO] Stock initial', admin_id
    ),
    (
      'de510004-0000-4000-8000-000000000004',
      'de500004-0000-4000-8000-000000000004', 0, 8, 'restock',
      '[DÉMO] Stock initial', admin_id
    ),
    (
      'de510005-0000-4000-8000-000000000005',
      'de500005-0000-4000-8000-000000000005', 0, 48, 'restock',
      '[DÉMO] Stock initial', admin_id
    ),
    (
      'de510006-0000-4000-8000-000000000006',
      'de500006-0000-4000-8000-000000000006', 0, 180, 'restock',
      '[DÉMO] Stock initial', admin_id
    );

  insert into public.equipment_assets (
    id, name, category, internal_code, quantity_total, location_id,
    status, condition, notes
  ) values
    (
      'de700001-0000-4000-8000-000000000001',
      '[DÉMO] Caisses pliantes', 'Transport', 'DEMO-CAISSES', 12,
      'de600002-0000-4000-8000-000000000002', 'available',
      'Bon état', 'Lot de caisses alimentaires.'
    ),
    (
      'de700002-0000-4000-8000-000000000002',
      '[DÉMO] Balance 50 kg', 'Pesée', 'DEMO-BALANCE-01', 1,
      'de600001-0000-4000-8000-000000000001', 'available',
      'Bon état', 'Pile vérifiée.'
    ),
    (
      'de700003-0000-4000-8000-000000000003',
      '[DÉMO] Diables de manutention', 'Transport', 'DEMO-DIABLES', 2,
      'de600002-0000-4000-8000-000000000002', 'available',
      'Bon état', null
    ),
    (
      'de700004-0000-4000-8000-000000000004',
      '[DÉMO] Gilets haute visibilité', 'Sécurité', 'DEMO-GILETS', 8,
      'de600003-0000-4000-8000-000000000003', 'needs_cleaning',
      'À nettoyer', 'Deux gilets à contrôler.'
    ),
    (
      'de700005-0000-4000-8000-000000000005',
      '[DÉMO] Trousse de secours', 'Sécurité', 'DEMO-SECOURS-01', 1,
      'de600003-0000-4000-8000-000000000003', 'available',
      'Complète', null
    );

  -- Les maraudes clôturées sont d'abord insérées dans un état opérationnel :
  -- cela permet aux contraintes de collecte et distribution de jouer leur
  -- rôle, avant la transition finale vers completed.
  insert into public.concerts (
    id, organization_id, artist, concert_date, concert_time, status, notes,
    created_by, venue_id, catering_closes_at, promoter_organization_id,
    promoter_contact_name, promoter_contact_phone, maraude_status,
    actual_start_at, closing_comment, cancellation_reason
  ) values
    (
      'de100001-0000-4000-8000-000000000001', club_id,
      '[ÉTAPE 1 — OUVERTE] Visibilité sans candidature',
      current_date + 5, time '20:30', 'planned',
      'À tester : visibilité bénévole, candidature et invitation ouverte.',
      promoter_user_id, olympia_id, time '23:00', promoter_id,
      'Théo Tourneur', '+33610000001', 'open', null, null, null
    ),
    (
      'de100002-0000-4000-8000-000000000002', club_id,
      '[ÉTAPE 2 — CANDIDATURES] Sélection et refus',
      current_date + 12, time '21:00', 'planned',
      'À tester : candidatures en attente, désistée et non sélectionnée.',
      admin_id, bataclan_id, time '22:45', promoter_id,
      'Camille Production', '+33610000002', 'open', null, null, null
    ),
    (
      'de100003-0000-4000-8000-000000000003', club_id,
      '[ÉTAPE 3 — ÉQUIPE PRÊTE] Rôles et confirmations',
      current_date + 2, time '20:00', 'confirmed',
      'À tester : équipe complète, rôles et confirmations reçues.',
      promoter_user_id, cigale_id, time '23:15', promoter_id,
      'Théo Tourneur', '+33610000001', 'team_ready', null, null, null
    ),
    (
      'de100004-0000-4000-8000-000000000004', club_id,
      '[ÉTAPE 4 — DISTRIBUTION] Plusieurs types de boîtes',
      current_date, time '20:00', 'confirmed',
      'À tester : quantités écoulées et restantes par référence de boîte.',
      admin_id, point_ephemere_id, time '22:30', promoter_id,
      'Théo Tourneur', '+33610000001', 'in_progress',
      clock_timestamp() - interval '2 hours', null, null
    ),
    (
      'de100005-0000-4000-8000-000000000005', club_id,
      '[ÉTAPE 5 — BILAN] Parcours opérationnel complet',
      current_date - 7, time '20:30', 'completed',
      'À tester : bilan complet avec collecte, distribution et rencontres.',
      promoter_user_id, trianon_id, time '22:30', promoter_id,
      'Théo Tourneur', '+33610000001', 'in_progress',
      ((current_date - 7) + time '20:15') at time zone 'Europe/Paris',
      '[DÉMO] Maraude fluide, aucun incident.', null
    ),
    (
      'de100006-0000-4000-8000-000000000006', club_id,
      '[CAS — ABSENCE] Présence et bilan',
      current_date - 21, time '21:00', 'completed',
      'À tester : bilan avec une absence dans l’équipe.',
      admin_id, belle_villoise_id, time '23:00', promoter_id,
      'Camille Production', '+33610000002', 'in_progress',
      ((current_date - 21) + time '20:40') at time zone 'Europe/Paris',
      '[DÉMO] Distribution terminée avec un bénévole absent.', null
    ),
    (
      'de100007-0000-4000-8000-000000000007', club_id,
      '[CAS — HISTORIQUE] Statistiques et crédits',
      current_date - 45, time '20:00', 'completed',
      'À tester : historique bénévole, statistiques et crédit attribué.',
      promoter_user_id, accor_arena_id, time '22:15', promoter_id,
      'Théo Tourneur', '+33610000001', 'in_progress',
      ((current_date - 45) + time '19:50') at time zone 'Europe/Paris',
      '[DÉMO] Volume important récupéré et distribué.', null
    ),
    (
      'de100008-0000-4000-8000-000000000008', club_id,
      '[CAS — ANNULÉE] Lecture seule',
      current_date + 20, time '20:00', 'cancelled',
      'À tester : annulation, motif et actions indisponibles.',
      admin_id, olympia_id, null, promoter_id,
      'Camille Production', '+33610000002', 'cancelled', null, null,
      'Annulation de la tournée'
    );

  -- Candidatures ouvertes.
  insert into public.concert_volunteers (
    id, concert_id, user_id, status, team_role, created_at
  ) values
    (
      'de200201-0000-4000-8000-000000000001',
      'de100002-0000-4000-8000-000000000002', volunteer_1,
      'pending', null, clock_timestamp() - interval '3 days'
    ),
    (
      'de200202-0000-4000-8000-000000000002',
      'de100002-0000-4000-8000-000000000002', volunteer_2,
      'pending', null, clock_timestamp() - interval '2 days'
    ),
    (
      'de200203-0000-4000-8000-000000000003',
      'de100002-0000-4000-8000-000000000002', volunteer_3,
      'withdrawn', null, clock_timestamp() - interval '4 days'
    ),
    (
      'de200204-0000-4000-8000-000000000004',
      'de100002-0000-4000-8000-000000000002', volunteer_4,
      'not_selected', null, clock_timestamp() - interval '5 days'
    );

  -- Équipes sélectionnées des scénarios prêt, en cours et terminés.
  insert into public.concert_volunteers (
    id, concert_id, user_id, status, team_role, created_at
  )
  select * from (
    values
      ('de200301-0000-4000-8000-000000000001'::uuid, 'de100003-0000-4000-8000-000000000003'::uuid, volunteer_1, 'selected'::public.concert_volunteer_status, 'team_leader'::public.maraude_role, clock_timestamp() - interval '8 days'),
      ('de200302-0000-4000-8000-000000000002'::uuid, 'de100003-0000-4000-8000-000000000003'::uuid, volunteer_2, 'selected'::public.concert_volunteer_status, 'communication'::public.maraude_role, clock_timestamp() - interval '8 days'),
      ('de200303-0000-4000-8000-000000000003'::uuid, 'de100003-0000-4000-8000-000000000003'::uuid, volunteer_3, 'selected'::public.concert_volunteer_status, 'logistics'::public.maraude_role, clock_timestamp() - interval '8 days'),
      ('de200304-0000-4000-8000-000000000004'::uuid, 'de100003-0000-4000-8000-000000000003'::uuid, volunteer_4, 'selected'::public.concert_volunteer_status, 'collection_distribution'::public.maraude_role, clock_timestamp() - interval '8 days'),

      ('de200401-0000-4000-8000-000000000001'::uuid, 'de100004-0000-4000-8000-000000000004'::uuid, volunteer_1, 'selected'::public.concert_volunteer_status, 'team_leader'::public.maraude_role, clock_timestamp() - interval '10 days'),
      ('de200402-0000-4000-8000-000000000002'::uuid, 'de100004-0000-4000-8000-000000000004'::uuid, volunteer_2, 'selected'::public.concert_volunteer_status, 'communication'::public.maraude_role, clock_timestamp() - interval '10 days'),
      ('de200403-0000-4000-8000-000000000003'::uuid, 'de100004-0000-4000-8000-000000000004'::uuid, volunteer_3, 'selected'::public.concert_volunteer_status, 'logistics'::public.maraude_role, clock_timestamp() - interval '10 days'),
      ('de200404-0000-4000-8000-000000000004'::uuid, 'de100004-0000-4000-8000-000000000004'::uuid, volunteer_4, 'selected'::public.concert_volunteer_status, 'collection_distribution'::public.maraude_role, clock_timestamp() - interval '10 days'),

      ('de200501-0000-4000-8000-000000000001'::uuid, 'de100005-0000-4000-8000-000000000005'::uuid, volunteer_1, 'selected'::public.concert_volunteer_status, 'team_leader'::public.maraude_role, clock_timestamp() - interval '20 days'),
      ('de200502-0000-4000-8000-000000000002'::uuid, 'de100005-0000-4000-8000-000000000005'::uuid, volunteer_2, 'selected'::public.concert_volunteer_status, 'communication'::public.maraude_role, clock_timestamp() - interval '20 days'),
      ('de200503-0000-4000-8000-000000000003'::uuid, 'de100005-0000-4000-8000-000000000005'::uuid, volunteer_3, 'selected'::public.concert_volunteer_status, 'logistics'::public.maraude_role, clock_timestamp() - interval '20 days'),

      ('de200601-0000-4000-8000-000000000001'::uuid, 'de100006-0000-4000-8000-000000000006'::uuid, volunteer_1, 'selected'::public.concert_volunteer_status, 'team_leader'::public.maraude_role, clock_timestamp() - interval '35 days'),
      ('de200602-0000-4000-8000-000000000002'::uuid, 'de100006-0000-4000-8000-000000000006'::uuid, volunteer_2, 'selected'::public.concert_volunteer_status, 'communication'::public.maraude_role, clock_timestamp() - interval '35 days'),
      ('de200603-0000-4000-8000-000000000003'::uuid, 'de100006-0000-4000-8000-000000000006'::uuid, volunteer_3, 'selected'::public.concert_volunteer_status, 'logistics'::public.maraude_role, clock_timestamp() - interval '35 days'),
      ('de200604-0000-4000-8000-000000000004'::uuid, 'de100006-0000-4000-8000-000000000006'::uuid, volunteer_4, 'selected'::public.concert_volunteer_status, 'collection_distribution'::public.maraude_role, clock_timestamp() - interval '35 days'),

      ('de200701-0000-4000-8000-000000000001'::uuid, 'de100007-0000-4000-8000-000000000007'::uuid, volunteer_1, 'selected'::public.concert_volunteer_status, 'team_leader'::public.maraude_role, clock_timestamp() - interval '60 days'),
      ('de200702-0000-4000-8000-000000000002'::uuid, 'de100007-0000-4000-8000-000000000007'::uuid, volunteer_3, 'selected'::public.concert_volunteer_status, 'logistics'::public.maraude_role, clock_timestamp() - interval '60 days'),
      ('de200703-0000-4000-8000-000000000003'::uuid, 'de100007-0000-4000-8000-000000000007'::uuid, volunteer_4, 'selected'::public.concert_volunteer_status, 'collection_distribution'::public.maraude_role, clock_timestamp() - interval '60 days'),
      ('de200704-0000-4000-8000-000000000004'::uuid, 'de100007-0000-4000-8000-000000000007'::uuid, volunteer_2, 'withdrawn'::public.concert_volunteer_status, null::public.maraude_role, clock_timestamp() - interval '61 days')
  ) as applications(id, concert_id, user_id, status, team_role, created_at);

  -- Confirmer les sélections. Le trigger métier conserve les dates de demande
  -- et renseigne automatiquement la date de réponse.
  update public.concert_volunteers
  set
    confirmation_status = 'confirmed',
    role_acknowledged_at = clock_timestamp() - interval '1 day'
  where id in (
    'de200301-0000-4000-8000-000000000001'::uuid,
    'de200302-0000-4000-8000-000000000002'::uuid,
    'de200303-0000-4000-8000-000000000003'::uuid,
    'de200304-0000-4000-8000-000000000004'::uuid,
    'de200401-0000-4000-8000-000000000001'::uuid,
    'de200402-0000-4000-8000-000000000002'::uuid,
    'de200403-0000-4000-8000-000000000003'::uuid,
    'de200404-0000-4000-8000-000000000004'::uuid,
    'de200501-0000-4000-8000-000000000001'::uuid,
    'de200502-0000-4000-8000-000000000002'::uuid,
    'de200503-0000-4000-8000-000000000003'::uuid,
    'de200601-0000-4000-8000-000000000001'::uuid,
    'de200602-0000-4000-8000-000000000002'::uuid,
    'de200603-0000-4000-8000-000000000003'::uuid,
    'de200604-0000-4000-8000-000000000004'::uuid,
    'de200701-0000-4000-8000-000000000001'::uuid,
    'de200702-0000-4000-8000-000000000002'::uuid,
    'de200703-0000-4000-8000-000000000003'::uuid
  );

  -- Présences des scénarios opérationnels et clôturés.
  update public.concert_volunteers
  set
    attendance_status = case
      when id = 'de200604-0000-4000-8000-000000000004'::uuid
        then 'absent'::public.volunteer_attendance_status
      else 'present'::public.volunteer_attendance_status
    end,
    attendance_validated_at = clock_timestamp() - interval '1 hour',
    attendance_validated_by = admin_id
  where concert_id in (
    'de100004-0000-4000-8000-000000000004'::uuid,
    'de100005-0000-4000-8000-000000000005'::uuid,
    'de100006-0000-4000-8000-000000000006'::uuid,
    'de100007-0000-4000-8000-000000000007'::uuid
  ) and status = 'selected';

  insert into public.maraude_consumable_allocations (
    id, concert_id, consumable_id, planned_quantity, actual_quantity,
    validated_by, validated_at
  ) values
    (
      'de800001-0000-4000-8000-000000000001',
      'de100004-0000-4000-8000-000000000004',
      'de500001-0000-4000-8000-000000000001', 40, 38,
      volunteer_1, clock_timestamp() - interval '110 minutes'
    ),
    (
      'de800002-0000-4000-8000-000000000002',
      'de100004-0000-4000-8000-000000000004',
      'de500002-0000-4000-8000-000000000002', 8, 8,
      volunteer_1, clock_timestamp() - interval '110 minutes'
    ),
    (
      'de800003-0000-4000-8000-000000000003',
      'de100004-0000-4000-8000-000000000004',
      'de500006-0000-4000-8000-000000000006', 16, 15,
      volunteer_1, clock_timestamp() - interval '110 minutes'
    );

  insert into public.maraude_equipment_allocations (
    id, concert_id, equipment_id, planned_quantity, taken_quantity,
    checkout_validated_by, checkout_validated_at
  ) values
    (
      'de810001-0000-4000-8000-000000000001',
      'de100004-0000-4000-8000-000000000004',
      'de700001-0000-4000-8000-000000000001', 6, 6,
      volunteer_1, clock_timestamp() - interval '110 minutes'
    ),
    (
      'de810002-0000-4000-8000-000000000002',
      'de100004-0000-4000-8000-000000000004',
      'de700002-0000-4000-8000-000000000002', 1, 1,
      volunteer_1, clock_timestamp() - interval '110 minutes'
    ),
    (
      'de810003-0000-4000-8000-000000000003',
      'de100004-0000-4000-8000-000000000004',
      'de700005-0000-4000-8000-000000000005', 1, 1,
      volunteer_1, clock_timestamp() - interval '110 minutes'
    );

  insert into public.maraude_operations (
    concert_id, current_step,
    preparation_completed_at, preparation_completed_by,
    collection_completed_at, collection_completed_by,
    last_modified_by
  ) values
    (
      'de100004-0000-4000-8000-000000000004', 'distribution',
      clock_timestamp() - interval '110 minutes', volunteer_1,
      clock_timestamp() - interval '25 minutes', volunteer_1,
      volunteer_1
    ),
    (
      'de100005-0000-4000-8000-000000000005', 'summary',
      ((current_date - 7) + time '20:20') at time zone 'Europe/Paris', volunteer_1,
      ((current_date - 7) + time '21:20') at time zone 'Europe/Paris', volunteer_1,
      admin_id
    ),
    (
      'de100006-0000-4000-8000-000000000006', 'summary',
      ((current_date - 21) + time '20:45') at time zone 'Europe/Paris', volunteer_1,
      ((current_date - 21) + time '21:40') at time zone 'Europe/Paris', volunteer_1,
      admin_id
    ),
    (
      'de100007-0000-4000-8000-000000000007', 'summary',
      ((current_date - 45) + time '19:55') at time zone 'Europe/Paris', volunteer_1,
      ((current_date - 45) + time '21:00') at time zone 'Europe/Paris', volunteer_1,
      admin_id
    );

  update public.maraude_operations
  set
    distribution_completed_at = case concert_id
      when 'de100005-0000-4000-8000-000000000005'::uuid then ((current_date - 7) + time '22:00') at time zone 'Europe/Paris'
      when 'de100006-0000-4000-8000-000000000006'::uuid then ((current_date - 21) + time '22:15') at time zone 'Europe/Paris'
      else ((current_date - 45) + time '21:45') at time zone 'Europe/Paris'
    end,
    distribution_completed_by = volunteer_1,
    equipment_return_completed_at = case concert_id
      when 'de100005-0000-4000-8000-000000000005'::uuid then ((current_date - 7) + time '22:10') at time zone 'Europe/Paris'
      when 'de100006-0000-4000-8000-000000000006'::uuid then ((current_date - 21) + time '22:25') at time zone 'Europe/Paris'
      else ((current_date - 45) + time '21:55') at time zone 'Europe/Paris'
    end,
    equipment_return_completed_by = volunteer_1,
    summary_completed_at = case concert_id
      when 'de100005-0000-4000-8000-000000000005'::uuid then ((current_date - 7) + time '22:20') at time zone 'Europe/Paris'
      when 'de100006-0000-4000-8000-000000000006'::uuid then ((current_date - 21) + time '22:35') at time zone 'Europe/Paris'
      else ((current_date - 45) + time '22:05') at time zone 'Europe/Paris'
    end,
    summary_completed_by = admin_id
  where concert_id in (
    'de100005-0000-4000-8000-000000000005'::uuid,
    'de100006-0000-4000-8000-000000000006'::uuid,
    'de100007-0000-4000-8000-000000000007'::uuid
  );

  insert into public.maraude_collections (
    id, concert_id, category, description, quantity, unit,
    weight_kg, average_weight_kg, comment
  ) values
    (
      'de900401-0000-4000-8000-000000000001',
      'de100004-0000-4000-8000-000000000004', 'prepared_meals',
      'Plats préparés', 38, 'piece', null, 0.42,
      '[DÉMO] Conditionnement varié.'
    ),
    (
      'de900402-0000-4000-8000-000000000002',
      'de100004-0000-4000-8000-000000000004', 'bakery',
      'Pains et viennoiseries', 3, 'crate', 8.4, null, null
    ),
    (
      'de900501-0000-4000-8000-000000000001',
      'de100005-0000-4000-8000-000000000005', 'prepared_meals',
      'Plats chauds', 54, 'piece', null, 0.38, null
    ),
    (
      'de900502-0000-4000-8000-000000000002',
      'de100005-0000-4000-8000-000000000005', 'fruits_vegetables',
      'Fruits frais', 4, 'crate', 18.5, null, null
    ),
    (
      'de900601-0000-4000-8000-000000000001',
      'de100006-0000-4000-8000-000000000006', 'prepared_meals',
      'Plateaux repas', 42, 'piece', null, 0.44, null
    ),
    (
      'de900602-0000-4000-8000-000000000002',
      'de100006-0000-4000-8000-000000000006', 'dairy',
      'Produits laitiers', 2, 'box', 7.2, null,
      '[DÉMO] Transportés en glacière.'
    ),
    (
      'de900701-0000-4000-8000-000000000001',
      'de100007-0000-4000-8000-000000000007', 'prepared_meals',
      'Repas complets', 76, 'piece', null, 0.41, null
    ),
    (
      'de900702-0000-4000-8000-000000000002',
      'de100007-0000-4000-8000-000000000007', 'bakery',
      'Pain', 5, 'crate', 12.5, null, null
    );

  insert into public.maraude_distributions (
    id, concert_id, distribution_location, estimated_beneficiaries,
    distributed_meals, remaining_weight_kg,
    distribution_started_at, distribution_completed_at,
    incident_comment, collected_boxes, distributed_boxes, remaining_boxes,
    last_modified_by
  ) values
    (
      'dea00501-0000-4000-8000-000000000001',
      'de100005-0000-4000-8000-000000000005',
      'Gare du Nord et alentours', 47, 44, 1.8,
      ((current_date - 7) + time '21:25') at time zone 'Europe/Paris',
      ((current_date - 7) + time '22:00') at time zone 'Europe/Paris',
      null, 9, 8, 1, admin_id
    ),
    (
      'dea00601-0000-4000-8000-000000000001',
      'de100006-0000-4000-8000-000000000006',
      'Place de la République', 39, 37, 0.9,
      ((current_date - 21) + time '21:45') at time zone 'Europe/Paris',
      ((current_date - 21) + time '22:15') at time zone 'Europe/Paris',
      '[DÉMO] Pluie pendant une partie de la distribution.',
      7, 7, 0, admin_id
    ),
    (
      'dea00701-0000-4000-8000-000000000001',
      'de100007-0000-4000-8000-000000000007',
      'Porte de la Chapelle', 68, 65, 2.4,
      ((current_date - 45) + time '21:05') at time zone 'Europe/Paris',
      ((current_date - 45) + time '21:45') at time zone 'Europe/Paris',
      null, 12, 11, 1, admin_id
    );

  insert into public.maraude_operational_reports (
    concert_id, total_weight_kg, estimated_meals, comment,
    last_modified_by, distance_km, quantities_unavailable
  ) values
    (
      'de100005-0000-4000-8000-000000000005', 39.02, 44,
      '[DÉMO] Bon déroulement général.', admin_id, 8.4, false
    ),
    (
      'de100006-0000-4000-8000-000000000006', 25.68, 37,
      '[DÉMO] Distribution adaptée à la météo.', admin_id, 6.8, false
    ),
    (
      'de100007-0000-4000-8000-000000000007', 43.66, 65,
      '[DÉMO] Forte collecte, équipe efficace.', admin_id, 11.2, false
    );

  insert into public.encounters (
    id, maraude_id, created_by, latitude, longitude, accuracy, created_at
  ) values
    ('deb00401-0000-4000-8000-000000000001', 'de100004-0000-4000-8000-000000000004', volunteer_1, 48.870, 2.365, 18, clock_timestamp() - interval '18 minutes'),
    ('deb00402-0000-4000-8000-000000000002', 'de100004-0000-4000-8000-000000000004', volunteer_2, 48.868, 2.362, 24, clock_timestamp() - interval '12 minutes'),
    ('deb00403-0000-4000-8000-000000000003', 'de100004-0000-4000-8000-000000000004', volunteer_1, 48.872, 2.360, 15, clock_timestamp() - interval '6 minutes'),
    ('deb00501-0000-4000-8000-000000000001', 'de100005-0000-4000-8000-000000000005', volunteer_1, 48.880, 2.355, 20, ((current_date - 7) + time '21:32') at time zone 'Europe/Paris'),
    ('deb00502-0000-4000-8000-000000000002', 'de100005-0000-4000-8000-000000000005', volunteer_2, 48.878, 2.352, 28, ((current_date - 7) + time '21:41') at time zone 'Europe/Paris'),
    ('deb00503-0000-4000-8000-000000000003', 'de100005-0000-4000-8000-000000000005', volunteer_3, 48.882, 2.349, 19, ((current_date - 7) + time '21:49') at time zone 'Europe/Paris'),
    ('deb00601-0000-4000-8000-000000000001', 'de100006-0000-4000-8000-000000000006', volunteer_1, 48.867, 2.363, 17, ((current_date - 21) + time '21:52') at time zone 'Europe/Paris'),
    ('deb00602-0000-4000-8000-000000000002', 'de100006-0000-4000-8000-000000000006', volunteer_3, 48.865, 2.366, 31, ((current_date - 21) + time '22:03') at time zone 'Europe/Paris'),
    ('deb00701-0000-4000-8000-000000000001', 'de100007-0000-4000-8000-000000000007', volunteer_1, 48.898, 2.360, 21, ((current_date - 45) + time '21:12') at time zone 'Europe/Paris'),
    ('deb00702-0000-4000-8000-000000000002', 'de100007-0000-4000-8000-000000000007', volunteer_3, 48.900, 2.365, 25, ((current_date - 45) + time '21:24') at time zone 'Europe/Paris'),
    ('deb00703-0000-4000-8000-000000000003', 'de100007-0000-4000-8000-000000000007', volunteer_4, 48.896, 2.368, 22, ((current_date - 45) + time '21:35') at time zone 'Europe/Paris');

  -- Clôture finale des trois maraudes historiques.
  update public.concerts
  set
    maraude_status = 'completed',
    actual_end_at = case id
      when 'de100005-0000-4000-8000-000000000005'::uuid then ((current_date - 7) + time '22:20') at time zone 'Europe/Paris'
      when 'de100006-0000-4000-8000-000000000006'::uuid then ((current_date - 21) + time '22:35') at time zone 'Europe/Paris'
      else ((current_date - 45) + time '22:05') at time zone 'Europe/Paris'
    end
  where id in (
    'de100005-0000-4000-8000-000000000005'::uuid,
    'de100006-0000-4000-8000-000000000006'::uuid,
    'de100007-0000-4000-8000-000000000007'::uuid
  );

  insert into public.volunteer_credits (
    id, concert_id, application_id, user_id, status, awarded_by, awarded_at
  ) values
    (
      'de300501-0000-4000-8000-000000000001',
      'de100005-0000-4000-8000-000000000005',
      'de200501-0000-4000-8000-000000000001', volunteer_1,
      'active', admin_id,
      ((current_date - 7) + time '22:25') at time zone 'Europe/Paris'
    ),
    (
      'de300601-0000-4000-8000-000000000001',
      'de100006-0000-4000-8000-000000000006',
      'de200601-0000-4000-8000-000000000001', volunteer_1,
      'active', admin_id,
      ((current_date - 21) + time '22:40') at time zone 'Europe/Paris'
    ),
    (
      'de300701-0000-4000-8000-000000000001',
      'de100007-0000-4000-8000-000000000007',
      'de200701-0000-4000-8000-000000000001', volunteer_1,
      'active', admin_id,
      ((current_date - 45) + time '22:10') at time zone 'Europe/Paris'
    );

  insert into public.invitation_campaigns (
    id, organization_id, concert_id, title, description, available_places,
    application_deadline, status, created_by, venue_id, event_date
  ) values
    (
      'de400001-0000-4000-8000-000000000001', promoter_id,
      'de100001-0000-4000-8000-000000000001',
      '[INVITATION OUVERTE] Test candidature et crédit',
      'À tester : visibilité bénévole, candidature et consommation du crédit.', 6,
      clock_timestamp() + interval '3 days', 'open', promoter_user_id,
      olympia_id, current_date + 5
    ),
    (
      'de400002-0000-4000-8000-000000000002', promoter_id,
      'de100002-0000-4000-8000-000000000002',
      '[INVITATION BROUILLON] Test gestion tourneur',
      'À tester : visibilité et modification côté tourneur et administration.', 4,
      clock_timestamp() + interval '8 days', 'draft', promoter_user_id,
      bataclan_id, current_date + 12
    );

  alter table public.maraude_collections
    enable trigger maraude_collections_enforce_active_maraude;
  alter table public.concerts
    enable trigger concerts_email_completion_notification;
  alter table public.concert_volunteers
    enable trigger concert_volunteers_mission_sheet_email;
  alter table public.concert_volunteers
    enable trigger concert_volunteers_email_notifications;

  raise notice 'Jeu de données de recette créé avec succès.';
end;
$seed$;

commit;

select
  (select count(*) from public.concerts
    where artist like '[ÉTAPE %' or artist like '[CAS %')
    as maraudes,
  (select count(*) from public.concert_volunteers application
    join public.concerts concert on concert.id = application.concert_id
    where concert.artist like '[ÉTAPE %' or concert.artist like '[CAS %')
    as candidatures,
  (select count(*) from public.encounters encounter
    join public.concerts concert on concert.id = encounter.maraude_id
    where concert.artist like '[ÉTAPE %' or concert.artist like '[CAS %')
    as rencontres,
  (select count(*) from public.consumables where name like '[DÉMO]%')
    as consommables,
  (select count(*) from public.equipment_assets where name like '[DÉMO]%')
    as materiels,
  (select count(*) from public.invitation_campaigns
    where title like '[INVITATION %')
    as invitations;
