-- Permet à un admin de relancer manuellement un bénévole dont le rôle est
-- verrouillé mais qui n'a toujours pas confirmé sa participation, plutôt
-- que d'attendre passivement - use case remonté en test : "je voudrais
-- pouvoir renvoyer une notification à quelqu'un qui doit confirmer sa
-- participation". Rafraîchit aussi confirmation_due_at pour que le délai
-- affiché au bénévole (fiche/e-mail) redevienne cohérent avec la relance.
alter table public.maraude_workflow_events
  drop constraint maraude_workflow_events_event_type_check;
alter table public.maraude_workflow_events
  add constraint maraude_workflow_events_event_type_check
  check (event_type = any (array[
    'selection_requested',
    'status_changed',
    'role_changed',
    'confirmation_completed',
    'confirmation_expired',
    'confirmation_reminder',
    'attendance_changed',
    'attendance_corrected',
    'attendance_validated',
    'maraude_started',
    'maraude_completed',
    'credit_awarded',
    'credit_revoked',
    'schedule_changed',
    'maraude_cancelled',
    'urgent_staffing_alert'
  ]));

create function public.remind_volunteer_confirmation(
  requested_application_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  application_concert_id uuid;
  application_user_id uuid;
  application_status public.concert_volunteer_status;
  application_confirmation_status public.volunteer_confirmation_status;
  application_locked boolean;
  application_role public.maraude_role;
  concert_artist text;
  role_label text;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut relancer un bénévole'
      using errcode = '42501';
  end if;

  select
    application.concert_id,
    application.user_id,
    application.status,
    application.confirmation_status,
    application.team_role_locked,
    application.team_role,
    concert.artist
  into
    application_concert_id,
    application_user_id,
    application_status,
    application_confirmation_status,
    application_locked,
    application_role,
    concert_artist
  from public.concert_volunteers application
  join public.concerts concert on concert.id = application.concert_id
  where application.id = requested_application_id
    and private.is_organization_member(
      concert.organization_id,
      (select auth.uid())
    )
  for update of application;

  if application_concert_id is null then
    raise exception 'Volontaire introuvable' using errcode = 'P0002';
  end if;

  if application_status <> 'selected'::public.concert_volunteer_status
    or application_confirmation_status
      <> 'pending'::public.volunteer_confirmation_status
    or not application_locked
  then
    raise exception
      'Ce bénévole n''a pas de confirmation en attente'
      using errcode = '22023';
  end if;

  update public.concert_volunteers
  set confirmation_due_at = clock_timestamp() + interval '24 hours'
  where id = requested_application_id;

  insert into public.maraude_workflow_events (
    concert_id,
    application_id,
    event_type,
    actor_id,
    previous_value,
    new_value
  )
  values (
    application_concert_id,
    requested_application_id,
    'confirmation_reminder',
    (select auth.uid()),
    jsonb_build_object('confirmation_status', application_confirmation_status),
    jsonb_build_object('reminded_at', clock_timestamp())
  );

  role_label := case application_role
    when 'team_leader'::public.maraude_role then 'chef.fe d’équipe'
    when 'communication'::public.maraude_role
      then 'chargé.e de communication'
    when 'logistics'::public.maraude_role then 'chargé.e de logistique'
    when 'collection_distribution'::public.maraude_role
      then 'chargé.e de récolte et distribution'
    else 'non attribué'
  end;

  perform private.notify_user(
    application_user_id,
    application_concert_id,
    'confirmation_reminder',
    'Rappel — confirmez votre participation',
    format(
      'Votre rôle pour la maraude %s (%s) attend toujours votre '
      || 'confirmation. Merci de confirmer votre participation dès que '
      || 'possible.',
      concert_artist,
      role_label
    )
  );
end;
$$;

revoke all on function public.remind_volunteer_confirmation(uuid)
  from public, anon;
grant execute on function public.remind_volunteer_confirmation(uuid)
  to authenticated;
