-- Follow-up audit after the role-lock confirmation fix (20260908001000)
-- found four related guardrail gaps in the same "flag exists but isn't
-- actually consulted" family. Fixes all four:
--
-- 1. Document validation (private.volunteer_has_required_documents) was
--    only ever wired into save_maraude_team, which the live UI stopped
--    calling once team-building became immediate-persistence
--    (20260828006000). select_concert_volunteers/set_volunteer_team_role
--    - the RPCs actually in use - never checked it, so a volunteer with
--    missing/rejected documents could be selected, given a role, locked,
--    and confirmed with no document check ever running.
--
-- 2. confirmation_due_at started its 24h countdown at role assignment,
--    but 20260908001000 made confirming impossible before the role is
--    locked - so a volunteer whose admin was slow to lock could get
--    auto-expired ("Votre place a été libérée") for a delay that was
--    never theirs. The countdown now only starts at lock time; before
--    that, confirmation_due_at is pushed 100 years out so the expiry
--    sweep (which already deliberately skips locked rows, per
--    20260902003000) simply never matches an unlocked one either.
--
-- 3. notify_volunteer_role_locked fired on every unlock->relock, even
--    when nothing about the role actually changed and the volunteer had
--    already confirmed - re-sending "confirm your participation" for a
--    confirmation already given.
--
-- 4. save_maraude_team is dead code (superseded by the two RPCs above)
--    but was still executable by any authenticated admin, bypassing the
--    lock-aware confirmation_due_at handling added here entirely. Revoke
--    its execute grant rather than leaving a second, drifting code path
--    reachable.

-- --- 1. Document validation on the RPCs actually used to build a team ---

create or replace function public.select_concert_volunteers(
  requested_concert_id uuid,
  requested_application_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  requested_count integer;
  matched_count integer;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut constituer une équipe'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.concerts c
    where c.id = requested_concert_id
      and private.is_organization_member(
        c.organization_id,
        (select auth.uid())
      )
  ) then
    raise exception 'Concert inaccessible'
      using errcode = '42501';
  end if;

  select count(distinct application_id)
  into requested_count
  from unnest(requested_application_ids) as application_id;

  if requested_count = 0 then
    raise exception 'Aucun volontaire sélectionné'
      using errcode = '22023';
  end if;

  select count(*)
  into matched_count
  from public.concert_volunteers cv
  where cv.concert_id = requested_concert_id
    and cv.id = any(requested_application_ids)
    and cv.status <> 'withdrawn'::public.concert_volunteer_status;

  if matched_count <> requested_count then
    raise exception 'Un volontaire est invalide ou désisté'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.concert_volunteers cv
    where cv.concert_id = requested_concert_id
      and cv.id = any(requested_application_ids)
      and not private.volunteer_has_required_documents(cv.user_id)
  ) then
    raise exception
      'Un bénévole sélectionné n’a pas tous ses documents validés'
      using errcode = '22023';
  end if;

  update public.concert_volunteers
  set
    status = 'selected'::public.concert_volunteer_status,
    attendance_status = coalesce(
      attendance_status,
      'pending'::public.volunteer_attendance_status
    )
  where concert_id = requested_concert_id
    and id = any(requested_application_ids);
end;
$$;

