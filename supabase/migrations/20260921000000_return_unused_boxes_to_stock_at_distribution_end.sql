-- Demande d'Antoine (2026-09-21) : en fin de distribution, les bénévoles
-- n'indiquent plus les boîtes "écoulées" mais les boîtes remises des sacs
-- vers le stock - symétrique de la préparation, où l'on indique ce qui
-- passe du stock vers les sacs. Les boîtes distribuées se déduisent
-- (emportées - remises au stock).
--
-- Jusqu'ici, la préparation débitait le stock de la quantité emportée
-- (`validate_maraude_preparation`) et rien ne remettait jamais les boîtes
-- non distribuées en stock : le stock ne remontait qu'avec une correction
-- manuelle. `save_maraude_distribution_v5` crédite désormais le stock de
-- la quantité remise.
--
-- `returned_to_stock_quantity` mémorise ce qui a réellement été crédité,
-- pour que les corrections après validation n'appliquent que la
-- différence (jamais deux fois la même remise). Les maraudes déjà
-- terminées gardent 0 : leur stock n'est pas modifié rétroactivement.

alter table public.maraude_consumable_allocations
add column returned_to_stock_quantity numeric not null default 0;

alter table public.maraude_consumable_allocations
add constraint maraude_consumable_allocations_returned_to_stock_check
check (
  returned_to_stock_quantity >= 0
  and returned_to_stock_quantity = trunc(returned_to_stock_quantity)
  and (
    returned_to_stock_quantity = 0
    or (
      actual_quantity is not null
      and returned_to_stock_quantity <= actual_quantity
    )
  )
);

comment on column public.maraude_consumable_allocations.returned_to_stock_quantity is
  'Quantité de cette référence remise des sacs vers le stock à la fin de la distribution (déjà créditée au stock).';

create or replace function public.save_maraude_distribution_v5(
  requested_concert_id uuid,
  requested_box_returns jsonb default '[]'::jsonb,
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
  item public.consumables%rowtype;
  value jsonb;
  returned numeric;
  distributed numeric;
  stock_delta numeric;
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

  if requested_box_returns is null
    or jsonb_typeof(requested_box_returns) <> 'array'
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
  join public.consumables consumable on consumable.id = candidate.consumable_id
  where candidate.concert_id = requested_concert_id
    and consumable.unit = 'box'::public.inventory_unit;

  if jsonb_array_length(requested_box_returns) <> expected_count then
    raise exception 'Toutes les références de boîtes doivent être renseignées'
      using errcode = '22023';
  end if;

  for allocation in
    select candidate.*
    from public.maraude_consumable_allocations candidate
    join public.consumables consumable on consumable.id = candidate.consumable_id
    where candidate.concert_id = requested_concert_id
      and consumable.unit = 'box'::public.inventory_unit
    order by candidate.id
    for update of candidate
  loop
    value := null;
    select entry
    into value
    from jsonb_array_elements(requested_box_returns) entry
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

    returned := (value ->> 'returned_quantity')::numeric;
    if returned is null
      or returned < 0
      or returned <> trunc(returned)
      or returned > allocation.actual_quantity
    then
      raise exception 'Quantité remise en stock invalide pour une référence de boîtes'
        using errcode = '22023';
    end if;
    distributed := allocation.actual_quantity - returned;

    -- Seule la différence avec ce qui a déjà été crédité touche le stock :
    -- une correction après validation ne compte jamais deux fois.
    stock_delta := returned - allocation.returned_to_stock_quantity;
    if stock_delta <> 0 then
      select * into item
      from public.consumables consumable
      where consumable.id = allocation.consumable_id
      for update;

      if item.current_quantity + stock_delta < 0 then
        raise exception 'Stock insuffisant pour corriger la remise en stock de %', item.name
          using errcode = '22023';
      end if;

      perform public.apply_consumable_movement(
        item.id,
        item.current_quantity + stock_delta,
        'maraude'::public.inventory_movement_reason,
        case
          when stock_delta > 0
            then 'Boîtes remises en stock en fin de distribution'
          else 'Correction de la remise en stock en fin de distribution'
        end,
        requested_concert_id
      );
    end if;

    update public.maraude_consumable_allocations target
    set
      distributed_quantity = distributed,
      returned_to_stock_quantity = returned
    where target.id = allocation.id;
  end loop;

  select
    coalesce(sum(stock_allocation.actual_quantity), 0)::integer,
    coalesce(sum(stock_allocation.distributed_quantity), 0)::integer
  into prepared_boxes, distributed_boxes
  from public.maraude_consumable_allocations stock_allocation
  join public.consumables consumable on consumable.id = stock_allocation.consumable_id
  where stock_allocation.concert_id = requested_concert_id
    and consumable.unit = 'box'::public.inventory_unit;

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

comment on function public.save_maraude_distribution_v5(
  uuid, jsonb, integer, text
) is
  'Enregistre les boîtes remises des sacs vers le stock (par référence), en déduit les boîtes distribuées et crédite le stock de la différence.';

revoke all on function public.save_maraude_distribution_v5(
  uuid, jsonb, integer, text
) from public, anon;
grant execute on function public.save_maraude_distribution_v5(
  uuid, jsonb, integer, text
) to authenticated;
