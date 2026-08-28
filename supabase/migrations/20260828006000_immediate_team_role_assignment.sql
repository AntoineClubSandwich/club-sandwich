-- Team-role assignment moves from a batch "Enregistrer l'équipe" save
-- (draft held only in the browser tab, lost on refresh/navigation before
-- saving - reported live during testing) to immediate persistence, the
-- same pattern already used for selecting/removing a volunteer.
--
-- This surfaces a real correctness gap: a volunteer's confirmation
-- ("je confirme ma participation") was never tied to the role they were
-- confirming for - changing someone's role after they'd already confirmed
-- silently kept their confirmation valid for the new role too. Fix this
-- first, since making role changes immediate makes the window for this
-- to bite in practice much larger.

create or replace function private.normalize_volunteer_confirmation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status = 'selected'::public.concert_volunteer_status then
    if tg_op = 'INSERT'
      or old.status is distinct from
        'selected'::public.concert_volunteer_status then
      new.confirmation_status :=
        'pending'::public.volunteer_confirmation_status;
      new.confirmation_requested_at := clock_timestamp();
      new.confirmation_responded_at := null;
    elsif new.confirmation_status is null then
      new.confirmation_status :=
        'pending'::public.volunteer_confirmation_status;
      new.confirmation_requested_at := clock_timestamp();
      new.confirmation_responded_at := null;
    elsif tg_op = 'UPDATE'
      and old.status = 'selected'::public.concert_volunteer_status
      and old.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
      and new.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
      and new.team_role is distinct from old.team_role
    then
      -- The volunteer confirmed for a specific role; a role change after
      -- that must be re-confirmed, not silently inherited.
      new.confirmation_status :=
        'pending'::public.volunteer_confirmation_status;
      new.confirmation_requested_at := clock_timestamp();
      new.confirmation_responded_at := null;
    elsif new.confirmation_status =
      'confirmed'::public.volunteer_confirmation_status
      and old.confirmation_status is distinct from
        'confirmed'::public.volunteer_confirmation_status then
      new.confirmation_responded_at := clock_timestamp();
    end if;
  else
    new.confirmation_status := null;
    new.confirmation_requested_at := null;
    new.confirmation_responded_at := null;
  end if;

  return new;
end;
$$;

drop trigger concert_volunteers_normalize_confirmation
  on public.concert_volunteers;
create trigger concert_volunteers_normalize_confirmation
before insert or update of status, confirmation_status, team_role
on public.concert_volunteers
for each row execute function private.normalize_volunteer_confirmation();

create or replace function private.notify_role_change_requires_reconfirmation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  concert_artist text;
begin
  if new.status = 'selected'::public.concert_volunteer_status
    and new.confirmation_status = 'pending'::public.volunteer_confirmation_status
    and old.confirmation_status = 'confirmed'::public.volunteer_confirmation_status
    and new.team_role is distinct from old.team_role
  then
    select concert.artist into concert_artist
    from public.concerts concert
    where concert.id = new.concert_id;

    perform private.notify_user(
      new.user_id,
      new.concert_id,
      'role_changed',
      'Votre rôle a changé',
      format(
        'Votre rôle pour la maraude %s a été modifié (%s). '
        || 'Merci de confirmer à nouveau votre participation.',
        concert_artist,
        case new.team_role
          when 'team_leader'::public.maraude_role then 'chef.fe d’équipe'
          when 'communication'::public.maraude_role
            then 'chargé.e de communication'
          when 'logistics'::public.maraude_role then 'chargé.e de logistique'
          when 'collection_distribution'::public.maraude_role
            then 'chargé.e de récolte et distribution'
          else 'non attribué'
        end
      )
    );
  end if;
  return new;
end;
$$;

revoke all on function private.notify_role_change_requires_reconfirmation()
from public, anon, authenticated;

create trigger concert_volunteers_notify_role_change
after update of team_role on public.concert_volunteers
for each row execute function private.notify_role_change_requires_reconfirmation();

create function public.set_volunteer_team_role(
  requested_application_id uuid,
  requested_role public.maraude_role
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  application_concert_id uuid;
  application_status public.concert_volunteer_status;
  concert_maraude_status public.maraude_status;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut constituer une équipe'
      using errcode = '42501';
  end if;

  select
    application.concert_id, application.status, concert.maraude_status
  into
    application_concert_id, application_status, concert_maraude_status
  from public.concert_volunteers application
  join public.concerts concert on concert.id = application.concert_id
  where application.id = requested_application_id
    and private.is_organization_member(
      concert.organization_id,
      (select auth.uid())
    )
  for update of application;

  if application_concert_id is null then
    raise exception 'Candidature introuvable' using errcode = 'P0002';
  end if;

  if application_status <> 'selected'::public.concert_volunteer_status then
    raise exception
      'Seul un bénévole sélectionné peut recevoir un rôle'
      using errcode = '22023';
  end if;

  if concert_maraude_status not in (
    'open'::public.maraude_status,
    'team_ready'::public.maraude_status
  ) then
    raise exception 'L’équipe de cette maraude n’est plus modifiable'
      using errcode = '22023';
  end if;

  if requested_role = 'team_leader'::public.maraude_role
    and exists (
      select 1
      from public.concert_volunteers other
      where other.concert_id = application_concert_id
        and other.id <> requested_application_id
        and other.status = 'selected'::public.concert_volunteer_status
        and other.team_role = 'team_leader'::public.maraude_role
    )
  then
    raise exception
      'Un autre bénévole est déjà chef d’équipe : retirez-lui ce rôle d’abord'
      using errcode = '23505';
  end if;

  update public.concert_volunteers
  set team_role = requested_role
  where id = requested_application_id;
end;
$$;

revoke all on function public.set_volunteer_team_role(
  uuid, public.maraude_role
) from public, anon;
grant execute on function public.set_volunteer_team_role(
  uuid, public.maraude_role
) to authenticated;
