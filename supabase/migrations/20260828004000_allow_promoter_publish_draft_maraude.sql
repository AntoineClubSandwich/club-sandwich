-- Draft maraudes: a tourneur (promoter) can already create a concert for
-- their own promoter organization, but set_maraude_status only let an
-- admin, or a confirmed team leader doing a narrow set of transitions,
-- change maraude_status — so a tourneur had no way to publish (draft ->
-- open) a draft they just created themselves. Add that one transition
-- for promoter organization members, on top of the existing admin/team
-- leader authorization already in place.

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
  ) and not (
    is_promoter_org_member
    and current_status = 'draft'::public.maraude_status
    and requested_status = 'open'::public.maraude_status
  ) then
    raise exception 'Action réservée au chef d''équipe'
      using errcode = '42501';
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
