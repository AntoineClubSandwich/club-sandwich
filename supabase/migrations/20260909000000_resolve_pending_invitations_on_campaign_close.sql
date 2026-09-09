-- Reported live on preprod: a volunteer's invitation application stayed
-- "En attente" (pending) forever after the campaign it belonged to was
-- closed. Cause: set_invitation_campaign_status only ever flipped
-- invitation_campaigns.status - nothing resolved the applications that
-- were still pending at that point, and a closed/cancelled campaign
-- never reopens to make that decision. Anyone not explicitly selected
-- before closing was left stuck watching "votre candidature attend une
-- décision" indefinitely.
--
-- Fixed at the close/cancel step: any still-pending application is
-- resolved to not_selected. That alone wasn't enough to notify them
-- though - notify_invitation_application_changes only fired
-- 'invitation_not_selected' for a selected -> not_selected transition
-- ("you were in, but didn't confirm in time"), which doesn't fit
-- "you applied and nobody ever picked you". Extended to also cover
-- pending -> not_selected with wording that matches that case.

create or replace function public.set_invitation_campaign_status(
  requested_campaign_id uuid,
  requested_status public.invitation_campaign_status
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target public.invitation_campaigns%rowtype;
begin
  select *
  into target
  from public.invitation_campaigns
  where id = requested_campaign_id
  for update;

  if target.id is null then
    raise exception 'Campagne d’invitations introuvable.'
      using errcode = 'P0002';
  end if;

  if not (
    private.is_club_sandwich_admin((select auth.uid()))
    or private.is_promoter_account_member(
      target.organization_id,
      (select auth.uid())
    )
  ) then
    raise exception
      'Seul un administrateur ou le tourneur associé peut modifier '
      'le statut de cette campagne.'
      using errcode = '42501';
  end if;

  if target.status in (
    'closed'::public.invitation_campaign_status,
    'cancelled'::public.invitation_campaign_status
  ) then
    raise exception
      'Cette campagne est déjà clôturée ou annulée et ne peut plus être '
      'modifiée.'
      using errcode = '22023';
  end if;

  if requested_status not in (
    'open'::public.invitation_campaign_status,
    'closed'::public.invitation_campaign_status,
    'cancelled'::public.invitation_campaign_status
  ) then
    raise exception 'Ce statut de campagne n’est pas pris en charge.'
      using errcode = '22023';
  end if;

  if target.status = 'draft'::public.invitation_campaign_status
    and requested_status = 'closed'::public.invitation_campaign_status
  then
    raise exception
      'Une campagne en brouillon doit d’abord être ouverte avant de '
      'pouvoir être clôturée.'
      using errcode = '22023';
  end if;

  if target.status = 'open'::public.invitation_campaign_status
    and requested_status = 'open'::public.invitation_campaign_status
  then
    return;
  end if;

  update public.invitation_campaigns
  set
    status = requested_status,
    updated_at = now()
  where id = requested_campaign_id;

  if requested_status in (
    'closed'::public.invitation_campaign_status,
    'cancelled'::public.invitation_campaign_status
  ) then
    update public.invitation_applications
    set status = 'not_selected'::public.invitation_application_status
    where campaign_id = requested_campaign_id
      and status = 'pending'::public.invitation_application_status;
  end if;
end;
$$;

revoke all on function public.set_invitation_campaign_status(
  uuid,
  public.invitation_campaign_status
) from public, anon;
grant execute on function public.set_invitation_campaign_status(
  uuid,
  public.invitation_campaign_status
) to authenticated;

create or replace function private.notify_invitation_application_changes()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  campaign_title text;
begin
  if new.status is distinct from old.status then
    select campaign.title into campaign_title
    from public.invitation_campaigns campaign
    where campaign.id = new.campaign_id;

    if new.status = 'selected'::public.invitation_application_status then
      perform private.notify_user(
        new.user_id,
        null,
        'invitation_selected',
        'Invitation attribuée',
        format(
          'Vous avez obtenu une invitation pour « %s ». '
          || 'Confirmez votre participation avant le %s.',
          campaign_title,
          to_char(new.confirmation_due_at, 'DD/MM/YYYY à HH24:MI')
        )
      );
    elsif new.status = 'not_selected'::public.invitation_application_status
    then
      if old.status = 'selected'::public.invitation_application_status then
        perform private.notify_user(
          new.user_id,
          null,
          'invitation_not_selected',
          'Invitation non retenue',
          format(
            'Votre invitation pour « %s » n’a pas été confirmée à temps '
            || 'ou a été retirée.',
            campaign_title
          )
        );
      elsif old.status = 'pending'::public.invitation_application_status
      then
        perform private.notify_user(
          new.user_id,
          null,
          'invitation_not_selected',
          'Invitation non retenue',
          format(
            'Votre candidature pour « %s » n’a pas été retenue.',
            campaign_title
          )
        );
      end if;
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.notify_invitation_application_changes()
from public, anon, authenticated;

-- One-time backfill: resolve applications already stuck pending under a
-- campaign that's already closed/cancelled (this session's "M" campaign
-- included) - the fix above only prevents new occurrences. Firing the
-- notify trigger here is correct, not a side effect to avoid: these
-- applicants were genuinely waiting on a decision, so telling them now
-- is the point.
update public.invitation_applications application
set status = 'not_selected'::public.invitation_application_status
from public.invitation_campaigns campaign
where campaign.id = application.campaign_id
  and application.status = 'pending'::public.invitation_application_status
  and campaign.status in (
    'closed'::public.invitation_campaign_status,
    'cancelled'::public.invitation_campaign_status
  );
