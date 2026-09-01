-- Today a confirmed team leader can start a maraude directly from 'open'
-- the moment enough volunteers have confirmed (3+, incl. exactly one
-- confirmed team leader) - no admin ever sees or approves that. The
-- 'team_ready' status already exists in the enum and is already labelled
-- "Équipe validée" client-side (dashboard_screen.dart), but nothing has
-- ever assigned it: it's a dead state.
--
-- This wires it up as a mandatory admin checkpoint: an admin must
-- explicitly validate ('open' -> 'team_ready', gated on the same
-- completeness rule already enforced for starting) before the team
-- leader's self-service start ('team_ready' -> 'in_progress') becomes
-- available. Admins keep their existing "démarrer à la place du chef"
-- override straight from 'open' - this only closes the team leader's
-- direct path.

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
  concert_promoter_organization_id uuid;
  is_admin boolean :=
    private.is_club_sandwich_admin((select auth.uid()));
  is_confirmed_team_leader boolean;
  is_promoter_org_member boolean;
  confirmed_member_count integer;
  confirmed_leader_count integer;
begin
  perform public.expire_volunteer_confirmations();

  select concert.maraude_status, concert.promoter_organization_id
  into current_status, concert_promoter_organization_id
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
      or private.is_promoter_account_member(
        concert.promoter_organization_id,
        (select auth.uid())
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

  is_promoter_org_member := private.is_promoter_account_member(
    concert_promoter_organization_id,
    (select auth.uid())
  );

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
  ) and not (
    is_promoter_org_member
    and current_status = 'draft'::public.maraude_status
    and requested_status = 'open'::public.maraude_status
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
    end,
    cancellation_reason = case
      when requested_status = 'cancelled'::public.maraude_status
        then nullif(btrim(requested_cancellation_reason), '')
      else cancellation_reason
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
end;
$$;

revoke all on function public.set_maraude_status(
  uuid, public.maraude_status, text
) from public, anon;
grant execute on function public.set_maraude_status(
  uuid, public.maraude_status, text
) to authenticated;

create or replace function private.require_complete_team_before_start()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  confirmed_member_count integer;
  confirmed_leader_count integer;
begin
  if new.maraude_status in (
    'team_ready'::public.maraude_status,
    'in_progress'::public.maraude_status
  )
    and old.maraude_status is distinct from new.maraude_status
  then
    select
      count(*),
      count(*) filter (
        where application.team_role =
          'team_leader'::public.maraude_role
      )
    into confirmed_member_count, confirmed_leader_count
    from public.concert_volunteers application
    where application.concert_id = new.id
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

  return new;
end;
$$;

revoke all on function private.require_complete_team_before_start()
  from public, anon, authenticated;

-- Expose team-confirmation counts so the dashboard can surface "team
-- confirmed, ready for admin validation" without every client re-deriving
-- the same rule the RPC/trigger above already enforce.
drop function public.get_maraude_overview(integer);

create function public.get_maraude_overview(
  requested_limit integer default 100
)
returns table (
  concert_id uuid,
  artist text,
  concert_date date,
  concert_time time,
  maraude_status public.maraude_status,
  venue_name text,
  venue_address text,
  catering_name text,
  catering_closes_at time,
  application_count bigint,
  pending_application_count bigint,
  selected_count bigint,
  pending_confirmation_count bigint,
  confirmed_count bigint,
  confirmed_leader_count bigint,
  pending_credit_validation_count bigint,
  total_weight_kg numeric,
  estimated_meals integer,
  own_status public.concert_volunteer_status,
  own_team_role public.maraude_role,
  own_confirmation_status public.volunteer_confirmation_status,
  is_admin boolean
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    concert.id,
    concert.artist,
    concert.concert_date,
    concert.concert_time,
    concert.maraude_status,
    venue.name,
    concat_ws(
      ', ',
      nullif(venue.public_address_line1, ''),
      nullif(venue.postal_code, ''),
      nullif(venue.city, '')
    ),
    concert.catering_contact_name,
    concert.catering_closes_at,
    count(application.id) filter (
      where application.status <>
        'withdrawn'::public.concert_volunteer_status
    ),
    count(application.id) filter (
      where application.status =
        'pending'::public.concert_volunteer_status
    ),
    count(application.id) filter (
      where application.status =
        'selected'::public.concert_volunteer_status
    ),
    count(application.id) filter (
      where application.status =
        'selected'::public.concert_volunteer_status
        and application.confirmation_status =
          'pending'::public.volunteer_confirmation_status
    ),
    count(application.id) filter (
      where application.status =
        'selected'::public.concert_volunteer_status
        and application.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
    ),
    count(application.id) filter (
      where application.status =
        'selected'::public.concert_volunteer_status
        and application.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
        and application.team_role =
          'team_leader'::public.maraude_role
    ),
    count(application.id) filter (
      where application.status =
        'selected'::public.concert_volunteer_status
        and application.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
        and application.attendance_validated_at is null
    ),
    report.total_weight_kg,
    report.estimated_meals,
    own_application.status,
    own_application.team_role,
    own_application.confirmation_status,
    private.is_club_sandwich_admin((select auth.uid()))
  from public.concerts concert
  join public.venues venue on venue.id = concert.venue_id
  left join public.concert_volunteers application
    on application.concert_id = concert.id
  left join public.concert_volunteers own_application
    on own_application.concert_id = concert.id
    and own_application.user_id = (select auth.uid())
  left join public.maraude_operational_reports report
    on report.concert_id = concert.id
  where private.is_active_user((select auth.uid()))
    and (
      private.is_club_sandwich_admin((select auth.uid()))
      or private.is_promoter_account_member(
        concert.promoter_organization_id,
        (select auth.uid())
      )
      or (
        private.is_volunteer_account((select auth.uid()))
        and (
          concert.maraude_status = 'open'::public.maraude_status
          or own_application.id is not null
        )
      )
    )
  group by
    concert.id,
    venue.id,
    report.concert_id,
    own_application.id
  order by
    concert.concert_date desc,
    concert.concert_time desc nulls last
  limit least(greatest(requested_limit, 1), 200);
$$;

revoke all on function public.get_maraude_overview(integer)
  from public, anon;
grant execute on function public.get_maraude_overview(integer)
  to authenticated;
