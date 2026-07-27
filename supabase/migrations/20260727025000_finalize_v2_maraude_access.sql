create or replace function public.get_concert_creation_context()
returns table (
  user_id uuid,
  organization_id uuid,
  promoter_organization_id uuid
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    account.profile_id,
    club.id,
    case
      when account.role = 'promoter'::public.app_role
        then account.organization_id
      else null::uuid
    end
  from public.user_accounts account
  cross join lateral (
    select organization.id
    from public.organizations organization
    where organization.kind =
      'club_sandwich'::public.organization_kind
    order by organization.created_at
    limit 1
  ) club
  where account.profile_id = (select auth.uid())
    and account.status = 'active'::public.user_account_status
    and account.role in (
      'admin'::public.app_role,
      'promoter'::public.app_role
    );
$$;

drop policy if exists "V2 users view accessible maraudes"
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
      or private.is_selected_maraude_member(id, (select auth.uid()))
    )
  )
);

create policy "Selected volunteers cannot update maraudes"
on public.concerts
for update
to authenticated
using (
  private.is_volunteer_account((select auth.uid()))
  and private.is_selected_maraude_member(id, (select auth.uid()))
)
with check (false);
