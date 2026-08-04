-- Remplace le lien photo unique (une seule photo, écrasée à chaque envoi,
-- jamais réellement affichée, jamais supprimable) par une véritable
-- galerie : jusqu'à 5 photos par maraude, ajoutées par le rôle "Chargé de
-- communication" (ou un admin), chacune supprimable par son auteur ou un
-- admin.

create table public.maraude_photos (
  id uuid primary key default gen_random_uuid(),
  concert_id uuid not null
    references public.concerts(id) on delete cascade,
  uploaded_by uuid not null
    references public.profiles(id) on delete cascade,
  storage_path text not null unique,
  created_at timestamptz not null default now()
);

create index maraude_photos_concert_idx
on public.maraude_photos (concert_id, created_at);

alter table public.maraude_photos enable row level security;
revoke all on public.maraude_photos from anon, authenticated;
grant select on public.maraude_photos to authenticated;

create policy "Authorized maraude members read photo rows"
on public.maraude_photos
for select
to authenticated
using (
  private.is_club_sandwich_admin((select auth.uid()))
  or exists (
    select 1
    from public.concert_volunteers application
    where application.concert_id = maraude_photos.concert_id
      and application.user_id = (select auth.uid())
      and application.status = 'selected'::public.concert_volunteer_status
      and application.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
  )
);

create function private.can_manage_maraude_photos(
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
      from public.concert_volunteers application
      where application.concert_id = requested_concert_id
        and application.user_id = requested_user_id
        and application.status =
          'selected'::public.concert_volunteer_status
        and application.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
        and application.team_role =
          'communication'::public.maraude_role
    );
$$;

create function public.add_maraude_photo(
  requested_concert_id uuid,
  requested_storage_path text
)
returns public.maraude_photos
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  created_row public.maraude_photos;
  current_count integer;
