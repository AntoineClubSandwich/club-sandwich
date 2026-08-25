-- Normalise les identités visibles des comptes de recette existants.
--
-- À exécuter uniquement sur la préproduction. Le script ne modifie ni les
-- e-mails Auth, ni les mots de passe, ni les rôles, ni les organisations.
-- Les numéros 06 39 98 sont réservés aux usages audiovisuels et fictifs.

begin;

do $normalize$
declare
  updated_profiles integer;
begin
  with expected_profiles(email, first_name, last_name, phone) as (
    values
      (
        'tourneurtest@gmail.com',
        'Tourneur 1',
        'TEST',
        '+33639980101'
      ),
      (
        'antoinevgnl+tourneur2@gmail.com',
        'Tourneur 2',
        'TEST',
        '+33639980102'
      ),
      (
        'antoinevgnl@gmail.com',
        'Bénévole 1',
        'TEST',
        '+33639980001'
      ),
      (
        'antoinevgnl+benevole2@gmail.com',
        'Bénévole 2',
        'TEST',
        '+33639980002'
      ),
      (
        'antoinevgnl+benevole3@gmail.com',
        'Bénévole 3',
        'TEST',
        '+33639980003'
      ),
      (
        'antoinevgnl+benevole4@gmail.com',
        'Bénévole 4',
        'TEST',
        '+33639980004'
      ),
      (
        'antoinevgnl+benevole5@gmail.com',
        'Bénévole 5',
        'TEST',
        '+33639980005'
      ),
      (
        'antoinevgnl+benevole6@gmail.com',
        'Bénévole 6',
        'TEST',
        '+33639980006'
      ),
      (
        'antoinevgnl+benevole7@gmail.com',
        'Bénévole 7',
        'TEST',
        '+33639980007'
      )
  )
  update public.profiles profile
  set
    first_name = expected.first_name,
    last_name = expected.last_name,
    phone = expected.phone
  from expected_profiles expected
  join auth.users auth_user
    on lower(auth_user.email) = expected.email
  where profile.id = auth_user.id;

  get diagnostics updated_profiles = row_count;

  if updated_profiles <> 9 then
    raise exception
      'Normalisation annulée : 9 profils attendus, % trouvés',
      updated_profiles;
  end if;
end;
$normalize$;

commit;

select
  auth_user.email,
  profile.first_name,
  profile.last_name,
  profile.phone,
  account.role,
  account.status,
  organization.name as organization
from auth.users auth_user
join public.profiles profile on profile.id = auth_user.id
join public.user_accounts account on account.profile_id = auth_user.id
left join public.organizations organization
  on organization.id = account.organization_id
where lower(auth_user.email) in (
  'tourneurtest@gmail.com',
  'antoinevgnl+tourneur2@gmail.com',
  'antoinevgnl@gmail.com',
  'antoinevgnl+benevole2@gmail.com',
  'antoinevgnl+benevole3@gmail.com',
  'antoinevgnl+benevole4@gmail.com',
  'antoinevgnl+benevole5@gmail.com',
  'antoinevgnl+benevole6@gmail.com',
  'antoinevgnl+benevole7@gmail.com'
)
order by account.role, profile.first_name;
