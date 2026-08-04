create extension if not exists pg_cron with schema pg_catalog;

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

create or replace function public.expire_volunteer_confirmations()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_active_user((select auth.uid())) then
    raise exception 'Compte actif requis' using errcode = '42501';
  end if;

  return private.expire_overdue_volunteer_confirmations();
end;
$$;

do $$
declare
  existing_job_id bigint;
begin
  select jobid
  into existing_job_id
  from cron.job
  where jobname = 'expire-volunteer-confirmations';

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'expire-volunteer-confirmations',
    '*/5 * * * *',
    'select private.expire_overdue_volunteer_confirmations();'
  );
end;
$$;
