create type public.inventory_unit as enum (
  'unit',
  'box',
  'roll',
  'pack',
  'pair',
  'carton',
  'bag',
  'bottle',
  'other'
);

create type public.inventory_movement_reason as enum (
  'restock',
  'maraude',
  'inventory_correction',
  'loss',
  'other'
);

create type public.equipment_status as enum (
  'available',
  'assigned',
  'in_use',
  'needs_check',
  'needs_cleaning',
  'damaged',
  'lost',
  'out_of_service'
);

create type public.equipment_incident_type as enum (
  'missing',
  'damaged',
  'needs_cleaning',
  'needs_check',
  'lost',
  'other'
);

create type public.maraude_operational_step as enum (
  'preparation',
  'collection',
  'distribution',
  'equipment_return',
  'summary'
);

create table public.consumables (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) > 0),
  category text not null check (char_length(btrim(category)) > 0),
  current_quantity numeric not null default 0
    check (current_quantity >= 0),
  unit public.inventory_unit not null,
  alert_threshold numeric not null default 0
    check (alert_threshold >= 0),
  storage_location text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index consumables_active_name_idx
on public.consumables (lower(btrim(name)))
where not is_archived;

create index consumables_purchase_list_idx
on public.consumables (is_archived, current_quantity, alert_threshold);

create trigger consumables_set_updated_at
before update on public.consumables
for each row execute function private.set_updated_at();

create table public.consumable_movements (
  id uuid primary key default gen_random_uuid(),
  consumable_id uuid not null
    references public.consumables(id) on delete restrict,
  concert_id uuid references public.concerts(id) on delete set null,
  previous_quantity numeric not null check (previous_quantity >= 0),
  new_quantity numeric not null check (new_quantity >= 0),
  quantity_difference numeric generated always as (
    new_quantity - previous_quantity
  ) stored,
  reason public.inventory_movement_reason not null,
  note text,
  actor_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index consumable_movements_item_created_idx
on public.consumable_movements (consumable_id, created_at desc);

create index consumable_movements_concert_idx
on public.consumable_movements (concert_id, created_at desc)
where concert_id is not null;

create table public.equipment_locations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index equipment_locations_active_name_idx
on public.equipment_locations (lower(btrim(name)))
where is_active;

create trigger equipment_locations_set_updated_at
before update on public.equipment_locations
for each row execute function private.set_updated_at();

create table public.equipment_assets (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) > 0),
  category text not null check (char_length(btrim(category)) > 0),
  internal_code text,
  quantity_total integer not null default 1 check (quantity_total > 0),
  location_id uuid references public.equipment_locations(id) on delete set null,
  status public.equipment_status not null default 'available',
  condition text,
  notes text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index equipment_assets_internal_code_idx
on public.equipment_assets (lower(btrim(internal_code)))
where internal_code is not null and not is_archived;

create index equipment_assets_status_location_idx
on public.equipment_assets (is_archived, status, location_id);

create trigger equipment_assets_set_updated_at
before update on public.equipment_assets
for each row execute function private.set_updated_at();

