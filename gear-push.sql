-- Run once in Supabase's SQL Editor (after live-gear.sql). Safe to re-run.
-- Lets the web app's "Push to gear" button ask the gear helper (on the ENG Mac)
-- to preview and send the Live show to the router/switcher.
--   * Admins and editors can create and read requests. Viewers can't.
--   * Only the helper (service key) can answer them.
--   * Nothing here changes any show.

create table if not exists public.gear_commands (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  kind         text not null check (kind in ('preview', 'execute')),
  show_id      text,
  token        text,
  then_follow  boolean not null default false,
  requested_by text,
  status       text not null default 'pending' check (status in ('pending', 'working', 'done', 'error')),
  result       jsonb,
  updated_at   timestamptz not null default now()
);

create index if not exists gear_commands_pending on public.gear_commands (created_at) where status = 'pending';

alter table public.gear_commands enable row level security;

-- True when the signed-in user is an admin or editor. SECURITY DEFINER so it works
-- whatever the access rules on user_access are.
create or replace function public.is_gear_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_access ua
    where lower(ua.email) = lower(auth.jwt() ->> 'email') and ua.role in ('admin', 'editor')
  );
$$;
revoke all on function public.is_gear_staff() from public, anon;
grant execute on function public.is_gear_staff() to authenticated;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='gear_commands' and policyname='staff can request gear pushes') then
    create policy "staff can request gear pushes" on public.gear_commands
      for insert to authenticated
      with check (status = 'pending' and public.is_gear_staff());
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='gear_commands' and policyname='staff can read gear pushes') then
    create policy "staff can read gear pushes" on public.gear_commands
      for select to authenticated
      using (public.is_gear_staff());
  end if;
end;
$$;

notify pgrst, 'reload schema';
