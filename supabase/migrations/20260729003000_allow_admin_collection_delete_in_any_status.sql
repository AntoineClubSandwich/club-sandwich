create or replace function private.enforce_collection_during_maraude()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  requested_concert_id uuid;
  current_status public.maraude_status;
begin
  requested_concert_id = case
    when tg_op = 'DELETE' then old.concert_id
    else new.concert_id
  end;

  select concert.maraude_status
  into current_status
  from public.concerts concert
  where concert.id = requested_concert_id
  for key share;

  if not found then
    raise exception 'Concert introuvable'
      using errcode = '23503';
  end if;

  if tg_op = 'DELETE'
    and private.is_club_sandwich_admin((select auth.uid()))
  then
    return old;
  end if;

  if current_status <> 'in_progress'::public.maraude_status
    and not (
      current_status = 'completed'::public.maraude_status
      and private.is_club_sandwich_admin((select auth.uid()))
    )
  then
    raise exception 'La collecte n’est plus modifiable'
      using errcode = '22023';
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
