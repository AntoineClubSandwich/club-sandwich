-- Extends read access to venue_access_details from admin-only to the whole
-- concert team (see the "later" TODO left in its table comment when it was
-- created): a promoter-org member or a confirmed volunteer for a concert at
-- that venue can now see where the artist entrance is, since they're the
-- people who actually need to know on the day.
drop policy if exists "Club Sandwich admins can view venue access details"
on public.venue_access_details;

create policy "Authorized concert team can view venue access details"
on public.venue_access_details
for select
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  or exists (
    select 1
    from public.concerts c
    where c.venue_id = venue_access_details.venue_id
      and (
        (
          c.promoter_organization_id is not null
          and private.is_producer_member(
            c.promoter_organization_id,
            (select auth.uid())
          )
        )
        or exists (
          select 1
          from public.concert_volunteers cv
          where cv.concert_id = c.id
            and cv.user_id = (select auth.uid())
            and cv.status = 'selected'::public.concert_volunteer_status
            and cv.confirmation_status =
              'confirmed'::public.volunteer_confirmation_status
        )
      )
  )
);
