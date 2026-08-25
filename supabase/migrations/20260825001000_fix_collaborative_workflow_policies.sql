create or replace function private.can_edit_maraude_operations(
  requested_concert_id uuid,
  requested_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    exists (
      select 1
      from public.concerts concert
      where concert.id = requested_concert_id
        and concert.maraude_status = 'in_progress'::public.maraude_status
        and (
          private.is_club_sandwich_admin(requested_user_id)
          or exists (
            select 1
            from public.concert_volunteers member
            where member.concert_id = concert.id
              and member.user_id = requested_user_id
              and member.status = 'selected'::public.concert_volunteer_status
          )
        )
    );
$$;

revoke all on function private.can_edit_maraude_operations(uuid, uuid)
from public, anon, authenticated;
grant execute on function private.can_edit_maraude_operations(uuid, uuid)
to authenticated;

drop policy if exists "Operational team creates collections"
on public.maraude_collections;
drop policy if exists "Operational team updates collections"
on public.maraude_collections;
drop policy if exists "Operational team deletes collections"
on public.maraude_collections;

create policy "Operational team creates collections"
on public.maraude_collections for insert to authenticated
with check (
  private.can_edit_maraude_operations(concert_id, (select auth.uid()))
  or (
    private.is_club_sandwich_admin((select auth.uid()))
    and exists (
      select 1 from public.concerts concert
      where concert.id = maraude_collections.concert_id
        and concert.maraude_status = 'completed'::public.maraude_status
    )
  )
);

create policy "Operational team updates collections"
on public.maraude_collections for update to authenticated
using (
  private.can_edit_maraude_operations(concert_id, (select auth.uid()))
  or (
    private.is_club_sandwich_admin((select auth.uid()))
    and exists (
      select 1 from public.concerts concert
      where concert.id = maraude_collections.concert_id
        and concert.maraude_status = 'completed'::public.maraude_status
    )
  )
)
with check (
  private.can_edit_maraude_operations(concert_id, (select auth.uid()))
  or (
    private.is_club_sandwich_admin((select auth.uid()))
    and exists (
      select 1 from public.concerts concert
      where concert.id = maraude_collections.concert_id
        and concert.maraude_status = 'completed'::public.maraude_status
    )
  )
);

create policy "Operational team deletes collections"
on public.maraude_collections for delete to authenticated
using (
  private.can_edit_maraude_operations(concert_id, (select auth.uid()))
  or (
    private.is_club_sandwich_admin((select auth.uid()))
    and exists (
      select 1 from public.concerts concert
      where concert.id = maraude_collections.concert_id
        and concert.maraude_status = 'completed'::public.maraude_status
    )
  )
);

create or replace function public.validate_maraude_preparation(
  requested_concert_id uuid,
  requested_consumables jsonb default '[]'::jsonb,
  requested_equipment jsonb default '[]'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  operation public.maraude_operations%rowtype;
  value jsonb;
  consumable_allocation public.maraude_consumable_allocations%rowtype;
  equipment_allocation public.maraude_equipment_allocations%rowtype;
  item public.consumables%rowtype;
  asset public.equipment_assets%rowtype;
  actual numeric;
  taken integer;
  changed_at timestamptz := clock_timestamp();
begin
  if not private.can_edit_maraude_operations(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Préparation non autorisée' using errcode = '42501';
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

  for value in select * from jsonb_array_elements(requested_consumables)
  loop
    actual := (value ->> 'actual_quantity')::numeric;
    select * into consumable_allocation
    from public.maraude_consumable_allocations resource
    where resource.id = (value ->> 'allocation_id')::uuid
      and resource.concert_id = requested_concert_id
    for update;

    if consumable_allocation.id is null or actual is null or actual < 0 then
      raise exception 'Quantité de consommable invalide'
        using errcode = '22023';
    end if;

    select * into item
    from public.consumables
    where id = consumable_allocation.consumable_id
    for update;

    if item.current_quantity < actual then
      raise exception 'Stock insuffisant pour %', item.name
        using errcode = '22023';
    end if;

    perform public.apply_consumable_movement(
      item.id,
      item.current_quantity - actual,
      'maraude'::public.inventory_movement_reason,
      'Sortie validée pendant la préparation',
      requested_concert_id
    );

    update public.maraude_consumable_allocations
    set
      actual_quantity = actual,
      validated_by = (select auth.uid()),
      validated_at = changed_at
    where id = consumable_allocation.id;
  end loop;

  for value in select * from jsonb_array_elements(requested_equipment)
  loop
    taken := (value ->> 'taken_quantity')::integer;
    select * into equipment_allocation
    from public.maraude_equipment_allocations resource
    where resource.id = (value ->> 'allocation_id')::uuid
      and resource.concert_id = requested_concert_id
    for update;

    if equipment_allocation.id is null or taken is null or taken < 0 then
      raise exception 'Quantité de matériel invalide'
        using errcode = '22023';
    end if;

    select * into asset
    from public.equipment_assets
    where id = equipment_allocation.equipment_id
      and not is_archived
    for update;

    if asset.id is null or taken > asset.quantity_total then
      raise exception 'Matériel indisponible' using errcode = '22023';
    end if;
    if taken > 0 and asset.status not in (
      'available'::public.equipment_status,
      'assigned'::public.equipment_status
    ) then
      raise exception 'Le matériel % n’est pas disponible', asset.name
        using errcode = '22023';
    end if;

    update public.equipment_assets
    set status = case
      when taken = 0 then 'available'::public.equipment_status
      else 'in_use'::public.equipment_status
    end
    where id = asset.id;

    update public.maraude_equipment_allocations
    set
      taken_quantity = taken,
      checkout_validated_by = (select auth.uid()),
      checkout_validated_at = changed_at
    where id = equipment_allocation.id;

    if taken > 0 then
      insert into public.equipment_events (
        equipment_id,
        concert_id,
        event_type,
        quantity,
        previous_status,
        new_status,
        actor_id
      ) values (
        asset.id,
        requested_concert_id,
        'checkout',
        taken,
        asset.status,
        'in_use'::public.equipment_status,
        (select auth.uid())
      );
    end if;
  end loop;

  if exists (
    select 1
    from public.maraude_consumable_allocations pending_consumable
    where pending_consumable.concert_id = requested_concert_id
      and pending_consumable.validated_at is null
  ) or exists (
    select 1
    from public.maraude_equipment_allocations pending_equipment
    where pending_equipment.concert_id = requested_concert_id
      and pending_equipment.checkout_validated_at is null
  ) then
    raise exception 'Toutes les ressources prévues doivent être confirmées'
      using errcode = '22023';
  end if;

  update public.maraude_operations
  set
    current_step = 'collection',
    preparation_completed_at = changed_at,
    preparation_completed_by = (select auth.uid()),
    last_modified_by = (select auth.uid())
  where concert_id = requested_concert_id;

  insert into public.maraude_step_events (
    concert_id, step, event_type, actor_id
  ) values (
    requested_concert_id,
    'preparation',
    'completed',
    (select auth.uid())
  ), (
    requested_concert_id,
    'collection',
    'opened',
    (select auth.uid())
  );
end;
$$;

revoke all on function public.validate_maraude_preparation(uuid, jsonb, jsonb)
from public, anon;
grant execute on function public.validate_maraude_preparation(uuid, jsonb, jsonb)
to authenticated;

