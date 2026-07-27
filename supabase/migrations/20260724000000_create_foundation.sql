create extension if not exists pgcrypto;

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'app_role'
  ) then
    create type public.app_role as enum (
      'super_admin',
      'admin',
      'coordinator',
      'volunteer'
    );
  end if;
end;
$$;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) > 0),
  slug text not null unique check (slug = lower(slug)),
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null,
  last_name text not null,
  phone text,
  avatar_url text,
  created_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists phone text,
  add column if not exists avatar_url text;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'prenom'
  ) then
    execute '
      update public.profiles
      set first_name = prenom
      where first_name is null
    ';
    execute '
      alter table public.profiles
      alter column prenom set default ''''
    ';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'nom'
  ) then
    execute '
      update public.profiles
      set last_name = nom
      where last_name is null
    ';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'telephone'
  ) then
    execute '
      update public.profiles
      set phone = telephone
      where phone is null
    ';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'email'
  ) then
    execute '
      alter table public.profiles
      alter column email set default ''''
    ';
  end if;
end;
$$;

update public.profiles
set
  first_name = coalesce(first_name, ''),
  last_name = coalesce(last_name, '');

alter table public.profiles
  alter column first_name set not null,
  alter column last_name set not null;

create table if not exists public.memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role public.app_role not null default 'volunteer',
  created_at timestamptz not null default now(),
  unique (organization_id, profile_id)
);

create index if not exists memberships_profile_id_idx
  on public.memberships (profile_id);

create index if not exists memberships_organization_id_idx
  on public.memberships (organization_id);

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.memberships enable row level security;

create schema if not exists private;
revoke all on schema private from public;

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
  select exists (
    select 1
    from public.memberships
    where organization_id = requested_organization_id
      and profile_id = requested_profile_id
  );
$$;

revoke all on function private.is_organization_member(uuid, uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.is_organization_member(uuid, uuid)
  to authenticated;

create policy "Members can view their organizations"
on public.organizations
for select
to authenticated
using (private.is_organization_member(id, (select auth.uid())));

create policy "Users can view their own profile"
on public.profiles
for select
to authenticated
using (id = (select auth.uid()));

create policy "Users can insert their own profile"
on public.profiles
for insert
to authenticated
with check (id = (select auth.uid()));

create policy "Users can update their own profile"
on public.profiles
for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create policy "Members can view memberships in their organizations"
on public.memberships
for select
to authenticated
using (
  private.is_organization_member(organization_id, (select auth.uid()))
);
