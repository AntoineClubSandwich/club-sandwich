-- Web Push notifications: lets a volunteer/tourneur/admin install the app
-- (PWA) and receive real device notifications instead of relying on
-- email/in-app only. Mirrors the existing workflow_email_deliveries queue
-- pattern exactly (private.notify_user -> user_notifications insert ->
-- trigger enqueues a delivery row -> a per-minute cron job dispatches it),
-- so every notification type already wired to email gets push for free.

create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  endpoint text not null,
  p256dh text not null,
  auth_key text not null,
  created_at timestamptz not null default now(),
  last_used_at timestamptz,
  unique (user_id, endpoint)
);

create index push_subscriptions_user_idx
on public.push_subscriptions (user_id);

alter table public.push_subscriptions enable row level security;

create policy "Users manage their own push subscriptions"
on public.push_subscriptions
for all
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create table public.workflow_push_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null unique
    references public.user_notifications(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  concert_id uuid references public.concerts(id) on delete cascade,
  title text not null check (char_length(btrim(title)) > 0),
  body text not null check (char_length(btrim(body)) > 0),
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'failed', 'skipped')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  claimed_at timestamptz,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);

create index workflow_push_deliveries_pending_idx
on public.workflow_push_deliveries (next_attempt_at, created_at)
where status = 'pending';

alter table public.workflow_push_deliveries enable row level security;
revoke all on public.workflow_push_deliveries from anon, authenticated;

create or replace function private.enqueue_workflow_push()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.workflow_push_deliveries (
    notification_id,
    user_id,
    concert_id,
    title,
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

revoke all on function private.enqueue_workflow_push()
from public, anon, authenticated;

create trigger user_notifications_enqueue_push
after insert on public.user_notifications
for each row execute function private.enqueue_workflow_push();

do $$
declare
  existing_job_id bigint;
begin
  select jobid into existing_job_id
  from cron.job
  where jobname = 'dispatch-workflow-push';
  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;
  perform cron.schedule(
    'dispatch-workflow-push',
    '* * * * *',
    $job$
      select net.http_post(
        url := 'https://yyqjhncuttwjgqtnzeyb.supabase.co/functions/v1/push-dispatch',
        headers := '{"Content-Type":"application/json"}'::jsonb,
        body := '{}'::jsonb
      );
    $job$
  );
end;
$$;
