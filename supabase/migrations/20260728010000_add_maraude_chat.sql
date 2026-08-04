create table public.maraude_messages (
  id uuid primary key default gen_random_uuid(),
  concert_id uuid not null
    references public.concerts(id) on delete cascade,
  user_id uuid not null
    references public.profiles(id) on delete cascade,
  message text not null check (
    char_length(btrim(message)) between 1 and 1000
  ),
  created_at timestamptz not null default now()
);

create index maraude_messages_concert_created_idx
  on public.maraude_messages (concert_id, created_at);

alter table public.maraude_messages enable row level security;

create or replace function private.can_access_maraude_chat(
  requested_concert_id uuid,
  requested_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    (
      private.is_club_sandwich_admin(requested_user_id)
      and exists (
        select 1
        from public.concerts
        where concerts.id = requested_concert_id
          and private.is_organization_member(
            concerts.organization_id,
            requested_user_id
          )
      )
    )
    or exists (
      select 1
      from public.concert_volunteers
      where concert_volunteers.concert_id = requested_concert_id
        and concert_volunteers.user_id = requested_user_id
        and concert_volunteers.status =
          'selected'::public.concert_volunteer_status
    );
$$;

create policy "Maraude team reads its chat"
on public.maraude_messages
for select
to authenticated
using (
  private.can_access_maraude_chat(
    concert_id,
    (select auth.uid())
  )
);

create policy "Maraude team writes its chat"
on public.maraude_messages
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and private.can_access_maraude_chat(
    concert_id,
    (select auth.uid())
  )
);

revoke all on public.maraude_messages from anon, authenticated;
grant select, insert on public.maraude_messages to authenticated;