create or replace function public.set_volunteer_team_role(
  requested_application_id uuid,
  requested_role public.maraude_role
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  application_concert_id uuid;
  application_user_id uuid;
  application_status public.concert_volunteer_status;
  concert_maraude_status public.maraude_status;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut constituer une équipe'
      using errcode = '42501';
  end if;

  select
    application.concert_id,
    application.user_id,
    application.status,
    concert.maraude_status
  into
    application_concert_id,
    application_user_id,
    application_status,
    concert_maraude_status
  from public.concert_volunteers application
  join public.concerts concert on concert.id = application.concert_id
  where application.id = requested_application_id
    and private.is_organization_member(
      concert.organization_id,
      (select auth.uid())
    )
  for update of application;

  if application_concert_id is null then
    raise exception 'Candidature introuvable' using errcode = 'P0002';
  end if;

  if application_status <> 'selected'::public.concert_volunteer_status then
    raise exception
      'Seul un bénévole sélectionné peut recevoir un rôle'
      using errcode = '22023';
  end if;

  if concert_maraude_status not in (
    'open'::public.maraude_status,
    'team_ready'::public.maraude_status
  ) then
    raise exception 'L’équipe de cette maraude n’est plus modifiable'
      using errcode = '22023';
  end if;

  if not private.volunteer_has_required_documents(application_user_id) then
    raise exception
      'Un bénévole sélectionné n’a pas tous ses documents validés'
      using errcode = '22023';
  end if;

  if requested_role = 'team_leader'::public.maraude_role
    and exists (
      select 1
      from public.concert_volunteers other
      where other.concert_id = application_concert_id
        and other.id <> requested_application_id
        and other.status = 'selected'::public.concert_volunteer_status
        and other.team_role = 'team_leader'::public.maraude_role
    )
  then
    raise exception
      'Un autre bénévole est déjà chef d’équipe : retirez-lui ce rôle d’abord'
      using errcode = '23505';
  end if;

  update public.concert_volunteers
  set team_role = requested_role
  where id = requested_application_id;
end;
$$;

-- --- 2. The confirmation deadline starts at lock, not at role assignment ---

create or replace function private.normalize_volunteer_confirmation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  changed_at timestamptz := clock_timestamp();
begin
  if new.status = 'selected'::public.concert_volunteer_status then
    if tg_op = 'INSERT'
      or old.status is distinct from
        'selected'::public.concert_volunteer_status
      or new.team_role is distinct from old.team_role
    then
      new.confirmation_status :=
        'pending'::public.volunteer_confirmation_status;
      new.confirmation_requested_at := changed_at;
      -- Real deadline only starts once the role is locked (see
      -- set_volunteer_role_lock) - a volunteer can't confirm before
      -- then, so a countdown here would just punish a slow admin.
      -- A concrete far-future date rather than 'infinity'::timestamptz:
      -- PostgREST/JSON renders 'infinity' as the string "infinity",
      -- which the Dart client's DateTime.parse can't parse.
      new.confirmation_due_at := changed_at + interval '100 years';
      new.confirmation_responded_at := null;
      new.role_acknowledged_at := null;
      new.attendance_status :=
        'pending'::public.volunteer_attendance_status;
      new.attendance_validated_at := null;
      new.attendance_validated_by := null;
    elsif new.confirmation_status =
      'confirmed'::public.volunteer_confirmation_status
      and old.confirmation_status is distinct from
        'confirmed'::public.volunteer_confirmation_status
    then
      if new.role_acknowledged_at is null then
        raise exception 'La fiche de mission doit être reconnue'
          using errcode = '22023';
      end if;
      new.confirmation_responded_at := changed_at;
    end if;
  else
    new.confirmation_status := null;
    new.confirmation_requested_at := null;
    new.confirmation_due_at := null;
    new.confirmation_responded_at := null;
    new.role_acknowledged_at := null;
    new.attendance_validated_at := null;
    new.attendance_validated_by := null;
  end if;

  new.last_modified_by := (select auth.uid());
  return new;
end;
$$;

create or replace function public.set_volunteer_role_lock(
  requested_application_id uuid,
  requested_locked boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  application_concert_id uuid;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut verrouiller un rôle'
      using errcode = '42501';
  end if;

  select application.concert_id
  into application_concert_id
  from public.concert_volunteers application
  join public.concerts concert on concert.id = application.concert_id
  where application.id = requested_application_id
    and private.is_organization_member(
      concert.organization_id,
      (select auth.uid())
    );

  if application_concert_id is null then
    raise exception 'Volontaire introuvable' using errcode = 'P0002';
  end if;

  update public.concert_volunteers app
  set
    team_role_locked = requested_locked,
    confirmation_due_at = case
      when app.status <> 'selected'::public.concert_volunteer_status
        then app.confirmation_due_at
      when requested_locked
        then clock_timestamp() + interval '24 hours'
      else clock_timestamp() + interval '100 years'
    end
  where app.id = requested_application_id;
end;
$$;

revoke all on function public.set_volunteer_role_lock(uuid, boolean)
  from public, anon;
grant execute on function public.set_volunteer_role_lock(uuid, boolean)
  to authenticated;

-- --- 3. Don't re-notify a relock that didn't actually change anything ---

create or replace function private.notify_volunteer_role_locked()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  concert_artist text;
  role_label text;
begin
  if new.team_role_locked is not true
    or old.team_role_locked is true
    or new.status <> 'selected'::public.concert_volunteer_status
    or new.team_role is null
    or new.confirmation_status =
      'confirmed'::public.volunteer_confirmation_status
  then
    return new;
  end if;

  select concert.artist into concert_artist
  from public.concerts concert
  where concert.id = new.concert_id;

  role_label := case new.team_role
    when 'team_leader'::public.maraude_role then 'chef.fe d’équipe'
    when 'communication'::public.maraude_role
      then 'chargé.e de communication'
    when 'logistics'::public.maraude_role then 'chargé.e de logistique'
    when 'collection_distribution'::public.maraude_role
      then 'chargé.e de récolte et distribution'
    else 'non attribué'
  end;

  perform private.notify_user(
    new.user_id,
    new.concert_id,
    'selection_requested',
    'Vous êtes sélectionné',
    format(
      'Votre rôle pour la maraude %s est confirmé : %s. '
      || 'Confirmez votre participation et prenez connaissance de votre '
      || 'fiche de mission.',
      concert_artist,
      role_label
    )
  );

  return new;
end;
$$;

-- --- 4. Retire the superseded, lock-unaware bulk-save RPC ---

revoke execute on function public.save_maraude_team(uuid, jsonb)
  from authenticated;
