drop function if exists public.activate_current_user();

create or replace function public.activate_current_user(
  requested_first_name text,
  requested_last_name text,
  requested_phone text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  caller_id uuid := (select auth.uid());
  normalized_phone text := nullif(btrim(requested_phone), '');
begin
  if caller_id is null then
    raise exception 'Authentification requise' using errcode = '28000';
  end if;
  if char_length(btrim(requested_first_name)) = 0 then
    raise exception 'Le prénom est obligatoire' using errcode = '22023';
  end if;
  if char_length(btrim(requested_last_name)) = 0 then
    raise exception 'Le nom est obligatoire' using errcode = '22023';
  end if;

  update public.user_accounts
  set
    status = 'active'::public.user_account_status,
    activated_at = coalesce(activated_at, now()),
    disabled_at = null,
    updated_at = now()
  where profile_id = caller_id
    and status = 'invited'::public.user_account_status;

  if not found then
    raise exception 'Invitation introuvable ou déjà utilisée'
      using errcode = 'P0002';
  end if;

  update public.profiles
  set
    first_name = btrim(requested_first_name),
    last_name = btrim(requested_last_name),
    phone = normalized_phone
  where id = caller_id;

  if not found then
    raise exception 'Profil introuvable' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.activate_current_user(text, text, text)
  from public, anon;
grant execute on function public.activate_current_user(text, text, text)
  to authenticated;

comment on function public.activate_current_user(text, text, text) is
  'Complète le profil et active atomiquement un compte invité.';
