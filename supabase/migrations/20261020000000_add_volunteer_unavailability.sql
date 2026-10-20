-- Demande d'Antoine (2026-10-20) : un bénévole peut déjà se positionner sur
-- une maraude ("Je me propose"), mais rien ne distinguait "n'a pas encore
-- répondu" de "sait déjà qu'il ne viendra pas". On ajoute une indisponibilité
-- explicite, visible uniquement par les admins et le tourneur de la maraude.
--
-- Table séparée plutôt qu'un nouveau statut de concert_volunteers : une
-- quinzaine de triggers y sont branchés (compteurs, notifications, rôles,
-- double réservation, taux de désistement...). Une indisponibilité ne doit
-- rien déclencher de tout ça, ni gonfler le nombre de volontaires, ni
-- compter comme un désistement dans les statistiques du bénévole.
--
-- Règles :
-- - écriture uniquement via set_concert_unavailability (security definer),
--   pendant la fenêtre de candidature (maraude open / team_ready), par un
--   compte bénévole membre de l'organisation de la maraude ;
-- - exclusive d'une candidature : impossible de se dire indisponible avec
--   une candidature existante (le bouton "Je me désiste" couvre ce cas), et
--   se proposer ensuite efface l'indisponibilité (trigger ci-dessous) ;
-- - lecture via get_concert_volunteer_bundle : `is_unavailable` pour le
--   bénévole lui-même, `unavailable_volunteers` pour qui peut voir les
--   candidatures (admin, tourneur de la maraude).

create table public.concert_volunteer_unavailabilities (
  id uuid primary key default gen_random_uuid(),
  concert_id uuid not null references public.concerts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (concert_id, user_id)
);

create index concert_volunteer_unavailabilities_user_id_idx
  on public.concert_volunteer_unavailabilities (user_id);

-- Écriture uniquement via les fonctions security definer ci-dessous. En
-- lecture directe, chacun ne voit que ses propres lignes : c'est ce qui
-- alimente le badge "Pas dispo" des listes et du calendrier de maraudes.
alter table public.concert_volunteer_unavailabilities enable row level security;

revoke all on public.concert_volunteer_unavailabilities from anon, authenticated;
grant select on public.concert_volunteer_unavailabilities to authenticated;

create policy "Volunteers view their own unavailabilities"
on public.concert_volunteer_unavailabilities
for select
to authenticated
using (user_id = (select auth.uid()));

create function public.set_concert_unavailability(
  requested_concert_id uuid,
  requested_unavailable boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  caller_id uuid := (select auth.uid());
begin
  if caller_id is null or not private.is_volunteer_account(caller_id) then
    raise exception 'Seuls les bénévoles peuvent indiquer leur disponibilité'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.concerts concert
    where concert.id = requested_concert_id
      and concert.maraude_status in (
        'open'::public.maraude_status,
        'team_ready'::public.maraude_status
      )
      and private.is_organization_member(concert.organization_id, caller_id)
  ) then
    raise exception 'Cette maraude n’accepte plus de réponse'
      using errcode = '22023';
  end if;

  if not requested_unavailable then
    delete from public.concert_volunteer_unavailabilities
    where concert_id = requested_concert_id
      and user_id = caller_id;
    return;
  end if;

  if exists (
    select 1
    from public.concert_volunteers application
    where application.concert_id = requested_concert_id
      and application.user_id = caller_id
  ) then
    raise exception 'Vous avez déjà répondu à cette maraude'
      using errcode = '22023';
  end if;

  insert into public.concert_volunteer_unavailabilities (concert_id, user_id)
  values (requested_concert_id, caller_id)
  on conflict (concert_id, user_id) do nothing;
end;
$$;

revoke all on function public.set_concert_unavailability(uuid, boolean)
  from public, anon;
grant execute on function public.set_concert_unavailability(uuid, boolean)
  to authenticated;

-- Se proposer après s'être dit indisponible : la candidature l'emporte.
create function private.clear_unavailability_on_application()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.concert_volunteer_unavailabilities
  where concert_id = new.concert_id
    and user_id = new.user_id;
  return new;
end;
$$;

revoke all on function private.clear_unavailability_on_application()
  from public, anon, authenticated;

create trigger concert_volunteers_clear_unavailability
after insert on public.concert_volunteers
for each row
execute function private.clear_unavailability_on_application();

