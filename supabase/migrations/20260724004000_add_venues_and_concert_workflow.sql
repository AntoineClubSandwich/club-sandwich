do $$
begin
  if exists (select 1 from public.concerts) then
    raise exception
      'public.concerts must be empty before adding required venue_id';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'organizations'
      and column_name = 'kind'
  ) and exists (
    select 1
    from public.organizations
    where slug <> 'club-sandwich'
  ) then
    raise exception
      'Existing organizations must be classified explicitly before this migration';
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'organization_kind'
      and (
        t.typtype <> 'e'
        or (
          select array_agg(e.enumlabel::text order by e.enumsortorder)
          from pg_enum e
          where e.enumtypid = t.oid
        ) <> array['club_sandwich', 'producer']
      )
  ) then
    raise exception
      'public.organization_kind exists but is not the expected enum';
  elsif not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'organization_kind'
  ) then
    create type public.organization_kind as enum (
      'club_sandwich',
      'producer'
    );
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'organizations'
      and column_name = 'kind'
      and (
        udt_schema <> 'public'
        or udt_name <> 'organization_kind'
      )
  ) then
    raise exception
      'public.organizations.kind exists with an incompatible type';
  end if;
end;
$$;

alter table public.organizations
  add column if not exists kind public.organization_kind;

update public.organizations
set kind = 'club_sandwich'::public.organization_kind
where slug = 'club-sandwich'
  and kind is distinct from 'club_sandwich'::public.organization_kind;

do $$
begin
  if exists (
    select 1
    from public.organizations
    where kind is null
  ) then
    raise exception
      'Existing organizations must be classified explicitly before this migration';
  end if;
end;
$$;

alter table public.organizations
  alter column kind set default 'producer'::public.organization_kind,
  alter column kind set not null;

create extension if not exists pg_trgm;

create table if not exists public.venues (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) > 0),
  public_address_line1 text not null
    check (char_length(trim(public_address_line1)) > 0),
  public_address_line2 text,
  postal_code text not null check (char_length(trim(postal_code)) > 0),
  city text not null default 'Paris' check (char_length(trim(city)) > 0),
  latitude double precision,
  longitude double precision,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists venues_identity_uidx
  on public.venues (
    lower(name),
    lower(public_address_line1),
    postal_code
  );

create index if not exists venues_name_lower_idx
  on public.venues (lower(name));

create index if not exists venues_name_idx
  on public.venues (name);

create index if not exists venues_active_name_idx
  on public.venues (is_active, name);

create index if not exists venues_name_trgm_idx
  on public.venues using gin (lower(name) gin_trgm_ops);

