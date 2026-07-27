create or replace function public.get_concert_creation_context()
returns table (
  user_id uuid,
  organization_id uuid,
  promoter_organization_id uuid
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  account public.user_accounts%rowtype;
  club_organization_id uuid;
begin
  select *
  into account
  from public.user_accounts
  where profile_id = (select auth.uid())
    and status = 'active'::public.user_account_status;

  if account.profile_id is null
    or account.role not in (
      'admin'::public.app_role,
      'promoter'::public.app_role
    ) then
    raise exception 'Création de maraude non autorisée'
      using errcode = '42501';
  end if;

  select id
  into club_organization_id
  from public.organizations
  where kind = 'club_sandwich'::public.organization_kind
  order by created_at
  limit 1;

  if club_organization_id is null then
    raise exception 'Organisation Club Sandwich introuvable'
      using errcode = 'P0002';
  end if;

  return query
  select
    account.profile_id,
    club_organization_id,
    case
      when account.role = 'promoter'::public.app_role
        then account.organization_id
      else null::uuid
    end;
end;
$$;

revoke all on function public.get_concert_creation_context()
  from public, anon;
grant execute on function public.get_concert_creation_context()
  to authenticated;

drop policy if exists "Authorized members can publish concerts"
  on public.concerts;
create policy "Admins and promoters publish maraudes"
on public.concerts
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and status = 'planned'::public.concert_status
  and exists (
    select 1
    from public.organizations club
    where club.id = concerts.organization_id
      and club.kind = 'club_sandwich'::public.organization_kind
  )
  and (
    (
      private.is_club_sandwich_admin((select auth.uid()))
      and promoter_organization_id is null
    )
    or private.is_promoter_account_member(
      promoter_organization_id,
      (select auth.uid())
    )
  )
);

drop policy if exists "Members can view concerts in their organizations"
  on public.concerts;
drop policy if exists "Members can view accessible concerts"
  on public.concerts;
create policy "V2 users view accessible maraudes"
on public.concerts
for select
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  or private.is_promoter_account_member(
    promoter_organization_id,
    (select auth.uid())
  )
  or (
    private.is_volunteer_account((select auth.uid()))
    and private.is_organization_member(
      organization_id,
      (select auth.uid())
    )
    and (
      maraude_status <> 'completed'::public.maraude_status
      or private.is_present_maraude_member(id, (select auth.uid()))
    )
  )
);

drop policy if exists "Members can update concerts in their organizations"
  on public.concerts;
create policy "Promoters update their maraudes"
on public.concerts
for update
to authenticated
using (
  private.is_promoter_account_member(
    promoter_organization_id,
    (select auth.uid())
  )
)
with check (
  private.is_promoter_account_member(
    promoter_organization_id,
    (select auth.uid())
  )
);

drop policy if exists "Members can delete concerts in their organizations"
  on public.concerts;

comment on function public.get_concert_creation_context() is
  'Retourne le tenant Club Sandwich et, pour un tourneur, son organisation.';
