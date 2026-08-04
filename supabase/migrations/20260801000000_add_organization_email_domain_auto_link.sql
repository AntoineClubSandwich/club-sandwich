alter table public.organizations
  add column if not exists email_domain text;

alter table public.organizations
  add constraint organizations_email_domain_is_lowercase
  check (email_domain = lower(email_domain));

alter table public.organizations
  add constraint organizations_email_domain_looks_like_a_domain
  check (
    email_domain is null
    or (
      email_domain !~ '[@\s]'
      and email_domain ~ '^[a-z0-9.-]+\.[a-z]{2,}$'
    )
  );

alter table public.organizations
  add constraint organizations_email_domain_only_for_promoters
  check (email_domain is null or kind = 'producer'::public.organization_kind);

create unique index organizations_email_domain_key
on public.organizations (email_domain)
where email_domain is not null;

comment on column public.organizations.email_domain is
  'Domaine e-mail (ex. "auguri.fr") utilisé pour pré-sélectionner cette '
  'organisation Tourneur à l’invitation d’un compte dont l’adresse '
  'correspond. Renseigné manuellement par un administrateur.';

-- Auto-crée la fiche contact d’un Tourneur à son activation, si son
-- organisation n’en a pas déjà une pour son adresse e-mail.
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
  caller_email text;
  target_organization_id uuid;
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
    and status = 'invited'::public.user_account_status
  returning organization_id into target_organization_id;

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

  if target_organization_id is not null then
    select users.email
    into caller_email
    from auth.users
    where users.id = caller_id;

    if caller_email is not null and not exists (
      select 1
      from public.organization_contacts contact
      where contact.organization_id = target_organization_id
        and lower(contact.email) = lower(caller_email)
    ) then
      insert into public.organization_contacts (
        organization_id,
        first_name,
        last_name,
        email,
        phone
      )
      values (
        target_organization_id,
        btrim(requested_first_name),
        btrim(requested_last_name),
        caller_email,
        normalized_phone
      );
    end if;
  end if;
end;
$$;

revoke all on function public.activate_current_user(text, text, text)
  from public, anon;
grant execute on function public.activate_current_user(text, text, text)
  to authenticated;

comment on function public.activate_current_user(text, text, text) is
  'Complète le profil et active atomiquement un compte invité, et crée '
  'automatiquement sa fiche contact dans son organisation si elle '
  'n’existe pas déjà.';
