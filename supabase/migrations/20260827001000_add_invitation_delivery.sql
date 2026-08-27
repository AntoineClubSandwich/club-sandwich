-- Lets a tourneur hand a validated invitation applicant their actual
-- invitation: upload a file (image/PDF), mark them "on the guest list"
-- with no file needed, or both — then send it by email in one click,
-- reusing the existing Brevo-backed workflow_email_deliveries pipeline.

alter table public.invitation_applications
  add column invitation_file_path text,
  add column on_guest_list boolean not null default false,
  add column invitation_sent_at timestamptz;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'invitation-files',
  'invitation-files',
  false,
  10485760,
  array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Promoters and admins upload invitation files"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'invitation-files'
  and exists (
    select 1
    from public.invitation_applications application
    join public.invitation_campaigns campaign
      on campaign.id = application.campaign_id
    where application.id = ((storage.foldername(name))[1])::uuid
      and (
        private.is_promoter_account_member(
          campaign.organization_id, (select auth.uid())
        )
        or private.is_club_sandwich_admin((select auth.uid()))
      )
  )
);

create policy "Promoters and admins update invitation files"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'invitation-files'
  and exists (
    select 1
    from public.invitation_applications application
    join public.invitation_campaigns campaign
      on campaign.id = application.campaign_id
    where application.id = ((storage.foldername(name))[1])::uuid
      and (
        private.is_promoter_account_member(
          campaign.organization_id, (select auth.uid())
        )
        or private.is_club_sandwich_admin((select auth.uid()))
      )
  )
)
with check (
  bucket_id = 'invitation-files'
  and exists (
    select 1
    from public.invitation_applications application
    join public.invitation_campaigns campaign
      on campaign.id = application.campaign_id
    where application.id = ((storage.foldername(name))[1])::uuid
      and (
        private.is_promoter_account_member(
          campaign.organization_id, (select auth.uid())
        )
        or private.is_club_sandwich_admin((select auth.uid()))
      )
  )
);

create policy "Applicants, promoters and admins read invitation files"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'invitation-files'
  and exists (
    select 1
    from public.invitation_applications application
    join public.invitation_campaigns campaign
      on campaign.id = application.campaign_id
    where application.id = ((storage.foldername(name))[1])::uuid
      and (
        application.user_id = (select auth.uid())
        or private.is_promoter_account_member(
          campaign.organization_id, (select auth.uid())
        )
        or private.is_club_sandwich_admin((select auth.uid()))
      )
  )
);

create policy "Promoters and admins delete invitation files"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'invitation-files'
  and exists (
    select 1
    from public.invitation_applications application
    join public.invitation_campaigns campaign
      on campaign.id = application.campaign_id
    where application.id = ((storage.foldername(name))[1])::uuid
      and (
        private.is_promoter_account_member(
          campaign.organization_id, (select auth.uid())
        )
        or private.is_club_sandwich_admin((select auth.uid()))
      )
  )
);

create function public.set_invitation_delivery(
  requested_application_id uuid,
  requested_file_path text default null,
  requested_on_guest_list boolean default false
)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  campaign_organization_id uuid;
  application_status public.invitation_application_status;
begin
  select campaign.organization_id, application.status
  into campaign_organization_id, application_status
  from public.invitation_applications application
  join public.invitation_campaigns campaign
    on campaign.id = application.campaign_id
  where application.id = requested_application_id;

  if campaign_organization_id is null then
    raise exception 'Candidature introuvable' using errcode = 'P0002';
  end if;

  if not (
    private.is_promoter_account_member(
      campaign_organization_id, (select auth.uid())
    )
    or private.is_club_sandwich_admin((select auth.uid()))
  ) then
    raise exception 'Accès non autorisé' using errcode = '42501';
  end if;

  if application_status <> 'selected'::public.invitation_application_status
  then
    raise exception 'Seuls les bénévoles retenus peuvent recevoir une invitation'
      using errcode = '22023';
  end if;

  update public.invitation_applications
  set
    invitation_file_path = requested_file_path,
    on_guest_list = requested_on_guest_list,
    updated_at = now()
  where id = requested_application_id;
end;
$$;

revoke all on function public.set_invitation_delivery(uuid, text, boolean)
  from public, anon;
grant execute on function public.set_invitation_delivery(uuid, text, boolean)
  to authenticated;

create function public.send_invitation_delivery_email(
  requested_application_id uuid
)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  campaign_organization_id uuid;
  campaign_title text;
  target_user_id uuid;
  has_file boolean;
  is_on_list boolean;
begin
  select
    campaign.organization_id, campaign.title, application.user_id,
    application.invitation_file_path is not null, application.on_guest_list
  into
    campaign_organization_id, campaign_title, target_user_id,
    has_file, is_on_list
  from public.invitation_applications application
  join public.invitation_campaigns campaign
    on campaign.id = application.campaign_id
  where application.id = requested_application_id;

  if campaign_organization_id is null then
    raise exception 'Candidature introuvable' using errcode = 'P0002';
  end if;

  if not (
    private.is_promoter_account_member(
      campaign_organization_id, (select auth.uid())
    )
    or private.is_club_sandwich_admin((select auth.uid()))
  ) then
    raise exception 'Accès non autorisé' using errcode = '42501';
  end if;

  if not has_file and not is_on_list then
    raise exception
      'Déposez un fichier ou cochez « Sur liste » avant d’envoyer'
      using errcode = '22023';
  end if;

  perform private.notify_user(
    target_user_id,
    null,
    'invitation_delivered',
    'Votre invitation est prête',
    format(
      'Votre invitation pour « %s » est disponible. '
      || 'Connectez-vous pour la consulter.',
      campaign_title
    )
  );

  update public.invitation_applications
  set invitation_sent_at = clock_timestamp()
  where id = requested_application_id;
end;
$$;

revoke all on function public.send_invitation_delivery_email(uuid)
  from public, anon;
grant execute on function public.send_invitation_delivery_email(uuid)
  to authenticated;
