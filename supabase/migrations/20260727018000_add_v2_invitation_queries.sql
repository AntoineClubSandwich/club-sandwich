create or replace function public.get_invitation_candidates(
  requested_campaign_id uuid
)
returns table (
  application_id uuid,
  user_id uuid,
  first_name text,
  last_name text,
  status public.invitation_application_status,
  member_since timestamptz,
  maraude_count bigint,
  withdrawal_count bigint,
  invitation_count bigint,
  last_invitation_at timestamptz,
  can_manage boolean
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  campaign_organization_id uuid;
  caller_is_admin boolean;
begin
  select organization_id
  into campaign_organization_id
  from public.invitation_campaigns
  where id = requested_campaign_id;

  caller_is_admin :=
    private.is_club_sandwich_admin((select auth.uid()));

  if campaign_organization_id is null or not (
    caller_is_admin
    or private.is_promoter_account_member(
      campaign_organization_id,
      (select auth.uid())
    )
  ) then
    raise exception 'Campagne inaccessible' using errcode = '42501';
  end if;

  return query
  select
    application.id,
    application.user_id,
    profile.first_name,
    profile.last_name,
    application.status,
    profile.created_at,
    (
      select count(*)::bigint
      from public.concert_volunteers volunteer_application
      join public.concerts concert
        on concert.id = volunteer_application.concert_id
      where volunteer_application.user_id = application.user_id
        and volunteer_application.status =
          'selected'::public.concert_volunteer_status
        and concert.maraude_status = 'completed'::public.maraude_status
    ),
    (
      select count(*)::bigint
      from public.concert_volunteer_events event
      join public.concert_volunteers volunteer_application
        on volunteer_application.id = event.application_id
      where volunteer_application.user_id = application.user_id
        and event.status = 'withdrawn'::public.concert_volunteer_status
    ),
    (
      select count(*)::bigint
      from public.invitation_applications previous_invitation
      where previous_invitation.user_id = application.user_id
        and previous_invitation.status =
          'selected'::public.invitation_application_status
    ),
    (
      select max(previous_invitation.updated_at)
      from public.invitation_applications previous_invitation
      where previous_invitation.user_id = application.user_id
        and previous_invitation.status =
          'selected'::public.invitation_application_status
    ),
    caller_is_admin
  from public.invitation_applications application
  join public.profiles profile on profile.id = application.user_id
  where application.campaign_id = requested_campaign_id
  order by
    case application.status
      when 'selected'::public.invitation_application_status then 0
      when 'pending'::public.invitation_application_status then 1
      when 'withdrawn'::public.invitation_application_status then 2
      else 3
    end,
    application.created_at;
end;
$$;

revoke all on function public.get_invitation_candidates(uuid)
  from public, anon;
grant execute on function public.get_invitation_candidates(uuid)
  to authenticated;

create or replace function public.set_invitation_application_status(
  requested_application_id uuid,
  requested_status public.invitation_application_status
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur attribue les invitations'
      using errcode = '42501';
  end if;

  if requested_status not in (
    'selected'::public.invitation_application_status,
    'not_selected'::public.invitation_application_status,
    'pending'::public.invitation_application_status
  ) then
    raise exception 'Statut d’attribution invalide'
      using errcode = '22023';
  end if;

  update public.invitation_applications
  set status = requested_status, updated_at = now()
  where id = requested_application_id;

  if not found then
    raise exception 'Candidature introuvable' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.set_invitation_application_status(
  uuid,
  public.invitation_application_status
) from public, anon;
grant execute on function public.set_invitation_application_status(
  uuid,
  public.invitation_application_status
) to authenticated;
