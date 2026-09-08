-- Perf follow-up: opening the "Bénévoles" tab of a maraude fired 6
-- separate round-trips from ConcertVolunteerRepository.fetchSection -
-- expire_volunteer_confirmations() awaited alone before anything else,
-- then get_concert_volunteer_counts / get_concert_access /
-- get_current_user_context in parallel, then (conditionally)
-- get_promoter_concert_applications or get_concert_volunteer_team_details,
-- then a plain confirmation-columns select to merge in - vs. the "mode
-- terrain" operation screen's single get_maraude_operation_bundle RPC.
-- This mirrors that pattern: one RPC, built by composing the existing,
-- already-audited functions as sub-selects rather than re-deriving their
-- permission logic, so the visibility rules stay exactly what they were.
--
-- Also folds in two related fixes flagged the same session:
-- - get_current_user_context() was fetched a second time here even
--   though currentUserContextProvider already has it on screen - the
--   bundle returns it once, callers stop double-fetching.
-- - expire_volunteer_confirmations() is a write-side sweep that doesn't
--   belong blocking a read path; it's already invoked from the RPCs that
--   actually need it fresh (select_concert_volunteers,
--   set_volunteer_team_role, confirm_concert_participation) - dropped
--   from here entirely rather than kept as a synchronous prefix. Same
--   reasoning applies to get_maraude_attendance below, which had the
--   same synchronous sweep sitting on its own read path (the "Présences"
--   tab) - removed there too.

create function public.get_concert_volunteer_bundle(
  requested_concert_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  caller_id uuid := (select auth.uid());
  account_profile_id uuid;
  account_role public.app_role;
  account_organization_id uuid;
  account_organization_name text;
  account_status public.user_account_status;
  count_application_count bigint;
  count_selected_count bigint;
  count_present_count bigint;
  count_absent_count bigint;
  access_can_view_applications boolean;
  access_can_manage_concert boolean;
  access_can_apply boolean;
  is_admin_flag boolean;
  is_promoter_flag boolean;
  is_volunteer_flag boolean;
  can_view_applications_flag boolean;
  can_apply_flag boolean;
  can_manage_concert_flag boolean;
  applications jsonb := '[]'::jsonb;
begin
  select profile_id, role, organization_id, organization_name, status
  into
    account_profile_id,
    account_role,
    account_organization_id,
    account_organization_name,
    account_status
  from public.get_current_user_context();

  if not found then
    raise exception 'Compte utilisateur introuvable' using errcode = '22023';
  end if;

  if account_profile_id <> caller_id
    or account_status <> 'active'::public.user_account_status then
    raise exception 'Compte utilisateur inactif' using errcode = '42501';
  end if;

  select
    application_count, selected_count, present_count, absent_count
  into
    count_application_count,
    count_selected_count,
    count_present_count,
    count_absent_count
  from public.get_concert_volunteer_counts(requested_concert_id);

  select can_view_applications, can_manage_concert, can_apply
  into
    access_can_view_applications,
    access_can_manage_concert,
    access_can_apply
  from public.get_concert_access(requested_concert_id);

  is_admin_flag := account_role = 'admin'::public.app_role;
  is_promoter_flag := account_role = 'promoter'::public.app_role;
  is_volunteer_flag := account_role = 'volunteer'::public.app_role;
  can_view_applications_flag :=
    is_admin_flag
    or (is_promoter_flag and coalesce(access_can_view_applications, false));
  can_apply_flag := is_volunteer_flag and coalesce(access_can_apply, false);
  can_manage_concert_flag :=
    is_admin_flag
    or (is_promoter_flag and coalesce(access_can_manage_concert, false));

  if can_view_applications_flag or can_apply_flag then
    if is_promoter_flag then
      select coalesce(jsonb_agg(to_jsonb(candidate)), '[]'::jsonb)
      into applications
      from public.get_promoter_concert_applications(
        requested_concert_id
      ) candidate;
    else
      select coalesce(
        jsonb_agg(
          to_jsonb(candidate) || jsonb_build_object(
            'confirmation_status', confirmation.confirmation_status,
            'confirmation_requested_at',
              confirmation.confirmation_requested_at,
            'confirmation_due_at', confirmation.confirmation_due_at,
            'confirmation_responded_at',
              confirmation.confirmation_responded_at,
            'role_acknowledged_at', confirmation.role_acknowledged_at,
            'attendance_validated_at', confirmation.attendance_validated_at,
            'attendance_validated_by', confirmation.attendance_validated_by,
            'last_modified_by', confirmation.last_modified_by
          )
        ),
        '[]'::jsonb
      )
      into applications
      from public.get_concert_volunteer_team_details(
        requested_concert_id
      ) candidate
      join public.concert_volunteers confirmation
        on confirmation.id = candidate.id;
    end if;
  end if;

  return jsonb_build_object(
    'current_user_id', caller_id,
    'role', account_role,
    'is_admin', is_admin_flag,
    'is_promoter', is_promoter_flag,
    'can_view_applications', can_view_applications_flag,
    'can_manage_concert', can_manage_concert_flag,
    'can_apply', can_apply_flag,
    'counts', jsonb_build_object(
      'application_count', coalesce(count_application_count, 0),
      'selected_count', coalesce(count_selected_count, 0),
      'present_count', coalesce(count_present_count, 0),
      'absent_count', coalesce(count_absent_count, 0)
    ),
    'applications', applications
  );
end;
$$;

revoke all on function public.get_concert_volunteer_bundle(uuid)
  from public, anon;
grant execute on function public.get_concert_volunteer_bundle(uuid)
  to authenticated;

create or replace function public.get_maraude_attendance(
  requested_concert_id uuid
)
returns table (
  application_id uuid,
  user_id uuid,
  display_name text,
  avatar_url text,
  team_role public.maraude_role,
  confirmation_status public.volunteer_confirmation_status,
  attendance_status public.volunteer_attendance_status,
  attendance_validated_at timestamptz,
  attendance_validated_by uuid,
  last_modified_at timestamptz,
  last_modified_by_name text,
  can_validate boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  caller_is_admin boolean :=
    private.is_club_sandwich_admin((select auth.uid()));
  caller_is_leader boolean;
begin
  select exists (
    select 1
    from public.concert_volunteers leader
    where leader.concert_id = requested_concert_id
      and leader.user_id = (select auth.uid())
      and leader.status = 'selected'::public.concert_volunteer_status
      and leader.team_role = 'team_leader'::public.maraude_role
      and leader.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
  )
  into caller_is_leader;

  if not caller_is_admin and not caller_is_leader then
    raise exception 'Accès aux présences refusé' using errcode = '42501';
  end if;

  return query
  select
    application.id,
    application.user_id,
    nullif(btrim(profile.first_name || ' ' || profile.last_name), ''),
    profile.avatar_url,
    application.team_role,
    application.confirmation_status,
    application.attendance_status,
    application.attendance_validated_at,
    application.attendance_validated_by,
    application.updated_at,
    nullif(btrim(modifier.first_name || ' ' || modifier.last_name), ''),
    caller_is_admin
  from public.concert_volunteers application
  join public.profiles profile on profile.id = application.user_id
  left join public.profiles modifier
    on modifier.id = application.last_modified_by
  where application.concert_id = requested_concert_id
    and application.status = 'selected'::public.concert_volunteer_status
  order by
    case
      when application.team_role = 'team_leader'::public.maraude_role
        then 0
      else 1
    end,
    profile.first_name,
    profile.last_name;
end;
$$;

revoke all on function public.get_maraude_attendance(uuid)
  from public, anon;
grant execute on function public.get_maraude_attendance(uuid)
  to authenticated;
