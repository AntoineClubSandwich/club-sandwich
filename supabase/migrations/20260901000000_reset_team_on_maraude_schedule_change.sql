-- Bug reported live on preprod: a maraude already had volunteers
-- "positionnés" (status = selected), the admin changed the maraude's
-- date, and nothing reset - the selected volunteers stayed selected
-- (with stale confirmation state) for a maraude that, from their point
-- of view, no longer exists on that date.
--
-- The only trigger on public.concerts was concerts_set_updated_at
-- (bumps updated_at only) - nothing propagated a schedule change to
-- concert_volunteers. This mirrors the pattern already used for a
-- team-role change after confirmation (20260828006000's
-- notify_role_change_requires_reconfirmation), but unselects instead of
-- just re-requesting confirmation: a date change is treated like the
-- team needs to be reconstituted from scratch for the new date.
--
-- Volunteers whose role is locked (team_role_locked, 20260828009000) are
-- deliberately left untouched - that flag exists specifically to protect
-- a settled assignment from being silently reverted by a bulk action.

alter table public.maraude_workflow_events
  drop constraint maraude_workflow_events_event_type_check;

alter table public.maraude_workflow_events
  add constraint maraude_workflow_events_event_type_check
  check (
    event_type in (
      'selection_requested',
      'status_changed',
      'role_changed',
      'confirmation_completed',
      'confirmation_expired',
      'attendance_changed',
      'attendance_corrected',
      'attendance_validated',
      'maraude_started',
      'maraude_completed',
      'credit_awarded',
      'credit_revoked',
      'schedule_changed'
    )
  );

create or replace function private.reset_team_on_maraude_schedule_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor uuid := (select auth.uid());
  application record;
begin
  if new.concert_date is not distinct from old.concert_date
    and new.concert_time is not distinct from old.concert_time
  then
    return new;
  end if;

  if new.maraude_status not in (
    'open'::public.maraude_status,
    'team_ready'::public.maraude_status
  ) then
    return new;
  end if;

  for application in
    select id, user_id
    from public.concert_volunteers
    where concert_id = new.id
      and status = 'selected'::public.concert_volunteer_status
      and not team_role_locked
  loop
    update public.concert_volunteers
    set status = 'pending'::public.concert_volunteer_status
    where id = application.id;

    insert into public.maraude_workflow_events (
      concert_id,
      application_id,
      event_type,
      actor_id,
      previous_value,
      new_value
    )
    values (
      new.id,
      application.id,
      'schedule_changed',
      actor,
      jsonb_build_object(
        'concert_date', old.concert_date,
        'concert_time', old.concert_time,
        'status', 'selected'
      ),
      jsonb_build_object(
        'concert_date', new.concert_date,
        'concert_time', new.concert_time,
        'status', 'pending'
      )
    );

    perform private.notify_user(
      application.user_id,
      new.id,
      'schedule_changed',
      'La date de la maraude a changé',
      format(
        'La maraude "%s" a été déplacée au %s. Votre sélection a été '
        || 'annulée : l’équipe doit être reconstituée pour la nouvelle '
        || 'date.',
        new.artist,
        to_char(new.concert_date, 'DD/MM/YYYY')
      )
    );
  end loop;

  return new;
end;
$$;

revoke all on function private.reset_team_on_maraude_schedule_change()
  from public, anon, authenticated;

create trigger concerts_reset_team_on_schedule_change
after update of concert_date, concert_time on public.concerts
for each row execute function private.reset_team_on_maraude_schedule_change();
