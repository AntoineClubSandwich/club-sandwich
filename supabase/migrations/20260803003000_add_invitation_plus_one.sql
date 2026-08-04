alter table public.invitation_applications
  add column plus_one boolean not null default false,
  add column plus_one_name text;

alter table public.invitation_applications
  add constraint invitation_applications_plus_one_name_requires_plus_one
  check (plus_one_name is null or plus_one);

create policy "Volunteers edit their pending plus-one"
on public.invitation_applications
for update
to authenticated
using (
  user_id = (select auth.uid())
  and status = 'pending'::public.invitation_application_status
)
with check (
  user_id = (select auth.uid())
  and status = 'pending'::public.invitation_application_status
);

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
  applicant_user_id uuid;
  applicant_plus_one boolean;
  previous_status public.invitation_application_status;
  campaign_capacity integer;
  attributed_places integer;
  requested_places integer;
  available_credits bigint;
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

  select
    application.campaign_id,
    application.user_id,
    application.status,
    application.plus_one
  into
    requested_campaign_id,
    applicant_user_id,
    previous_status,
    applicant_plus_one
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
    'selected'::public.invitation_application_status
    and previous_status <> 'selected'::public.invitation_application_status
  then
    select coalesce(
      sum(case when application.plus_one then 2 else 1 end),
      0
    )
    into attributed_places
    from public.invitation_applications application
    where application.campaign_id = requested_campaign_id
      and application.status =
        'selected'::public.invitation_application_status
      and application.id <> requested_application_id;

    requested_places := case when applicant_plus_one then 2 else 1 end;

    if attributed_places + requested_places > campaign_capacity then
      raise exception 'Toutes les places ont déjà été attribuées'
        using errcode = '22023';
    end if;

    select private.volunteer_credit_count(applicant_user_id)
    into available_credits;

    if available_credits < 3 then
      raise exception 'Crédits insuffisants pour attribuer cette invitation'
        using errcode = '22023';
    end if;
  elsif previous_status = 'selected'::public.invitation_application_status
    and requested_status <> 'selected'::public.invitation_application_status
  then
    update public.volunteer_credits
    set
      status = 'active',
      consumed_by_invitation_application_id = null,
      consumed_at = null
    where consumed_by_invitation_application_id = requested_application_id
      and status = 'consumed';
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
