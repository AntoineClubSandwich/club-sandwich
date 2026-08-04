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
  is_admin boolean :=
    private.is_club_sandwich_admin((select auth.uid()));
  is_confirmed_team_leader boolean;
begin
  select concert.maraude_status
  into current_status
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
        from public.concert_volunteers volunteer
        where volunteer.concert_id = concert.id
          and volunteer.user_id = (select auth.uid())
          and volunteer.status =
            'selected'::public.concert_volunteer_status
          and volunteer.team_role =
            'team_leader'::public.maraude_role
          and volunteer.confirmation_status =
            'confirmed'::public.volunteer_confirmation_status
      )
    )
  for update;

  if not found then
    raise exception 'Concert inaccessible'
      using errcode = '42501';
  end if;

  select exists (
    select 1
    from public.concert_volunteers volunteer
    where volunteer.concert_id = requested_concert_id
      and volunteer.user_id = (select auth.uid())
      and volunteer.status =
        'selected'::public.concert_volunteer_status
      and volunteer.team_role = 'team_leader'::public.maraude_role
      and volunteer.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
  )
  into is_confirmed_team_leader;

  if not is_admin and not (
    is_confirmed_team_leader
    and (
      (
        current_status in (
          'open'::public.maraude_status,
          'team_ready'::public.maraude_status
        )
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

  if requested_status = 'completed'::public.maraude_status
    and not exists (
      select 1
      from public.maraude_operational_reports report
      where report.concert_id = requested_concert_id
    )
  then
    raise exception 'Le compte rendu doit être renseigné avant la clôture'
      using errcode = '22023';
  end if;

  update public.concerts
  set
    maraude_status = requested_status,
    actual_start_at = case
      when requested_status = 'in_progress'::public.maraude_status
        then coalesce(actual_start_at, changed_at)
      when requested_status in (
        'completed'::public.maraude_status,
        'cancelled'::public.maraude_status
      ) then actual_start_at
      else null
    end,
    actual_end_at = case
      when requested_status = 'completed'::public.maraude_status
        then greatest(changed_at, coalesce(actual_start_at, changed_at))
      when requested_status = 'cancelled'::public.maraude_status
        then actual_end_at
      else null
    end,
    cancellation_reason = case
      when requested_status = 'cancelled'::public.maraude_status
        then nullif(btrim(requested_cancellation_reason), '')
      else null
    end
  where id = requested_concert_id;

  if requested_status = 'completed'::public.maraude_status then
    update public.concert_volunteers
    set attendance_status = 'present'::public.volunteer_attendance_status
    where concert_id = requested_concert_id
      and status = 'selected'::public.concert_volunteer_status
      and confirmation_status =
        'confirmed'::public.volunteer_confirmation_status;
  end if;
end;
$$;
