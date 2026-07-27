alter table public.concerts
  add column cancellation_reason text;

alter table public.concerts
  add constraint concerts_maraude_dates_are_coherent
  check (
    actual_end_at is null
    or (
      actual_start_at is not null
      and actual_end_at >= actual_start_at
    )
  );

create table public.maraude_operational_reports (
  concert_id uuid primary key
    references public.concerts(id) on delete cascade,
  total_weight_kg numeric not null default 0
    check (total_weight_kg >= 0),
  estimated_meals integer not null default 0
    check (estimated_meals >= 0),
  comment text,
  photo_folder_url text,
  last_modified_by uuid
    references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger maraude_operational_reports_set_updated_at
before update on public.maraude_operational_reports
for each row execute function private.set_updated_at();

create index concerts_maraude_status_date_idx
on public.concerts (organization_id, maraude_status, concert_date desc);

alter table public.maraude_operational_reports enable row level security;

create policy "Accessible team members view operational reports"
on public.maraude_operational_reports
for select
to authenticated
using (
  exists (
    select 1
    from public.concerts c
    where c.id = maraude_operational_reports.concert_id
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
      and (
        private.is_club_sandwich_admin((select auth.uid()))
        or exists (
          select 1
          from public.concert_volunteers cv
          where cv.concert_id = c.id
            and cv.user_id = (select auth.uid())
            and cv.status = 'selected'::public.concert_volunteer_status
        )
      )
  )
);

revoke all on public.maraude_operational_reports from anon, authenticated;
grant select on public.maraude_operational_reports to authenticated;

create or replace function private.is_selected_maraude_member(
  requested_concert_id uuid,
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
    from public.concert_volunteers cv
    where cv.concert_id = requested_concert_id
      and cv.user_id = requested_user_id
      and cv.status = 'selected'::public.concert_volunteer_status
  );
$$;

revoke all on function private.is_selected_maraude_member(uuid, uuid)
  from public, anon, authenticated;

drop policy if exists "Members can view accessible concerts"
  on public.concerts;

create policy "Members can view accessible concerts"
on public.concerts
for select
to authenticated
using (
  private.is_organization_member(organization_id, (select auth.uid()))
  and (
    maraude_status <> 'completed'::public.maraude_status
    or private.is_club_sandwich_admin((select auth.uid()))
    or private.is_selected_maraude_member(id, (select auth.uid()))
  )
);

create or replace function private.can_edit_maraude_report(
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
    private.is_club_sandwich_admin(requested_user_id)
    or exists (
      select 1
      from public.concert_volunteers cv
      where cv.concert_id = requested_concert_id
        and cv.user_id = requested_user_id
        and cv.status = 'selected'::public.concert_volunteer_status
        and cv.team_role = 'team_leader'::public.maraude_role
    );
$$;

revoke all on function private.can_edit_maraude_report(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.set_maraude_status(
  requested_concert_id uuid,
  requested_status public.maraude_status,
  requested_cancellation_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  changed_at timestamptz := clock_timestamp();
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut modifier la maraude'
      using errcode = '42501';
  end if;

  perform 1
  from public.concerts c
  where c.id = requested_concert_id
    and private.is_organization_member(
      c.organization_id,
      (select auth.uid())
    )
  for update;

  if not found then
    raise exception 'Concert inaccessible'
      using errcode = '42501';
  end if;

  update public.concerts
  set
    maraude_status = requested_status,
    actual_start_at = case
      when requested_status = 'in_progress'::public.maraude_status
        then coalesce(actual_start_at, changed_at)
      when requested_status in (
        'completed'::public.maraude_status,
        'cancelled'::public.maraude_status
      ) then actual_start_at
      else null
    end,
    actual_end_at = case
      when requested_status = 'completed'::public.maraude_status
        then greatest(changed_at, coalesce(actual_start_at, changed_at))
      when requested_status = 'cancelled'::public.maraude_status
        then actual_end_at
      else null
    end,
    cancellation_reason = case
      when requested_status = 'cancelled'::public.maraude_status
        then nullif(btrim(requested_cancellation_reason), '')
      else null
    end
  where id = requested_concert_id;
end;
$$;

revoke all on function public.set_maraude_status(
  uuid,
  public.maraude_status,
  text
) from public, anon;
grant execute on function public.set_maraude_status(
  uuid,
  public.maraude_status,
  text
) to authenticated;

create or replace function public.start_maraude(
  requested_concert_id uuid
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  select public.set_maraude_status(
    requested_concert_id,
    'in_progress'::public.maraude_status,
    null
  );
$$;

create or replace function public.complete_maraude(
  requested_concert_id uuid
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  select public.set_maraude_status(
    requested_concert_id,
    'completed'::public.maraude_status,
    null
  );
$$;

revoke all on function public.start_maraude(uuid) from public, anon;
revoke all on function public.complete_maraude(uuid) from public, anon;
grant execute on function public.start_maraude(uuid) to authenticated;
grant execute on function public.complete_maraude(uuid) to authenticated;

create or replace function public.save_maraude_report(
  requested_concert_id uuid,
  requested_total_weight_kg numeric,
  requested_estimated_meals integer,
  requested_comment text default null,
  requested_photo_folder_url text default null,
  requested_complete boolean default true
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  concert_organization_id uuid;
  changed_at timestamptz := clock_timestamp();
begin
  if requested_total_weight_kg is null or requested_total_weight_kg < 0 then
    raise exception 'Le poids doit être positif ou nul'
      using errcode = '22023';
  end if;

  if requested_estimated_meals is null or requested_estimated_meals < 0 then
    raise exception 'Le nombre de repas doit être positif ou nul'
      using errcode = '22023';
  end if;

  select c.organization_id
  into concert_organization_id
  from public.concerts c
  where c.id = requested_concert_id
    and private.is_organization_member(
      c.organization_id,
      (select auth.uid())
    )
  for update;

  if not found then
    raise exception 'Concert inaccessible'
      using errcode = '42501';
  end if;

  if not private.can_edit_maraude_report(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Vous ne pouvez pas modifier ce compte rendu'
      using errcode = '42501';
  end if;

  insert into public.maraude_operational_reports (
    concert_id,
    total_weight_kg,
    estimated_meals,
    comment,
    photo_folder_url,
    last_modified_by
  )
  values (
    requested_concert_id,
    requested_total_weight_kg,
    requested_estimated_meals,
    nullif(btrim(requested_comment), ''),
    nullif(btrim(requested_photo_folder_url), ''),
    (select auth.uid())
  )
  on conflict (concert_id) do update
  set
    total_weight_kg = excluded.total_weight_kg,
    estimated_meals = excluded.estimated_meals,
    comment = excluded.comment,
    photo_folder_url = excluded.photo_folder_url,
    last_modified_by = excluded.last_modified_by;

  if requested_complete then
    update public.concerts
    set
      maraude_status = 'completed'::public.maraude_status,
      actual_start_at = coalesce(actual_start_at, changed_at),
      actual_end_at = greatest(
        changed_at,
        coalesce(actual_start_at, changed_at)
      )
    where id = requested_concert_id;
  end if;
end;
$$;

revoke all on function public.save_maraude_report(
  uuid,
  numeric,
  integer,
  text,
  text,
  boolean
) from public, anon;
grant execute on function public.save_maraude_report(
  uuid,
  numeric,
  integer,
  text,
  text,
  boolean
) to authenticated;

create or replace function public.update_maraude_photo_link(
  requested_concert_id uuid,
  requested_photo_folder_url text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1
    from public.concerts c
    where c.id = requested_concert_id
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
      and (
        private.is_club_sandwich_admin((select auth.uid()))
        or exists (
          select 1
          from public.concert_volunteers cv
          where cv.concert_id = c.id
            and cv.user_id = (select auth.uid())
            and cv.status = 'selected'::public.concert_volunteer_status
            and cv.team_role = 'communication'::public.maraude_role
        )
      )
  ) then
    raise exception 'Vous ne pouvez pas modifier le lien photo'
      using errcode = '42501';
  end if;

  insert into public.maraude_operational_reports (
    concert_id,
    photo_folder_url,
    last_modified_by
  )
  values (
    requested_concert_id,
    nullif(btrim(requested_photo_folder_url), ''),
    (select auth.uid())
  )
  on conflict (concert_id) do update
  set
    photo_folder_url = excluded.photo_folder_url,
    last_modified_by = excluded.last_modified_by;
end;
$$;

revoke all on function public.update_maraude_photo_link(uuid, text)
  from public, anon;
grant execute on function public.update_maraude_photo_link(uuid, text)
  to authenticated;

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
  where private.is_organization_member(
    c.organization_id,
    (select auth.uid())
  )
    and (
      private.is_club_sandwich_admin((select auth.uid()))
      or own_application.id is not null
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
