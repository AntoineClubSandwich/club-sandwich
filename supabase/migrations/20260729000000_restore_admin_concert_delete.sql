create policy "Club Sandwich admins delete concerts"
on public.concerts
for delete
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
);
