-- Foundations for live updates without manual refresh (recap item 6).
--
-- `encounters` was already listened to client-side by the maraude
-- operation screen but was never added to the realtime publication, so
-- that listener has been silently dead since it was written. Add it here.
--
-- Also publish the tables backing the concert detail screen (team /
-- candidatures), the first screen wired for live updates.

alter publication supabase_realtime add table public.encounters;
alter publication supabase_realtime add table public.concerts;
alter publication supabase_realtime add table public.concert_volunteers;
alter publication supabase_realtime add table public.concert_volunteer_events;
