create table public.avatar_configs (
  user_id uuid primary key
    references public.profiles(id) on delete cascade,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger avatar_configs_set_updated_at
before update on public.avatar_configs
for each row execute function private.set_updated_at();

alter table public.avatar_configs enable row level security;

create policy "Users can view their own avatar config"
on public.avatar_configs
for select
to authenticated
using (user_id = (select auth.uid()));

create policy "Users can create their own avatar config"
on public.avatar_configs
for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy "Users can update their own avatar config"
on public.avatar_configs
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

revoke all on public.avatar_configs from anon, authenticated;
grant select, insert, update on public.avatar_configs to authenticated;
