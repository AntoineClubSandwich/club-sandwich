-- The invitation campaign list computed selected/pending/remaining-places
-- counts client-side from the embedded `invitation_applications` join.
-- That join is RLS-filtered per caller: a volunteer only ever sees their
-- own application row there ("Volunteers view their invitation
-- applications" policy), so a volunteer's computed counts reflected only
-- their own application instead of the campaign's real totals — showing
-- a different "places restantes" than what an admin/promoter saw for the
-- exact same campaign. Counts are safe to expose to any authenticated
-- user (no applicant identity leaks), so compute them here with elevated
-- privileges instead of relying on the RLS-filtered client-side join.

create function public.get_invitation_campaign_counts(
  requested_campaign_ids uuid[]
)
returns table (
  campaign_id uuid,
  application_count integer,
  pending_count integer,
  selected_count integer,
  attributed_places_count integer,
  awaiting_confirmation_count integer
)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  select
    application.campaign_id,
    count(*) filter (
      where application.status <> 'withdrawn'::public.invitation_application_status
    )::integer as application_count,
    count(*) filter (
      where application.status = 'pending'::public.invitation_application_status
    )::integer as pending_count,
    count(*) filter (
      where application.status = 'selected'::public.invitation_application_status
    )::integer as selected_count,
    coalesce(sum(
      case
        when application.status = 'selected'::public.invitation_application_status
          then (case when application.plus_one then 2 else 1 end)
        else 0
      end
    ), 0)::integer as attributed_places_count,
    count(*) filter (
      where application.status = 'selected'::public.invitation_application_status
        and application.confirmation_status = 'pending'::public.volunteer_confirmation_status
    )::integer as awaiting_confirmation_count
  from public.invitation_applications application
  where application.campaign_id = any(requested_campaign_ids)
  group by application.campaign_id;
$$;

revoke all on function public.get_invitation_campaign_counts(uuid[])
  from public, anon;
grant execute on function public.get_invitation_campaign_counts(uuid[])
  to authenticated;
