create type public.concert_status as enum (
  'planned',
  'confirmed',
  'completed',
  'cancelled'
);

create table public.concerts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete cascade,
  title text not null check (char_length(trim(title)) > 0),
  artist text not null check (char_length(trim(artist)) > 0),
  tour text,
  concert_date date not null,
  concert_time time not null,
  status public.concert_status not null default 'planned',
  notes text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index concerts_organization_date_idx
  on public.concerts (organization_id, concert_date, concert_time);

alter table public.concerts enable row level security;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function private.set_updated_at() from public;

create trigger concerts_set_updated_at
before update on public.concerts
for each row execute function private.set_updated_at();

create policy "Members can view concerts in their organizations"
on public.concerts
for select
to authenticated
using (
  private.is_organization_member(organization_id, (select auth.uid()))
);

create policy "Members can create concerts in their organizations"
on public.concerts
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and private.is_organization_member(
    organization_id,
    (select auth.uid())
  )
);

create policy "Members can update concerts in their organizations"
on public.concerts
for update
to authenticated
using (
  private.is_organization_member(organization_id, (select auth.uid()))
)
with check (
  private.is_organization_member(organization_id, (select auth.uid()))
);

create policy "Members can delete concerts in their organizations"
on public.concerts
for delete
to authenticated
using (
  private.is_organization_member(organization_id, (select auth.uid()))
);

grant select, insert, delete on public.concerts to authenticated;
grant update (
  title,
  artist,
  tour,
  concert_date,
  concert_time,
  status,
  notes
) on public.concerts to authenticated;