create table public.equipment_events (
  id uuid primary key default gen_random_uuid(),
  equipment_id uuid not null
    references public.equipment_assets(id) on delete restrict,
  concert_id uuid references public.concerts(id) on delete set null,
  event_type text not null check (
    event_type in (
      'assignment',
      'checkout',
      'return',
      'status_change',
      'move',
      'incident'
    )
  ),
  quantity integer check (quantity is null or quantity > 0),
  previous_status public.equipment_status,
  new_status public.equipment_status,
  previous_location_id uuid
    references public.equipment_locations(id) on delete set null,
  new_location_id uuid
    references public.equipment_locations(id) on delete set null,
  note text,
  actor_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index equipment_events_asset_created_idx
on public.equipment_events (equipment_id, created_at desc);

create table public.maraude_consumable_allocations (
  id uuid primary key default gen_random_uuid(),
  concert_id uuid not null references public.concerts(id) on delete cascade,
  consumable_id uuid not null
    references public.consumables(id) on delete restrict,
  planned_quantity numeric not null check (planned_quantity >= 0),
  actual_quantity numeric check (actual_quantity is null or actual_quantity >= 0),
  validated_by uuid references public.profiles(id) on delete set null,
  validated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (concert_id, consumable_id),
  check (
    (validated_at is null and validated_by is null)
    or (validated_at is not null and validated_by is not null)
  )
);

create index maraude_consumable_allocations_concert_idx
on public.maraude_consumable_allocations (concert_id);

create trigger maraude_consumable_allocations_set_updated_at
before update on public.maraude_consumable_allocations
for each row execute function private.set_updated_at();

create table public.maraude_equipment_allocations (
  id uuid primary key default gen_random_uuid(),
  concert_id uuid not null references public.concerts(id) on delete cascade,
  equipment_id uuid not null
    references public.equipment_assets(id) on delete restrict,
  planned_quantity integer not null check (planned_quantity > 0),
  taken_quantity integer check (taken_quantity is null or taken_quantity >= 0),
  returned_quantity integer check (
    returned_quantity is null or returned_quantity >= 0
  ),
  incident_type public.equipment_incident_type,
  incident_note text,
  checkout_validated_by uuid references public.profiles(id) on delete set null,
  checkout_validated_at timestamptz,
  return_validated_by uuid references public.profiles(id) on delete set null,
  return_validated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (concert_id, equipment_id),
  check (
    returned_quantity is null
    or taken_quantity is not null and returned_quantity <= taken_quantity
  )
);

create index maraude_equipment_allocations_concert_idx
on public.maraude_equipment_allocations (concert_id);

create trigger maraude_equipment_allocations_set_updated_at
before update on public.maraude_equipment_allocations
for each row execute function private.set_updated_at();

create table public.maraude_operations (
  concert_id uuid primary key references public.concerts(id) on delete cascade,
  current_step public.maraude_operational_step not null default 'preparation',
  preparation_completed_at timestamptz,
  preparation_completed_by uuid references public.profiles(id) on delete set null,
  collection_completed_at timestamptz,
  collection_completed_by uuid references public.profiles(id) on delete set null,
  distribution_completed_at timestamptz,
  distribution_completed_by uuid references public.profiles(id) on delete set null,
  equipment_return_completed_at timestamptz,
  equipment_return_completed_by uuid references public.profiles(id) on delete set null,
  summary_completed_at timestamptz,
  summary_completed_by uuid references public.profiles(id) on delete set null,
  last_modified_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger maraude_operations_set_updated_at
before update on public.maraude_operations
for each row execute function private.set_updated_at();

create table public.maraude_step_events (
  id uuid primary key default gen_random_uuid(),
  concert_id uuid not null references public.concerts(id) on delete cascade,
  step public.maraude_operational_step not null,
  event_type text not null check (event_type in ('opened', 'completed', 'corrected')),
  actor_id uuid references public.profiles(id) on delete set null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index maraude_step_events_concert_created_idx
on public.maraude_step_events (concert_id, created_at desc);

alter table public.maraude_distributions
  add column collected_boxes integer check (collected_boxes is null or collected_boxes >= 0),
  add column distributed_boxes integer check (distributed_boxes is null or distributed_boxes >= 0),
  add column remaining_boxes integer check (remaining_boxes is null or remaining_boxes >= 0),
  add column last_modified_by uuid references public.profiles(id) on delete set null;

update public.maraude_distributions
set distributed_boxes = distributed_meals
where distributed_boxes is null and distributed_meals is not null;

drop trigger if exists maraude_collections_limit_types
on public.maraude_collections;

create or replace function private.can_view_maraude_operations(
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
    private.is_club_sandwich_admin(requested_user_id)
    or exists (
      select 1
      from public.concert_volunteers member
      where member.concert_id = requested_concert_id
        and member.user_id = requested_user_id
        and member.status = 'selected'::public.concert_volunteer_status
    );
$$;

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

create or replace function private.can_lead_maraude_operations(
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
    private.is_club_sandwich_admin(requested_user_id)
    or exists (
      select 1
      from public.concert_volunteers leader
      where leader.concert_id = requested_concert_id
        and leader.user_id = requested_user_id
        and leader.status = 'selected'::public.concert_volunteer_status
        and leader.team_role = 'team_leader'::public.maraude_role
        and leader.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
    );
$$;

revoke all on function private.can_view_maraude_operations(uuid, uuid)
from public, anon, authenticated;
revoke all on function private.can_edit_maraude_operations(uuid, uuid)
from public, anon, authenticated;
revoke all on function private.can_lead_maraude_operations(uuid, uuid)
from public, anon, authenticated;

grant execute on function private.can_view_maraude_operations(uuid, uuid)
to authenticated;
grant execute on function private.can_edit_maraude_operations(uuid, uuid)
to authenticated;

create or replace function private.protect_consumable_quantity()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.current_quantity is distinct from old.current_quantity
    and coalesce(current_setting('app.allow_stock_change', true), '') <> 'on'
  then
    raise exception 'Utilisez une opération de stock tracée'
      using errcode = '55000';
  end if;
  return new;
end;
$$;

create trigger consumables_protect_quantity
before update of current_quantity on public.consumables
for each row execute function private.protect_consumable_quantity();

create or replace function private.log_equipment_asset_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status is distinct from old.status then
    insert into public.equipment_events (
      equipment_id, event_type, previous_status, new_status, actor_id
    ) values (
      new.id, 'status_change', old.status, new.status, (select auth.uid())
    );
  end if;
  if new.location_id is distinct from old.location_id then
    insert into public.equipment_events (
      equipment_id,
      event_type,
      previous_location_id,
      new_location_id,
      actor_id
    ) values (
      new.id,
      'move',
      old.location_id,
      new.location_id,
      (select auth.uid())
    );
  end if;
  return new;
end;
$$;

create trigger equipment_assets_log_change
after update of status, location_id on public.equipment_assets
for each row execute function private.log_equipment_asset_change();

create or replace function private.log_equipment_assignment()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.equipment_events (
    equipment_id, concert_id, event_type, quantity, actor_id
  ) values (
    new.equipment_id,
    new.concert_id,
    'assignment',
    new.planned_quantity,
    (select auth.uid())
  );
  return new;
end;
$$;

create trigger maraude_equipment_allocations_log_assignment
after insert on public.maraude_equipment_allocations
for each row execute function private.log_equipment_assignment();

create or replace function public.apply_consumable_movement(
  requested_consumable_id uuid,
  requested_new_quantity numeric,
  requested_reason public.inventory_movement_reason,
  requested_note text default null,
  requested_concert_id uuid default null
)
returns public.consumables
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  item public.consumables%rowtype;
  updated_item public.consumables%rowtype;
begin
  if requested_new_quantity is null or requested_new_quantity < 0 then
    raise exception 'La quantité doit être positive ou nulle'
      using errcode = '22023';
  end if;

  if not private.is_club_sandwich_admin((select auth.uid()))
    and not (
      requested_reason = 'maraude'::public.inventory_movement_reason
      and requested_concert_id is not null
      and private.can_edit_maraude_operations(
        requested_concert_id,
        (select auth.uid())
      )
    )
  then
    raise exception 'Mouvement de stock non autorisé'
      using errcode = '42501';
  end if;

  select * into item
  from public.consumables
  where id = requested_consumable_id and not is_archived
  for update;

  if item.id is null then
    raise exception 'Consommable introuvable' using errcode = 'P0002';
  end if;

  perform set_config('app.allow_stock_change', 'on', true);
  update public.consumables
  set current_quantity = requested_new_quantity
  where id = item.id
  returning * into updated_item;

  insert into public.consumable_movements (
    consumable_id,
    concert_id,
    previous_quantity,
    new_quantity,
    reason,
    note,
    actor_id
  ) values (
    item.id,
    requested_concert_id,
    item.current_quantity,
    requested_new_quantity,
    requested_reason,
    nullif(btrim(requested_note), ''),
    (select auth.uid())
  );

  return updated_item;
end;
$$;

create or replace function public.create_consumable(
  requested_name text,
  requested_category text,
  requested_unit public.inventory_unit,
  requested_initial_quantity numeric default 0,
  requested_alert_threshold numeric default 0,
  requested_storage_location text default null
)
returns public.consumables
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  item public.consumables%rowtype;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Création non autorisée' using errcode = '42501';
  end if;
  if nullif(btrim(requested_name), '') is null
    or nullif(btrim(requested_category), '') is null
  then
    raise exception 'Le nom et la catégorie sont obligatoires'
      using errcode = '22023';
  end if;
  if requested_initial_quantity < 0 or requested_alert_threshold < 0 then
    raise exception 'Les quantités doivent être positives ou nulles'
      using errcode = '22023';
  end if;

  insert into public.consumables (
    name,
    category,
    current_quantity,
    unit,
    alert_threshold,
    storage_location
  ) values (
    btrim(requested_name),
    btrim(requested_category),
    requested_initial_quantity,
    requested_unit,
    requested_alert_threshold,
    nullif(btrim(requested_storage_location), '')
  ) returning * into item;

  if requested_initial_quantity > 0 then
    insert into public.consumable_movements (
      consumable_id,
      previous_quantity,
      new_quantity,
      reason,
      note,
      actor_id
    ) values (
      item.id,
      0,
      requested_initial_quantity,
      'restock'::public.inventory_movement_reason,
      'Stock initial',
      (select auth.uid())
    );
  end if;
  return item;
end;
$$;

revoke all on function public.apply_consumable_movement(
  uuid, numeric, public.inventory_movement_reason, text, uuid
) from public, anon;
grant execute on function public.apply_consumable_movement(
  uuid, numeric, public.inventory_movement_reason, text, uuid
) to authenticated;
revoke all on function public.create_consumable(
  text, text, public.inventory_unit, numeric, numeric, text
) from public, anon;
grant execute on function public.create_consumable(
  text, text, public.inventory_unit, numeric, numeric, text
) to authenticated;

create or replace function private.initialize_maraude_operation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.maraude_status = 'in_progress'::public.maraude_status
    and old.maraude_status is distinct from new.maraude_status
  then
    insert into public.maraude_operations (
      concert_id,
      current_step,
      last_modified_by
    ) values (
      new.id,
      'preparation'::public.maraude_operational_step,
      (select auth.uid())
    ) on conflict (concert_id) do nothing;

    insert into public.maraude_step_events (
      concert_id,
      step,
      event_type,
      actor_id
    ) values (
      new.id,
      'preparation'::public.maraude_operational_step,
      'opened',
      (select auth.uid())
    );
  end if;
  return new;
end;
$$;

create trigger concerts_initialize_maraude_operation
after update of maraude_status on public.concerts
for each row execute function private.initialize_maraude_operation();

insert into public.maraude_operations (concert_id, current_step)
select concert.id, 'preparation'::public.maraude_operational_step
from public.concerts concert
where concert.maraude_status = 'in_progress'::public.maraude_status
on conflict (concert_id) do nothing;

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
  allocation public.maraude_consumable_allocations%rowtype;
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
    select * into allocation
    from public.maraude_consumable_allocations
    where id = (value ->> 'allocation_id')::uuid
      and concert_id = requested_concert_id
    for update;

    if allocation.id is null or actual is null or actual < 0 then
      raise exception 'Quantité de consommable invalide'
        using errcode = '22023';
    end if;

    select * into item
    from public.consumables
    where id = allocation.consumable_id
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
    where id = allocation.id;
  end loop;

  for value in select * from jsonb_array_elements(requested_equipment)
  loop
    taken := (value ->> 'taken_quantity')::integer;
    select * into equipment_allocation
    from public.maraude_equipment_allocations
    where id = (value ->> 'allocation_id')::uuid
      and concert_id = requested_concert_id
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

create or replace function public.validate_maraude_step(
  requested_concert_id uuid,
  requested_step public.maraude_operational_step
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  operation public.maraude_operations%rowtype;
  changed_at timestamptz := clock_timestamp();
  next_step public.maraude_operational_step;
  allocation record;
  next_status public.equipment_status;
begin
  if not private.can_edit_maraude_operations(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Validation non autorisée' using errcode = '42501';
  end if;

  select * into operation
  from public.maraude_operations
  where concert_id = requested_concert_id
  for update;

  if operation.current_step <> requested_step then
    raise exception 'Cette étape n’est pas active' using errcode = '22023';
  end if;

  case requested_step
    when 'collection'::public.maraude_operational_step then
      if not exists (
        select 1 from public.maraude_collections
        where concert_id = requested_concert_id
      ) then
        raise exception 'Ajoutez au moins un plat à la collecte'
          using errcode = '22023';
      end if;
      update public.maraude_operations set
        current_step = 'distribution',
        collection_completed_at = changed_at,
        collection_completed_by = (select auth.uid()),
        last_modified_by = (select auth.uid())
      where concert_id = requested_concert_id;
      next_step := 'distribution';

    when 'distribution'::public.maraude_operational_step then
      if not exists (
        select 1 from public.maraude_distributions distribution
        where distribution.concert_id = requested_concert_id
          and distribution.distributed_boxes is not null
          and distribution.estimated_beneficiaries is not null
      ) then
        raise exception 'Complétez la distribution avant de continuer'
          using errcode = '22023';
      end if;
      update public.maraude_operations set
        current_step = 'equipment_return',
        distribution_completed_at = changed_at,
        distribution_completed_by = (select auth.uid()),
        last_modified_by = (select auth.uid())
      where concert_id = requested_concert_id;
      next_step := 'equipment_return';

    when 'equipment_return'::public.maraude_operational_step then
      if exists (
        select 1 from public.maraude_equipment_allocations assignment
        where assignment.concert_id = requested_concert_id
          and assignment.taken_quantity is not null
          and assignment.returned_quantity is null
      ) then
        raise exception 'Confirmez le retour de tout le matériel'
          using errcode = '22023';
      end if;

      for allocation in
        select assignment.*, asset.status as previous_status
        from public.maraude_equipment_allocations assignment
        join public.equipment_assets asset on asset.id = assignment.equipment_id
        where assignment.concert_id = requested_concert_id
        for update of assignment, asset
      loop
        next_status := case allocation.incident_type
          when 'damaged' then 'damaged'::public.equipment_status
          when 'needs_cleaning' then 'needs_cleaning'::public.equipment_status
          when 'needs_check' then 'needs_check'::public.equipment_status
          when 'lost' then 'lost'::public.equipment_status
          when 'missing' then 'needs_check'::public.equipment_status
          when 'other' then 'needs_check'::public.equipment_status
          else 'available'::public.equipment_status
        end;

        update public.equipment_assets
        set status = next_status
        where id = allocation.equipment_id;

        update public.maraude_equipment_allocations
        set
          return_validated_by = (select auth.uid()),
          return_validated_at = changed_at
        where id = allocation.id;

        insert into public.equipment_events (
          equipment_id,
          concert_id,
          event_type,
          quantity,
          previous_status,
          new_status,
          note,
          actor_id
        ) values (
          allocation.equipment_id,
          requested_concert_id,
          case when allocation.incident_type is null then 'return' else 'incident' end,
          nullif(coalesce(allocation.returned_quantity, 0), 0),
          allocation.previous_status,
          next_status,
          allocation.incident_note,
          (select auth.uid())
        );
      end loop;

      update public.maraude_operations set
        current_step = 'summary',
        equipment_return_completed_at = changed_at,
        equipment_return_completed_by = (select auth.uid()),
        last_modified_by = (select auth.uid())
      where concert_id = requested_concert_id;
      next_step := 'summary';

    else
      raise exception 'Cette étape utilise une action dédiée'
        using errcode = '22023';
  end case;

  insert into public.maraude_step_events (
    concert_id, step, event_type, actor_id
  ) values (
    requested_concert_id,
    requested_step,
    'completed',
    (select auth.uid())
  ), (
    requested_concert_id,
    next_step,
    'opened',
    (select auth.uid())
  );

end;
$$;

create or replace function public.complete_guided_maraude(
  requested_concert_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  operation public.maraude_operations%rowtype;
  changed_at timestamptz := clock_timestamp();
begin
  if not private.can_lead_maraude_operations(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Seul le chef d’équipe ou un administrateur peut clôturer'
      using errcode = '42501';
  end if;

  select * into operation
  from public.maraude_operations
  where concert_id = requested_concert_id
  for update;

  if operation.current_step <> 'summary'::public.maraude_operational_step
    or operation.equipment_return_completed_at is null
  then
    raise exception 'Toutes les étapes doivent être validées avant la clôture'
      using errcode = '22023';
  end if;

  update public.maraude_operations
  set
    summary_completed_at = changed_at,
    summary_completed_by = (select auth.uid()),
    last_modified_by = (select auth.uid())
  where concert_id = requested_concert_id;

  insert into public.maraude_step_events (
    concert_id, step, event_type, actor_id
  ) values (
    requested_concert_id,
    'summary',
    'completed',
    (select auth.uid())
  );

  insert into public.maraude_operational_reports (
    concert_id,
    total_weight_kg,
    estimated_meals,
    quantities_unavailable,
    last_modified_by
  ) values (
    requested_concert_id,
    coalesce((
      select sum(collection.weight_kg)
      from public.maraude_collections collection
      where collection.concert_id = requested_concert_id
    ), 0),
    null,
    false,
    (select auth.uid())
  ) on conflict (concert_id) do update set
    total_weight_kg = excluded.total_weight_kg,
    estimated_meals = null,
    quantities_unavailable = false,
    last_modified_by = excluded.last_modified_by;

  perform public.set_maraude_status(
    requested_concert_id,
    'completed'::public.maraude_status,
    null
  );
end;
$$;

create or replace function public.plan_maraude_resources(
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
  current_status public.maraude_status;
  value jsonb;
begin
  if not private.is_club_sandwich_admin((select auth.uid())) then
    raise exception 'Planification non autorisée' using errcode = '42501';
  end if;

  select maraude_status into current_status
  from public.concerts
  where id = requested_concert_id
  for update;

  if current_status is null then
    raise exception 'Maraude introuvable' using errcode = 'P0002';
  end if;
  if current_status in (
    'in_progress'::public.maraude_status,
    'completed'::public.maraude_status,
    'cancelled'::public.maraude_status
  ) then
    raise exception 'Les ressources de cette maraude sont verrouillées'
      using errcode = '22023';
  end if;

  delete from public.maraude_consumable_allocations
  where concert_id = requested_concert_id;
  for value in select * from jsonb_array_elements(requested_consumables)
  loop
    if (value ->> 'planned_quantity')::numeric < 0 then
      raise exception 'Quantité de consommable invalide'
        using errcode = '22023';
    end if;
    insert into public.maraude_consumable_allocations (
      concert_id, consumable_id, planned_quantity
    ) values (
      requested_concert_id,
      (value ->> 'consumable_id')::uuid,
      (value ->> 'planned_quantity')::numeric
    );
  end loop;

  delete from public.maraude_equipment_allocations
  where concert_id = requested_concert_id;
  update public.equipment_assets asset
  set status = 'available'::public.equipment_status
  where asset.status = 'assigned'::public.equipment_status
    and not exists (
      select 1
      from public.maraude_equipment_allocations assignment
      join public.concerts concert on concert.id = assignment.concert_id
      where assignment.equipment_id = asset.id
        and concert.maraude_status not in (
          'completed'::public.maraude_status,
          'cancelled'::public.maraude_status
        )
    );
  for value in select * from jsonb_array_elements(requested_equipment)
  loop
    if (value ->> 'planned_quantity')::integer <= 0 then
      raise exception 'Quantité de matériel invalide'
        using errcode = '22023';
    end if;
    insert into public.maraude_equipment_allocations (
      concert_id, equipment_id, planned_quantity
    ) values (
      requested_concert_id,
      (value ->> 'equipment_id')::uuid,
      (value ->> 'planned_quantity')::integer
    );
    if (
      select (value ->> 'planned_quantity')::integer > asset.quantity_total
      from public.equipment_assets asset
      where asset.id = (value ->> 'equipment_id')::uuid
    ) then
      raise exception 'La quantité prévue dépasse le matériel disponible'
        using errcode = '22023';
    end if;
  end loop;

  update public.equipment_assets asset
  set status = 'assigned'::public.equipment_status
  where asset.status = 'available'::public.equipment_status
    and exists (
      select 1
      from public.maraude_equipment_allocations assignment
      where assignment.concert_id = requested_concert_id
        and assignment.equipment_id = asset.id
    );
end;
$$;

create or replace function public.save_maraude_collection_v2(
  requested_concert_id uuid,
  requested_collection_id uuid,
  requested_description text,
  requested_box_count integer,
  requested_weight_kg numeric,
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
  if requested_weight_kg is null or requested_weight_kg <= 0 then
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
      requested_weight_kg,
      requested_weight_kg / requested_box_count,
      nullif(btrim(requested_comment), '')
    ) returning *;
  else
    return query update public.maraude_collections collection set
      category = 'prepared_meals'::public.collection_category,
      description = btrim(requested_description),
      quantity = requested_box_count,
      unit = 'box'::public.collection_unit,
      weight_kg = requested_weight_kg,
      average_weight_kg = requested_weight_kg / requested_box_count,
      comment = nullif(btrim(requested_comment), '')
    where collection.id = requested_collection_id
    returning collection.*;
  end if;
end;
$$;

create or replace function public.save_maraude_distribution_v2(
  requested_concert_id uuid,
  requested_collected_boxes integer,
  requested_distributed_boxes integer,
  requested_remaining_boxes integer,
  requested_beneficiaries integer,
  requested_comment text default null
)
returns setof public.maraude_distributions
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.can_edit_maraude_operations(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Vous ne pouvez pas modifier cette distribution'
      using errcode = '42501';
  end if;
  if requested_collected_boxes is null or requested_collected_boxes < 0
    or requested_distributed_boxes is null or requested_distributed_boxes < 0
    or requested_remaining_boxes is null or requested_remaining_boxes < 0
    or requested_beneficiaries is null or requested_beneficiaries < 0
  then
    raise exception 'Les quantités doivent être positives ou nulles'
      using errcode = '22023';
  end if;
  if requested_distributed_boxes + requested_remaining_boxes
    <> requested_collected_boxes
  then
    raise exception 'Le total distribué et restant doit correspondre à la collecte'
      using errcode = '22023';
  end if;
  if requested_collected_boxes <> coalesce((
    select sum(collection.quantity)::integer
    from public.maraude_collections collection
    where collection.concert_id = requested_concert_id
      and collection.unit = 'box'::public.collection_unit
  ), 0) then
    raise exception 'Le nombre de boîtes collectées est incohérent'
      using errcode = '22023';
  end if;

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
    requested_collected_boxes,
    requested_distributed_boxes,
    requested_remaining_boxes,
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

create or replace function public.record_maraude_equipment_return(
  requested_concert_id uuid,
  requested_returns jsonb default '[]'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  value jsonb;
  assignment public.maraude_equipment_allocations%rowtype;
  returned integer;
begin
  if not private.can_edit_maraude_operations(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Retour matériel non autorisé' using errcode = '42501';
  end if;

  for value in select * from jsonb_array_elements(requested_returns)
  loop
    returned := (value ->> 'returned_quantity')::integer;
    select * into assignment
    from public.maraude_equipment_allocations
    where id = (value ->> 'allocation_id')::uuid
      and concert_id = requested_concert_id
    for update;

    if assignment.id is null or returned is null or returned < 0
      or returned > coalesce(assignment.taken_quantity, 0)
    then
      raise exception 'Quantité retournée invalide' using errcode = '22023';
    end if;

    update public.maraude_equipment_allocations set
      returned_quantity = returned,
      incident_type = nullif(value ->> 'incident_type', '')::public.equipment_incident_type,
      incident_note = nullif(btrim(value ->> 'incident_note'), '')
    where id = assignment.id;
  end loop;
end;
$$;

revoke all on function public.validate_maraude_preparation(uuid, jsonb, jsonb)
from public, anon;
grant execute on function public.validate_maraude_preparation(uuid, jsonb, jsonb)
to authenticated;
revoke all on function public.validate_maraude_step(
  uuid, public.maraude_operational_step
) from public, anon;
grant execute on function public.validate_maraude_step(
  uuid, public.maraude_operational_step
) to authenticated;
revoke all on function public.complete_guided_maraude(uuid)
from public, anon;
grant execute on function public.complete_guided_maraude(uuid)
to authenticated;
revoke all on function public.plan_maraude_resources(uuid, jsonb, jsonb)
from public, anon;
grant execute on function public.plan_maraude_resources(uuid, jsonb, jsonb)
to authenticated;
revoke all on function public.save_maraude_collection_v2(
  uuid, uuid, text, integer, numeric, text
) from public, anon;
grant execute on function public.save_maraude_collection_v2(
  uuid, uuid, text, integer, numeric, text
) to authenticated;
revoke all on function public.save_maraude_distribution_v2(
  uuid, integer, integer, integer, integer, text
) from public, anon;
grant execute on function public.save_maraude_distribution_v2(
  uuid, integer, integer, integer, integer, text
) to authenticated;
revoke all on function public.record_maraude_equipment_return(uuid, jsonb)
from public, anon;
grant execute on function public.record_maraude_equipment_return(uuid, jsonb)
to authenticated;

create or replace function public.get_maraude_operation_bundle(
  requested_concert_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.can_view_maraude_operations(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Maraude inaccessible' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'operation', (
      select to_jsonb(operation)
      from public.maraude_operations operation
      where operation.concert_id = requested_concert_id
    ),
    'consumables', coalesce((
      select jsonb_agg(
        to_jsonb(allocation) || jsonb_build_object(
          'name', item.name,
          'unit', item.unit,
          'available_quantity', item.current_quantity
        ) order by item.name
      )
      from public.maraude_consumable_allocations allocation
      join public.consumables item on item.id = allocation.consumable_id
      where allocation.concert_id = requested_concert_id
    ), '[]'::jsonb),
    'equipment', coalesce((
      select jsonb_agg(
        to_jsonb(allocation) || jsonb_build_object(
          'name', asset.name,
          'status', asset.status,
          'quantity_total', asset.quantity_total,
          'location_name', location.name
        ) order by asset.name
      )
      from public.maraude_equipment_allocations allocation
      join public.equipment_assets asset on asset.id = allocation.equipment_id
      left join public.equipment_locations location on location.id = asset.location_id
      where allocation.concert_id = requested_concert_id
    ), '[]'::jsonb),
    'collections', coalesce((
      select jsonb_agg(to_jsonb(collection) order by collection.created_at)
      from public.maraude_collections collection
      where collection.concert_id = requested_concert_id
    ), '[]'::jsonb),
    'distribution', (
      select to_jsonb(distribution)
      from public.maraude_distributions distribution
      where distribution.concert_id = requested_concert_id
    ),
    'history', coalesce((
      select jsonb_agg(to_jsonb(event) order by event.created_at desc)
      from public.maraude_step_events event
      where event.concert_id = requested_concert_id
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_maraude_operation_bundle(uuid)
from public, anon;
grant execute on function public.get_maraude_operation_bundle(uuid)
to authenticated;

alter table public.consumables enable row level security;
alter table public.consumable_movements enable row level security;
alter table public.equipment_locations enable row level security;
alter table public.equipment_assets enable row level security;
alter table public.equipment_events enable row level security;
alter table public.maraude_consumable_allocations enable row level security;
alter table public.maraude_equipment_allocations enable row level security;
alter table public.maraude_operations enable row level security;
alter table public.maraude_step_events enable row level security;

create policy "Admins manage consumables"
on public.consumables for all to authenticated
using (private.is_club_sandwich_admin((select auth.uid())))
with check (private.is_club_sandwich_admin((select auth.uid())));

create policy "Admins view consumable movements"
on public.consumable_movements for select to authenticated
using (private.is_club_sandwich_admin((select auth.uid())));

create policy "Admins manage equipment locations"
on public.equipment_locations for all to authenticated
using (private.is_club_sandwich_admin((select auth.uid())))
with check (private.is_club_sandwich_admin((select auth.uid())));

create policy "Admins manage equipment assets"
on public.equipment_assets for all to authenticated
using (private.is_club_sandwich_admin((select auth.uid())))
with check (private.is_club_sandwich_admin((select auth.uid())));

create policy "Admins view equipment events"
on public.equipment_events for select to authenticated
using (private.is_club_sandwich_admin((select auth.uid())));

create policy "Team views maraude consumables"
on public.maraude_consumable_allocations for select to authenticated
using (private.can_view_maraude_operations(concert_id, (select auth.uid())));

create policy "Admins plan maraude consumables"
on public.maraude_consumable_allocations for all to authenticated
using (private.is_club_sandwich_admin((select auth.uid())))
with check (private.is_club_sandwich_admin((select auth.uid())));

create policy "Team views maraude equipment"
on public.maraude_equipment_allocations for select to authenticated
using (private.can_view_maraude_operations(concert_id, (select auth.uid())));

create policy "Admins plan maraude equipment"
on public.maraude_equipment_allocations for all to authenticated
using (private.is_club_sandwich_admin((select auth.uid())))
with check (private.is_club_sandwich_admin((select auth.uid())));

create policy "Team views maraude operation"
on public.maraude_operations for select to authenticated
using (private.can_view_maraude_operations(concert_id, (select auth.uid())));

create policy "Team views maraude step history"
on public.maraude_step_events for select to authenticated
using (private.can_view_maraude_operations(concert_id, (select auth.uid())));

revoke all on public.consumables from anon, authenticated;
revoke all on public.consumable_movements from anon, authenticated;
revoke all on public.equipment_locations from anon, authenticated;
revoke all on public.equipment_assets from anon, authenticated;
revoke all on public.equipment_events from anon, authenticated;
revoke all on public.maraude_consumable_allocations from anon, authenticated;
revoke all on public.maraude_equipment_allocations from anon, authenticated;
revoke all on public.maraude_operations from anon, authenticated;
revoke all on public.maraude_step_events from anon, authenticated;

grant select, insert, update, delete on public.consumables to authenticated;
grant select on public.consumable_movements to authenticated;
grant select, insert, update, delete on public.equipment_locations to authenticated;
grant select, insert, update, delete on public.equipment_assets to authenticated;
grant select on public.equipment_events to authenticated;
grant select, insert, update, delete on public.maraude_consumable_allocations
to authenticated;
grant select, insert, update, delete on public.maraude_equipment_allocations
to authenticated;
grant select on public.maraude_operations to authenticated;
grant select on public.maraude_step_events to authenticated;

drop policy if exists "Authorized team creates collections"
on public.maraude_collections;
drop policy if exists "Authorized team updates collections"
on public.maraude_collections;
drop policy if exists "Authorized team deletes collections"
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

drop policy if exists "Club Sandwich admins can create distribution"
on public.maraude_distributions;
drop policy if exists "Club Sandwich admins can update distribution"
on public.maraude_distributions;

create policy "Operational team creates distribution"
on public.maraude_distributions for insert to authenticated
with check (
  private.can_edit_maraude_operations(concert_id, (select auth.uid()))
);

create policy "Operational team updates distribution"
on public.maraude_distributions for update to authenticated
using (private.can_edit_maraude_operations(concert_id, (select auth.uid())))
with check (private.can_edit_maraude_operations(concert_id, (select auth.uid())));

create policy "Assigned team views distribution"
on public.maraude_distributions for select to authenticated
using (private.can_view_maraude_operations(concert_id, (select auth.uid())));

alter publication supabase_realtime add table public.maraude_operations;
alter publication supabase_realtime add table public.maraude_step_events;
alter publication supabase_realtime add table public.maraude_consumable_allocations;
alter publication supabase_realtime add table public.maraude_equipment_allocations;
alter publication supabase_realtime add table public.maraude_collections;
alter publication supabase_realtime add table public.maraude_distributions;
