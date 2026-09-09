-- Gestion complète du statut et de l'annulation des maraudes.
--
-- Réutilise l'existant au maximum : l'enum maraude_status a déjà la
-- forme voulue (draft/open/team_ready/in_progress/completed/cancelled),
-- set_maraude_status() gère déjà les transitions "normales" et accepte
-- déjà un motif d'annulation, concerts.cancellation_reason existe déjà.
-- Ce qui manquait : la valeur par défaut à la création (actuellement
-- 'open', pas 'draft'), une piste d'audit complète de l'annulation
-- (qui/quand/origine, pas seulement le motif), un point d'entrée dédié
-- à l'annulation (le dropdown générique laissait déjà passer 'cancelled'
-- sans confirmation ni notification ni motif obligatoire), le droit
-- d'annuler pour le tourneur (actuellement aucun), et la tâche J-3.
--
-- Deux chaînes de validation distinctes, confirmées par Antoine :
-- - "Confirmée" (team_ready) reste la validation manuelle admin
--   existante ("Valider l'équipe") - non touchée ici.
-- - Le contrôle J-3 ne regarde que le nombre brut de bénévoles
--   confirmés (n'importe lequel, pas besoin d'un chef d'équipe parmi
--   eux comme l'exige team_ready) - complètement indépendant du
--   statut de la maraude.
--
-- Écart assumé avec l'existant, signalé à Antoine : le tourneur pouvait
-- déjà publier lui-même un brouillon (20260828004000, ajouté
-- spécifiquement pour lui). Le cahier des charges est explicite -
-- "seul un administrateur peut ouvrir les inscriptions" - ce droit lui
-- est retiré ici ; il ne garde que le droit d'annuler.

-- 1. Une nouvelle maraude est "À confirmer" (draft), pas déjà ouverte.
alter table public.concerts
  alter column maraude_status set default 'draft'::public.maraude_status;

-- 2. Piste d'audit complète de l'annulation.
alter table public.concerts
  add column cancelled_at timestamptz,
  add column cancelled_by uuid references public.profiles(id) on delete set null,
  add column cancellation_origin text
    check (cancellation_origin in ('automatic', 'admin', 'promoter'));

alter table public.maraude_workflow_events
  drop constraint maraude_workflow_events_event_type_check;

alter table public.maraude_workflow_events
  add constraint maraude_workflow_events_event_type_check
  check (
    event_type in (
      'selection_requested',
      'status_changed',
      'role_changed',
      'confirmation_completed',
      'confirmation_expired',
      'attendance_changed',
      'attendance_corrected',
      'attendance_validated',
      'maraude_started',
      'maraude_completed',
      'credit_awarded',
      'credit_revoked',
      'schedule_changed',
      'maraude_cancelled',
      'urgent_staffing_alert'
    )
  );

-- 3. Le coeur de l'annulation, partagé par le point d'entrée manuel et
--    la tâche automatique : notifie AVANT de désinscrire tout le monde
--    (sinon plus personne à notifier une fois passé à "withdrawn"),
--    puis clôture les inscriptions, journalise, et prévient l'autre
--    partie (tourneur si annulation admin/auto, admins si annulation
--    tourneur).
create function private.cancel_maraude(
  requested_concert_id uuid,
  requested_reason text,
  requested_origin text,
  requested_actor uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_status public.maraude_status;
  concert_promoter_organization_id uuid;
  concert_artist text;
  concert_date_value date;
  concert_time_value time;
  clean_reason text := coalesce(nullif(btrim(requested_reason), ''), 'Non précisé');
  volunteer record;
  promoter_account record;
  volunteer_body text;
  admin_body text;
begin
  select
    concert.maraude_status,
    concert.promoter_organization_id,
    concert.artist,
    concert.concert_date,
    concert.concert_time
  into
    current_status,
    concert_promoter_organization_id,
    concert_artist,
    concert_date_value,
    concert_time_value
  from public.concerts concert
  where concert.id = requested_concert_id
  for update;

  if not found then
    raise exception 'Maraude introuvable' using errcode = 'P0002';
  end if;

  if current_status in (
    'completed'::public.maraude_status,
    'cancelled'::public.maraude_status
  ) then
    raise exception 'Cette maraude est déjà terminée ou annulée'
      using errcode = '22023';
  end if;

  volunteer_body := format(
    E'La maraude prévue le %s à %s pour %s a été annulée.\n\nMotif : %s\n\nVotre participation est automatiquement annulée. Aucune action supplémentaire n’est nécessaire.',
    to_char(concert_date_value, 'DD/MM/YYYY'),
    to_char(concert_time_value, 'HH24:MI'),
    concert_artist,
    clean_reason
  );
  admin_body := format(
    E'La maraude prévue le %s à %s pour %s a été annulée.\n\nMotif : %s',
    to_char(concert_date_value, 'DD/MM/YYYY'),
    to_char(concert_time_value, 'HH24:MI'),
    concert_artist,
    clean_reason
  );

  for volunteer in
    select distinct user_id
    from public.concert_volunteers
    where concert_id = requested_concert_id
      and status <> 'withdrawn'::public.concert_volunteer_status
  loop
    perform private.notify_user(
      volunteer.user_id,
      requested_concert_id,
      'maraude_cancelled',
      format('Maraude annulée — %s', concert_artist),
      volunteer_body
    );
  end loop;

  update public.concert_volunteers
  set status = 'withdrawn'::public.concert_volunteer_status
  where concert_id = requested_concert_id
    and status <> 'withdrawn'::public.concert_volunteer_status;

  update public.concerts
  set
    maraude_status = 'cancelled'::public.maraude_status,
    cancellation_reason = clean_reason,
    cancelled_at = clock_timestamp(),
    cancelled_by = requested_actor,
    cancellation_origin = requested_origin
  where id = requested_concert_id;

  insert into public.maraude_workflow_events (
    concert_id,
    event_type,
    actor_id,
    previous_value,
    new_value
  )
  values (
    requested_concert_id,
    'maraude_cancelled',
    requested_actor,
    jsonb_build_object('status', current_status),
    jsonb_build_object(
      'status', 'cancelled',
      'origin', requested_origin,
      'reason', clean_reason
    )
  );

  if requested_origin = 'promoter' then
    perform private.notify_active_admins(
      requested_concert_id,
      'maraude_cancelled',
      format('Maraude annulée — %s', concert_artist),
      admin_body
    );
  elsif concert_promoter_organization_id is not null then
    for promoter_account in
      select account.profile_id
      from public.user_accounts account
      where account.role = 'promoter'::public.app_role
        and account.status = 'active'::public.user_account_status
        and account.organization_id = concert_promoter_organization_id
    loop
      perform private.notify_user(
        promoter_account.profile_id,
        requested_concert_id,
        'maraude_cancelled',
        format('Maraude annulée — %s', concert_artist),
        admin_body
      );
    end loop;
  end if;
end;
$$;

revoke all on function private.cancel_maraude(uuid, text, text, uuid)
from public, anon, authenticated;

-- 4. Point d'entrée public : admin, ou tourneur responsable de cette
--    maraude (annulation uniquement - pas d'accès aux autres
--    transitions via cette fonction).
create function public.cancel_maraude(
  requested_concert_id uuid,
  requested_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor uuid := (select auth.uid());
  concert_promoter_organization_id uuid;
  is_admin boolean := private.is_club_sandwich_admin(actor);
  is_promoter boolean;
begin
  select concert.promoter_organization_id
  into concert_promoter_organization_id
  from public.concerts concert
  where concert.id = requested_concert_id;

  if not found then
    raise exception 'Maraude introuvable' using errcode = 'P0002';
  end if;

  is_promoter := private.is_promoter_account_member(
    concert_promoter_organization_id,
    actor
  );

  if not is_admin and not is_promoter then
    raise exception
      'Seul un administrateur ou le tourneur responsable peut annuler cette maraude'
      using errcode = '42501';
  end if;

  perform private.cancel_maraude(
    requested_concert_id,
    requested_reason,
    case when is_admin then 'admin' else 'promoter' end,
    actor
  );
end;
$$;

revoke all on function public.cancel_maraude(uuid, text) from public, anon;
grant execute on function public.cancel_maraude(uuid, text) to authenticated;

-- 5. set_maraude_status : n'accepte plus 'cancelled' (utiliser
--    cancel_maraude ci-dessus, qui garantit motif/audit/notifications),
--    n'autorise plus le tourneur à ouvrir les inscriptions lui-même
--    (écart avec 20260828004000, assumé et documenté en tête de
--    fichier), et signale aux admins une maraude ouverte déjà à moins
--    de J-3 (cas limite : ne pas l'annuler instantanément, mais
--    prévenir que c'est urgent).
create or replace function public.set_maraude_status(
  requested_concert_id uuid,
  requested_status public.maraude_status,
  requested_cancellation_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  changed_at timestamptz := clock_timestamp();
  current_status public.maraude_status;
  concert_artist text;
  concert_date_value date;
  concert_time_value time;
  is_admin boolean :=
    private.is_club_sandwich_admin((select auth.uid()));
  is_confirmed_team_leader boolean;
  confirmed_member_count integer;
  confirmed_leader_count integer;
begin
  if requested_status = 'cancelled'::public.maraude_status then
    raise exception
      'Utilisez cancel_maraude pour annuler une maraude'
      using errcode = '22023';
  end if;

  perform public.expire_volunteer_confirmations();

  select
    concert.maraude_status,
    concert.artist,
    concert.concert_date,
    concert.concert_time
  into
    current_status,
    concert_artist,
    concert_date_value,
    concert_time_value
  from public.concerts concert
  where concert.id = requested_concert_id
    and (
      (
        is_admin
        and private.is_organization_member(
          concert.organization_id,
          (select auth.uid())
        )
      )
      or exists (
        select 1
        from public.concert_volunteers leader
        where leader.concert_id = concert.id
          and leader.user_id = (select auth.uid())
          and leader.status =
            'selected'::public.concert_volunteer_status
          and leader.team_role = 'team_leader'::public.maraude_role
          and leader.confirmation_status =
            'confirmed'::public.volunteer_confirmation_status
      )
    )
  for update;

  if not found then
    raise exception 'Concert inaccessible' using errcode = '42501';
  end if;

  select exists (
    select 1
    from public.concert_volunteers leader
    where leader.concert_id = requested_concert_id
      and leader.user_id = (select auth.uid())
      and leader.status = 'selected'::public.concert_volunteer_status
      and leader.team_role = 'team_leader'::public.maraude_role
      and leader.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status
  )
  into is_confirmed_team_leader;

  if not is_admin and not (
    is_confirmed_team_leader
    and (
      (
        current_status = 'team_ready'::public.maraude_status
        and requested_status = 'in_progress'::public.maraude_status
      )
      or (
        current_status = 'in_progress'::public.maraude_status
        and requested_status = 'completed'::public.maraude_status
      )
    )
  ) then
    raise exception 'Action réservée au chef d''équipe'
      using errcode = '42501';
  end if;

  if requested_status = 'team_ready'::public.maraude_status then
    if current_status <> 'open'::public.maraude_status then
      raise exception 'Seule une maraude planifiée peut être validée'
        using errcode = '22023';
    end if;

    select
      count(*),
      count(*) filter (
        where application.team_role =
          'team_leader'::public.maraude_role
      )
    into confirmed_member_count, confirmed_leader_count
    from public.concert_volunteers application
    where application.concert_id = requested_concert_id
      and application.status =
        'selected'::public.concert_volunteer_status
      and application.confirmation_status =
        'confirmed'::public.volunteer_confirmation_status;

    if confirmed_member_count < 3 or confirmed_leader_count <> 1 then
      raise exception
        'Trois bénévoles confirmés sont requis, dont exactement un chef d’équipe'
        using errcode = '22023';
    end if;
  end if;

  if requested_status = 'in_progress'::public.maraude_status then
    if current_status not in (
      'open'::public.maraude_status,
      'team_ready'::public.maraude_status
    ) then
      raise exception 'Cette maraude ne peut pas être démarrée'
        using errcode = '22023';
    end if;

    if not exists (
      select 1
      from public.concert_volunteers leader
      where leader.concert_id = requested_concert_id
        and leader.status = 'selected'::public.concert_volunteer_status
        and leader.team_role = 'team_leader'::public.maraude_role
        and leader.confirmation_status =
          'confirmed'::public.volunteer_confirmation_status
    ) then
      raise exception 'Un chef d''équipe confirmé est requis'
        using errcode = '22023';
    end if;
  end if;

  if requested_status = 'completed'::public.maraude_status
    and current_status <> 'in_progress'::public.maraude_status
  then
    raise exception 'La maraude doit être en cours avant sa clôture'
      using errcode = '22023';
  end if;

  if current_status in (
    'completed'::public.maraude_status,
    'cancelled'::public.maraude_status
  ) and requested_status is distinct from current_status
  then
    raise exception 'Une maraude archivée ne peut plus changer d''état'
      using errcode = '22023';
  end if;

  update public.concerts
  set
    maraude_status = requested_status,
    actual_start_at = case
      when requested_status = 'in_progress'::public.maraude_status
        then coalesce(actual_start_at, changed_at)
      else actual_start_at
    end,
    actual_end_at = case
      when requested_status = 'completed'::public.maraude_status
        then greatest(changed_at, coalesce(actual_start_at, changed_at))
      else actual_end_at
    end
  where id = requested_concert_id;

  if requested_status in (
    'team_ready'::public.maraude_status,
    'in_progress'::public.maraude_status,
    'completed'::public.maraude_status
  ) and requested_status is distinct from current_status
  then
    insert into public.maraude_workflow_events (
      concert_id,
      event_type,
      actor_id,
      previous_value,
      new_value
    )
    values (
      requested_concert_id,
      case
        when requested_status = 'team_ready'::public.maraude_status
          then 'status_changed'
        when requested_status = 'in_progress'::public.maraude_status
          then 'maraude_started'
        else 'maraude_completed'
      end,
      (select auth.uid()),
      jsonb_build_object('status', current_status),
      jsonb_build_object('status', requested_status, 'at', changed_at)
    );
  end if;

  -- Cas limite : une maraude tout juste ouverte à moins de 3 jours de
  -- son horaire ne doit pas être annulée dans la foulée par la tâche
  -- J-3 sans que personne ne l'ait vu venir - prévenir tout de suite.
  if requested_status = 'open'::public.maraude_status
    and requested_status is distinct from current_status
    and (
      (concert_date_value + concert_time_value) at time zone 'Europe/Paris'
    ) <= changed_at + interval '3 days'
  then
    perform private.notify_active_admins(
      requested_concert_id,
      'urgent_staffing_alert',
      format('Décision urgente — %s', concert_artist),
      format(
        'La maraude %s a été ouverte à moins de 3 jours de son horaire. '
        || 'Si elle n’atteint pas 3 bénévoles confirmés à temps, elle '
        || 'sera automatiquement annulée à J-3. Vérifiez la situation '
        || 'rapidement.',
        concert_artist
      )
    );
  end if;
end;
$$;

revoke all on function public.set_maraude_status(
  uuid, public.maraude_status, text
) from public, anon;
grant execute on function public.set_maraude_status(
  uuid, public.maraude_status, text
) to authenticated;

-- 6. Tâche planifiée J-3 : ne regarde que le nombre brut de bénévoles
--    confirmés, indépendamment de team_ready. Idempotente par
--    construction - une maraude déjà annulée sort du filtre
--    maraude_status au prochain passage, donc jamais retraitée ni
--    renotifiée. for update skip locked protège contre un
--    chevauchement avec une annulation manuelle simultanée ; le bloc
--    exception protège le reste du lot si private.cancel_maraude
--    échoue sur une ligne donnée (déjà traitée entre-temps).
create function private.auto_cancel_understaffed_maraudes()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  candidate record;
  confirmed_count integer;
  cancelled_count integer := 0;
begin
  for candidate in
    select concert.id
    from public.concerts concert
    where concert.maraude_status in (
      'draft'::public.maraude_status,
      'open'::public.maraude_status,
      'team_ready'::public.maraude_status
    )
    and (
      (concert.concert_date + concert.concert_time) at time zone 'Europe/Paris'
    ) <= clock_timestamp() + interval '3 days'
    and (
      (concert.concert_date + concert.concert_time) at time zone 'Europe/Paris'
    ) > clock_timestamp()
    for update of concert skip locked
  loop
    select count(distinct user_id)
    into confirmed_count
    from public.concert_volunteers
    where concert_id = candidate.id
      and status = 'selected'::public.concert_volunteer_status
      and confirmation_status = 'confirmed'::public.volunteer_confirmation_status;

    if confirmed_count < 3 then
      begin
        perform private.cancel_maraude(
          candidate.id,
          'Nombre insuffisant de bénévoles à J-3',
          'automatic',
          null
        );
        cancelled_count := cancelled_count + 1;
      exception when others then
        -- Déjà traitée par ailleurs (annulation manuelle concurrente,
        -- par exemple) - ne bloque pas le reste du lot.
        null;
      end;
    end if;
  end loop;

  return cancelled_count;
end;
$$;

revoke all on function private.auto_cancel_understaffed_maraudes()
from public, anon, authenticated;

do $$
declare
  existing_job_id bigint;
begin
  select jobid into existing_job_id
  from cron.job
  where jobname = 'auto-cancel-understaffed-maraudes';

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'auto-cancel-understaffed-maraudes',
    '*/15 * * * *',
    'select private.auto_cancel_understaffed_maraudes();'
  );
end;
$$;
