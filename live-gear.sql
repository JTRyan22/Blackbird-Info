-- Run this once in Supabase's SQL Editor (needs lock-show.sql run first).
-- Adds what the "gear helper" needs:
--   1. shows.is_live  - marks the ONE show that the router/switcher feeds.
--   2. gear_status    - a heartbeat row the helper updates, so the app can
--                       show "connected / offline".
--   3. gear_apply()   - lets the helper change just specific cells in the live
--                       show in one safe step (it never rewrites the whole show,
--                       so it can't clobber someone's edit in a different cell).
-- Nothing here deletes or drops anything.

-- 1. The live-show flag. Only one show can be live at a time: turning it on for
--    one show turns it off everywhere else.
alter table public.shows add column if not exists is_live boolean not null default false;

create unique index if not exists shows_only_one_live on public.shows (is_live) where is_live;

create or replace function public.single_live_show()
returns trigger
language plpgsql
as $$
begin
  if new.is_live and (tg_op = 'INSERT' or not old.is_live) then
    update public.shows set is_live = false where is_live and id <> new.id;
  end if;
  return new;
end;
$$;

create or replace trigger one_live_show
  before insert or update of is_live on public.shows
  for each row execute function public.single_live_show();

-- 2. Helper heartbeat. Everyone signed in can READ it; only the helper (which
--    uses the service key) can write it.
create table if not exists public.gear_status (
  id           text primary key default 'main',
  last_seen    timestamptz not null default now(),
  mode         text,
  router_state text,
  switcher_state text,
  show_id      text,
  show_name    text,
  detail       text
);

alter table public.gear_status enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'gear_status' and policyname = 'gear status is readable'
  ) then
    create policy "gear status is readable" on public.gear_status
      for select to authenticated using (true);
  end if;
end;
$$;

-- 3. Change specific cells in the live show. p_changes is a list like
--    [{"kind":"switcher","port":3,"field":"label2","value":"Cam 3"}, ...].
--    Refuses if the show isn't the live one, and a locked show refuses it too
--    (the lock trigger from lock-show.sql blocks the write).
create or replace function public.gear_apply(p_show_id text, p_changes jsonb)
returns jsonb
language plpgsql
as $$
declare
  d    jsonb;
  live boolean;
  ch   jsonb;
  li   int;
  ri   int;
  n    int := 0;
begin
  select data, is_live into d, live from public.shows where id = p_show_id for update;
  if not found then
    raise exception 'show not found';
  end if;
  if not live then
    raise exception 'that show is not the live show';
  end if;

  for ch in select * from jsonb_array_elements(p_changes) loop
    if (ch->>'field') not in ('label', 'label2', 'destination', 'sourceRefPort') then
      raise exception 'field % may not be changed by the gear helper', ch->>'field';
    end if;

    li := null; ri := null;
    select ord - 1 into li
      from jsonb_array_elements(d->'lists') with ordinality as t(el, ord)
      where el->>'kind' = ch->>'kind' limit 1;
    continue when li is null;

    select ord - 1 into ri
      from jsonb_array_elements(d->'lists'->li->'rows') with ordinality as t(el, ord)
      where el->>'port' = ch->>'port' limit 1;
    continue when ri is null;

    d := jsonb_set(d, array['lists', li::text, 'rows', ri::text, ch->>'field'],
                   coalesce(ch->'value', 'null'::jsonb));
    n := n + 1;
  end loop;

  if n > 0 then
    update public.shows set data = d where id = p_show_id;
  end if;
  return jsonb_build_object('applied', n);
end;
$$;

-- Only the helper's service key may call it, not ordinary signed-in users.
revoke all on function public.gear_apply(text, jsonb) from public, anon, authenticated;
grant execute on function public.gear_apply(text, jsonb) to service_role;
