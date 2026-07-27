create or replace function private.is_volunteer_account(
  requested_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    private.is_active_user(requested_profile_id)
    and (
      not exists (
        select 1
        from public.user_accounts
        where profile_id = requested_profile_id
      )
      or exists (
        select 1
        from public.user_accounts
        where profile_id = requested_profile_id
          and role = 'volunteer'::public.app_role
          and status = 'active'::public.user_account_status
      )
    );
$$;

revoke all on function private.is_volunteer_account(uuid)
  from public, anon, authenticated;
grant execute on function private.is_volunteer_account(uuid)
  to authenticated;

drop policy if exists "Volunteers view open invitation campaigns"
  on public.invitation_campaigns;
create policy "Volunteers view open invitation campaigns"
on public.invitation_campaigns
for select
to authenticated
using (
  status = 'open'::public.invitation_campaign_status
  and private.is_volunteer_account((select auth.uid()))
);

drop policy if exists "Volunteers view their invitation applications"
  on public.invitation_applications;
create policy "Volunteers view their invitation applications"
on public.invitation_applications
for select
to authenticated
using (
  user_id = (select auth.uid())
  and private.is_volunteer_account((select auth.uid()))
);

drop policy if exists "Volunteers create their invitation applications"
  on public.invitation_applications;
create policy "Volunteers create their invitation applications"
on public.invitation_applications
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and private.is_volunteer_account((select auth.uid()))
  and status = 'pending'::public.invitation_application_status
  and exists (
    select 1
    from public.invitation_campaigns campaign
    where campaign.id = invitation_applications.campaign_id
      and campaign.status = 'open'::public.invitation_campaign_status
      and (
        campaign.application_deadline is null
        or campaign.application_deadline >= now()
      )
  )
);

drop policy if exists "Volunteers withdraw invitation applications"
  on public.invitation_applications;
create policy "Volunteers withdraw invitation applications"
on public.invitation_applications
for update
to authenticated
using (
  user_id = (select auth.uid())
  and private.is_volunteer_account((select auth.uid()))
  and status = 'pending'::public.invitation_application_status
)
with check (
  user_id = (select auth.uid())
  and private.is_volunteer_account((select auth.uid()))
  and status = 'withdrawn'::public.invitation_application_status
);
