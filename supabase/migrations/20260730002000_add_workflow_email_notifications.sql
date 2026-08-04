create extension if not exists pg_net with schema extensions;

create table public.workflow_email_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null unique
    references public.user_notifications(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  concert_id uuid references public.concerts(id) on delete cascade,
  subject text not null check (char_length(btrim(subject)) > 0),
  body text not null check (char_length(btrim(body)) > 0),
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  claimed_at timestamptz,
  sent_at timestamptz,
  provider_message_id text,
  last_error text,
  created_at timestamptz not null default now()
);

create index workflow_email_deliveries_pending_idx
on public.workflow_email_deliveries (next_attempt_at, created_at)
where status = 'pending';

alter table public.workflow_email_deliveries enable row level security;
revoke all on public.workflow_email_deliveries from anon, authenticated;

create or replace function private.enqueue_workflow_email()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.workflow_email_deliveries (
    notification_id,
    user_id,
    concert_id,
    subject,
    body
  )
  values (
    new.id,
    new.user_id,
    new.concert_id,
    new.title,
    new.body
  )
  on conflict (notification_id) do nothing;
  return new;
end;
$$;

revoke all on function private.enqueue_workflow_email()
from public, anon, authenticated;

create trigger user_notifications_enqueue_email
after insert on public.user_notifications
for each row execute function private.enqueue_workflow_email();

create or replace function private.notify_active_admins(
  requested_concert_id uuid,
  requested_type text,
  requested_title text,
  requested_body text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  admin_account record;
begin
  for admin_account in
    select account.profile_id
    from public.user_accounts account
    where account.role = 'admin'::public.app_role
      and account.status = 'active'::public.user_account_status
  loop
    perform private.notify_user(
      admin_account.profile_id,
      requested_concert_id,
      requested_type,
      requested_title,
      requested_body
    );
  end loop;
end;
$$;

revoke all on function private.notify_active_admins(
  uuid, text, text, text
) from public, anon, authenticated;

create or replace function private.notify_volunteer_application_changes()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  concert_artist text;
begin
  select concert.artist into concert_artist
  from public.concerts concert
  where concert.id = new.concert_id;

  if tg_op = 'INSERT'
    and new.status = 'pending'::public.concert_volunteer_status
  then
    perform private.notify_user(
      new.user_id,
      new.concert_id,
      'application_received',
      'Candidature reçue',
      format(
        'Votre candidature pour la maraude %s a bien été enregistrée.',
        concert_artist
      )
    );
  elsif new.status is distinct from old.status then
    if new.status = 'not_selected'::public.concert_volunteer_status then
      perform private.notify_user(
        new.user_id,
        new.concert_id,
        'application_rejected',
        'Candidature non retenue',
        format(
          'Votre candidature pour la maraude %s n’a pas été retenue.',
          concert_artist
        )
      );
    elsif new.status = 'withdrawn'::public.concert_volunteer_status then
      perform private.notify_active_admins(
        new.concert_id,
        'volunteer_withdrawn',
        'Désistement bénévole',
        format(
          'Un bénévole s’est désisté de la maraude %s.',
          concert_artist
        )
      );
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.notify_volunteer_application_changes()
from public, anon, authenticated;

create trigger concert_volunteers_email_notifications
after insert or update of status on public.concert_volunteers
for each row execute function private.notify_volunteer_application_changes();

create or replace function private.notify_completed_maraude_promoters()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  promoter_account record;
begin
  if new.maraude_status = 'completed'::public.maraude_status
    and old.maraude_status is distinct from new.maraude_status
  then
    for promoter_account in
      select account.profile_id
      from public.user_accounts account
      where account.role = 'promoter'::public.app_role
        and account.status = 'active'::public.user_account_status
        and account.organization_id = new.organization_id
    loop
      perform private.notify_user(
        promoter_account.profile_id,
        new.id,
        'maraude_report_available',
        'Bilan de maraude disponible',
        format(
          'La maraude %s est terminée. Son bilan est disponible.',
          new.artist
        )
      );
    end loop;
  end if;
  return new;
end;
$$;

revoke all on function private.notify_completed_maraude_promoters()
from public, anon, authenticated;

create trigger concerts_email_completion_notification
after update of maraude_status on public.concerts
for each row execute function private.notify_completed_maraude_promoters();

create or replace function private.enqueue_maraude_email_reminders()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  candidate record;
  queued integer := 0;
begin
  for candidate in
    select
      volunteer.user_id,
      volunteer.concert_id,
      concert.artist,
      volunteer.team_role
    from public.concert_volunteers volunteer
    join public.concerts concert on concert.id = volunteer.concert_id
    where concert.concert_date = current_date + 1
      and concert.maraude_status not in (
        'completed'::public.maraude_status,
        'cancelled'::public.maraude_status
      )
      and volunteer.status = 'selected'::public.concert_volunteer_status
      and volunteer.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
      and not exists (
        select 1
        from public.user_notifications notification
        where notification.user_id = volunteer.user_id
          and notification.concert_id = volunteer.concert_id
          and notification.notification_type = 'maraude_tomorrow'
      )
  loop
    perform private.notify_user(
      candidate.user_id,
      candidate.concert_id,
      'maraude_tomorrow',
      'Votre maraude a lieu demain',
      format(
        'Rendez-vous demain pour la maraude %s. Consultez les informations pratiques et votre rôle.',
        candidate.artist
      )
    );
    queued := queued + 1;
  end loop;

  for candidate in
    select concert.id, concert.artist
    from public.concerts concert
    where concert.concert_date = current_date + 1
      and concert.maraude_status not in (
        'completed'::public.maraude_status,
        'cancelled'::public.maraude_status
      )
      and not exists (
        select 1
        from public.concert_volunteers leader
        where leader.concert_id = concert.id
          and leader.status = 'selected'::public.concert_volunteer_status
          and leader.team_role = 'team_leader'::public.maraude_role
          and leader.confirmation_status =
            'confirmed'::public.volunteer_confirmation_status
      )
      and not exists (
        select 1
        from public.user_notifications notification
        where notification.concert_id = concert.id
          and notification.notification_type = 'team_leader_missing'
      )
  loop
    perform private.notify_active_admins(
      candidate.id,
      'team_leader_missing',
      'Chef d’équipe non confirmé',
      format(
        'La maraude %s a lieu demain sans chef d’équipe confirmé.',
        candidate.artist
      )
    );
    queued := queued + 1;
  end loop;
  return queued;
end;
$$;

revoke all on function private.enqueue_maraude_email_reminders()
from public, anon, authenticated;

do $$
declare
  existing_job_id bigint;
begin
  select jobid into existing_job_id
  from cron.job
  where jobname = 'enqueue-maraude-email-reminders';
  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;
  perform cron.schedule(
    'enqueue-maraude-email-reminders',
    '0 8 * * *',
    'select private.enqueue_maraude_email_reminders();'
  );

  select jobid into existing_job_id
  from cron.job
  where jobname = 'dispatch-workflow-emails';
  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;
  perform cron.schedule(
    'dispatch-workflow-emails',
    '* * * * *',
    $job$
      select net.http_post(
        url := 'https://yyqjhncuttwjgqtnzeyb.supabase.co/functions/v1/workflow-email-dispatch',
        headers := '{"Content-Type":"application/json"}'::jsonb,
        body := '{}'::jsonb
      );
    $job$
  );
end;
$$;
