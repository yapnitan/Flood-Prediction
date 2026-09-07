-- Resource Consumption Cost (Task/asset report §23/§39 "SEPARATE SHELTER
-- FLOW"): a helper logs demographic headcounts for a shelter; the app
-- computes a resource cost from a fixed per-person rate table
-- (lib/constants/resource_cost_rates.dart) and stores the result. This is
-- intentionally the minimal version — the spec's own description of this
-- sub-flow is far lighter than the district-assignment one (no per-shelter
-- helper assignment/conflict rules are described), so any active
-- helper/admin may log an occupancy snapshot for any active shelter.
-- Append-only: no update/delete policy, so a helper corrects a headcount by
-- logging a new snapshot rather than editing history. The Economic Loss
-- Dashboard sums the latest row per facility (current occupancy), not a
-- running total of every snapshot ever logged.
create table if not exists public.shelter_occupancy_report (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.facilities(id) on delete cascade,
  recorded_by uuid references public.account(id) on delete set null,
  adults int not null default 0 check (adults >= 0),
  children int not null default 0 check (children >= 0),
  elderly int not null default 0 check (elderly >= 0),
  infants int not null default 0 check (infants >= 0),
  persons_with_disabilities int not null default 0 check (persons_with_disabilities >= 0),
  total_victims int generated always as
    (adults + children + elderly + infants + persons_with_disabilities) stored,
  resource_cost numeric(12,2) not null default 0 check (resource_cost >= 0),
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_shelter_occupancy_report_facility
  on public.shelter_occupancy_report (facility_id, recorded_at desc);

alter table public.shelter_occupancy_report enable row level security;

create policy "Helpers and admins can log shelter occupancy"
  on public.shelter_occupancy_report
  for insert
  to authenticated
  with check (
    recorded_by = auth.uid()
    and exists (
      select 1 from public.account a
      where a.id = auth.uid() and a.role in ('admin', 'helper')
    )
  );

create policy "Helpers and admins can view shelter occupancy"
  on public.shelter_occupancy_report
  for select
  to authenticated
  using (
    exists (
      select 1 from public.account a
      where a.id = auth.uid() and a.role in ('admin', 'helper')
    )
  );
