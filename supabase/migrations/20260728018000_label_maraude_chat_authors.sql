create or replace function public.get_maraude_messages(
  requested_concert_id uuid
)
returns table (
  id uuid,
  user_id uuid,
  author_name text,
  message text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not private.can_access_maraude_chat(
    requested_concert_id,
    (select auth.uid())
  ) then
    raise exception 'Vous ne pouvez pas accéder à cette discussion'
      using errcode = '42501';
  end if;

  return query
  select
    chat_message.id,
    chat_message.user_id,
    case
      when private.is_club_sandwich_admin(chat_message.user_id)
        then 'Admin'
      else coalesce(
        nullif(
          btrim(concat_ws(
            ' ',
            profile.first_name,
            profile.last_name
          )),
          ''
        ),
        'Bénévole'
      )
    end as author_name,
    chat_message.message,
    chat_message.created_at
  from public.maraude_messages chat_message
  left join public.profiles profile
    on profile.id = chat_message.user_id
  where chat_message.concert_id = requested_concert_id
  order by chat_message.created_at;
end;
$$;

revoke all on function public.get_maraude_messages(uuid)
  from public, anon;
grant execute on function public.get_maraude_messages(uuid)
  to authenticated;
