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

  perform 1
  from public.concerts
  where id = requested_concert_id
  for update;

  if not found then
    raise exception 'Maraude introuvable ou déjà supprimée'
      using errcode = 'P0002';
  end if;

  update public.invitation_campaigns
  set concert_id = null
  where concert_id = requested_concert_id;

  delete from public.maraude_messages
  where concert_id = requested_concert_id;

  delete from public.maraude_distributions
  where concert_id = requested_concert_id;

  delete from public.maraude_operational_reports
  where concert_id = requested_concert_id;

  delete from public.maraude_collections
  where concert_id = requested_concert_id;

  delete from public.concert_volunteers
  where concert_id = requested_concert_id;

  delete from public.concerts
  where id = requested_concert_id;
end;
$$;
