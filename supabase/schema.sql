-- WordBlocks account sync.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
--
-- Each signed-in user has one row holding their review progress as JSON:
--   { "v": 1, "cards": { "<morpheme id>": {ease, ivl, reps, lapses, last, due, t} },
--     "days": ["2026-11-01", ...], "counters": { "split": 0, "ext": 0, "puzzles": 0, "myth": 0 } }
-- The web app and the Android app merge this with their local copy before writing it back
-- (newer card wins, days are combined, counters keep the larger value).

create table if not exists public.progress (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Row Level Security: the public (publishable/anon) key can only reach the signed-in user's own row.
alter table public.progress enable row level security;

drop policy if exists "Users read their own progress" on public.progress;
create policy "Users read their own progress"
  on public.progress for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users create their own progress" on public.progress;
create policy "Users create their own progress"
  on public.progress for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users update their own progress" on public.progress;
create policy "Users update their own progress"
  on public.progress for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Explicit grants so the table is reachable through the API (some new projects do not
-- expose tables in the public schema automatically).
grant select, insert, update on public.progress to authenticated;