-- Même corps que 20260908003000_bundle_volunteer_section_fetch.sql, avec en
-- plus `is_unavailable` et `unavailable_volunteers`.
create or replace function public.get_concert_volunteer_bundle(
  requested_concert_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  caller_id uuid := (select auth.uid());
  account_profile_id uuid;
  account_role public.app_role;
  account_organization_id uuid;
  account_organization_name text;
  account_status public.user_account_status;
  count_application_count bigint;
  count_selected_count bigint;
  count_present_count bigint;
  count_absent_count bigint;
  access_can_view_applications boolean;
  access_can_manage_concert boolean;
  access_can_apply boolean;
  is_admin_flag boolean;
  is_promoter_flag boolean;
  is_volunteer_flag boolean;
  can_view_applications_flag boolean;
  can_apply_flag boolean;
  can_manage_concert_flag boolean;
  applications jsonb := '[]'::jsonb;
  is_unavailable_flag boolean := false;
  unavailable_volunteers jsonb := '[]'::jsonb;
begin
  select profile_id, role, organization_id, organization_name, status
  into
    account_profile_id,
    account_role,
    account_organization_id,
    account_organization_name,
    account_status
  from public.get_current_user_context();

  if not found then
    raise exception 'Compte utilisateur introuvable' using errcode = '22023';
  end if;

  if account_profile_id <> caller_id
    or account_status <> 'active'::public.user_account_status then
    raise exception 'Compte utilisateur inactif' using errcode = '42501';
  end if;

  select
    application_count, selected_count, present_count, absent_count
  into
    count_application_count,
    count_selected_count,
    count_present_count,
    count_absent_count
  from public.get_concert_volunteer_counts(requested_concert_id);

  select can_view_applications, can_manage_concert, can_apply
  into
    access_can_view_applications,
    access_can_manage_concert,
    access_can_apply
  from public.get_concert_access(requested_concert_id);

  is_admin_flag := account_role = 'admin'::public.app_role;
  is_promoter_flag := account_role = 'promoter'::public.app_role;
  is_volunteer_flag := account_role = 'volunteer'::public.app_role;
  can_view_applications_flag :=
    is_admin_flag
    or (is_promoter_flag and coalesce(access_can_view_applications, false));
  can_apply_flag := is_volunteer_flag and coalesce(access_can_apply, false);
  can_manage_concert_flag :=
    is_admin_flag
    or (is_promoter_flag and coalesce(access_can_manage_concert, false));

  if can_view_applications_flag or can_apply_flag then
    if is_promoter_flag then
      select coalesce(jsonb_agg(to_jsonb(candidate)), '[]'::jsonb)
      into applications
      from public.get_promoter_concert_applications(
        requested_concert_id
      ) candidate;
    else
      select coalesce(
        jsonb_agg(
          to_jsonb(candidate) || jsonb_build_object(
            'confirmation_status', confirmation.confirmation_status,
            'confirmation_requested_at',
              confirmation.confirmation_requested_at,
            'confirmation_due_at', confirmation.confirmation_due_at,
            'confirmation_responded_at',
              confirmation.confirmation_responded_at,
            'role_acknowledged_at', confirmation.role_acknowledged_at,
            'attendance_validated_at', confirmation.attendance_validated_at,
            'attendance_validated_by', confirmation.attendance_validated_by,
            'last_modified_by', confirmation.last_modified_by
          )
        ),
        '[]'::jsonb
      )
      into applications
      from public.get_concert_volunteer_team_details(
        requested_concert_id
      ) candidate
      join public.concert_volunteers confirmation
        on confirmation.id = candidate.id;
    end if;
  end if;

  if can_apply_flag then
    select exists (
      select 1
      from public.concert_volunteer_unavailabilities unavailability
      where unavailability.concert_id = requested_concert_id
        and unavailability.user_id = caller_id
    )
    into is_unavailable_flag;
  end if;

  if can_view_applications_flag then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'user_id', unavailability.user_id,
          'first_name', profile.first_name,
          'last_name', profile.last_name,
          'avatar_url', profile.avatar_url,
          'created_at', unavailability.created_at
        )
        order by profile.first_name, profile.last_name
      ),
      '[]'::jsonb
    )
    into unavailable_volunteers
    from public.concert_volunteer_unavailabilities unavailability
    join public.profiles profile on profile.id = unavailability.user_id
    where unavailability.concert_id = requested_concert_id;
  end if;

  return jsonb_build_object(
    'current_user_id', caller_id,
    'role', account_role,
    'is_admin', is_admin_flag,
    'is_promoter', is_promoter_flag,
    'can_view_applications', can_view_applications_flag,
    'can_manage_concert', can_manage_concert_flag,
    'can_apply', can_apply_flag,
    'counts', jsonb_build_object(
      'application_count', coalesce(count_application_count, 0),
      'selected_count', coalesce(count_selected_count, 0),
      'present_count', coalesce(count_present_count, 0),
      'absent_count', coalesce(count_absent_count, 0)
    ),
    'applications', applications,
    'is_unavailable', is_unavailable_flag,
    'unavailable_volunteers', unavailable_volunteers
  );
end;
$$;
