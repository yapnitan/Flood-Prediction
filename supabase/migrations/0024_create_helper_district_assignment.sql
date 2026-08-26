-- Admin assigns approved helpers to a state/district so they can verify
-- Potential Asset Loss reports in that area (Task/asset report §24-§26).
create table if not exists public.helper_district_assignment (
  id uuid primary key default gen_random_uuid(),
  helper_id uuid not null references public.account(id) on delete cascade,
  state text not null,
  district text not null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  assigned_at timestamptz not null default now(),
  start_date date,
  end_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_helper_district_assignment_helper
  on public.helper_district_assignment (helper_id);
create index if not exists idx_helper_district_assignment_district
  on public.helper_district_assignment (state, district);

-- One active primary helper per district (§34) — enforced at the DB level,
-- not just app-side, via a partial unique index over active rows only.
create unique index if not exists uq_helper_district_assignment_active_district
  on public.helper_district_assignment (state, district)
  where (status = 'active');

alter table public.helper_district_assignment enable row level security;

create policy "Admins manage helper district assignments"
  on public.helper_district_assignment
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

create policy "Helpers can view their own district assignments"
  on public.helper_district_assignment
  for select
  to authenticated
  using (helper_id = auth.uid());
