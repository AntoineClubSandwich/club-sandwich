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

  select c.maraude_status
  into current_status
  from public.concerts c
  where c.id = requested_concert_id
  for key share;

  if not found then
    raise exception 'Concert introuvable'
      using errcode = '23503';
  end if;

  if current_status <> 'in_progress'::public.maraude_status then
    raise exception 'La collecte est modifiable uniquement pendant la maraude'
      using errcode = '22023';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function private.enforce_distribution_during_maraude()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  current_status public.maraude_status;
begin
  if tg_op = 'UPDATE' and new.concert_id <> old.concert_id then
    raise exception 'Une distribution ne peut pas changer de maraude'
      using errcode = '22023';
  end if;

  select c.maraude_status
  into current_status
  from public.concerts c
  where c.id = new.concert_id
  for key share;

  if not found then
    raise exception 'Concert introuvable'
      using errcode = '23503';
  end if;

  if current_status <> 'in_progress'::public.maraude_status then
    raise exception 'La distribution est modifiable uniquement pendant la maraude'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

create or replace function public.reapply_to_concert(
  requested_concert_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.concert_volunteers cv
  set status = 'pending'::public.concert_volunteer_status
  from public.concerts c
  where cv.concert_id = requested_concert_id
    and cv.user_id = (select auth.uid())
    and cv.status = 'withdrawn'::public.concert_volunteer_status
    and c.id = cv.concert_id
    and c.maraude_status = 'open'::public.maraude_status
    and private.is_organization_member(
      c.organization_id,
      (select auth.uid())
    );

  if not found then
    raise exception 'Cette disponibilité ne peut pas être renouvelée'
      using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.reapply_to_concert(uuid)
  from public, anon;
grant execute on function public.reapply_to_concert(uuid)
  to authenticated;
