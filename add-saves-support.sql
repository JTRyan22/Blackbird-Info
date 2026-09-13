-- Run this ONCE in your Supabase project's SQL Editor to enable the new
-- multi-save feature. This just adds one column to the existing "shows"
-- table -- your current data is untouched.

alter table shows
  add column if not exists is_default boolean not null default false;

-- That's it. The app will automatically detect that your existing show has
-- no default marked yet, and will promote it to be the default the next
-- time anyone loads the page -- no further action needed.
