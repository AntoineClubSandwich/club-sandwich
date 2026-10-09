-- Antoine a demandé de retirer l'annulation automatique d'une maraude à
-- J-3 quand elle n'a pas assez de bénévoles confirmés (2026-09-16). Le
-- cron toutes les 15 minutes et la fonction qu'il appelait sont
-- supprimés. L'alerte "urgent_staffing_alert" envoyée aux admins quand
-- une maraude ouvre à moins de 3 jours de son horaire reste (toujours
-- utile pour signaler l'urgence), mais son texte ne promet plus une
-- annulation automatique qui n'a plus lieu.

do $$
declare
  existing_job_id bigint;
begin
  select jobid into existing_job_id
  from cron.job
  where jobname = 'auto-cancel-understaffed-maraudes';

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;
end;
$$;

drop function if exists private.auto_cancel_understaffed_maraudes();

create or replace function public.set_maraude_status(
  requested_concert_id uuid,
  requested_status public.maraude_status,
  requested_cancellation_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  changed_at timestamptz := clock_timestamp();
  current_status public.maraude_status;
  concert_artist text;
  concert_date_value date;
  concert_time_value time;
  is_admin boolean :=
    private.is_club_sandwich_admin((select auth.uid()));
  is_confirmed_team_leader boolean;
  confirmed_member_count integer;
  confirmed_leader_count integer;
begin
  if requested_status = 'cancelled'::public.maraude_status then
    raise exception
      'Utilisez cancel_maraude pour annuler une maraude'
      using errcode = '22023';
  end if;

  perform public.expire_volunteer_confirmations();

  select
    concert.maraude_status,
    concert.artist,
    concert.concert_date,
    concert.concert_time
  into
    current_status,
    concert_artist,
    concert_date_value,
    concert_time_value
  from public.concerts concert
  where concert.id = requested_concert_id
    and (
      (
        is_admin
        and private.is_organization_member(
          concert.organization_id,
          (select auth.uid())
        )
      )
      or exists (
        select 1
        from public.concert_volunteers leader
        where leader.concert_id = concert.id
          and leader.user_id = (select auth.uid())
          and leader.status =
            'selected'::public.concert_volunteer_status
          and leader.team_role = 'team_leader'::public.maraude_role
          and leader.confirmation_status =
            'confirmed'::public.volunteer_confirmation_status
      )
    )
  for update;

  if not found then
    raise exception 'Concert inaccessible' using errcode = '42501';
  end if;

  select exists (
    select 1
    from public.concert_volunteers leader
    where leader.concert_id = requested_concert_id
      and leader.user_id = (select auth.uid())
      and leader.status = 'selected'::public.concert_volunteer_status
      and leader.team_role = 'team_leader'::public.maraude_role
      and leader.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
  )
  into is_confirmed_team_leader;

  if not is_admin and not (
    is_confirmed_team_leader
    and (
      (
        current_status = 'team_ready'::public.maraude_status
        and requested_status = 'in_progress'::public.maraude_status
      )
      or (
        current_status = 'in_progress'::public.maraude_status
        and requested_status = 'completed'::public.maraude_status
      )
    )
  ) then
    raise exception 'Action réservée au chef d''équipe'
      using errcode = '42501';
  end if;

  if requested_status in (
    'team_ready'::public.maraude_status,
    'in_progress'::public.maraude_status
  ) then
    select
      count(*),
      count(*) filter (
        where application.team_role =
          'team_leader'::public.maraude_role
      )
    into confirmed_member_count, confirmed_leader_count
    from public.concert_volunteers application
    where application.concert_id = requested_concert_id
      and application.status =
        'selected'::public.concert_volunteer_status
      and application.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status;
  end if;

  if requested_status = 'team_ready'::public.maraude_status then
    if current_status <> 'open'::public.maraude_status then
      raise exception 'Seule une maraude planifiée peut être validée'
        using errcode = '22023';
    end if;

    if confirmed_member_count < 3 or confirmed_leader_count <> 1 then
      raise exception
        'Trois bénévoles confirmés sont requis, dont exactement un chef d’équipe'
        using errcode = '22023';
    end if;
  end if;

  if requested_status = 'in_progress'::public.maraude_status then
    if current_status not in (
      'open'::public.maraude_status,
      'team_ready'::public.maraude_status
    ) then
      raise exception 'Cette maraude ne peut pas être démarrée'
        using errcode = '22023';
    end if;

    if confirmed_member_count < 3 or confirmed_leader_count <> 1 then
      raise exception
        'Trois bénévoles confirmés sont requis, dont exactement un chef d’équipe, avant de démarrer'
        using errcode = '22023';
    end if;
  end if;

  if requested_status = 'completed'::public.maraude_status
    and current_status <> 'in_progress'::public.maraude_status
  then
    raise exception 'La maraude doit être en cours avant sa clôture'
      using errcode = '22023';
  end if;

  if current_status in (
    'completed'::public.maraude_status,
    'cancelled'::public.maraude_status
  ) and requested_status is distinct from current_status
  then
    raise exception 'Une maraude archivée ne peut plus changer d''état'
      using errcode = '22023';
  end if;

  update public.concerts
  set
    maraude_status = requested_status,
    actual_start_at = case
      when requested_status = 'in_progress'::public.maraude_status
        then coalesce(actual_start_at, changed_at)
      else actual_start_at
    end,
    actual_end_at = case
      when requested_status = 'completed'::public.maraude_status
        then greatest(changed_at, coalesce(actual_start_at, changed_at))
      else actual_end_at
    end
  where id = requested_concert_id;

  if requested_status in (
    'team_ready'::public.maraude_status,
    'in_progress'::public.maraude_status,
    'completed'::public.maraude_status
  ) and requested_status is distinct from current_status
  then
    insert into public.maraude_workflow_events (
      concert_id,
      event_type,
      actor_id,
      previous_value,
      new_value
    )
    values (
      requested_concert_id,
      case
        when requested_status = 'team_ready'::public.maraude_status
          then 'status_changed'
        when requested_status = 'in_progress'::public.maraude_status
          then 'maraude_started'
        else 'maraude_completed'
      end,
      (select auth.uid()),
      jsonb_build_object('status', current_status),
      jsonb_build_object('status', requested_status, 'at', changed_at)
    );
  end if;

  -- Cas limite : une maraude tout juste ouverte à moins de 3 jours de son
  -- horaire mérite un signalement immédiat, même si plus rien ne
  -- l'annule automatiquement à J-3 désormais.
  if requested_status = 'open'::public.maraude_status
    and requested_status is distinct from current_status
    and (
      (concert_date_value + concert_time_value) at time zone 'Europe/Paris'
    ) <= changed_at + interval '3 days'
  then
    perform private.notify_active_admins(
      requested_concert_id,
      'urgent_staffing_alert',
      format('Décision urgente — %s', concert_artist),
      format(
        'La maraude %s a été ouverte à moins de 3 jours de son horaire, '
        || 'sans équipe confirmée. Vérifiez la situation rapidement.',
        concert_artist
      )
    );
  end if;
end;
$$;

revoke all on function public.set_maraude_status(
  uuid, public.maraude_status, text
) from public, anon;
grant execute on function public.set_maraude_status(
  uuid, public.maraude_status, text
) to authenticated;
