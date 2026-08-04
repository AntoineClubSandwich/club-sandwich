create or replace function private.can_access_maraude_chat(
  requested_concert_id uuid,
  requested_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    (
      private.is_club_sandwich_admin(requested_user_id)
      and exists (
        select 1
        from public.concerts
        where concerts.id = requested_concert_id
          and private.is_organization_member(
            concerts.organization_id,
            requested_user_id
          )
      )
    )
    or exists (
      select 1
      from public.concert_volunteers
      where concert_volunteers.concert_id = requested_concert_id
        and concert_volunteers.user_id = requested_user_id
        and concert_volunteers.status =
          'selected'::public.concert_volunteer_status
        and concert_volunteers.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
    );
$$;

create or replace function public.set_invitation_campaign_status(
  requested_campaign_id uuid,
  requested_status public.invitation_campaign_status
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target public.invitation_campaigns%rowtype;
begin
  select *
  into target
  from public.invitation_campaigns
  where id = requested_campaign_id
  for update;

  if target.id is null then
    raise exception 'Campagne d’invitations introuvable.'
      using errcode = 'P0002';
  end if;

  if not (
    private.is_club_sandwich_admin((select auth.uid()))
    or private.is_promoter_account_member(
      target.organization_id,
      (select auth.uid())
    )
  ) then
    raise exception
      'Seul un administrateur ou le tourneur associé peut modifier '
      'le statut de cette campagne.'
      using errcode = '42501';
  end if;

  if target.status in (
    'closed'::public.invitation_campaign_status,
    'cancelled'::public.invitation_campaign_status
  ) then
    raise exception
      'Cette campagne est déjà clôturée ou annulée et ne peut plus être '
      'modifiée.'
      using errcode = '22023';
  end if;

  if requested_status not in (
    'open'::public.invitation_campaign_status,
    'closed'::public.invitation_campaign_status,
    'cancelled'::public.invitation_campaign_status
  ) then
    raise exception 'Ce statut de campagne n’est pas pris en charge.'
      using errcode = '22023';
  end if;

  if target.status = 'draft'::public.invitation_campaign_status
    and requested_status = 'closed'::public.invitation_campaign_status
  then
    raise exception
      'Une campagne en brouillon doit d’abord être ouverte avant de '
      'pouvoir être clôturée.'
      using errcode = '22023';
  end if;

  if target.status = 'open'::public.invitation_campaign_status
    and requested_status = 'open'::public.invitation_campaign_status
  then
    return;
  end if;

  update public.invitation_campaigns
  set
    status = requested_status,
    updated_at = now()
  where id = requested_campaign_id;
end;
$$;

revoke all on function public.set_invitation_campaign_status(
  uuid,
  public.invitation_campaign_status
) from public, anon;
grant execute on function public.set_invitation_campaign_status(
  uuid,
  public.invitation_campaign_status
) to authenticated;

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
  pending_credit_validation_count bigint,
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
    count(application.id) filter (
      where application.status =
        'selected'::public.concert_volunteer_status
        and application.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
        and application.attendance_validated_at is null
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
