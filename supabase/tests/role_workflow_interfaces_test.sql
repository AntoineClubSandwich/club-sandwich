begin;

create extension if not exists pgtap with schema extensions;

select plan(3);

select has_function(
  'public',
  'set_invitation_campaign_status',
  array['uuid', 'invitation_campaign_status'],
  'Le cycle de vie des campagnes est piloté par une RPC sécurisée'
);

select ok(
  position(
    'confirmation_status' in pg_get_functiondef(
      'private.can_access_maraude_chat(uuid,uuid)'::regprocedure
    )
  ) > 0,
  'Le chat vérifie la confirmation du bénévole sélectionné'
);

select ok(
  exists (
    select 1
    from information_schema.parameters parameter
    join information_schema.routines routine
      on routine.specific_schema = parameter.specific_schema
      and routine.specific_name = parameter.specific_name
    where routine.routine_schema = 'public'
      and routine.routine_name = 'get_maraude_overview'
      and parameter.parameter_name = 'pending_credit_validation_count'
  ),
  'Le dashboard reçoit le nombre de crédits restant à valider'
);

select * from finish();

rollback;
