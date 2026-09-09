-- concert_time is nullable (relaxed in 20260724004000) - the J-3 date
-- arithmetic in 20260909005000 used it directly, so a maraude with no
-- time set would silently drop out of both the auto-cancel cron's
-- WHERE clause and the urgent-staffing-alert check (date + null =
-- null, matches nothing). Defaults to midnight Europe/Paris so a
-- timeless maraude is still covered rather than silently skipped.

create or replace function private.auto_cancel_understaffed_maraudes()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  candidate record;
  confirmed_count integer;
  cancelled_count integer := 0;
begin
  for candidate in
    select concert.id
    from public.concerts concert
    where concert.maraude_status in (
      'draft'::public.maraude_status,
      'open'::public.maraude_status,
      'team_ready'::public.maraude_status
    )
    and (
      (concert.concert_date + coalesce(concert.concert_time, '00:00'::time))
        at time zone 'Europe/Paris'
    ) <= clock_timestamp() + interval '3 days'
    and (
      (concert.concert_date + coalesce(concert.concert_time, '00:00'::time))
        at time zone 'Europe/Paris'
    ) > clock_timestamp()
    for update of concert skip locked
  loop
    select count(distinct user_id)
    into confirmed_count
    from public.concert_volunteers
    where concert_id = candidate.id
      and status = 'selected'::public.concert_volunteer_status
      and confirmation_status = 'confirmed'::public.volunteer_confirmation_status;

    if confirmed_count < 3 then
      begin
        perform private.cancel_maraude(
          candidate.id,
          'Nombre insuffisant de bénévoles à J-3',
          'automatic',
          null
        );
        cancelled_count := cancelled_count + 1;
      exception when others then
        null;
      end;
    end if;
  end loop;

  return cancelled_count;
end;
$$;

revoke all on function private.auto_cancel_understaffed_maraudes()
from public, anon, authenticated;

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

  if requested_status = 'team_ready'::public.maraude_status then
    if current_status <> 'open'::public.maraude_status then
      raise exception 'Seule une maraude planifiée peut être validée'
        using errcode = '22023';
    end if;

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

    if not exists (
      select 1
      from public.concert_volunteers leader
      where leader.concert_id = requested_concert_id
        and leader.status = 'selected'::public.concert_volunteer_status
        and leader.team_role = 'team_leader'::public.maraude_role
        and leader.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
    ) then
      raise exception 'Un chef d''équipe confirmé est requis'
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

  if requested_status = 'open'::public.maraude_status
    and requested_status is distinct from current_status
    and (
      (concert_date_value + coalesce(concert_time_value, '00:00'::time))
        at time zone 'Europe/Paris'
    ) <= changed_at + interval '3 days'
  then
    perform private.notify_active_admins(
      requested_concert_id,
      'urgent_staffing_alert',
      format('Décision urgente — %s', concert_artist),
      format(
        'La maraude %s a été ouverte à moins de 3 jours de son horaire. '
        || 'Si elle n’atteint pas 3 bénévoles confirmés à temps, elle '
        || 'sera automatiquement annulée à J-3. Vérifiez la situation '
        || 'rapidement.',
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
