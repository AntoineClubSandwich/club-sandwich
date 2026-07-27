create type public.collection_category as enum (
  'prepared_meals',
  'fruits_vegetables',
  'bakery',
  'dairy',
  'groceries',
  'drinks',
  'other'
);

create type public.collection_unit as enum (
  'kg',
  'crate',
  'box',
  'bag',
  'piece',
  'other'
);

create table public.maraude_collections (
  id uuid primary key default gen_random_uuid(),
  concert_id uuid not null
    references public.concerts(id) on delete cascade,
  category public.collection_category not null,
  description text,
  quantity numeric not null
    check (quantity > 0),
  unit public.collection_unit not null,
  weight_kg numeric
    check (weight_kg >= 0),
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index maraude_collections_concert_created_idx
  on public.maraude_collections (concert_id, created_at);

create trigger maraude_collections_set_updated_at
before update on public.maraude_collections
for each row execute function private.set_updated_at();

create or replace function private.enforce_collection_during_maraude()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  requested_concert_id uuid;
  current_status public.maraude_status;
begin
  requested_concert_id = case
    when tg_op = 'DELETE' then old.concert_id
    else new.concert_id
  end;

  select c.maraude_status
  into current_status
  from public.concerts c
  where c.id = requested_concert_id
  for key share;

  if not found then
    raise exception 'Concert introuvable'
      using errcode = '23503';
  end if;

  if current_status <> 'started'::public.maraude_status then
    raise exception 'La collecte est modifiable uniquement pendant la maraude'
      using errcode = '22023';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_collection_during_maraude()
  from public;

create trigger maraude_collections_enforce_active_maraude
before insert or update or delete
on public.maraude_collections
for each row execute function private.enforce_collection_during_maraude();

alter table public.maraude_collections enable row level security;

create policy "Maraude members can view collections"
on public.maraude_collections
for select
to authenticated
using (
  exists (
    select 1
    from public.concert_volunteers cv
    where cv.concert_id = maraude_collections.concert_id
      and cv.user_id = (select auth.uid())
      and cv.status = 'selected'::public.concert_volunteer_status
  )
);

create policy "Club Sandwich admins can view collections"
on public.maraude_collections
for select
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  and exists (
    select 1
    from public.concerts c
    where c.id = maraude_collections.concert_id
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  )
);

create policy "Club Sandwich admins can create collections"
on public.maraude_collections
for insert
to authenticated
with check (
  private.is_club_sandwich_admin((select auth.uid()))
  and exists (
    select 1
    from public.concerts c
    where c.id = maraude_collections.concert_id
      and c.maraude_status = 'started'::public.maraude_status
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  )
);

create policy "Club Sandwich admins can update collections"
on public.maraude_collections
for update
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  and exists (
    select 1
    from public.concerts c
    where c.id = maraude_collections.concert_id
      and c.maraude_status = 'started'::public.maraude_status
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  )
)
with check (
  private.is_club_sandwich_admin((select auth.uid()))
  and exists (
    select 1
    from public.concerts c
    where c.id = maraude_collections.concert_id
      and c.maraude_status = 'started'::public.maraude_status
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  )
);

create policy "Club Sandwich admins can delete collections"
on public.maraude_collections
for delete
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  and exists (
    select 1
    from public.concerts c
    where c.id = maraude_collections.concert_id
      and c.maraude_status = 'started'::public.maraude_status
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  )
);

revoke all on public.maraude_collections from anon, authenticated;
grant select, insert, update, delete on public.maraude_collections
  to authenticated;
