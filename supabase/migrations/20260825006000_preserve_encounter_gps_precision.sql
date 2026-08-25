alter table public.encounters
  alter column latitude type double precision
    using latitude::double precision,
  alter column longitude type double precision
    using longitude::double precision;

comment on table public.encounters is
  'Rencontres terrain géolocalisées. Aucune donnée sur les bénéficiaires.';
comment on column public.encounters.latitude is
  'Latitude GPS transmise par l’appareil, conservée sans arrondi volontaire.';
comment on column public.encounters.longitude is
  'Longitude GPS transmise par l’appareil, conservée sans arrondi volontaire.';
comment on column public.encounters.accuracy is
  'Précision en mètres annoncée par l’appareil au moment de la saisie.';

create or replace function public.record_maraude_encounter(
  requested_maraude_id uuid,
  requested_latitude double precision,
  requested_longitude double precision,
  requested_accuracy double precision
)
returns public.encounters
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  saved public.encounters;
begin
  if requested_latitude is null
    or requested_latitude < -90
    or requested_latitude > 90
    or requested_longitude is null
    or requested_longitude < -180
    or requested_longitude > 180
  then
    raise exception 'Position GPS invalide' using errcode = '22023';
  end if;

  if requested_accuracy is null
    or requested_accuracy < 0
    or requested_accuracy > 25
  then
    raise exception 'Précision GPS insuffisante' using errcode = '22023';
  end if;

  insert into public.encounters (
    maraude_id,
    created_by,
    latitude,
    longitude,
    accuracy
  )
  values (
    requested_maraude_id,
    (select auth.uid()),
    requested_latitude,
    requested_longitude,
    round(requested_accuracy::numeric, 2)
  )
  returning * into saved;

  return saved;
end;
$$;

comment on function public.record_maraude_encounter(
  uuid, double precision, double precision, double precision
) is
  'Enregistre une rencontre uniquement avec une position GPS précise (25 m maximum), sans arrondir ses coordonnées.';

revoke all on function public.record_maraude_encounter(
  uuid,
  double precision,
  double precision,
  double precision
) from public, anon;
grant execute on function public.record_maraude_encounter(
  uuid,
  double precision,
  double precision,
  double precision
) to authenticated;
