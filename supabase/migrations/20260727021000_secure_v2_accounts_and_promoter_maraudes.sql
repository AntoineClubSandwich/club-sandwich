create or replace function private.is_organization_member(
  requested_organization_id uuid,
  requested_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    private.is_active_user(requested_profile_id)
    and exists (
      select 1
      from public.memberships
      where organization_id = requested_organization_id
        and profile_id = requested_profile_id
    );
$$;

create or replace function private.is_club_sandwich_admin(
  requested_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    private.is_active_user(requested_profile_id)
    and exists (
      select 1
      from public.memberships m
      join public.organizations o on o.id = m.organization_id
      where m.profile_id = requested_profile_id
        and o.kind = 'club_sandwich'::public.organization_kind
        and m.role = 'admin'::public.app_role
    );
$$;

create or replace function public.get_concert_access(
  requested_concert_id uuid
)
returns table (
  is_admin boolean,
  is_promoter boolean,
  can_view_applications boolean,
  can_manage_concert boolean,
  can_apply boolean
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    private.is_club_sandwich_admin((select auth.uid())),
    private.is_promoter_account_member(
      concert.promoter_organization_id,
      (select auth.uid())
    ),
    private.is_club_sandwich_admin((select auth.uid()))
      or private.is_promoter_account_member(
        concert.promoter_organization_id,
        (select auth.uid())
      ),
    private.is_club_sandwich_admin((select auth.uid()))
      or private.is_promoter_account_member(
        concert.promoter_organization_id,
        (select auth.uid())
      ),
    not private.is_club_sandwich_admin((select auth.uid()))
      and not private.is_promoter_account_member(
        concert.promoter_organization_id,
        (select auth.uid())
      )
      and private.is_organization_member(
        concert.organization_id,
        (select auth.uid())
      )
  from public.concerts concert
  where concert.id = requested_concert_id
    and (
      private.is_club_sandwich_admin((select auth.uid()))
      or private.is_promoter_account_member(
        concert.promoter_organization_id,
        (select auth.uid())
      )
      or exists (
        select 1
        from public.concert_volunteers application
        where application.concert_id = concert.id
          and application.user_id = (select auth.uid())
      )
      or private.is_organization_member(
        concert.organization_id,
        (select auth.uid())
      )
    );
$$;

create or replace function public.get_promoter_concert_applications(
  requested_concert_id uuid
)
returns table (
  id uuid,
  concert_id uuid,
  user_id uuid,
  status public.concert_volunteer_status,
  team_role public.maraude_role,
  attendance_status public.volunteer_attendance_status,
  created_at timestamptz,
  updated_at timestamptz,
  first_name text,
  last_name text,
  avatar_url text,
  total_applications bigint,
  selected_applications bigint,
  not_selected_applications bigint,
  withdrawn_applications bigint,
  last_selected_date date,
  history jsonb
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1
    from public.concerts concert
    where concert.id = requested_concert_id
      and private.is_promoter_account_member(
        concert.promoter_organization_id,
        (select auth.uid())
      )
  ) then
    raise exception 'Maraude inaccessible' using errcode = '42501';
  end if;

  return query
  select
    application.id,
    application.concert_id,
    application.user_id,
    application.status,
    application.team_role,
    application.attendance_status,
    application.created_at,
    application.updated_at,
    profile.first_name,
    profile.last_name,
    profile.avatar_url,
    0::bigint,
    0::bigint,
    0::bigint,
    0::bigint,
    null::date,
    '[]'::jsonb
  from public.concert_volunteers application
  join public.profiles profile on profile.id = application.user_id
  where application.concert_id = requested_concert_id
  order by application.created_at;
end;
$$;

create or replace function public.get_concert_volunteer_counts(
  requested_concert_id uuid
)
returns table (
  application_count bigint,
  selected_count bigint,
  present_count bigint,
  absent_count bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    count(application.id) filter (
      where application.status <>
        'withdrawn'::public.concert_volunteer_status
    ),
    count(application.id) filter (
      where application.status =
        'selected'::public.concert_volunteer_status
    ),
    count(application.id) filter (
      where application.status =
        'selected'::public.concert_volunteer_status
        and application.attendance_status =
          'present'::public.volunteer_attendance_status
    ),
    count(application.id) filter (
      where application.status =
        'selected'::public.concert_volunteer_status
        and application.attendance_status =
          'absent'::public.volunteer_attendance_status
    )
  from public.concerts concert
  left join public.concert_volunteers application
    on application.concert_id = concert.id
  where concert.id = requested_concert_id
    and (
      private.is_club_sandwich_admin((select auth.uid()))
      or private.is_promoter_account_member(
        concert.promoter_organization_id,
        (select auth.uid())
      )
      or exists (
        select 1
        from public.concert_volunteers own_application
        where own_application.concert_id = concert.id
          and own_application.user_id = (select auth.uid())
      )
      or private.is_organization_member(
        concert.organization_id,
        (select auth.uid())
      )
    )
  group by concert.id;
$$;

revoke all on function public.get_concert_access(uuid)
  from public, anon;
revoke all on function public.get_promoter_concert_applications(uuid)
  from public, anon;
revoke all on function public.get_concert_volunteer_counts(uuid)
  from public, anon;
grant execute on function public.get_concert_access(uuid) to authenticated;
grant execute on function public.get_promoter_concert_applications(uuid)
  to authenticated;
grant execute on function public.get_concert_volunteer_counts(uuid)
  to authenticated;

create policy "Active accounts only"
on public.profiles
as restrictive
for all
to authenticated
using (private.is_active_user((select auth.uid())))
with check (private.is_active_user((select auth.uid())));

create policy "Active accounts only"
on public.memberships
as restrictive
for all
to authenticated
using (private.is_active_user((select auth.uid())))
with check (private.is_active_user((select auth.uid())));

create policy "Active accounts only"
on public.concerts
as restrictive
for all
to authenticated
using (private.is_active_user((select auth.uid())))
with check (private.is_active_user((select auth.uid())));

create policy "Active accounts only"
on public.concert_volunteers
as restrictive
for all
to authenticated
using (private.is_active_user((select auth.uid())))
with check (private.is_active_user((select auth.uid())));

create policy "Active accounts only"
on public.invitation_campaigns
as restrictive
for all
to authenticated
using (private.is_active_user((select auth.uid())))
with check (private.is_active_user((select auth.uid())));

create policy "Active accounts only"
on public.invitation_applications
as restrictive
for all
to authenticated
using (private.is_active_user((select auth.uid())))
with check (private.is_active_user((select auth.uid())));
