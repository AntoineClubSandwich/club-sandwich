-- This project has no ambient default privileges: every RLS-protected
-- table needs its grants spelled out explicitly (confirmed by every other
-- table migration in this project), which the previous migration omitted
-- for the two new push-notification tables.

grant select, insert, update, delete on public.push_subscriptions
to authenticated;
grant select, update, delete on public.push_subscriptions
to service_role;

grant select, update on public.workflow_push_deliveries
to service_role;
