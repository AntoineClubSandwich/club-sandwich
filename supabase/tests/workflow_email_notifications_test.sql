begin;

create extension if not exists pgtap with schema extensions;

select plan(8);

select has_table(
  'public',
  'workflow_email_deliveries',
  'La file d’attente des emails existe'
);
select has_column(
  'public',
  'workflow_email_deliveries',
  'notification_id',
  'Chaque email référence une notification métier'
);
select has_column(
  'public',
  'workflow_email_deliveries',
  'provider_message_id',
  'L’identifiant Brevo est conservé'
);
select has_function(
  'private',
  'enqueue_workflow_email',
  array[]::text[],
  'La notification est transformée en email'
);
select has_function(
  'private',
  'enqueue_maraude_email_reminders',
  array[]::text[],
  'Les rappels de maraude sont planifiables'
);
select results_eq(
  $$
    select count(*)::bigint
    from pg_trigger
    where tgname = 'user_notifications_enqueue_email'
      and not tgisinternal
  $$,
  array[1::bigint],
  'La mise en file est automatique'
);
select results_eq(
  $$
    select count(*)::bigint
    from cron.job
    where jobname = 'enqueue-maraude-email-reminders'
      and schedule = '0 8 * * *'
  $$,
  array[1::bigint],
  'Les rappels sont préparés chaque matin'
);
select results_eq(
  $$
    select count(*)::bigint
    from cron.job
    where jobname = 'dispatch-workflow-emails'
      and schedule = '* * * * *'
  $$,
  array[1::bigint],
  'La file email est distribuée chaque minute'
);

select * from finish();

rollback;
