-- Phase 2 ("refonte des fiches de mission") of the notification/email
-- overhaul: the 4 role emails move to the spec's fixed 9-block
-- structure (salutation, confirmation du rôle, informations pratiques,
-- mission, responsabilités, bonnes pratiques, objectif, bouton,
-- signature) instead of a single flat body. The wrapper (salutation/
-- confirmation/practical info/signature) is built in the edge function
-- from structured facts captured here at enqueue time - the stored
-- body goes back to being just the mission content (mission/
-- responsabilités/bonnes pratiques/objectif), which is also what shows
-- in-app, so the in-app version doesn't need the wrapper repeated.
--
-- Two new facts needed for that wrapper that nothing captured before:
-- the recipient's first name (for "Bonjour {prénom}") and their role
-- label for this concert (for "Confirmation du rôle" - previously only
-- available baked into the notification title's text, not as its own
-- field).

alter table public.workflow_email_deliveries
  add column recipient_first_name text,
  add column role_label text;

create or replace function private.enqueue_workflow_email()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_artist text;
  v_concert_date date;
  v_concert_time time;
  v_venue_name text;
  v_venue_address text;
  v_first_name text;
  v_role_label text;
begin
  if not new.send_email then
    return new;
  end if;

  if new.concert_id is not null then
    select
      concert.artist,
      concert.concert_date,
      concert.concert_time,
      venue.name,
      nullif(
        btrim(
          concat_ws(
            ', ',
            nullif(
              btrim(
                concat_ws(
                  ' ',
                  venue.public_address_line1,
                  venue.public_address_line2
                )
              ),
              ''
            ),
            nullif(
              btrim(concat_ws(' ', venue.postal_code, venue.city)),
              ''
            )
          )
        ),
        ''
      )
    into v_artist, v_concert_date, v_concert_time, v_venue_name, v_venue_address
    from public.concerts concert
    left join public.venues venue on venue.id = concert.venue_id
    where concert.id = new.concert_id;

    select private.maraude_role_label(volunteer.team_role)
    into v_role_label
    from public.concert_volunteers volunteer
    where volunteer.concert_id = new.concert_id
      and volunteer.user_id = new.user_id
      and volunteer.team_role is not null;
  end if;

  select profile.first_name
  into v_first_name
  from public.profiles profile
  where profile.id = new.user_id;

  insert into public.workflow_email_deliveries (
    notification_id,
    user_id,
    concert_id,
    subject,
    body,
    concert_artist,
    concert_date,
    concert_time,
    venue_name,
    venue_address,
    recipient_first_name,
    role_label
  )
  values (
    new.id,
    new.user_id,
    new.concert_id,
    new.title,
    new.body,
    v_artist,
    v_concert_date,
    v_concert_time,
    v_venue_name,
    v_venue_address,
    v_first_name,
    v_role_label
  )
  on conflict (notification_id) do nothing;
  return new;
end;
$$;

revoke all on function private.enqueue_workflow_email()
from public, anon, authenticated;

