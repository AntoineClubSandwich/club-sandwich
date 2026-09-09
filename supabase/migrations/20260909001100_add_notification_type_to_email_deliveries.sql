-- The edge function needs to tell a mission_sheet delivery apart from
-- every other notification type to apply the 9-block email structure
-- only there (per spec section 5, scoped to the 4 role emails) - role_label
-- alone isn't a reliable signal, since other concert+role-scoped types
-- (selection_requested) would also have one.

alter table public.workflow_email_deliveries
  add column notification_type text;

create or replace function private.enqueue_workflow_email()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_artist text;
  v_concert_date date;
  v_concert_time time;
  v_venue_name text;
  v_venue_address text;
  v_first_name text;
  v_role_label text;
begin
  if not new.send_email then
    return new;
  end if;

  if new.concert_id is not null then
    select
      concert.artist,
      concert.concert_date,
      concert.concert_time,
      venue.name,
      nullif(
        btrim(
          concat_ws(
            ', ',
            nullif(
              btrim(
                concat_ws(
                  ' ',
                  venue.public_address_line1,
                  venue.public_address_line2
                )
              ),
              ''
            ),
            nullif(
              btrim(concat_ws(' ', venue.postal_code, venue.city)),
              ''
            )
          )
        ),
        ''
      )
    into v_artist, v_concert_date, v_concert_time, v_venue_name, v_venue_address
    from public.concerts concert
    left join public.venues venue on venue.id = concert.venue_id
    where concert.id = new.concert_id;

    select private.maraude_role_label(volunteer.team_role)
    into v_role_label
    from public.concert_volunteers volunteer
    where volunteer.concert_id = new.concert_id
      and volunteer.user_id = new.user_id
      and volunteer.team_role is not null;
  end if;

  select profile.first_name
  into v_first_name
  from public.profiles profile
  where profile.id = new.user_id;

  insert into public.workflow_email_deliveries (
    notification_id,
    user_id,
    concert_id,
    subject,
    body,
    concert_artist,
    concert_date,
    concert_time,
    venue_name,
    venue_address,
    recipient_first_name,
    role_label,
    notification_type
  )
  values (
    new.id,
    new.user_id,
    new.concert_id,
    new.title,
    new.body,
    v_artist,
    v_concert_date,
    v_concert_time,
    v_venue_name,
    v_venue_address,
    v_first_name,
    v_role_label,
    new.notification_type
  )
  on conflict (notification_id) do nothing;
  return new;
end;
$$;

revoke all on function private.enqueue_workflow_email()
from public, anon, authenticated;
