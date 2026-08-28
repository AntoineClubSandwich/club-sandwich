-- Wording only: "candidature" reads oddly for something that's actually
-- volunteering, not a competitive job application. Renames user-facing
-- text (notifications, error messages) to "volontariat"/"volontaire" for
-- the maraude volunteer flow, matching the Flutter UI rename. Scoped to
-- maraude volunteering only — the concert invitation/guest-list flow
-- keeps "candidature" (it genuinely is competitive: you apply, you may
-- not get a place).
--
-- Each function body below is copied verbatim from the current live
-- definition (via pg_get_functiondef) with only the flagged strings
-- changed, to avoid the kind of regression this session already hit
-- once by rewriting from a stale migration file instead of live state.

create or replace function private.notify_volunteer_application_changes()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  concert_artist text;
begin
  select concert.artist into concert_artist
  from public.concerts concert
  where concert.id = new.concert_id;

  if tg_op = 'INSERT'
    and new.status = 'pending'::public.concert_volunteer_status
  then
    perform private.notify_user(
      new.user_id,
      new.concert_id,
      'application_received',
      'Volontariat enregistré',
      format(
        'Votre volontariat pour la maraude %s a bien été enregistré.',
        concert_artist
      )
    );
  elsif new.status is distinct from old.status then
    if new.status = 'not_selected'::public.concert_volunteer_status then
      perform private.notify_user(
        new.user_id,
        new.concert_id,
        'application_rejected',
        'Volontariat non retenu',
        format(
          'Votre volontariat pour la maraude %s n’a pas été retenu.',
          concert_artist
        )
      );
    elsif new.status = 'withdrawn'::public.concert_volunteer_status then
      perform private.notify_active_admins(
        new.concert_id,
        'volunteer_withdrawn',
        'Désistement bénévole',
        format(
          'Un bénévole s’est désisté de la maraude %s.',
          concert_artist
        )
      );
    end if;
  end if;
  return new;
end;
$$;

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

  update public.concert_volunteers
  set
    status = 'selected'::public.concert_volunteer_status,
    team_role = coalesce(
      team_role,
      'collection_distribution'::public.maraude_role
    ),
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
  application_status public.concert_volunteer_status;
  concert_maraude_status public.maraude_status;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut constituer une équipe'
      using errcode = '42501';
  end if;

  select
    application.concert_id, application.status, concert.maraude_status
  into
    application_concert_id, application_status, concert_maraude_status
  from public.concert_volunteers application
  join public.concerts concert on concert.id = application.concert_id
  where application.id = requested_application_id
    and private.is_organization_member(
      concert.organization_id,
      (select auth.uid())
    )
  for update of application;

  if application_concert_id is null then
    raise exception 'Volontaire introuvable' using errcode = 'P0002';
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
