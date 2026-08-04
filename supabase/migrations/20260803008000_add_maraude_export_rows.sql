create or replace function private.collection_category_label(
  category public.collection_category
)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case category
    when 'prepared_meals' then 'Plats préparés'
    when 'fruits_vegetables' then 'Fruits et légumes'
    when 'bakery' then 'Boulangerie'
    when 'dairy' then 'Produits laitiers'
    when 'groceries' then 'Épicerie'
    when 'drinks' then 'Boissons'
    else 'Autre'
  end;
$$;

revoke all on function private.collection_category_label(public.collection_category)
from public, anon, authenticated;

create or replace function private.collection_unit_label(
  unit public.collection_unit
)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case unit
    when 'kg' then 'kg'
    when 'crate' then 'cageot(s)'
    when 'box' then 'carton(s)'
    when 'bag' then 'sac(s)'
    when 'piece' then 'pièce(s)'
    else 'unité(s)'
  end;
$$;

revoke all on function private.collection_unit_label(public.collection_unit)
from public, anon, authenticated;

create or replace function public.get_maraude_export_rows(
  requested_start_date date default null,
  requested_end_date date default null,
  requested_organization_id uuid default null
)
returns table (
  concert_id uuid,
  artist text,
  concert_date date,
  organization_name text,
  venue_name text,
  actual_start_at timestamptz,
  actual_end_at timestamptz,
  duration_hours numeric,
  distance_km numeric,
  total_weight_kg numeric,
  estimated_meals integer,
  distributed_meals integer,
  estimated_beneficiaries integer,
  volunteer_count bigint,
  volunteer_hours numeric,
  collection_summary text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  caller_is_admin boolean;
  caller_promoter_organization_id uuid;
begin
  caller_is_admin := private.is_club_sandwich_admin((select auth.uid()));

  if not caller_is_admin then
    select account.organization_id
    into caller_promoter_organization_id
    from public.user_accounts account
    where account.profile_id = (select auth.uid())
      and account.role = 'promoter'::public.app_role
      and account.status = 'active'::public.user_account_status;

    if caller_promoter_organization_id is null then
      raise exception 'Accès réservé aux administrateurs et tourneurs'
        using errcode = '42501';
    end if;
  end if;

  return query
  select
    concert.id,
    concert.artist,
    concert.concert_date,
    promoter_org.name,
    venue.name,
    concert.actual_start_at,
    concert.actual_end_at,
    round(
      (
        extract(
          epoch from (concert.actual_end_at - concert.actual_start_at)
        ) / 3600
      )::numeric,
      2
    ),
    report.distance_km,
    report.total_weight_kg,
    report.estimated_meals,
    distribution.distributed_meals,
    distribution.estimated_beneficiaries,
    coalesce(present.volunteer_count, 0),
    round(
      coalesce(present.volunteer_count, 0) * (
        extract(
          epoch from (concert.actual_end_at - concert.actual_start_at)
        ) / 3600
      )::numeric,
      2
    ),
    collection_summary.value
  from public.concerts concert
  left join public.organizations promoter_org
    on promoter_org.id = concert.promoter_organization_id
  left join public.venues venue on venue.id = concert.venue_id
  left join public.maraude_operational_reports report
    on report.concert_id = concert.id
  left join public.maraude_distributions distribution
    on distribution.concert_id = concert.id
  left join lateral (
    select count(*)::bigint as volunteer_count
    from public.concert_volunteers application
    where application.concert_id = concert.id
      and application.status = 'selected'::public.concert_volunteer_status
      and application.attendance_status =
        'present'::public.volunteer_attendance_status
  ) present on true
  left join lateral (
    select string_agg(
      format(
        '%s: %s %s',
        private.collection_category_label(per_category.category),
        trim(to_char(per_category.total_quantity, 'FM999999990.##')),
        private.collection_unit_label(per_category.unit)
      ),
      '; '
      order by per_category.category
    ) as value
    from (
      select
        collection.category,
        collection.unit,
        sum(collection.quantity) as total_quantity
      from public.maraude_collections collection
      where collection.concert_id = concert.id
      group by collection.category, collection.unit
    ) per_category
  ) collection_summary on true
  where concert.maraude_status = 'completed'::public.maraude_status
    and (
      requested_start_date is null
      or concert.concert_date >= requested_start_date
    )
    and (
      requested_end_date is null
      or concert.concert_date <= requested_end_date
    )
    and (
      caller_is_admin
      or concert.promoter_organization_id = caller_promoter_organization_id
    )
    and (
      requested_organization_id is null
      or concert.promoter_organization_id = requested_organization_id
    )
  order by concert.concert_date desc;
end;
$$;

revoke all on function public.get_maraude_export_rows(date, date, uuid)
from public, anon;
grant execute on function public.get_maraude_export_rows(date, date, uuid)
to authenticated;
