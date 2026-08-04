create or replace function public.set_invitation_application_status(
  requested_application_id uuid,
  requested_status public.invitation_application_status
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  requested_campaign_id uuid;
  campaign_capacity integer;
  attributed_count integer;
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

  select application.campaign_id
  into requested_campaign_id
  from public.invitation_applications application
  where application.id = requested_application_id
  for update;

  if not found then
    raise exception 'Candidature introuvable' using errcode = 'P0002';
  end if;

  select campaign.available_places
  into campaign_capacity
  from public.invitation_campaigns campaign
  where campaign.id = requested_campaign_id
  for update;

  if requested_status =
    'selected'::public.invitation_application_status then
    select count(*)
    into attributed_count
    from public.invitation_applications application
    where application.campaign_id = requested_campaign_id
      and application.status =
        'selected'::public.invitation_application_status
      and application.id <> requested_application_id;

    if attributed_count >= campaign_capacity then
      raise exception 'Toutes les places ont déjà été attribuées'
        using errcode = '22023';
    end if;
  end if;

  update public.invitation_applications
  set status = requested_status, updated_at = now()
  where id = requested_application_id;
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
