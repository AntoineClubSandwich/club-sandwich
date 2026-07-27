drop function if exists public.get_concert_volunteer_admin_details(uuid);
drop function if exists public.get_concert_volunteer_details(uuid);

create function public.get_concert_volunteer_details(
  requested_concert_id uuid
)
returns table (
  id uuid,
  concert_id uuid,
  user_id uuid,
  status public.concert_volunteer_status,
  created_at timestamptz,
  updated_at timestamptz,
  first_name text,
  last_name text,
  phone text,
  avatar_url text,
  birth_date date,
  has_driving_license boolean,
  can_lift_heavy_loads boolean,
  emergency_contact_name text,
  emergency_contact_phone text,
  total_applications bigint,
  selected_applications bigint,
  not_selected_applications bigint,
  withdrawn_applications bigint,
  last_selected_date date,
  history jsonb
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with requested_candidates as (
    select cv.*
    from public.concert_volunteers cv
    join public.concerts c on c.id = cv.concert_id
    where cv.concert_id = requested_concert_id
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
      and (
        cv.user_id = (select auth.uid())
        or private.is_club_sandwich_admin((select auth.uid()))
      )
  ),
  accessible_history as (
    select
      cv.user_id,
      cv.concert_id,
      cv.status,
      cv.created_at,
      c.concert_date,
      c.artist,
      v.name as venue_name,
      row_number() over (
        partition by cv.user_id
        order by c.concert_date desc, cv.created_at desc
      ) as history_position
    from public.concert_volunteers cv
    join requested_candidates rc on rc.user_id = cv.user_id
    join public.concerts c on c.id = cv.concert_id
    join public.venues v on v.id = c.venue_id
    where private.is_organization_member(
      c.organization_id,
      (select auth.uid())
    )
  ),
  candidate_statistics as (
    select
      ah.user_id,
      count(*) as total_applications,
      count(*) filter (
        where ah.status = 'selected'::public.concert_volunteer_status
      ) as selected_applications,
      count(*) filter (
        where ah.status = 'not_selected'::public.concert_volunteer_status
      ) as not_selected_applications,
      count(*) filter (
        where ah.status = 'withdrawn'::public.concert_volunteer_status
      ) as withdrawn_applications,
      max(ah.concert_date) filter (
        where ah.status = 'selected'::public.concert_volunteer_status
      ) as last_selected_date
    from accessible_history ah
    group by ah.user_id
  ),
  candidate_history as (
    select
      ah.user_id,
      jsonb_agg(
        jsonb_build_object(
          'concert_id', ah.concert_id,
          'concert_date', ah.concert_date,
          'artist', ah.artist,
          'venue_name', ah.venue_name,
          'status', ah.status
        )
        order by ah.concert_date desc, ah.created_at desc
      ) as history
    from accessible_history ah
    where ah.history_position <= 20
    group by ah.user_id
  )
  select
    cv.id,
    cv.concert_id,
    cv.user_id,
    cv.status,
    cv.created_at,
    cv.updated_at,
    p.first_name,
    p.last_name,
    p.phone,
    p.avatar_url,
    vp.birth_date,
    vp.has_driving_license,
    vp.can_lift_heavy_loads,
    vp.emergency_contact_name,
    vp.emergency_contact_phone,
    coalesce(cs.total_applications, 0),
    coalesce(cs.selected_applications, 0),
    coalesce(cs.not_selected_applications, 0),
    coalesce(cs.withdrawn_applications, 0),
    cs.last_selected_date,
    coalesce(ch.history, '[]'::jsonb)
  from requested_candidates cv
  join public.profiles p on p.id = cv.user_id
  left join public.volunteer_profiles vp on vp.user_id = cv.user_id
  left join candidate_statistics cs on cs.user_id = cv.user_id
  left join candidate_history ch on ch.user_id = cv.user_id
  order by cv.created_at;
$$;

revoke all on function public.get_concert_volunteer_details(uuid)
  from public, anon;
grant execute on function public.get_concert_volunteer_details(uuid)
  to authenticated;
