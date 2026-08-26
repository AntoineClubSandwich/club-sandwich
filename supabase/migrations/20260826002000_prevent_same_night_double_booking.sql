-- Un bénévole ne peut pas être sélectionné sur deux maraudes le même soir :
-- il ne peut physiquement en assurer qu'une. Le blocage porte uniquement sur
-- la sélection (statut "selected"), pas sur la simple candidature.

create function private.prevent_same_night_double_booking()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  target_date date;
begin
  select concert.concert_date into target_date
  from public.concerts concert
  where concert.id = new.concert_id;

  if exists (
    select 1
    from public.concert_volunteers other
    join public.concerts other_concert on other_concert.id = other.concert_id
    where other.user_id = new.user_id
      and other.id <> new.id
      and other.status = 'selected'::public.concert_volunteer_status
      and other.concert_id <> new.concert_id
      and other_concert.concert_date = target_date
      and other_concert.maraude_status <> 'cancelled'::public.maraude_status
  ) then
    raise exception
      'Ce bénévole est déjà positionné sur une autre maraude le même soir.'
      using errcode = '22023';
  end if;

  return new;
end;
$$;

create trigger concert_volunteers_prevent_same_night_double_booking
before insert or update of status on public.concert_volunteers
for each row
when (new.status = 'selected'::public.concert_volunteer_status)
execute function private.prevent_same_night_double_booking();
