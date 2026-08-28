-- The "Ajouter un consommable/matériel" action added to the field
-- preparation step called the admin-only consumables/equipment_assets
-- tables directly (via the same providers as the Stock screens), which
-- are locked down to admins by RLS ("Admins manage consumables/equipment
-- assets"). A volunteer team leader got an empty catalog and a misleading
-- "tout est déjà listé" message instead of a permission error.
--
-- These two read-only functions expose just enough of the catalog (id,
-- name, stock) to the exact population allowed to add a resource
-- allocation (private.can_edit_maraude_operations: admin or a selected
-- volunteer on that in-progress maraude), without opening up the
-- admin-only Stock tables themselves.

create function public.get_maraude_consumable_catalog(
  requested_concert_id uuid
)
returns table (
  id uuid,
  name text,
  unit public.inventory_unit,
  current_quantity numeric
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select item.id, item.name, item.unit, item.current_quantity
  from public.consumables item
  where not item.is_archived
    and private.can_edit_maraude_operations(
      requested_concert_id,
      (select auth.uid())
    )
  order by item.name;
$$;

revoke all on function public.get_maraude_consumable_catalog(uuid)
from public, anon;
grant execute on function public.get_maraude_consumable_catalog(uuid)
to authenticated;

create function public.get_maraude_equipment_catalog(
  requested_concert_id uuid
)
returns table (
  id uuid,
  name text,
  quantity_total integer
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select asset.id, asset.name, asset.quantity_total
  from public.equipment_assets asset
  where not asset.is_archived
    and private.can_edit_maraude_operations(
      requested_concert_id,
      (select auth.uid())
    )
  order by asset.name;
$$;

revoke all on function public.get_maraude_equipment_catalog(uuid)
from public, anon;
grant execute on function public.get_maraude_equipment_catalog(uuid)
to authenticated;
