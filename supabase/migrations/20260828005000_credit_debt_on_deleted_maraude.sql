-- Deleting a maraude cascades and destroys every volunteer_credits row
-- tied to it (via concert_volunteers -> volunteer_credits on delete
-- cascade), with zero distinction between a credit that was never used
-- and one already spent (status = 'consumed') on a confirmed invitation.
-- The latter case must not just silently vanish: the volunteer already
-- received the invitation, so removing the maraude that backed one of
-- its 3 required credits should leave a trace and put them one credit
-- short, not erase the fact they owe it.
--
-- Adds a 'debt' status: a -1 adjustment row, detached from any concert
-- (concert_id/application_id nullable), inserted for every consumed
-- credit right before its source concert (and therefore its
-- concert_volunteers row) gets deleted. Balance can go negative until
-- the volunteer earns enough credits to cover it.

alter table public.volunteer_credits
  alter column concert_id drop not null,
  alter column application_id drop not null,
  add column note text;

alter table public.volunteer_credits
  drop constraint volunteer_credits_status_check;
alter table public.volunteer_credits
  add constraint volunteer_credits_status_check
  check (status in ('active', 'consumed', 'revoked', 'debt'));

alter table public.volunteer_credits
  drop constraint volunteer_credits_check;
alter table public.volunteer_credits
  add constraint volunteer_credits_check
  check (
    (
      status = 'active'
      and concert_id is not null
      and application_id is not null
      and revoked_by is null
      and revoked_at is null
      and consumed_by_invitation_application_id is null
      and consumed_at is null
    )
    or (
      status = 'consumed'
      and concert_id is not null
      and application_id is not null
      and revoked_by is null
      and revoked_at is null
      and consumed_by_invitation_application_id is not null
      and consumed_at is not null
    )
    or (
      status = 'revoked'
      and revoked_at is not null
    )
    or (
      status = 'debt'
      and concert_id is null
      and application_id is null
      and revoked_by is null
      and revoked_at is null
      and consumed_by_invitation_application_id is null
      and consumed_at is null
    )
  );

create or replace function private.volunteer_credit_count(
  requested_user_id uuid
)
returns bigint
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    count(*) filter (where credit.status = 'active')::bigint
    - count(*) filter (where credit.status = 'debt')::bigint
  from public.volunteer_credits credit
  where credit.user_id = requested_user_id;
$$;

create or replace function public.get_my_volunteer_credit_summary()
returns table (
  earned bigint,
  consumed bigint,
  available bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    count(*) filter (
      where credit.status in ('active', 'consumed')
    )::bigint as earned,
    count(*) filter (where credit.status = 'consumed')::bigint as consumed,
    (
      count(*) filter (where credit.status = 'active')::bigint
      - count(*) filter (where credit.status = 'debt')::bigint
    ) as available
  from public.volunteer_credits credit
  where credit.user_id = (select auth.uid());
$$;

create or replace function public.delete_concert(
  requested_concert_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut supprimer une maraude'
      using errcode = '42501';
  end if;

  perform 1
  from public.concerts
  where id = requested_concert_id
  for update;

  if not found then
    raise exception 'Maraude introuvable ou déjà supprimée'
      using errcode = 'P0002';
  end if;

  insert into public.volunteer_credits (
    user_id, status, awarded_by, awarded_at, note
  )
  select
    credit.user_id,
    'debt',
    (select auth.uid()),
    clock_timestamp(),
    format(
      'Maraude supprimée alors que ce crédit (obtenu le %s) était déjà '
      'utilisé pour une invitation confirmée.',
      to_char(credit.awarded_at, 'DD/MM/YYYY')
    )
  from public.volunteer_credits credit
  where credit.concert_id = requested_concert_id
    and credit.status = 'consumed';

  update public.invitation_campaigns
  set concert_id = null
  where concert_id = requested_concert_id;

  delete from public.maraude_messages
  where concert_id = requested_concert_id;

  delete from public.maraude_distributions
  where concert_id = requested_concert_id;

  delete from public.maraude_operational_reports
  where concert_id = requested_concert_id;

  delete from public.maraude_collections
  where concert_id = requested_concert_id;

  delete from public.concert_volunteers
  where concert_id = requested_concert_id;

  delete from public.concerts
  where id = requested_concert_id;
end;
$$;
