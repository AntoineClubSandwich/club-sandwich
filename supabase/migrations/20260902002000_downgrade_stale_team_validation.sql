-- Once an admin validates a team (open -> team_ready), nothing revoked
-- that validation if the team stopped being complete afterwards - a
-- volunteer could still withdraw while team_ready (concert_detail_screen's
-- _canWithdraw explicitly allows it), and a schedule change on a
-- team_ready maraude already resets confirmations (20260901000000) but
-- never touched the maraude's own status. Either way the maraude kept
-- showing "Équipe validée" with a team that no longer met the rule that
-- validation is supposed to guarantee, and the "Démarrer" button stayed
-- visible for the team leader until it failed at the last moment on
-- require_complete_team_before_start.
--
-- One trigger on concert_volunteers, not concerts: it catches every path
-- that can break a validated team's completeness (withdrawal, role
-- change, and the schedule-change reset, since that reset is itself a
-- concert_volunteers update) without duplicating the "3 confirmés dont 1
-- chef" rule anywhere new - it's the same check already enforced by
-- require_complete_team_before_start and set_maraude_status.

create or replace function private.downgrade_stale_team_validation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_maraude_status public.maraude_status;
  confirmed_member_count integer;
  confirmed_leader_count integer;
begin
  select concert.maraude_status
  into current_maraude_status
  from public.concerts concert
  where concert.id = new.concert_id;

  if current_maraude_status is distinct from
    'team_ready'::public.maraude_status
  then
    return new;
  end if;

  select
    count(*),
    count(*) filter (
      where application.team_role = 'team_leader'::public.maraude_role
    )
  into confirmed_member_count, confirmed_leader_count
  from public.concert_volunteers application
  where application.concert_id = new.concert_id
    and application.status = 'selected'::public.concert_volunteer_status
    and application.confirmation_status =
      'confirmed'::public.volunteer_confirmation_status;

  if confirmed_member_count < 3 or confirmed_leader_count <> 1 then
    update public.concerts
    set maraude_status = 'open'::public.maraude_status
    where id = new.concert_id
      and maraude_status = 'team_ready'::public.maraude_status;

    if found then
      insert into public.maraude_workflow_events (
        concert_id,
        event_type,
        actor_id,
        previous_value,
        new_value
      )
      values (
        new.concert_id,
        'status_changed',
        (select auth.uid()),
        jsonb_build_object('status', 'team_ready'),
        jsonb_build_object(
          'status', 'open',
          'reason', 'team_no_longer_complete'
        )
      );
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.downgrade_stale_team_validation()
  from public, anon, authenticated;

create trigger concert_volunteers_downgrade_stale_validation
after update of status, confirmation_status, team_role
on public.concert_volunteers
for each row
execute function private.downgrade_stale_team_validation();
