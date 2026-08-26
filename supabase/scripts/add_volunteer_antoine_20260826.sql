-- Ajoute le compte bénévole Antoine Vignol (antoinevgnl@gmail.com) à la
-- simulation du 2026-08-26 : équipe opérationnelle de ce soir + 3 crédits
-- actifs + rencontres passées, comme pour les 5 autres bénévoles.

begin;

do $add$
declare
  admin_id uuid;
  antoine_v_id uuid;
  concert_operational uuid := 'df100002-0000-4000-8000-000000000002';
  c1 uuid := 'df100003-0000-4000-8000-000000000003';
  c2 uuid := 'df100004-0000-4000-8000-000000000004';
  c3 uuid := 'df100005-0000-4000-8000-000000000005';
  app1 uuid;
  app2 uuid;
  app3 uuid;
begin
  select id into strict admin_id from auth.users where lower(email) = 'antoine@clubsandwich-records.com';
  select p.id into strict antoine_v_id
  from auth.users au
  join public.profiles p on p.id = au.id
  join public.user_accounts ua on ua.profile_id = p.id
  where lower(au.email) = 'antoinevgnl@gmail.com' and ua.role = 'volunteer';

  alter table public.concert_volunteers disable trigger concert_volunteers_email_notifications;
  alter table public.concert_volunteers disable trigger concert_volunteers_mission_sheet_email;
  alter table public.user_notifications disable trigger user_notifications_enqueue_email;

  delete from public.volunteer_credits where user_id = antoine_v_id and concert_id in (c1, c2, c3);
  delete from public.concert_volunteers where user_id = antoine_v_id and concert_id in (concert_operational, c1, c2, c3);

  -- Ce soir : rejoint l'équipe opérationnelle du Bataclan.
  insert into public.concert_volunteers (id, concert_id, user_id, status, team_role, created_at)
  values (gen_random_uuid(), concert_operational, antoine_v_id, 'selected', 'communication', clock_timestamp() - interval '1 hour');

  update public.concert_volunteers
  set confirmation_status = 'confirmed', role_acknowledged_at = clock_timestamp() - interval '30 minutes'
  where concert_id = concert_operational and user_id = antoine_v_id;

  -- Historique : 3 maraudes passées pour les 3 crédits actifs.
  insert into public.concert_volunteers (id, concert_id, user_id, status, created_at)
  values
    (gen_random_uuid(), c1, antoine_v_id, 'selected', clock_timestamp() - interval '40 days'),
    (gen_random_uuid(), c2, antoine_v_id, 'selected', clock_timestamp() - interval '40 days'),
    (gen_random_uuid(), c3, antoine_v_id, 'selected', clock_timestamp() - interval '40 days');

  update public.concert_volunteers
  set confirmation_status = 'confirmed', role_acknowledged_at = clock_timestamp() - interval '35 days',
      attendance_status = 'present', attendance_validated_at = clock_timestamp() - interval '30 days',
      attendance_validated_by = admin_id
  where user_id = antoine_v_id and concert_id in (c1, c2, c3);

  select id into strict app1 from public.concert_volunteers where user_id = antoine_v_id and concert_id = c1;
  select id into strict app2 from public.concert_volunteers where user_id = antoine_v_id and concert_id = c2;
  select id into strict app3 from public.concert_volunteers where user_id = antoine_v_id and concert_id = c3;

  insert into public.volunteer_credits (id, concert_id, application_id, user_id, status, awarded_by, awarded_at)
  values
    (gen_random_uuid(), c1, app1, antoine_v_id, 'active', admin_id, clock_timestamp() - interval '29 days'),
    (gen_random_uuid(), c2, app2, antoine_v_id, 'active', admin_id, clock_timestamp() - interval '29 days'),
    (gen_random_uuid(), c3, app3, antoine_v_id, 'active', admin_id, clock_timestamp() - interval '29 days');

  insert into public.encounters (id, maraude_id, created_by, latitude, longitude, accuracy, created_at)
  values
    (gen_random_uuid(), c1, antoine_v_id, 48.8718, 2.3699, 20, ((current_date - 10) + time '21:10') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c2, antoine_v_id, 48.8722, 2.3540, 17, ((current_date - 20) + time '21:00') at time zone 'Europe/Paris'),
    (gen_random_uuid(), c3, antoine_v_id, 48.8830, 2.3428, 23, ((current_date - 30) + time '21:10') at time zone 'Europe/Paris');

  alter table public.user_notifications enable trigger user_notifications_enqueue_email;
  alter table public.concert_volunteers enable trigger concert_volunteers_mission_sheet_email;
  alter table public.concert_volunteers enable trigger concert_volunteers_email_notifications;

  raise notice 'Antoine Vignol (bénévole) intégré à la simulation.';
end;
$add$;

commit;

select
  (select count(*) from public.concert_volunteers cv
    join auth.users au on au.id = cv.user_id
    where lower(au.email) = 'antoinevgnl@gmail.com') as applications,
  (select count(*) from public.volunteer_credits vc
    join auth.users au on au.id = vc.user_id
    where lower(au.email) = 'antoinevgnl@gmail.com' and vc.status = 'active') as active_credits;
