begin;

create extension if not exists pgtap with schema extensions;

select plan(2);

select has_column(
  'public',
  'invitation_campaigns',
  'event_date',
  'Une campagne peut porter la date de l’événement, pour l’affichage calendrier'
);

select col_type_is(
  'public',
  'invitation_campaigns',
  'event_date',
  'date',
  'La date d’événement ne porte pas d’heure'
);

select * from finish();

rollback;
