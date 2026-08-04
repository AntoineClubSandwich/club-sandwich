create type public.volunteer_confirmation_status as enum (
  'pending',
  'confirmed'
);

alter table public.concert_volunteers
  add column confirmation_status public.volunteer_confirmation_status,
  add column confirmation_requested_at timestamptz,
  add column confirmation_responded_at timestamptz;

update public.concert_volunteers
set
  confirmation_status = 'confirmed'::public.volunteer_confirmation_status,
  confirmation_requested_at = updated_at,
  confirmation_responded_at = updated_at
where status = 'selected'::public.concert_volunteer_status;

alter table public.concert_volunteers
  add constraint concert_volunteers_confirmation_requires_selection
  check (
    (
      status = 'selected'::public.concert_volunteer_status
      and confirmation_status is not null
      and confirmation_requested_at is not null
    )
    or (
      status <> 'selected'::public.concert_volunteer_status
      and confirmation_status is null
      and confirmation_requested_at is null
      and confirmation_responded_at is null
    )
  );

create or replace function private.normalize_volunteer_confirmation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status = 'selected'::public.concert_volunteer_status then
    if tg_op = 'INSERT'
      or old.status is distinct from
        'selected'::public.concert_volunteer_status then
      new.confirmation_status :=
        'pending'::public.volunteer_confirmation_status;
      new.confirmation_requested_at := clock_timestamp();
      new.confirmation_responded_at := null;
    elsif new.confirmation_status is null then
      new.confirmation_status :=
        'pending'::public.volunteer_confirmation_status;
      new.confirmation_requested_at := clock_timestamp();
      new.confirmation_responded_at := null;
    elsif new.confirmation_status =
      'confirmed'::public.volunteer_confirmation_status
      and old.confirmation_status is distinct from
        'confirmed'::public.volunteer_confirmation_status then
      new.confirmation_responded_at := clock_timestamp();
    end if;
  else
    new.confirmation_status := null;
    new.confirmation_requested_at := null;
    new.confirmation_responded_at := null;
  end if;

  return new;
end;
$$;

revoke all on function private.normalize_volunteer_confirmation()
  from public, anon, authenticated;

create trigger concert_volunteers_normalize_confirmation
before insert or update of status, confirmation_status
on public.concert_volunteers
for each row execute function private.normalize_volunteer_confirmation();

create or replace function public.confirm_concert_participation(
  requested_concert_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_volunteer_account((select auth.uid())) then
    raise exception 'Compte bénévole actif requis'
      using errcode = '42501';
  end if;

  update public.concert_volunteers application
  set confirmation_status =
    'confirmed'::public.volunteer_confirmation_status
  where application.concert_id = requested_concert_id
    and application.user_id = (select auth.uid())
    and application.status = 'selected'::public.concert_volunteer_status
    and application.confirmation_status =
      'pending'::public.volunteer_confirmation_status;

  if not found then
    raise exception 'Aucune participation à confirmer'
      using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.confirm_concert_participation(uuid)
  from public, anon;
grant execute on function public.confirm_concert_participation(uuid)
  to authenticated;

create or replace function private.is_selected_maraude_member(
  requested_concert_id uuid,
  requested_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.concert_volunteers application
    where application.concert_id = requested_concert_id
      and application.user_id = requested_user_id
      and application.status =
        'selected'::public.concert_volunteer_status
      and application.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
  );
$$;

revoke all on function private.is_selected_maraude_member(uuid, uuid)
  from public, anon, authenticated;

create or replace function private.can_edit_maraude_report(
  requested_concert_id uuid,
  requested_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    private.is_club_sandwich_admin(requested_user_id)
    or exists (
      select 1
      from public.concert_volunteers application
      where application.concert_id = requested_concert_id
        and application.user_id = requested_user_id
        and application.status =
          'selected'::public.concert_volunteer_status
        and application.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
        and application.team_role = 'team_leader'::public.maraude_role
    );
$$;

revoke all on function private.can_edit_maraude_report(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.update_maraude_photo_link(
  requested_concert_id uuid,
  requested_photo_folder_url text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1
    from public.concerts concert
    where concert.id = requested_concert_id
      and private.is_organization_member(
        concert.organization_id,
        (select auth.uid())
      )
      and (
        private.is_club_sandwich_admin((select auth.uid()))
        or exists (
          select 1
          from public.concert_volunteers application
          where application.concert_id = concert.id
            and application.user_id = (select auth.uid())
            and application.status =
              'selected'::public.concert_volunteer_status
            and application.confirmation_status =
              'confirmed'::public.volunteer_confirmation_status
            and application.team_role =
              'communication'::public.maraude_role
        )
      )
  ) then
    raise exception 'Vous ne pouvez pas modifier le lien photo'
      using errcode = '42501';
  end if;

  insert into public.maraude_operational_reports (
    concert_id,
    photo_folder_url,
    last_modified_by
  )
  values (
    requested_concert_id,
    nullif(btrim(requested_photo_folder_url), ''),
    (select auth.uid())
  )
  on conflict (concert_id) do update
  set
    photo_folder_url = excluded.photo_folder_url,
    last_modified_by = excluded.last_modified_by,
    updated_at = now();
end;
$$;

comment on column public.concert_volunteers.confirmation_status is
  'Double validation du bénévole après sa sélection dans l’équipe.';
