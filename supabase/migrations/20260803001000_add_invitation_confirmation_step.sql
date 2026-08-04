alter table public.invitation_applications
  add column confirmation_status public.volunteer_confirmation_status,
  add column confirmation_requested_at timestamptz,
  add column confirmation_due_at timestamptz,
  add column confirmation_responded_at timestamptz;

update public.invitation_applications
set
  confirmation_status = 'pending'::public.volunteer_confirmation_status,
  confirmation_requested_at = updated_at,
  confirmation_due_at = updated_at + interval '24 hours'
where status = 'selected'::public.invitation_application_status;

alter table public.invitation_applications
  add constraint invitation_applications_confirmation_requires_selection
  check (
    (
      status = 'selected'::public.invitation_application_status
      and confirmation_status is not null
      and confirmation_requested_at is not null
      and confirmation_due_at is not null
      and (
        confirmation_status =
          'pending'::public.volunteer_confirmation_status
        or (
          confirmation_status =
            'confirmed'::public.volunteer_confirmation_status
          and confirmation_responded_at is not null
        )
      )
    )
    or (
      status <> 'selected'::public.invitation_application_status
      and confirmation_status is null
      and confirmation_requested_at is null
      and confirmation_due_at is null
      and confirmation_responded_at is null
    )
  );

create or replace function private.normalize_invitation_confirmation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status = 'selected'::public.invitation_application_status
    and old.status is distinct from new.status
  then
    new.confirmation_status := 'pending'::public.volunteer_confirmation_status;
    new.confirmation_requested_at := clock_timestamp();
    new.confirmation_due_at := clock_timestamp() + interval '24 hours';
    new.confirmation_responded_at := null;
  elsif new.status <> 'selected'::public.invitation_application_status then
    new.confirmation_status := null;
    new.confirmation_requested_at := null;
    new.confirmation_due_at := null;
    new.confirmation_responded_at := null;
  end if;
  return new;
end;
$$;

revoke all on function private.normalize_invitation_confirmation()
from public, anon, authenticated;

create trigger invitation_applications_normalize_confirmation
before update of status on public.invitation_applications
for each row execute function private.normalize_invitation_confirmation();

create or replace function private.notify_invitation_application_changes()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  campaign_title text;
begin
  if new.status is distinct from old.status then
    select campaign.title into campaign_title
    from public.invitation_campaigns campaign
    where campaign.id = new.campaign_id;

    if new.status = 'selected'::public.invitation_application_status then
      perform private.notify_user(
        new.user_id,
        null,
        'invitation_selected',
        'Invitation attribuée',
        format(
          'Vous avez obtenu une invitation pour « %s ». '
          || 'Confirmez votre participation avant le %s.',
          campaign_title,
          to_char(new.confirmation_due_at, 'DD/MM/YYYY à HH24:MI')
        )
      );
    elsif old.status = 'selected'::public.invitation_application_status
      and new.status = 'not_selected'::public.invitation_application_status
    then
      perform private.notify_user(
        new.user_id,
        null,
        'invitation_not_selected',
        'Invitation non retenue',
        format(
          'Votre invitation pour « %s » n’a pas été confirmée à temps '
          || 'ou a été retirée.',
          campaign_title
        )
      );
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.notify_invitation_application_changes()
from public, anon, authenticated;

create trigger invitation_applications_notify_changes
after update of status on public.invitation_applications
for each row execute function private.notify_invitation_application_changes();

create or replace function public.confirm_invitation_application(
  requested_application_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  applicant_user_id uuid;
  available_credits bigint;
begin
  if not private.is_volunteer_account((select auth.uid())) then
    raise exception 'Compte bénévole actif requis'
      using errcode = '42501';
  end if;

  select application.user_id
  into applicant_user_id
  from public.invitation_applications application
  where application.id = requested_application_id
    and application.user_id = (select auth.uid())
    and application.status =
      'selected'::public.invitation_application_status
    and application.confirmation_status =
      'pending'::public.volunteer_confirmation_status
  for update;

  if not found then
    raise exception 'Aucune invitation à confirmer'
      using errcode = '22023';
  end if;

  select count(*)
  into available_credits
  from (
    select credit.id
    from public.volunteer_credits credit
    where credit.user_id = applicant_user_id
      and credit.status = 'active'
    for update
  ) locked_credits;

  if available_credits < 3 then
    raise exception 'Crédits insuffisants pour confirmer cette invitation'
      using errcode = '22023';
  end if;

  update public.volunteer_credits
  set
    status = 'consumed',
    consumed_by_invitation_application_id = requested_application_id,
    consumed_at = clock_timestamp()
  where id in (
    select credit.id
    from public.volunteer_credits credit
    where credit.user_id = applicant_user_id
      and credit.status = 'active'
    order by credit.awarded_at
    limit 3
  );

  update public.invitation_applications
  set
    confirmation_status = 'confirmed'::public.volunteer_confirmation_status,
    confirmation_responded_at = clock_timestamp(),
    updated_at = now()
  where id = requested_application_id;
end;
$$;

revoke all on function public.confirm_invitation_application(uuid)
from public, anon;
grant execute on function public.confirm_invitation_application(uuid)
to authenticated;

create or replace function private.expire_overdue_invitation_confirmations()
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
    select application.id, application.user_id, application.campaign_id
    from public.invitation_applications application
    where application.status =
        'selected'::public.invitation_application_status
      and application.confirmation_status =
        'pending'::public.volunteer_confirmation_status
      and application.confirmation_due_at <= clock_timestamp()
    for update of application skip locked
  loop
    update public.invitation_applications
    set status = 'not_selected'::public.invitation_application_status
    where id = expired_application.id;

    expired_count := expired_count + 1;
  end loop;

  return expired_count;
end;
$$;

revoke all on function private.expire_overdue_invitation_confirmations()
from public, anon, authenticated;

do $$
declare
  existing_job_id bigint;
begin
  select jobid
  into existing_job_id
  from cron.job
  where jobname = 'expire-invitation-confirmations';

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'expire-invitation-confirmations',
    '*/5 * * * *',
    'select private.expire_overdue_invitation_confirmations();'
  );
end;
$$;
