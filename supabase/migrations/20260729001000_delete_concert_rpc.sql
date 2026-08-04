create or replace function public.delete_concert(
  requested_concert_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Seul un administrateur peut supprimer une maraude'
      using errcode = '42501';
  end if;

  delete from public.concerts
  where id = requested_concert_id;

  if not found then
    raise exception 'Maraude introuvable ou déjà supprimée'
      using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.delete_concert(uuid)
  from public, anon;
grant execute on function public.delete_concert(uuid)
  to authenticated;
