-- Real-world workflow: volunteers are physically at the stock when they
-- press "Démarrer la maraude" and only then decide what they're actually
-- taking. Until now, the "1. Préparation" step of the guided operation
-- could only adjust the quantity of consumables/equipment an admin had
-- pre-planned in advance (via plan_maraude_resources, admin-only, locked
-- once the maraude starts) — if nothing was pre-planned, there was no way
-- for anyone, including the admin, to record what was taken.
--
-- This lets whoever is running the maraude (admin or a selected
-- volunteer, same population as validate_maraude_preparation) add a new
-- consumable/equipment line for this concert directly from the field,
-- during the preparation step. It reuses the exact same allocation
-- tables and downstream validation as the pre-planned path.

create function public.add_maraude_resource_allocation(
  requested_concert_id uuid,
  requested_consumable_id uuid default null,
  requested_equipment_id uuid default null,
  requested_quantity numeric default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  operation public.maraude_operations%rowtype;
  asset public.equipment_assets%rowtype;
begin
  if not private.can_edit_maraude_operations(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Action non autorisée' using errcode = '42501';
  end if;

  select * into operation
  from public.maraude_operations
  where concert_id = requested_concert_id
  for update;

  if operation.current_step <> 'preparation'::public.maraude_operational_step
    or operation.preparation_completed_at is not null
  then
    raise exception 'La préparation est déjà validée'
      using errcode = '22023';
  end if;

  if requested_consumable_id is not null then
    if requested_quantity is null or requested_quantity < 0 then
      raise exception 'Quantité de consommable invalide'
        using errcode = '22023';
    end if;

    insert into public.maraude_consumable_allocations (
      concert_id, consumable_id, planned_quantity
    ) values (
      requested_concert_id, requested_consumable_id, requested_quantity
    )
    on conflict (concert_id, consumable_id) do update
      set planned_quantity = excluded.planned_quantity
      where public.maraude_consumable_allocations.validated_at is null;

  elsif requested_equipment_id is not null then
    if requested_quantity is null or requested_quantity <= 0 then
      raise exception 'Quantité de matériel invalide'
        using errcode = '22023';
    end if;

    select * into asset
    from public.equipment_assets
    where id = requested_equipment_id
      and not is_archived;

    if asset.id is null then
      raise exception 'Matériel introuvable' using errcode = 'P0002';
    end if;
    if requested_quantity > asset.quantity_total then
      raise exception 'La quantité dépasse le matériel disponible'
        using errcode = '22023';
    end if;

    insert into public.maraude_equipment_allocations (
      concert_id, equipment_id, planned_quantity
    ) values (
      requested_concert_id,
      requested_equipment_id,
      requested_quantity::integer
    )
    on conflict (concert_id, equipment_id) do update
      set planned_quantity = excluded.planned_quantity
      where public.maraude_equipment_allocations.checkout_validated_at is null;

  else
    raise exception 'Ressource non spécifiée' using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.add_maraude_resource_allocation(
  uuid, uuid, uuid, numeric
) from public, anon;
grant execute on function public.add_maraude_resource_allocation(
  uuid, uuid, uuid, numeric
) to authenticated;
