-- Profile photos are public identity thumbnails displayed to teammates and
-- administrators. Private volunteer documents remain in their own bucket.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-avatars',
  'profile-avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Users upload their own profile avatar"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Users replace their own profile avatar"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Users delete their own profile avatar"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Authenticated users view profile avatars"
on storage.objects
for select
to authenticated
using (bucket_id = 'profile-avatars');

-- Include photos in existing grouped RPC payloads: no query per volunteer.
drop function public.get_admin_users();

create function public.get_admin_users()
returns table (
  profile_id uuid,
  first_name text,
  last_name text,
  email text,
  avatar_url text,
  role public.app_role,
  organization_id uuid,
  organization_name text,
  status public.user_account_status,
  invited_at timestamptz,
  last_sign_in_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Accès administrateur requis' using errcode = '42501';
  end if;

  return query
  select
    account.profile_id,
    profile.first_name,
    profile.last_name,
    auth_user.email::text,
    profile.avatar_url,
    account.role,
    account.organization_id,
    organization.name,
    account.status,
    account.invited_at,
    auth_user.last_sign_in_at
  from public.user_accounts account
  join public.profiles profile on profile.id = account.profile_id
  join auth.users auth_user on auth_user.id = account.profile_id
  left join public.organizations organization
    on organization.id = account.organization_id
  order by profile.last_name, profile.first_name;
end;
$$;

revoke all on function public.get_admin_users() from public, anon;
grant execute on function public.get_admin_users() to authenticated;

drop function public.get_concert_volunteer_roster(uuid);

create function public.get_concert_volunteer_roster(
  requested_concert_id uuid
)
returns table (
  id uuid,
  user_id uuid,
  status public.concert_volunteer_status,
  team_role public.maraude_role,
  first_name text,
  last_name text,
  avatar_url text
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
      and private.is_active_user((select auth.uid()))
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
            or exists (
              select 1
              from public.concert_volunteers own_application
              where own_application.concert_id = concert.id
                and own_application.user_id = (select auth.uid())
            )
          )
        )
      )
  ) then
    raise exception 'Maraude inaccessible' using errcode = '42501';
  end if;

  return query
  select
    application.id,
    application.user_id,
    application.status,
    application.team_role,
    profile.first_name,
    profile.last_name,
    profile.avatar_url
  from public.concert_volunteers application
  join public.profiles profile on profile.id = application.user_id
  where application.concert_id = requested_concert_id
    and application.status <> 'withdrawn'::public.concert_volunteer_status
  order by
    application.status = 'selected'::public.concert_volunteer_status desc,
    profile.last_name,
    profile.first_name;
end;
$$;

revoke all on function public.get_concert_volunteer_roster(uuid)
  from public, anon;
grant execute on function public.get_concert_volunteer_roster(uuid)
  to authenticated;

comment on function public.get_concert_volunteer_roster(uuid) is
  'Liste restreinte (identité publique, avatar, statut et rôle) des '
  'candidatures d’une maraude visible par le bénévole.';

drop function public.get_maraude_attendance(uuid);

create function public.get_maraude_attendance(
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
  perform public.expire_volunteer_confirmations();

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
