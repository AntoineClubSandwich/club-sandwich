create or replace function private.is_club_sandwich_organization(
  requested_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.organizations
    where id = requested_organization_id
      and kind = 'club_sandwich'::public.organization_kind
  );
$$;

revoke all on function private.is_club_sandwich_organization(uuid)
  from public, anon, authenticated;
grant execute on function private.is_club_sandwich_organization(uuid)
  to authenticated;

drop policy if exists "Admins and promoters publish maraudes"
  on public.concerts;
create policy "Admins and promoters publish maraudes"
on public.concerts
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and status = 'planned'::public.concert_status
  and private.is_club_sandwich_organization(organization_id)
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
