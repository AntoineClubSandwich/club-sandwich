alter table public.volunteer_credits
  add column consumed_by_invitation_application_id uuid
    references public.invitation_applications(id) on delete set null,
  add column consumed_at timestamptz;

alter table public.volunteer_credits
  drop constraint volunteer_credits_status_check,
  drop constraint volunteer_credits_check;

alter table public.volunteer_credits
  add constraint volunteer_credits_status_check
  check (status in ('active', 'consumed', 'revoked'));

alter table public.volunteer_credits
  add constraint volunteer_credits_check
  check (
    (
      status = 'active'
      and revoked_by is null
      and revoked_at is null
      and consumed_by_invitation_application_id is null
      and consumed_at is null
    )
    or (
      status = 'consumed'
      and revoked_by is null
      and revoked_at is null
      and consumed_by_invitation_application_id is not null
      and consumed_at is not null
    )
    or (
      status = 'revoked'
      and revoked_at is not null
    )
  );

create index volunteer_credits_consumed_by_invitation_idx
on public.volunteer_credits (consumed_by_invitation_application_id)
where consumed_by_invitation_application_id is not null;

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
  previous_status public.invitation_application_status;
  campaign_capacity integer;
  attributed_count integer;
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

  select application.campaign_id, application.user_id, application.status
  into requested_campaign_id, applicant_user_id, previous_status
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

create or replace function private.volunteer_credit_consumed_count(
  requested_user_id uuid
)
returns bigint
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select count(*)::bigint
  from public.volunteer_credits credit
  where credit.user_id = requested_user_id
    and credit.status = 'consumed';
$$;

revoke all on function private.volunteer_credit_consumed_count(uuid)
from public, anon, authenticated;

create or replace function public.get_my_volunteer_credit_summary()
returns table (
  earned bigint,
  consumed bigint,
  available bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    count(*) filter (
      where credit.status in ('active', 'consumed')
    )::bigint as earned,
    count(*) filter (where credit.status = 'consumed')::bigint as consumed,
    count(*) filter (where credit.status = 'active')::bigint as available
  from public.volunteer_credits credit
  where credit.user_id = (select auth.uid());
$$;

revoke all on function public.get_my_volunteer_credit_summary()
from public, anon;
grant execute on function public.get_my_volunteer_credit_summary()
to authenticated;
