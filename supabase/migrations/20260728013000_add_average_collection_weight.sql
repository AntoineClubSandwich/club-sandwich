alter table public.maraude_collections
  add column if not exists average_weight_kg numeric
    check (average_weight_kg is null or average_weight_kg >= 0);

create or replace function private.calculate_collection_weight()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.average_weight_kg is not null then
    new.weight_kg = new.quantity * new.average_weight_kg;
  end if;
  return new;
end;
$$;

create trigger maraude_collections_calculate_weight
before insert or update of quantity, average_weight_kg
on public.maraude_collections
for each row execute function private.calculate_collection_weight();

revoke all on function private.calculate_collection_weight()
  from public, anon, authenticated;

create or replace function private.limit_collection_types()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if (
    select count(*)
    from public.maraude_collections collection
    where collection.concert_id = new.concert_id
  ) >= 6 then
    raise exception 'Six types de plats maximum par maraude'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger maraude_collections_limit_types
before insert on public.maraude_collections
for each row execute function private.limit_collection_types();

revoke all on function private.limit_collection_types()
  from public, anon, authenticated;
