-- Live crash on preprod: expire_overdue_volunteer_confirmations() tries
-- to bump an overdue-and-still-pending selection back to 'pending', but
-- never excludes locked roles - so the moment a locked volunteer's
-- confirmation deadline passes, its UPDATE hits
-- protect_locked_team_role's guard ("Le rôle de ce bénévole est
-- verrouillé...") and raises. That exception aborts the whole loop
-- (no per-row handling), which breaks every caller: the "Équipe" tab
-- calls expire_volunteer_confirmations() as the very first step of
-- every load (concert_volunteer_repository.dart's fetchSection), so it
-- never got past that call - reads as a perpetual loading state - and
-- the */5 * * * * cron job hits the same failure in the background.
--
-- Fix: a locked role is explicitly protected from being silently
-- reverted (that's the whole point of the lock, per 20260828009000) -
-- expiry should leave it alone rather than crash trying to touch it.

create or replace function private.expire_overdue_volunteer_confirmations()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  expired_application record;
  expired_count integer := 0;
begin
  for expired_application in
    select application.id, application.concert_id, application.user_id
    from public.concert_volunteers application
    join public.concerts concert on concert.id = application.concert_id
    where application.status =
        'selected'::public.concert_volunteer_status
      and application.confirmation_status =
        'pending'::public.volunteer_confirmation_status
      and application.confirmation_due_at <= clock_timestamp()
      and not application.team_role_locked
      and concert.maraude_status in (
        'open'::public.maraude_status,
        'team_ready'::public.maraude_status
      )
    for update of application skip locked
  loop
    insert into public.maraude_workflow_events (
      concert_id,
      application_id,
      event_type,
      previous_value,
      new_value
    )
    values (
      expired_application.concert_id,
      expired_application.id,
      'confirmation_expired',
      jsonb_build_object('confirmation', 'pending'),
      jsonb_build_object('status', 'pending')
    );

    update public.concert_volunteers
    set status = 'pending'::public.concert_volunteer_status
    where id = expired_application.id;

    perform private.notify_user(
      expired_application.user_id,
      expired_application.concert_id,
      'confirmation_expired',
      'Délai de confirmation expiré',
      'Votre place a été libérée. Vous pouvez de nouveau être sélectionné.'
    );
    expired_count := expired_count + 1;
  end loop;

  return expired_count;
end;
$$;

revoke all on function private.expire_overdue_volunteer_confirmations()
from public, anon, authenticated;
