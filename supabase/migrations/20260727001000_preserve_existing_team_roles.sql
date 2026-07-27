-- The preceding team-role migration was applied to the local development
-- database before its backfill was removed. Restore the intended
-- backward-compatible state without changing any application status.
update public.concert_volunteers
set team_role = null
where team_role = 'volunteer'::public.maraude_role;

create or replace function private.normalize_concert_volunteer_role()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status <> 'selected'::public.concert_volunteer_status then
    new.team_role = null;
  end if;

  return new;
end;
$$;

revoke all on function private.normalize_concert_volunteer_role()
  from public;
