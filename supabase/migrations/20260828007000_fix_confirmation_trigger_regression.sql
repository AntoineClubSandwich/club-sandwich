-- Corrective migration: the previous migration (20260828006000) rewrote
-- private.normalize_volunteer_confirmation() from an outdated copy of the
-- function (read from an old migration file instead of the actual current
-- database state), dropping confirmation_due_at, role_acknowledged_at,
-- attendance_status reset and last_modified_by handling that a later
-- migration (20260729004000) had already added. This broke the
-- concert_volunteers_confirmation_requires_selection check constraint for
-- every new selection, making "Sélectionner" fail outright.
--
-- It turns out 20260729004000 already reset confirmation to pending on
-- any team_role change (via `or new.team_role is distinct from
-- old.team_role`), so the "role changed after confirmation" gap this
-- session set out to fix didn't actually exist - it just needed
-- set_volunteer_team_role's UPDATE of team_role to keep reaching this
-- trigger, which it already does. This migration restores the correct,
-- complete function and trigger.

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
      new.confirmation_due_at := changed_at + interval '24 hours';
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

revoke all on function private.normalize_volunteer_confirmation()
  from public, anon, authenticated;

drop trigger concert_volunteers_normalize_confirmation
  on public.concert_volunteers;
create trigger concert_volunteers_normalize_confirmation
before insert or update of
  status,
  team_role,
  confirmation_status,
  attendance_status
on public.concert_volunteers
for each row execute function private.normalize_volunteer_confirmation();
