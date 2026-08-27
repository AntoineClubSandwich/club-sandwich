-- Phase 2 of live updates without manual refresh (recap item 6):
-- invitations screen and dashboard overview.

alter publication supabase_realtime add table public.invitation_campaigns;
alter publication supabase_realtime add table public.invitation_applications;
