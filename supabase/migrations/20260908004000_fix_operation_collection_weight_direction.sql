-- Reported live by a team leader: the "Ajouter un plat" quick-add dialog
-- in mode terrain asked for a "Poids total (kg)" and then divided it by
-- the box count to derive average_weight_kg. Backwards - nobody weighs
-- every box on the ground, so what's actually being estimated is the
-- average weight of one box; the total should be computed by
-- multiplying that estimate by the box count, exactly like the other
-- collection entry point (MaraudeCollectionFormDialog) already does.
--
-- Existing rows keep whatever weight_kg/average_weight_kg they were
-- saved with - not touched here, by explicit choice, since there's no
-- way to tell after the fact whether a given past entry was a genuine
-- total or already an eyeballed average typed into the wrong field.

drop function public.save_maraude_collection_v2(
  uuid, uuid, text, integer, numeric, text
);

create function public.save_maraude_collection_v2(
  requested_concert_id uuid,
  requested_collection_id uuid,
  requested_description text,
  requested_box_count integer,
  requested_average_weight_kg numeric,
  requested_comment text default null
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
    select concert_id into target_concert_id
    from public.maraude_collections
    where id = requested_collection_id;
    if not found then
      raise exception 'Plat introuvable' using errcode = 'P0002';
    end if;
  end if;

  if not private.can_edit_maraude_operations(
    target_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Vous ne pouvez pas modifier cette collecte'
      using errcode = '42501';
  end if;
  if nullif(btrim(requested_description), '') is null then
    raise exception 'Le nom du plat est obligatoire' using errcode = '22023';
  end if;
  if requested_box_count is null or requested_box_count <= 0 then
    raise exception 'Le nombre de boîtes doit être supérieur à zéro'
      using errcode = '22023';
  end if;
  if requested_average_weight_kg is null
    or requested_average_weight_kg <= 0 then
    raise exception 'Le poids doit être supérieur à zéro'
      using errcode = '22023';
  end if;

  if requested_collection_id is null then
    return query insert into public.maraude_collections (
      concert_id, category, description, quantity, unit,
      weight_kg, average_weight_kg, comment
    ) values (
      target_concert_id,
      'prepared_meals'::public.collection_category,
      btrim(requested_description),
      requested_box_count,
      'box'::public.collection_unit,
      requested_average_weight_kg * requested_box_count,
      requested_average_weight_kg,
      nullif(btrim(requested_comment), '')
    ) returning *;
  else
    return query update public.maraude_collections collection set
      category = 'prepared_meals'::public.collection_category,
      description = btrim(requested_description),
      quantity = requested_box_count,
      unit = 'box'::public.collection_unit,
      weight_kg = requested_average_weight_kg * requested_box_count,
      average_weight_kg = requested_average_weight_kg,
      comment = nullif(btrim(requested_comment), '')
    where collection.id = requested_collection_id
    returning collection.*;
  end if;
end;
$$;

revoke all on function public.save_maraude_collection_v2(
  uuid, uuid, text, integer, numeric, text
) from public, anon;
grant execute on function public.save_maraude_collection_v2(
  uuid, uuid, text, integer, numeric, text
) to authenticated;
