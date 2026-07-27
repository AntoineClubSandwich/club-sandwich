alter type public.app_role rename value 'coordinator' to 'promoter';

update public.memberships
set role = 'admin'::public.app_role
where role::text = 'super_admin';

alter table public.memberships
  add constraint memberships_supported_role_check
  check (role::text in ('admin', 'promoter', 'volunteer'));

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
      and m.role = 'admin'::public.app_role
  );
$$;

create type public.user_account_status as enum (
  'invited',
  'active',
  'disabled'
);

alter table public.organizations
  add column contact_email text,
  add column phone text,
  add column address text,
  add column website_url text,
  add column notes text,
  add column updated_at timestamptz not null default now();

create table public.organization_contacts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete cascade,
  first_name text not null default '',
  last_name text not null default '',
  job_title text,
  email text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    char_length(btrim(first_name || last_name)) > 0
    or email is not null
    or phone is not null
  )
);

create index organization_contacts_organization_idx
on public.organization_contacts (organization_id, last_name, first_name);

create table public.organization_documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete cascade,
  name text not null check (char_length(btrim(name)) > 0),
  url text not null check (char_length(btrim(url)) > 0),
  created_at timestamptz not null default now()
);

create index organization_documents_organization_idx
on public.organization_documents (organization_id, created_at desc);

create table public.user_accounts (
  profile_id uuid primary key
    references public.profiles(id) on delete cascade,
  role public.app_role not null,
  organization_id uuid
    references public.organizations(id) on delete restrict,
  status public.user_account_status not null default 'invited',
  invited_at timestamptz not null default now(),
  activated_at timestamptz,
  disabled_at timestamptz,
  updated_at timestamptz not null default now(),
  check (role::text in ('admin', 'promoter', 'volunteer')),
  check (
    (role = 'promoter'::public.app_role and organization_id is not null)
    or
    (role <> 'promoter'::public.app_role and organization_id is null)
  ),
  check (
    (status = 'active'::public.user_account_status and activated_at is not null)
    or status <> 'active'::public.user_account_status
  )
);

create index user_accounts_organization_idx
on public.user_accounts (organization_id)
where organization_id is not null;

create index user_accounts_status_idx
on public.user_accounts (status, invited_at desc);

insert into public.user_accounts (
  profile_id,
  role,
  organization_id,
  status,
  invited_at,
  activated_at
)
select
  p.id,
  case
    when exists (
      select 1
      from public.memberships admin_membership
      join public.organizations admin_organization
        on admin_organization.id = admin_membership.organization_id
      where admin_membership.profile_id = p.id
        and admin_membership.role = 'admin'::public.app_role
        and admin_organization.kind =
          'club_sandwich'::public.organization_kind
    ) then 'admin'::public.app_role
    when producer_membership.organization_id is not null
      then 'promoter'::public.app_role
    else 'volunteer'::public.app_role
  end,
  producer_membership.organization_id,
  'active'::public.user_account_status,
  p.created_at,
  p.created_at
from public.profiles p
left join lateral (
  select m.organization_id
  from public.memberships m
  join public.organizations o on o.id = m.organization_id
  where m.profile_id = p.id
    and o.kind = 'producer'::public.organization_kind
  order by m.created_at
  limit 1
) producer_membership on true
on conflict (profile_id) do nothing;

update public.user_accounts
set organization_id = null
where role <> 'promoter'::public.app_role;

create or replace function private.sync_user_account_membership()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_organization_id uuid;
begin
  if new.role = 'promoter'::public.app_role then
    if not exists (
      select 1
      from public.organizations
      where id = new.organization_id
        and kind = 'producer'::public.organization_kind
    ) then
      raise exception 'Un tourneur doit appartenir à une organisation tourneur'
        using errcode = '23514';
    end if;
    target_organization_id := new.organization_id;
  else
    select id
    into target_organization_id
    from public.organizations
    where slug = 'club-sandwich';
  end if;

  delete from public.memberships
  where profile_id = new.profile_id
    and organization_id <> target_organization_id;

  insert into public.memberships (
    organization_id,
    profile_id,
    role
  )
  values (
    target_organization_id,
    new.profile_id,
    new.role
  )
  on conflict (organization_id, profile_id)
  do update set role = excluded.role;

  return new;
end;
$$;

create trigger user_accounts_sync_membership
after insert or update of role, organization_id
on public.user_accounts
for each row execute function private.sync_user_account_membership();

update public.user_accounts
set role = role;

create or replace function private.is_active_user(
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
    from public.user_accounts
    where profile_id = requested_profile_id
      and status = 'active'::public.user_account_status
  );
$$;

create or replace function private.is_promoter_account_member(
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
    from public.user_accounts
    where profile_id = requested_profile_id
      and role = 'promoter'::public.app_role
      and organization_id = requested_organization_id
      and status = 'active'::public.user_account_status
  );
