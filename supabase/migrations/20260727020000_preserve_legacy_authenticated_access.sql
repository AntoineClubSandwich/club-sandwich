create or replace function private.is_active_user(
  requested_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    not exists (
      select 1
      from public.user_accounts
      where profile_id = requested_profile_id
    )
    or exists (
      select 1
      from public.user_accounts
      where profile_id = requested_profile_id
        and status = 'active'::public.user_account_status
    );
$$;

revoke all on function private.is_active_user(uuid)
  from public, anon, authenticated;
grant execute on function private.is_active_user(uuid) to authenticated;

comment on function private.is_active_user(uuid) is
  'Les comptes historiques sans ligne user_accounts restent actifs; '
  'tous les nouveaux comptes administrés possèdent une ligne explicite.';
