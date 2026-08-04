create or replace function public.save_maraude_collection(
  requested_concert_id uuid,
  requested_collection_id uuid,
  requested_category public.collection_category,
  requested_description text,
  requested_quantity numeric,
  requested_unit public.collection_unit,
  requested_average_weight_kg numeric,
  requested_comment text
)
returns setof public.maraude_collections
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_concert_id uuid;
begin
  if requested_collection_id is null then
    target_concert_id := requested_concert_id;
  else
    select collection.concert_id
    into target_concert_id
    from public.maraude_collections collection
    where collection.id = requested_collection_id;

    if not found then
      raise exception 'Lot introuvable'
        using errcode = 'P0002';
    end if;
  end if;

  if target_concert_id is null
    or not private.can_edit_maraude_report(
      target_concert_id,
      (select auth.uid())
    )
  then
    raise exception 'Vous ne pouvez pas modifier cette collecte'
      using errcode = '42501';
  end if;

  if requested_quantity is null or requested_quantity <= 0 then
    raise exception 'La quantité doit être supérieure à zéro'
      using errcode = '22023';
  end if;

  if requested_average_weight_kg is null
    or requested_average_weight_kg <= 0
  then
    raise exception 'Le poids moyen doit être supérieur à zéro'
      using errcode = '22023';
  end if;

  if requested_collection_id is null then
    return query
    insert into public.maraude_collections (
      concert_id,
      category,
      description,
      quantity,
      unit,
      average_weight_kg,
      comment
    )
    values (
      target_concert_id,
      requested_category,
      nullif(btrim(requested_description), ''),
      requested_quantity,
      requested_unit,
      requested_average_weight_kg,
      nullif(btrim(requested_comment), '')
    )
    returning *;
  else
    return query
    update public.maraude_collections collection
    set
      category = requested_category,
      description = nullif(btrim(requested_description), ''),
      quantity = requested_quantity,
      unit = requested_unit,
      average_weight_kg = requested_average_weight_kg,
      comment = nullif(btrim(requested_comment), '')
    where collection.id = requested_collection_id
    returning collection.*;
  end if;
end;
$$;

revoke all on function public.save_maraude_collection(
  uuid,
  uuid,
  public.collection_category,
  text,
  numeric,
  public.collection_unit,
  numeric,
  text
) from public, anon;

grant execute on function public.save_maraude_collection(
  uuid,
  uuid,
  public.collection_category,
  text,
  numeric,
  public.collection_unit,
  numeric,
  text
) to authenticated;
