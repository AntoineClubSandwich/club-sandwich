create or replace function public.get_maraude_overview(
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
  selected_count bigint,
  total_weight_kg numeric,
  estimated_meals integer,
  own_status public.concert_volunteer_status,
  own_team_role public.maraude_role,
  is_admin boolean
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    c.id,
    c.artist,
    c.concert_date,
    c.concert_time,
    c.maraude_status,
    v.name,
    concat_ws(
      ', ',
      nullif(v.public_address_line1, ''),
      nullif(v.postal_code, ''),
      nullif(v.city, '')
    ),
    c.catering_contact_name,
    c.catering_closes_at,
    count(cv.id) filter (
      where cv.status <> 'withdrawn'::public.concert_volunteer_status
    ),
    count(cv.id) filter (
      where cv.status = 'selected'::public.concert_volunteer_status
    ),
    report.total_weight_kg,
    report.estimated_meals,
    own_application.status,
    own_application.team_role,
    private.is_club_sandwich_admin((select auth.uid()))
  from public.concerts c
  join public.venues v on v.id = c.venue_id
  left join public.concert_volunteers cv on cv.concert_id = c.id
  left join public.concert_volunteers own_application
    on own_application.concert_id = c.id
    and own_application.user_id = (select auth.uid())
  left join public.maraude_operational_reports report
    on report.concert_id = c.id
  where private.is_active_user((select auth.uid()))
    and (
      private.is_club_sandwich_admin((select auth.uid()))
      or private.is_promoter_account_member(
        c.promoter_organization_id,
        (select auth.uid())
      )
      or (
        private.is_volunteer_account((select auth.uid()))
        and (
          c.maraude_status = 'open'::public.maraude_status
          or own_application.id is not null
        )
      )
    )
  group by
    c.id,
    v.id,
    report.concert_id,
    own_application.id
  order by c.concert_date desc, c.concert_time desc nulls last
  limit least(greatest(requested_limit, 1), 200);
$$;

revoke all on function public.get_maraude_overview(integer)
  from public, anon;
grant execute on function public.get_maraude_overview(integer)
  to authenticated;

comment on function public.get_maraude_overview(integer) is
  'Vue agrégée des maraudes : toutes pour les admins, celles de leur '
  'organisation pour les tourneurs, ouvertes ou déjà candidatées pour les '
  'bénévoles.';
