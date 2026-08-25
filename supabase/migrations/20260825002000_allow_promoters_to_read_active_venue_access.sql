-- A promoter needs the artist entrance while choosing a venue for a new
-- maraude. The previous policy only granted access after a concert already
-- existed at the venue, which made the creation flow circular.
create or replace function private.is_active_promoter_account(
  requested_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.user_accounts account
    where account.profile_id = requested_profile_id
      and account.role = 'promoter'::public.app_role
      and account.status = 'active'::public.user_account_status
  );
$$;

revoke all on function private.is_active_promoter_account(uuid) from public;
revoke all on function private.is_active_promoter_account(uuid) from anon;
grant execute on function private.is_active_promoter_account(uuid)
  to authenticated;

drop policy if exists "Authorized concert team can view venue access details"
on public.venue_access_details;

create policy "Authorized concert team can view venue access details"
on public.venue_access_details
for select
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  or (
    private.is_active_promoter_account((select auth.uid()))
    and exists (
      select 1
      from public.venues venue
      where venue.id = venue_access_details.venue_id
        and venue.is_active
    )
  )
  or exists (
    select 1
    from public.concerts concert
    where concert.venue_id = venue_access_details.venue_id
      and (
        (
          concert.promoter_organization_id is not null
          and private.is_producer_member(
            concert.promoter_organization_id,
            (select auth.uid())
          )
        )
        or exists (
          select 1
          from public.concert_volunteers application
          where application.concert_id = concert.id
            and application.user_id = (select auth.uid())
            and application.status =
              'selected'::public.concert_volunteer_status
            and application.confirmation_status =
              'confirmed'::public.volunteer_confirmation_status
        )
      )
  )
);
