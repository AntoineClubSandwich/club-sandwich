alter table public.invitation_campaigns
  add column venue_id uuid
    references public.venues(id) on delete restrict;

create index invitation_campaigns_venue_id_idx
on public.invitation_campaigns (venue_id);

alter table public.invitation_campaigns
  add constraint invitation_campaigns_venue_required
  check (venue_id is not null) not valid;

comment on column public.invitation_campaigns.venue_id is
  'Salle obligatoire pour toute nouvelle campagne. La contrainte NOT VALID '
  'préserve les campagnes historiques créées avant cette migration.';
