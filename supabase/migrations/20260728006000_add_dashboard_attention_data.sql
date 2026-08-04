drop function public.get_maraude_overview(integer);

create function public.get_maraude_overview(
  requested_limit integer default 100
)
returns table (
  concert_id uuid,
  artist text,
  concert_date date,
  concert_time time,
  maraude_status public.maraude_status,
  venue_name text,
  venue_address text,
  catering_name text,
  catering_closes_at time,
  application_count bigint,
  pending_application_count bigint,
  selected_count bigint,
  pending_confirmation_count bigint,
  total_weight_kg numeric,
  estimated_meals integer,
  own_status public.concert_volunteer_status,
  own_team_role public.maraude_role,
  own_confirmation_status public.volunteer_confirmation_status,
  is_admin boolean
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    concert.id,
    concert.artist,
    concert.concert_date,
    concert.concert_time,
    concert.maraude_status,
    venue.name,
    concat_ws(
      ', ',
      nullif(venue.public_address_line1, ''),
      nullif(venue.postal_code, ''),
      nullif(venue.city, '')
    ),
    concert.catering_contact_name,
    concert.catering_closes_at,
    count(application.id) filter (
      where application.status <>
        'withdrawn'::public.concert_volunteer_status
    ),
    count(application.id) filter (
      where application.status =
        'pending'::public.concert_volunteer_status
    ),
    count(application.id) filter (
      where application.status =
        'selected'::public.concert_volunteer_status
    ),
    count(application.id) filter (
      where application.status =
        'selected'::public.concert_volunteer_status
        and application.confirmation_status =
          'pending'::public.volunteer_confirmation_status
    ),
    report.total_weight_kg,
    report.estimated_meals,
    own_application.status,
    own_application.team_role,
    own_application.confirmation_status,
    private.is_club_sandwich_admin((select auth.uid()))
  from public.concerts concert
  join public.venues venue on venue.id = concert.venue_id
  left join public.concert_volunteers application
    on application.concert_id = concert.id
  left join public.concert_volunteers own_application
    on own_application.concert_id = concert.id
    and own_application.user_id = (select auth.uid())
  left join public.maraude_operational_reports report
    on report.concert_id = concert.id
  where private.is_active_user((select auth.uid()))
    and (
      private.is_club_sandwich_admin((select auth.uid()))
      or private.is_promoter_account_member(
        concert.promoter_organization_id,
        (select auth.uid())
      )
      or (
        private.is_volunteer_account((select auth.uid()))
        and (
          concert.maraude_status = 'open'::public.maraude_status
          or own_application.id is not null
        )
      )
    )
  group by
    concert.id,
    venue.id,
    report.concert_id,
    own_application.id
  order by
    concert.concert_date desc,
    concert.concert_time desc nulls last
  limit least(greatest(requested_limit, 1), 200);
$$;

revoke all on function public.get_maraude_overview(integer)
  from public, anon;
grant execute on function public.get_maraude_overview(integer)
  to authenticated;

drop policy if exists "Volunteers view open invitation campaigns"
  on public.invitation_campaigns;

create function private.has_invitation_application(
  requested_campaign_id uuid,
  requested_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.invitation_applications application
    where application.campaign_id = requested_campaign_id
      and application.user_id = requested_user_id
  );
$$;

revoke all on function private.has_invitation_application(uuid, uuid)
  from public, anon;
grant execute on function private.has_invitation_application(uuid, uuid)
  to authenticated;

create policy "Volunteers view accessible invitation campaigns"
on public.invitation_campaigns
for select
to authenticated
using (
  private.is_volunteer_account((select auth.uid()))
  and (
    status = 'open'::public.invitation_campaign_status
    or private.has_invitation_application(
      id,
      (select auth.uid())
    )
  )
);
