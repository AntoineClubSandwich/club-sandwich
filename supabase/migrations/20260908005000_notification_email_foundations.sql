-- Phase 1 ("fondations") of the notification/email overhaul requested by
-- Antoine. Three infrastructure pieces, no visible change to any existing
-- notification's routing or wording:
--
-- 1. An in-app-only capability: every notify_user() call currently
--    enqueues an email unconditionally (user_notifications_enqueue_email
--    fires on every insert, no way to opt out). That's the prerequisite
--    for most of the spec's per-flow rules ("document validé : notification
--    interne uniquement", etc.) - added here as a send_email flag,
--    defaulting to true so nothing changes yet. Which call sites actually
--    flip it is a follow-up phase, done per flow with its own review.
-- 2. Normalized email subjects: "[Club Sandwich] — {date} — {lieu} —
--    {titre}" for concert-scoped emails, "[Club Sandwich] — {titre}"
--    otherwise. Built in the edge function (French month names need
--    Intl, not Postgres locale-dependent to_char) from structured facts
--    captured here at enqueue time.
-- 3. Those structured facts (artist/date/heure/lieu/adresse) stored on
--    workflow_email_deliveries, reusable by any future email template
--    (the mission-sheet "informations pratiques" block, still to come)
--    without another query per send.

alter table public.user_notifications
  add column send_email boolean not null default true;

alter table public.workflow_email_deliveries
  add column concert_artist text,
  add column concert_date date,
  add column concert_time time,
  add column venue_name text,
  add column venue_address text;

create or replace function private.notify_user(
  requested_user_id uuid,
  requested_concert_id uuid,
  requested_type text,
  requested_title text,
  requested_body text,
  requested_send_email boolean default true
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.user_notifications (
    user_id,
    concert_id,
    notification_type,
    title,
    body,
    send_email
  )
  values (
    requested_user_id,
    requested_concert_id,
    requested_type,
    requested_title,
    requested_body,
    requested_send_email
  );
$$;

revoke all on function private.notify_user(
  uuid, uuid, text, text, text, boolean
) from public, anon, authenticated;

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
  end if;

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
    venue_address
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
    v_venue_address
  )
  on conflict (notification_id) do nothing;
  return new;
end;
$$;

revoke all on function private.enqueue_workflow_email()
from public, anon, authenticated;
