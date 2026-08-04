create or replace function private.maraude_role_label(role public.maraude_role)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case role
    when 'team_leader' then 'Chef.fe d’équipe'
    when 'communication' then 'Chargé.e de communication'
    when 'logistics' then 'Chargé.e de logistique'
    when 'collection_distribution' then 'Chargé.e de récolte et distribution'
  end;
$$;

revoke all on function private.maraude_role_label(public.maraude_role)
from public, anon, authenticated;

create or replace function private.maraude_role_mission_email_body(
  role public.maraude_role
)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case role
    when 'team_leader' then E'Responsabilités\n- Être le point de contact unique de l’équipe pendant toute la maraude.\n- Coordonner les autres membres et s’assurer que chacun connaît son rôle.\n- Superviser le bon déroulement de la récolte, de la distribution et de la communication.\n- Transmettre le compte-rendu final de la maraude.\n\nCheck-list\n- Vérifier que l’équipe est au complet avant le départ.\n- S’assurer que chaque membre a confirmé sa participation et pris connaissance de sa fiche de mission.\n- Superviser l’enregistrement des récoltes et des distributions dans l’application.\n- Renseigner le compte-rendu opérationnel à la fin de la maraude.\n- Signaler tout incident à l’équipe organisatrice.\n\nBonnes pratiques\n- Rester joignable pour l’équipe et pour les organisateurs pendant toute la maraude.\n- Reformuler les consignes en cas de doute pour éviter les malentendus.\n- Privilégier le dialogue en cas de désaccord ou d’imprévu sur le terrain.\n\nObjectifs de la mission\n- Une équipe coordonnée et informée.\n- Une récolte et une distribution correctement tracées dans l’application.\n- Un compte-rendu complet transmis sans délai.'
    when 'communication' then E'Responsabilités\n- Documenter le déroulement de la maraude en images.\n- Alimenter la galerie photo de la maraude.\n- Assurer la communication au sein de l’équipe via le chat dédié.\n\nCheck-list\n- Prendre des photos représentatives des temps forts de la maraude.\n- Ajouter les photos à la galerie (5 photos maximum).\n- Vérifier avant publication qu’aucune personne vulnérable n’est identifiable sans son accord.\n- Relayer les informations utiles à l’équipe via le chat de la maraude.\n\nBonnes pratiques\n- Privilégier des photos de l’action collective plutôt que des gros plans de personnes.\n- Demander l’accord des personnes concernées avant de les photographier.\n- Garder un ton factuel et bienveillant dans le chat.\n\nObjectifs de la mission\n- Une galerie photo illustrant fidèlement la maraude, dans le respect de la vie privée des personnes accompagnées.\n- Une équipe bien informée tout au long de la maraude.'
    when 'logistics' then E'Responsabilités\n- Veiller au bon déroulement matériel de la maraude.\n- Vérifier la disponibilité du matériel nécessaire à la collecte et à la distribution.\n- Appuyer le chef d’équipe sur l’organisation du parcours et des arrêts.\n\nCheck-list\n- Vérifier avant le départ que le matériel nécessaire est disponible.\n- Confirmer les points de collecte et de distribution prévus.\n- Signaler au chef d’équipe toute contrainte matérielle rencontrée sur le terrain.\n\nBonnes pratiques\n- Anticiper les imprévus matériels plutôt que de les découvrir sur place.\n- Communiquer rapidement toute difficulté pour permettre une adaptation en temps réel.\n\nObjectifs de la mission\n- Une maraude qui se déroule sans accroc matériel.\n- Une équipe qui dispose de tout le nécessaire au bon moment.'
    when 'collection_distribution' then E'Responsabilités\n- Réceptionner et peser les denrées collectées.\n- Distribuer les repas dans le respect des régimes alimentaires signalés.\n- Veiller à une distribution ordonnée et équitable.\n\nCheck-list\n- Peser et enregistrer chaque collecte dans l’application.\n- Identifier et signaler les régimes alimentaires particuliers (sans gluten, végétarien, allergènes, etc.).\n- Enregistrer chaque distribution effectuée.\n- Respecter les règles d’hygiène lors de la manipulation des denrées.\n\nBonnes pratiques\n- Vérifier les régimes alimentaires avant de servir plutôt qu’après réclamation.\n- Rester attentif à un partage équitable entre les personnes accompagnées.\n\nObjectifs de la mission\n- Une récolte intégralement tracée et pesée.\n- Une distribution respectueuse des régimes alimentaires de chacun.'
  end;
$$;

revoke all on function private.maraude_role_mission_email_body(public.maraude_role)
from public, anon, authenticated;

create or replace function private.notify_mission_sheet_email()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  concert_artist text;
begin
  if new.confirmation_status = 'confirmed'::public.volunteer_confirmation_status
    and new.team_role is not null
    and (
      old.confirmation_status is distinct from new.confirmation_status
      or old.team_role is distinct from new.team_role
    )
  then
    select concert.artist into concert_artist
    from public.concerts concert
    where concert.id = new.concert_id;

    perform private.notify_user(
      new.user_id,
      new.concert_id,
      'mission_sheet',
      format(
        'Votre fiche de mission — %s',
        private.maraude_role_label(new.team_role)
      ),
      format(
        E'Votre participation à la maraude %s est confirmée en tant que %s.\n\n%s',
        concert_artist,
        private.maraude_role_label(new.team_role),
        private.maraude_role_mission_email_body(new.team_role)
      )
    );
  end if;
  return new;
end;
$$;

revoke all on function private.notify_mission_sheet_email()
from public, anon, authenticated;

create trigger concert_volunteers_mission_sheet_email
after update of confirmation_status, team_role on public.concert_volunteers
for each row execute function private.notify_mission_sheet_email();
