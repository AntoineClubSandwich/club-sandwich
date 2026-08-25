create or replace function public.save_maraude_distribution_v3(
  requested_concert_id uuid,
  requested_distributed_boxes integer,
  requested_beneficiaries integer,
  requested_comment text default null
)
returns setof public.maraude_distributions
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  prepared_boxes numeric;
  remaining_boxes integer;
begin
  if not private.can_edit_maraude_operations(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Vous ne pouvez pas modifier cette distribution'
      using errcode = '42501';
  end if;

  if requested_distributed_boxes is null or requested_distributed_boxes < 0
    or requested_beneficiaries is null or requested_beneficiaries < 0
  then
    raise exception 'Les quantités doivent être positives ou nulles'
      using errcode = '22023';
  end if;

  perform 1
  from public.maraude_consumable_allocations allocation
  join public.consumables item on item.id = allocation.consumable_id
  where allocation.concert_id = requested_concert_id
    and item.unit = 'box'::public.inventory_unit
  for share of allocation;

  select coalesce(sum(allocation.actual_quantity), 0)
  into prepared_boxes
  from public.maraude_consumable_allocations allocation
  join public.consumables item on item.id = allocation.consumable_id
  where allocation.concert_id = requested_concert_id
    and item.unit = 'box'::public.inventory_unit;

  if prepared_boxes <> trunc(prepared_boxes) then
    raise exception 'La quantité de boîtes emportées doit être entière'
      using errcode = '22023';
  end if;

  if requested_distributed_boxes > prepared_boxes then
    raise exception 'Le nombre de boîtes distribuées dépasse les boîtes emportées'
      using errcode = '22023';
  end if;

  remaining_boxes := prepared_boxes::integer - requested_distributed_boxes;

  return query insert into public.maraude_distributions (
    concert_id,
    estimated_beneficiaries,
    distributed_meals,
    collected_boxes,
    distributed_boxes,
    remaining_boxes,
    incident_comment,
    last_modified_by
  ) values (
    requested_concert_id,
    requested_beneficiaries,
    requested_distributed_boxes,
    prepared_boxes::integer,
    requested_distributed_boxes,
    remaining_boxes,
    nullif(btrim(requested_comment), ''),
    (select auth.uid())
  ) on conflict (concert_id) do update set
    estimated_beneficiaries = excluded.estimated_beneficiaries,
    distributed_meals = excluded.distributed_meals,
    collected_boxes = excluded.collected_boxes,
    distributed_boxes = excluded.distributed_boxes,
    remaining_boxes = excluded.remaining_boxes,
    incident_comment = excluded.incident_comment,
    last_modified_by = excluded.last_modified_by
  returning *;
end;
$$;

comment on function public.save_maraude_distribution_v3(
  uuid, integer, integer, text
) is
  'Enregistre une distribution et calcule les boîtes restantes depuis les consommables en unité boîte réellement emportés.';

revoke all on function public.save_maraude_distribution_v3(
  uuid, integer, integer, text
) from public, anon;
grant execute on function public.save_maraude_distribution_v3(
  uuid, integer, integer, text
) to authenticated;
