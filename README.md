# Router & Switcher I/O List

A browser-based tool for managing the trailer's 120x120 router and switcher
input/output lists, editable per show. Plain HTML/CSS/JS, no build step, data
stored in Supabase so it's shared across every machine that opens the site.

## What it does

- **Router (1–120)** — Output labels are fixed per port. Input is a dropdown
  pulled from a shared list of source names.
- **Switcher Inputs (1–40)** — Inputs 21–26 are live-linked to whatever the
  matching Router port's Input is currently set to (chain icon, no manual
  edit needed — click "Unlink" if a show doesn't wire it that way). The rest
  are dropdowns from the same source list.
- **Switcher Outputs (1–24)** — Plain editable labels.
- **Manage Names** — One shared list of source names. Rename an entry there
  and every dropdown using it updates everywhere, in every list.
- **Shows** — Save, duplicate, rename, and delete named configs per show.
  Export/import as JSON, export as CSV for a printable patch sheet.

## 1. Create the Supabase project

1. Go to [supabase.com](https://supabase.com) and create a new project (free
   tier is plenty for this).
2. Once it's up, open **SQL Editor** → **New query**, paste in the contents
   of `schema.sql` from this repo, and run it. This creates the `shows`
   table and opens it up for read/write (see the comment in that file if you
   want to lock it down with auth later).
3. Go to **Settings → API**. You'll need two values:
   - **Project URL**
   - **anon public** key (NOT the `service_role` key — that one must never
     go in client-side code)

## 2. Configure the app

Open `index.html` and find this block near the top:

```js
const SUPABASE_URL = "YOUR_SUPABASE_URL";
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
```

Replace both placeholders with the values from step 1. The anon key is
meant to be public in client-side code — it's not a secret, access control
is handled by the Row Level Security policies in `schema.sql`.

You can test locally at this point by just opening `index.html` in a
browser (or run any static file server in this folder).

## 3. Push to GitHub

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin <your-new-repo-url>
git push -u origin main
```

Create the repo on GitHub first (empty, no README) if you haven't already,
then use its URL above.

## 4. Deploy on Vercel

1. [vercel.com](https://vercel.com) → **Add New… → Project** → import the
   GitHub repo you just pushed.
2. Framework preset: **Other** (it's a static site, no build step needed).
3. Leave build/output settings default and deploy.
4. Vercel gives you a URL — that's the one to bookmark on every machine in
   the trailer.

Every `git push` to `main` after this auto-deploys.

## Notes

- Nothing here requires a login. Anyone with the site URL can read and edit
  every show. That's fine for an internal tool on a private link, but if you
  want to restrict editing, add Supabase Auth (email/password or magic
  link) and tighten the RLS policies in `schema.sql`.
- The switcher's 24 outputs start blank — there was no source data for
  those in the original spreadsheet.
