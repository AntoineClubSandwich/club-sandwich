-- Remise à zéro des données opérationnelles de préproduction.
--
-- Ce script conserve volontairement :
-- - les comptes Auth et leurs profils ;
-- - les rôles et rattachements aux organisations ;
-- - les organisations, salles et modèles de documents.
--
-- Il supprime toutes les maraudes, invitations, données de stock et
-- événements associés. À ne jamais exécuter en production.

begin;

do $guard$
declare
  expected_test_accounts integer;
begin
  select count(*)
  into expected_test_accounts
  from auth.users
  where lower(email) in (
    'antoine@clubsandwich-records.com',
    'tourneurtest@gmail.com',
    'antoinevgnl@gmail.com',
    'antoinevgnl+benevole2@gmail.com',
    'antoinevgnl+benevole3@gmail.com',
    'antoinevgnl+benevole4@gmail.com'
  );

  if expected_test_accounts <> 6 then
    raise exception
      'Remise à zéro refusée : environnement de recette non reconnu (%/6 comptes)',
      expected_test_accounts;
  end if;

  if not exists (
    select 1 from public.organizations where slug = 'club-sandwich'
  ) or not exists (
    select 1 from public.organizations where slug = 'aeg'
  ) then
    raise exception
      'Remise à zéro refusée : organisations de recette introuvables';
  end if;
end;
$guard$;

-- Ces triggers ne doivent ni envoyer d'e-mail ni empêcher la suppression de
-- lignes appartenant à une maraude déjà clôturée.
alter table public.concert_volunteers
  disable trigger concert_volunteers_email_notifications;
alter table public.concert_volunteers
  disable trigger concert_volunteers_mission_sheet_email;
alter table public.concerts
  disable trigger concerts_email_completion_notification;
alter table public.maraude_collections
  disable trigger maraude_collections_enforce_active_maraude;

-- Les crédits consommés référencent une candidature à une invitation. Les
-- maraudes doivent donc disparaître en premier afin que leurs crédits soient
-- supprimés en cascade avant les campagnes d'invitation.
delete from public.concerts;
delete from public.invitation_campaigns;

delete from public.consumable_movements;
delete from public.consumables;

delete from public.equipment_events;
delete from public.equipment_assets;
delete from public.equipment_locations;

alter table public.maraude_collections
  enable trigger maraude_collections_enforce_active_maraude;
alter table public.concerts
  enable trigger concerts_email_completion_notification;
alter table public.concert_volunteers
  enable trigger concert_volunteers_mission_sheet_email;
alter table public.concert_volunteers
  enable trigger concert_volunteers_email_notifications;

commit;

select
  (select count(*) from public.concerts) as maraudes,
  (select count(*) from public.invitation_campaigns) as invitations,
  (select count(*) from public.consumables) as consommables,
  (select count(*) from public.equipment_assets) as materiels;
