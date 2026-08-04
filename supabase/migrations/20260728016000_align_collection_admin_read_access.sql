drop policy if exists "Club Sandwich admins can view collections"
  on public.maraude_collections;

create policy "Club Sandwich admins can view collections"
on public.maraude_collections
for select
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
);