create table if not exists public.venue_access_details (
  venue_id uuid primary key
    references public.venues(id) on delete cascade,
  artist_entrance_address_line1 text,
  artist_entrance_address_line2 text,
  artist_entrance_postal_code text,
  artist_entrance_city text,
  access_instructions text,
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists venues_set_updated_at on public.venues;
create trigger venues_set_updated_at
before update on public.venues
for each row execute function private.set_updated_at();

drop trigger if exists venue_access_details_set_updated_at
  on public.venue_access_details;
create trigger venue_access_details_set_updated_at
before update on public.venue_access_details
for each row execute function private.set_updated_at();

insert into public.venues (
  name,
  public_address_line1,
  postal_code
)
values
  ('Accor Arena', '8 boulevard de Bercy', '75012'),
  ('Adidas Arena', '56 boulevard Ney', '75018'),
  ('L’Olympia', '28 boulevard des Capucines', '75009'),
  ('Zénith Paris – La Villette', '211 avenue Jean Jaurès', '75019'),
  ('Bataclan', '50 boulevard Voltaire', '75011'),
  ('Le Trianon', '80 boulevard de Rochechouart', '75018'),
  ('Élysée Montmartre', '72 boulevard de Rochechouart', '75018'),
  ('Salle Pleyel', '252 rue du Faubourg Saint-Honoré', '75008'),
  ('Philharmonie de Paris', '221 avenue Jean Jaurès', '75019'),
  ('Cité de la Musique', '221 avenue Jean Jaurès', '75019'),
  ('La Cigale', '120 boulevard Marguerite de Rochechouart', '75018'),
  ('Le Trabendo', '211 avenue Jean Jaurès', '75019'),
  ('Cabaret Sauvage', '59 boulevard Macdonald', '75019'),
  ('Point Éphémère', '200 quai de Valmy', '75010'),
  ('La Maroquinerie', '23 rue Boyer', '75020'),
  ('Café de la Danse', '5 passage Louis-Philippe', '75011'),
  ('New Morning', '7-9 rue des Petites Écuries', '75010'),
  ('Casino de Paris', '16 rue de Clichy', '75009'),
  ('Grand Rex', '1 boulevard Poissonnière', '75002'),
  ('Théâtre du Châtelet', '1 place du Châtelet', '75001'),
  ('Théâtre de la Ville', '2 place du Châtelet', '75004'),
  (
    'Maison de la Radio et de la Musique',
    '116 avenue du Président Kennedy',
    '75016'
  ),
  ('Le Hasard Ludique', '128 avenue de Saint-Ouen', '75018'),
  ('Petit Bain', '7 port de la Gare', '75013'),
  ('La Bellevilloise', '19-21 rue Boyer', '75020'),
  ('La Machine du Moulin Rouge', '90 boulevard de Clichy', '75018'),
  ('Badaboum', '2 bis rue des Taillandiers', '75011'),
  ('Supersonic', '9 rue Biscornet', '75012'),
  ('Alhambra', '21 rue Yves Toudic', '75010'),
  ('Pan Piper', '2-4 impasse Lamier', '75011'),
  ('Bal Blomet', '33 rue Blomet', '75015'),
  ('Duc des Lombards', '42 rue des Lombards', '75001'),
  ('Sunset-Sunside', '60 rue des Lombards', '75001'),
  ('La Petite Halle', '211 avenue Jean Jaurès', '75019'),
  ('360 Paris Music Factory', '32 rue Myrha', '75018'),
  ('Le Flow', '4 port des Invalides', '75007'),
  ('La Flèche d’Or', '102 bis rue de Bagnolet', '75020')
on conflict do nothing;

alter table public.concerts
  alter column title drop not null,
  alter column concert_time drop not null,
  add column if not exists venue_id uuid
    references public.venues(id),
  add column if not exists catering_closes_at time,
  add column if not exists promoter_organization_id uuid
    references public.organizations(id);

alter table public.concerts
  alter column venue_id set not null;

create index if not exists concerts_venue_id_idx
  on public.concerts (venue_id);

create index if not exists concerts_promoter_organization_id_idx
  on public.concerts (promoter_organization_id);

create or replace function private.is_club_sandwich_admin(
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
    from public.memberships m
    join public.organizations o on o.id = m.organization_id
    where m.profile_id = requested_profile_id
      and o.kind = 'club_sandwich'::public.organization_kind
      and m.role in (
        'super_admin'::public.app_role,
        'admin'::public.app_role
      )
  );
$$;

create or replace function private.is_producer_member(
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
    from public.memberships m
    join public.organizations o on o.id = m.organization_id
    where m.organization_id = requested_organization_id
      and m.profile_id = requested_profile_id
      and o.kind = 'producer'::public.organization_kind
  );
$$;

revoke all on function private.is_club_sandwich_admin(uuid) from public;
revoke all on function private.is_producer_member(uuid, uuid) from public;
grant execute on function private.is_club_sandwich_admin(uuid)
  to authenticated;
grant execute on function private.is_producer_member(uuid, uuid)
  to authenticated;

alter table public.venues enable row level security;
alter table public.venue_access_details enable row level security;

create policy "Authenticated users can view available venues"
on public.venues
for select
to authenticated
using (
  is_active
  or private.is_club_sandwich_admin((select auth.uid()))
);

create policy "Club Sandwich admins can create venues"
on public.venues
for insert
to authenticated
with check (
  private.is_club_sandwich_admin((select auth.uid()))
);

create policy "Club Sandwich admins can update venues"
on public.venues
for update
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
)
with check (
  private.is_club_sandwich_admin((select auth.uid()))
);

create policy "Club Sandwich admins can view venue access details"
on public.venue_access_details
for select
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
);

create policy "Club Sandwich admins can create venue access details"
on public.venue_access_details
for insert
to authenticated
with check (
  private.is_club_sandwich_admin((select auth.uid()))
);

create policy "Club Sandwich admins can update venue access details"
on public.venue_access_details
for update
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
)
with check (
  private.is_club_sandwich_admin((select auth.uid()))
);

comment on table public.venue_access_details is
  'Sensitive artist access data. Later, SELECT must be extended to volunteers '
  'assigned to a confirmed team for a concert at the venue.';

drop policy if exists "Members can create concerts in their organizations"
  on public.concerts;

create policy "Authorized members can publish concerts"
on public.concerts
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and status = 'planned'::public.concert_status
  and private.is_organization_member(
    organization_id,
    (select auth.uid())
  )
  and (
    (
      promoter_organization_id is null
      and private.is_club_sandwich_admin((select auth.uid()))
    )
    or (
      promoter_organization_id is not null
      and private.is_producer_member(
        promoter_organization_id,
        (select auth.uid())
      )
    )
  )
);

revoke all on public.venues from anon, authenticated;
revoke all on public.venue_access_details from anon, authenticated;

grant select, insert, update on public.venues to authenticated;
grant select, insert, update on public.venue_access_details to authenticated;

revoke update (
  title,
  artist,
  tour,
  concert_date,
  concert_time,
  status,
  notes
) on public.concerts from authenticated;

grant update (
  title,
  artist,
  tour,
  concert_date,
  concert_time,
  venue_id,
  catering_closes_at,
  notes
) on public.concerts to authenticated;
