-- A named flood event admins can (optionally) tag Asset Loss Reports to,
-- so the Economic Loss Dashboard can drill down "by flood incident"
-- (Task/asset report §16). Deliberately lightweight: a report's own
-- address already carries state/district, so an incident doesn't need to
-- declare a single state/district itself — one incident can span several
-- districts, derived from whichever reports reference it.
create table if not exists public.flood_incident (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  started_at date not null default current_date,
  ended_at date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.flood_incident enable row level security;

-- Any authenticated user needs to read the list to (optionally) tag their
-- own report with an active incident at submission time.
create policy "Authenticated users can view flood incidents"
  on public.flood_incident
  for select
  to authenticated
  using (true);

create policy "Admins manage flood incidents"
  on public.flood_incident
  for all
  to authenticated
  using (
    exists (
      select 1 from public.account a
      where a.id = auth.uid() and a.role = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.account a
      where a.id = auth.uid() and a.role = 'admin'
    )
  );