-- New 4-block content (mission/responsabilités/bonnes pratiques/
-- objectif), replacing the previous responsabilités/check-list/bonnes
-- pratiques/objectifs shape - the check-list block is dropped per the
-- new structure, its still-relevant items folded into responsabilités.
create or replace function private.maraude_role_mission_email_body(
  role public.maraude_role
)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case role
    when 'team_leader' then E'Votre mission\nVous coordonnez l’équipe et supervisez le bon déroulement de la maraude, de la préparation au compte-rendu final.\n\nVos responsabilités\n- Être le point de contact unique de l’équipe pendant toute la maraude.\n- Vérifier les présences et que chaque membre connaît son rôle avant le départ.\n- Superviser le bon déroulement de la récolte et de la distribution.\n- Suivre les informations saisies dans l’application (récoltes, distributions, présences).\n- Transmettre le compte-rendu final de la maraude.\n- Signaler tout incident à l’équipe organisatrice.\n\nQuelques bonnes pratiques\n- Rester joignable pour l’équipe et pour les organisateurs pendant toute la maraude.\n- Reformuler les consignes en cas de doute pour éviter les malentendus.\n- Privilégier le dialogue en cas de désaccord ou d’imprévu sur le terrain.\n\nVotre objectif\nUne équipe coordonnée, une récolte et une distribution correctement tracées, et un compte-rendu transmis sans délai.'
    when 'communication' then E'Votre mission\nVous documentez le déroulement de la maraude en images et assurez la communication au sein de l’équipe.\n\nVos responsabilités\n- Prendre des photos représentatives des temps forts de la maraude.\n- Ajouter les photos à la galerie (5 photos maximum).\n- Relayer les informations utiles à l’équipe via le chat de la maraude.\n\nQuelques bonnes pratiques\n- Ne jamais photographier une personne identifiable sans son accord.\n- Privilégier des photos de l’action collective plutôt que des gros plans de personnes.\n- Respecter la dignité et la vie privée des personnes accompagnées à tout moment.\n\nVotre objectif\nUne galerie photo illustrant fidèlement la maraude, dans le respect de la vie privée des personnes accompagnées, et une équipe bien informée.'
    when 'logistics' then E'Votre mission\nVous veillez au bon déroulement matériel de la maraude et appuyez le chef d’équipe sur l’organisation du parcours.\n\nVos responsabilités\n- Vérifier avant le départ que le matériel nécessaire est disponible.\n- Confirmer les points de collecte et de distribution prévus.\n- Appuyer le chef d’équipe sur l’organisation du parcours et des arrêts.\n\nQuelques bonnes pratiques\n- Anticiper les imprévus matériels plutôt que de les découvrir sur place.\n- Signaler rapidement toute difficulté pour permettre une adaptation en temps réel.\n\nVotre objectif\nUne maraude qui se déroule sans accroc matériel, avec une équipe qui dispose de tout le nécessaire au bon moment.'
    when 'collection_distribution' then E'Votre mission\nVous réceptionnez les denrées collectées et distribuez les repas dans le respect des régimes alimentaires signalés.\n\nVos responsabilités\n- Réceptionner, peser et enregistrer chaque collecte dans l’application.\n- Enregistrer chaque distribution effectuée.\n- Identifier et signaler les régimes alimentaires particuliers (sans gluten, végétarien, allergènes, etc.).\n- Respecter les règles d’hygiène lors de la manipulation des denrées.\n\nQuelques bonnes pratiques\n- Vérifier les régimes alimentaires avant de servir plutôt qu’après réclamation.\n- Veiller à une distribution ordonnée et équitable entre les personnes accompagnées.\n\nVotre objectif\nUne récolte intégralement tracée et pesée, et une distribution respectueuse des régimes alimentaires de chacun.'
  end;
$$;

revoke all on function private.maraude_role_mission_email_body(public.maraude_role)
from public, anon, authenticated;

-- Body goes back to pure mission content - the "confirmée en tant que"
-- line moves to the email wrapper (built in the edge function from
-- role_label/concert_artist, now captured above) so it isn't duplicated
-- there while staying implicit-but-fine in-app (the notification title
-- already says "Votre fiche de mission — {rôle}").
create or replace function private.notify_mission_sheet_email()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.confirmation_status = 'confirmed'::public.volunteer_confirmation_status
    and new.team_role is not null
    and (
      old.confirmation_status is distinct from new.confirmation_status
      or old.team_role is distinct from new.team_role
    )
  then
    perform private.notify_user(
      new.user_id,
      new.concert_id,
      'mission_sheet',
      format(
        'Votre fiche de mission — %s',
        private.maraude_role_label(new.team_role)
      ),
      private.maraude_role_mission_email_body(new.team_role)
    );
  end if;
  return new;
end;
$$;

revoke all on function private.notify_mission_sheet_email()
from public, anon, authenticated;