$$;

revoke all on function private.is_active_user(uuid)
  from public, anon, authenticated;
revoke all on function private.is_promoter_account_member(uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.is_active_user(uuid) to authenticated;
grant execute on function private.is_promoter_account_member(uuid, uuid)
  to authenticated;

alter table public.organization_contacts enable row level security;
alter table public.organization_documents enable row level security;
alter table public.user_accounts enable row level security;

create policy "Admins manage organizations"
on public.organizations
for all
to authenticated
using (private.is_club_sandwich_admin((select auth.uid())))
with check (private.is_club_sandwich_admin((select auth.uid())));

create policy "Admins manage organization contacts"
on public.organization_contacts
for all
to authenticated
using (private.is_club_sandwich_admin((select auth.uid())))
with check (private.is_club_sandwich_admin((select auth.uid())));

create policy "Promoters view their organization contacts"
on public.organization_contacts
for select
to authenticated
using (
  private.is_promoter_account_member(
    organization_id,
    (select auth.uid())
  )
);

create policy "Admins manage organization documents"
on public.organization_documents
for all
to authenticated
using (private.is_club_sandwich_admin((select auth.uid())))
with check (private.is_club_sandwich_admin((select auth.uid())));

create policy "Promoters view their organization documents"
on public.organization_documents
for select
to authenticated
using (
  private.is_promoter_account_member(
    organization_id,
    (select auth.uid())
  )
);

create policy "Users view their account"
on public.user_accounts
for select
to authenticated
using (
  profile_id = (select auth.uid())
  or private.is_club_sandwich_admin((select auth.uid()))
);

create policy "Admins manage user accounts"
on public.user_accounts
for all
to authenticated
using (private.is_club_sandwich_admin((select auth.uid())))
with check (private.is_club_sandwich_admin((select auth.uid())));

create policy "Admins view all profiles"
on public.profiles
for select
to authenticated
using (private.is_club_sandwich_admin((select auth.uid())));

create policy "Admins update all profiles"
on public.profiles
for update
to authenticated
using (private.is_club_sandwich_admin((select auth.uid())))
with check (private.is_club_sandwich_admin((select auth.uid())));

revoke all on public.organization_contacts from anon, authenticated;
revoke all on public.organization_documents from anon, authenticated;
revoke all on public.user_accounts from anon, authenticated;
grant select, insert, update, delete on public.organizations to authenticated;
grant select, insert, update, delete
  on public.organization_contacts to authenticated;
grant select, insert, update, delete
  on public.organization_documents to authenticated;
grant select, insert, update, delete on public.user_accounts to authenticated;

create type public.invitation_campaign_status as enum (
  'draft',
  'open',
  'closed',
  'cancelled'
);

create type public.invitation_application_status as enum (
  'pending',
  'selected',
  'not_selected',
  'withdrawn'
);

create table public.invitation_campaigns (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete cascade,
  concert_id uuid references public.concerts(id) on delete set null,
  title text not null check (char_length(btrim(title)) > 0),
  description text,
  available_places integer not null default 0
    check (available_places >= 0),
  application_deadline timestamptz,
  status public.invitation_campaign_status not null default 'draft',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index invitation_campaigns_organization_status_idx
on public.invitation_campaigns (
  organization_id,
  status,
  application_deadline
);

create table public.invitation_applications (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null
    references public.invitation_campaigns(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status public.invitation_application_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (campaign_id, user_id)
);

create index invitation_applications_campaign_status_idx
on public.invitation_applications (campaign_id, status, created_at);

create index invitation_applications_user_idx
on public.invitation_applications (user_id, created_at desc);

alter table public.invitation_campaigns enable row level security;
alter table public.invitation_applications enable row level security;

create policy "Admins manage invitation campaigns"
on public.invitation_campaigns
for all
to authenticated
using (private.is_club_sandwich_admin((select auth.uid())))
with check (private.is_club_sandwich_admin((select auth.uid())));

create policy "Promoters manage their invitation campaigns"
on public.invitation_campaigns
for all
to authenticated
using (
  private.is_promoter_account_member(
    organization_id,
    (select auth.uid())
  )
)
with check (
  created_by = (select auth.uid())
  and private.is_promoter_account_member(
    organization_id,
    (select auth.uid())
  )
);

create policy "Volunteers view open invitation campaigns"
on public.invitation_campaigns
for select
to authenticated
using (
  status = 'open'::public.invitation_campaign_status
  and private.is_active_user((select auth.uid()))
);

create policy "Admins manage invitation applications"
on public.invitation_applications
for all
to authenticated
using (private.is_club_sandwich_admin((select auth.uid())))
with check (private.is_club_sandwich_admin((select auth.uid())));

create policy "Promoters view applications for their campaigns"
on public.invitation_applications
for select
to authenticated
using (
  exists (
    select 1
    from public.invitation_campaigns campaign
    where campaign.id = invitation_applications.campaign_id
      and private.is_promoter_account_member(
        campaign.organization_id,
        (select auth.uid())
      )
  )
);

create policy "Volunteers view their invitation applications"
on public.invitation_applications
for select
to authenticated
using (user_id = (select auth.uid()));

create policy "Volunteers create their invitation applications"
on public.invitation_applications
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and status = 'pending'::public.invitation_application_status
  and exists (
    select 1
    from public.invitation_campaigns campaign
    where campaign.id = invitation_applications.campaign_id
      and campaign.status = 'open'::public.invitation_campaign_status
      and (
        campaign.application_deadline is null
        or campaign.application_deadline >= now()
      )
  )
);

create policy "Volunteers withdraw invitation applications"
on public.invitation_applications
for update
to authenticated
using (
  user_id = (select auth.uid())
  and status = 'pending'::public.invitation_application_status
)
with check (
  user_id = (select auth.uid())
  and status = 'withdrawn'::public.invitation_application_status
);

revoke all on public.invitation_campaigns from anon, authenticated;
revoke all on public.invitation_applications from anon, authenticated;
grant select, insert, update, delete
  on public.invitation_campaigns to authenticated;
grant select, insert, update, delete
  on public.invitation_applications to authenticated;

create or replace function public.get_current_user_context()
returns table (
  profile_id uuid,
  role public.app_role,
  organization_id uuid,
  organization_name text,
  status public.user_account_status
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    account.profile_id,
    account.role,
    account.organization_id,
    organization.name,
    account.status
  from public.user_accounts account
  left join public.organizations organization
    on organization.id = account.organization_id
  where account.profile_id = (select auth.uid());
$$;

create or replace function public.activate_current_user()
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.user_accounts
  set
    status = 'active'::public.user_account_status,
    activated_at = coalesce(activated_at, now()),
    disabled_at = null,
    updated_at = now()
  where profile_id = (select auth.uid())
    and status = 'invited'::public.user_account_status;
$$;

create or replace function public.get_admin_users()
returns table (
  profile_id uuid,
  first_name text,
  last_name text,
  email text,
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

create or replace function public.get_my_volunteer_statistics()
returns table (
  member_since timestamptz,
  maraudes_completed bigint,
  volunteering_hours numeric,
  roles jsonb,
  invitations_obtained bigint,
  collective_weight_kg numeric,
  collective_meals bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with participation as (
    select
      cv.team_role,
      greatest(
        extract(
          epoch from (
            coalesce(c.actual_end_at, c.actual_start_at)
            - c.actual_start_at
          )
        ) / 3600,
        0
      ) as hours,
      report.total_weight_kg,
      report.estimated_meals
    from public.concert_volunteers cv
    join public.concerts c on c.id = cv.concert_id
    left join public.maraude_operational_reports report
      on report.concert_id = c.id
    where cv.user_id = (select auth.uid())
      and cv.status = 'selected'::public.concert_volunteer_status
      and cv.attendance_status = 'present'::public.volunteer_attendance_status
      and c.maraude_status = 'completed'::public.maraude_status
  )
  select
    profile.created_at,
    count(participation.hours)::bigint,
    coalesce(sum(participation.hours), 0)::numeric,
    coalesce(
      jsonb_object_agg(
        participation.team_role::text,
        role_count.total
      ) filter (where participation.team_role is not null),
      '{}'::jsonb
    ),
    (
      select count(*)::bigint
      from public.invitation_applications invitation_application
      where invitation_application.user_id = (select auth.uid())
        and invitation_application.status =
          'selected'::public.invitation_application_status
    ),
    coalesce(sum(participation.total_weight_kg), 0)::numeric,
    coalesce(sum(participation.estimated_meals), 0)::bigint
  from public.profiles profile
  left join participation on true
  left join lateral (
    select count(*)::bigint as total
    from participation same_role
    where same_role.team_role = participation.team_role
  ) role_count on true
  where profile.id = (select auth.uid())
  group by profile.created_at;
$$;

revoke all on function public.get_current_user_context()
  from public, anon;
revoke all on function public.activate_current_user()
  from public, anon;
revoke all on function public.get_admin_users()
  from public, anon;
revoke all on function public.get_my_volunteer_statistics()
  from public, anon;
grant execute on function public.get_current_user_context() to authenticated;
grant execute on function public.activate_current_user() to authenticated;
grant execute on function public.get_admin_users() to authenticated;
grant execute on function public.get_my_volunteer_statistics()
  to authenticated;

comment on table public.user_accounts is
  'Rôle applicatif unique et cycle de vie des comptes Club Sandwich.';
comment on table public.invitation_campaigns is
  'Campagnes de places offertes créées par les tourneurs ou administrateurs.';
comment on table public.invitation_applications is
  'Candidatures bénévoles aux campagnes, attribuées uniquement par un administrateur.';
