grant execute on function private.can_edit_maraude_report(uuid, uuid)
to authenticated;

drop policy if exists "Eligible volunteers create invitation applications"
  on public.invitation_applications;

create policy "Eligible volunteers create invitation applications"
on public.invitation_applications
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and status = 'pending'::public.invitation_application_status
  and private.is_volunteer_account((select auth.uid()))
  and public.get_my_volunteer_credit_count() >= 3
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
