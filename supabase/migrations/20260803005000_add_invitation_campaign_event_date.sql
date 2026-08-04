alter table public.invitation_campaigns
  add column event_date date;

create index invitation_campaigns_event_date_idx
on public.invitation_campaigns (event_date)
where event_date is not null;
