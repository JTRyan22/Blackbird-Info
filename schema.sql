-- Router & Switcher I/O List — Supabase schema
-- Run this once in your Supabase project's SQL Editor (Database -> SQL Editor -> New query).

create table if not exists shows (
  id text primary key,
  name text not null,
  data jsonb not null default '{}'::jsonb,   -- { sourceNames: [...], lists: [...] }
  updated_at timestamptz not null default now()
);

-- Row Level Security
alter table shows enable row level security;

-- Open policy: anyone with your Supabase anon key (i.e. anyone who has the
-- deployed site's URL) can read and write shows. That matches an internal
-- trailer tool with no login. If you later want to restrict who can edit,
-- replace these with policies tied to Supabase Auth (e.g. auth.uid() checks)
-- and add a login screen to the app.
create policy "Public read" on shows
  for select using (true);

create policy "Public write" on shows
  for insert with check (true);

create policy "Public update" on shows
  for update using (true);

create policy "Public delete" on shows
  for delete using (true);