begin
  if not private.can_manage_maraude_photos(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Vous ne pouvez pas ajouter de photo à cette maraude'
      using errcode = '42501';
  end if;

  select count(*)
  into current_count
  from public.maraude_photos
  where concert_id = requested_concert_id;

  if current_count >= 5 then
    raise exception 'Cinq photos au maximum par maraude'
      using errcode = '22023';
  end if;

  insert into public.maraude_photos (
    concert_id,
    uploaded_by,
    storage_path
  )
  values (
    requested_concert_id,
    (select auth.uid()),
    requested_storage_path
  )
  returning * into created_row;

  return created_row;
end;
$$;

revoke all on function public.add_maraude_photo(uuid, text)
  from public, anon;
grant execute on function public.add_maraude_photo(uuid, text)
  to authenticated;

create function public.delete_maraude_photo(
  requested_photo_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target public.maraude_photos%rowtype;
begin
  select *
  into target
  from public.maraude_photos
  where id = requested_photo_id
  for update;

  if target.id is null then
    raise exception 'Photo introuvable' using errcode = 'P0002';
  end if;

  if not (
    private.is_club_sandwich_admin((select auth.uid()))
    or target.uploaded_by = (select auth.uid())
  ) then
    raise exception 'Vous ne pouvez pas supprimer cette photo'
      using errcode = '42501';
  end if;

  delete from public.maraude_photos where id = requested_photo_id;
end;
$$;

revoke all on function public.delete_maraude_photo(uuid)
  from public, anon;
grant execute on function public.delete_maraude_photo(uuid)
  to authenticated;

comment on table public.maraude_photos is
  'Galerie de photos par maraude (5 maximum), ajoutées par le rôle '
  'communication ou un admin, à l’exclusion du lien unique historique.';

-- L’ancien lien photo unique est remplacé par la galerie ci-dessus.
drop function if exists public.update_maraude_photo_link(uuid, text);

drop function if exists public.save_maraude_report(
  uuid, numeric, integer, text, text, boolean
);

create function public.save_maraude_report(
  requested_concert_id uuid,
  requested_total_weight_kg numeric,
  requested_estimated_meals integer,
  requested_comment text default null,
  requested_complete boolean default true
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  changed_at timestamptz := clock_timestamp();
begin
  if requested_total_weight_kg is null or requested_total_weight_kg < 0 then
    raise exception 'Le poids doit être positif ou nul'
      using errcode = '22023';
  end if;

  if requested_estimated_meals is null or requested_estimated_meals < 0 then
    raise exception 'Le nombre de repas doit être positif ou nul'
      using errcode = '22023';
  end if;

  perform 1
  from public.concerts c
  where c.id = requested_concert_id
    and private.is_organization_member(
      c.organization_id,
      (select auth.uid())
    )
  for update;

  if not found then
    raise exception 'Concert inaccessible'
      using errcode = '42501';
  end if;

  if not private.can_edit_maraude_report(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Vous ne pouvez pas modifier ce compte rendu'
      using errcode = '42501';
  end if;

  insert into public.maraude_operational_reports (
    concert_id,
    total_weight_kg,
    estimated_meals,
    comment,
    last_modified_by
  )
  values (
    requested_concert_id,
    requested_total_weight_kg,
    requested_estimated_meals,
    nullif(btrim(requested_comment), ''),
    (select auth.uid())
  )
  on conflict (concert_id) do update
  set
    total_weight_kg = excluded.total_weight_kg,
    estimated_meals = excluded.estimated_meals,
    comment = excluded.comment,
    last_modified_by = excluded.last_modified_by;

  if requested_complete then
    update public.concerts
    set
      maraude_status = 'completed'::public.maraude_status,
      actual_start_at = coalesce(actual_start_at, changed_at),
      actual_end_at = greatest(
        changed_at,
        coalesce(actual_start_at, changed_at)
      )
    where id = requested_concert_id;
  end if;
end;
$$;

revoke all on function public.save_maraude_report(
  uuid, numeric, integer, text, boolean
) from public, anon;
grant execute on function public.save_maraude_report(
  uuid, numeric, integer, text, boolean
) to authenticated;

drop function if exists public.save_maraude_operational_report_v2(
  uuid, numeric, numeric, boolean, text, text
);

create function public.save_maraude_operational_report_v2(
  requested_concert_id uuid,
  requested_total_weight_kg numeric,
  requested_distance_km numeric,
  requested_quantities_unavailable boolean,
  requested_comment text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if requested_quantities_unavailable is not true
    and requested_total_weight_kg is null
  then
    raise exception 'Le poids doit être renseigné'
      using errcode = '22023';
  end if;

  if requested_total_weight_kg is not null
    and requested_total_weight_kg < 0
  then
    raise exception 'Le poids doit être positif ou nul'
      using errcode = '22023';
  end if;

  if requested_distance_km is not null
    and requested_distance_km < 0
  then
    raise exception 'La distance doit être positive ou nulle'
      using errcode = '22023';
  end if;

  if not private.can_edit_maraude_report(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Vous ne pouvez pas modifier ce compte rendu'
      using errcode = '42501';
  end if;

  insert into public.maraude_operational_reports (
    concert_id,
    total_weight_kg,
    estimated_meals,
    distance_km,
    quantities_unavailable,
    comment,
    last_modified_by
  )
  values (
    requested_concert_id,
    case
      when requested_quantities_unavailable then null
      else requested_total_weight_kg
    end,
    null,
    requested_distance_km,
    requested_quantities_unavailable,
    nullif(btrim(requested_comment), ''),
    (select auth.uid())
  )
  on conflict (concert_id) do update
  set
    total_weight_kg = excluded.total_weight_kg,
    estimated_meals = excluded.estimated_meals,
    distance_km = excluded.distance_km,
    quantities_unavailable = excluded.quantities_unavailable,
    comment = excluded.comment,
    last_modified_by = excluded.last_modified_by;
end;
$$;

revoke all on function public.save_maraude_operational_report_v2(
  uuid, numeric, numeric, boolean, text
) from public, anon;
grant execute on function public.save_maraude_operational_report_v2(
  uuid, numeric, numeric, boolean, text
) to authenticated;

alter table public.maraude_operational_reports
  drop column if exists photo_folder_url;

-- Le stockage suit désormais les mêmes règles que la table : seul le
-- rôle communication (ou un admin) peut ajouter, l’auteur ou un admin
-- peut supprimer. Auparavant, tout membre confirmé pouvait envoyer une
-- photo et personne ne pouvait en supprimer.
drop policy if exists "Authorized maraude members upload photos"
on storage.objects;

create policy "Communication role uploads maraude photos"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'maraude-photos'
  and private.can_manage_maraude_photos(
    ((storage.foldername(name))[1])::uuid,
    (select auth.uid())
  )
);

create policy "Photo authors or admins delete maraude photos"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'maraude-photos'
  and (
    private.is_club_sandwich_admin((select auth.uid()))
    or (storage.foldername(name))[2] = (select auth.uid())::text
  )
);
