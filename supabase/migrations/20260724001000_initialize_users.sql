grant select on public.organizations to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select on public.memberships to authenticated;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (
    id,
    first_name,
    last_name,
    phone,
    avatar_url
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    new.raw_user_meta_data ->> 'phone',
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'email'
  ) then
    execute '
      update public.profiles
      set
        email = $2,
        prenom = $3,
        nom = $4,
        telephone = $5
      where id = $1
    '
    using
      new.id,
      coalesce(new.email, ''),
      coalesce(new.raw_user_meta_data ->> 'first_name', ''),
      coalesce(new.raw_user_meta_data ->> 'last_name', ''),
      new.raw_user_meta_data ->> 'phone';
  end if;

  return new;
end;
$$;

revoke all on function private.handle_new_user() from public;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

insert into public.profiles (
  id,
  first_name,
  last_name,
  phone,
  avatar_url,
  created_at
)
select
  id,
  coalesce(raw_user_meta_data ->> 'first_name', ''),
  coalesce(raw_user_meta_data ->> 'last_name', ''),
  raw_user_meta_data ->> 'phone',
  raw_user_meta_data ->> 'avatar_url',
  created_at
from auth.users
on conflict (id) do nothing;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'email'
  ) then
    execute '
      update public.profiles p
      set
        email = case when p.email = '''' then coalesce(u.email, '''') else p.email end,
        prenom = case
          when p.prenom = ''''
          then coalesce(u.raw_user_meta_data ->> ''first_name'', '''')
          else p.prenom
        end,
        nom = case
          when p.nom = ''''
          then coalesce(u.raw_user_meta_data ->> ''last_name'', '''')
          else p.nom
        end
      from auth.users u
      where p.id = u.id
    ';
  end if;
end;
$$;

insert into public.organizations (name, slug)
values ('Club Sandwich', 'club-sandwich')
on conflict (slug) do nothing;

create or replace function private.assign_club_sandwich_admin(
  target_email text
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  target_profile_id uuid;
  club_sandwich_id uuid;
begin
  select id
  into target_profile_id
  from auth.users
  where lower(email) = lower(trim(target_email));

  if target_profile_id is null then
    raise exception 'Aucun utilisateur ne correspond à cette adresse e-mail';
  end if;

  select id
  into club_sandwich_id
  from public.organizations
  where slug = 'club-sandwich';

  insert into public.memberships (
    organization_id,
    profile_id,
    role
  )
  values (
    club_sandwich_id,
    target_profile_id,
    'admin'
  )
  on conflict (organization_id, profile_id)
  do update set role = excluded.role;
end;
$$;

revoke all
on function private.assign_club_sandwich_admin(text)
from public, anon, authenticated;

comment on function private.assign_club_sandwich_admin(text) is
  'À exécuter manuellement depuis le SQL Editor pour affecter un administrateur.';
