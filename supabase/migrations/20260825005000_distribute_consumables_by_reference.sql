alter table public.maraude_consumable_allocations
add column distributed_quantity numeric;

alter table public.maraude_consumable_allocations
add constraint maraude_consumable_allocations_distributed_quantity_check
check (
  distributed_quantity is null
  or (
    actual_quantity is not null
    and distributed_quantity >= 0
    and distributed_quantity = trunc(distributed_quantity)
    and distributed_quantity <= actual_quantity
  )
);

comment on column public.maraude_consumable_allocations.distributed_quantity is
  'Quantité de cette référence de boîtes écoulée pendant la distribution.';

-- Les anciennes distributions ne peuvent être ventilées sans ambiguïté que
-- lorsqu’une seule référence de boîtes avait été emportée.
with single_box_allocation as (
  select allocation.concert_id, (array_agg(allocation.id))[1] as allocation_id
  from public.maraude_consumable_allocations allocation
  join public.consumables item on item.id = allocation.consumable_id
  where item.unit = 'box'::public.inventory_unit
  group by allocation.concert_id
  having count(*) = 1
)
update public.maraude_consumable_allocations allocation
set distributed_quantity = distribution.distributed_boxes
from single_box_allocation single_allocation
join public.maraude_distributions distribution
  on distribution.concert_id = single_allocation.concert_id
where allocation.id = single_allocation.allocation_id
  and distribution.distributed_boxes is not null
  and distribution.distributed_boxes <= allocation.actual_quantity;

create or replace function public.save_maraude_distribution_v4(
  requested_concert_id uuid,
  requested_box_distributions jsonb default '[]'::jsonb,
  requested_beneficiaries integer default 0,
  requested_comment text default null
)
returns setof public.maraude_distributions
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  allocation public.maraude_consumable_allocations%rowtype;
  value jsonb;
  distributed numeric;
  expected_count integer;
  prepared_boxes integer;
  distributed_boxes integer;
  remaining_boxes integer;
begin
  if not private.can_edit_maraude_operations(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Vous ne pouvez pas modifier cette distribution'
      using errcode = '42501';
  end if;

  if requested_box_distributions is null
    or jsonb_typeof(requested_box_distributions) <> 'array'
  then
    raise exception 'La répartition des boîtes est invalide'
      using errcode = '22023';
  end if;
  if requested_beneficiaries is null or requested_beneficiaries < 0 then
    raise exception 'Le nombre de bénéficiaires doit être positif ou nul'
      using errcode = '22023';
  end if;

  select count(*)::integer
  into expected_count
  from public.maraude_consumable_allocations candidate
  join public.consumables item on item.id = candidate.consumable_id
  where candidate.concert_id = requested_concert_id
    and item.unit = 'box'::public.inventory_unit;

  if jsonb_array_length(requested_box_distributions) <> expected_count then
    raise exception 'Toutes les références de boîtes doivent être renseignées'
      using errcode = '22023';
  end if;

  for allocation in
    select candidate.*
    from public.maraude_consumable_allocations candidate
    join public.consumables item on item.id = candidate.consumable_id
    where candidate.concert_id = requested_concert_id
      and item.unit = 'box'::public.inventory_unit
    order by candidate.id
    for update of candidate
  loop
    value := null;
    select entry
    into value
    from jsonb_array_elements(requested_box_distributions) entry
    where entry ->> 'allocation_id' = allocation.id::text
    limit 1;

    if value is null then
      raise exception 'Une référence de boîtes est absente de la distribution'
        using errcode = '22023';
    end if;
    if allocation.actual_quantity is null then
      raise exception 'La préparation des consommables doit être validée'
        using errcode = '22023';
    end if;

    distributed := (value ->> 'distributed_quantity')::numeric;
    if distributed is null
      or distributed < 0
      or distributed <> trunc(distributed)
      or distributed > allocation.actual_quantity
    then
      raise exception 'Quantité écoulée invalide pour une référence de boîtes'
        using errcode = '22023';
    end if;

    update public.maraude_consumable_allocations target
    set distributed_quantity = distributed
    where target.id = allocation.id;
  end loop;

  select
    coalesce(sum(stock_allocation.actual_quantity), 0)::integer,
    coalesce(sum(stock_allocation.distributed_quantity), 0)::integer
  into prepared_boxes, distributed_boxes
  from public.maraude_consumable_allocations stock_allocation
  join public.consumables item on item.id = stock_allocation.consumable_id
  where stock_allocation.concert_id = requested_concert_id
    and item.unit = 'box'::public.inventory_unit;

  remaining_boxes := prepared_boxes - distributed_boxes;

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
    distributed_boxes,
    prepared_boxes,
    distributed_boxes,
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

comment on function public.save_maraude_distribution_v4(
  uuid, jsonb, integer, text
) is
  'Enregistre les boîtes écoulées référence par référence et calcule les totaux de distribution.';

revoke all on function public.save_maraude_distribution_v4(
  uuid, jsonb, integer, text
) from public, anon;
grant execute on function public.save_maraude_distribution_v4(
  uuid, jsonb, integer, text
) to authenticated;
