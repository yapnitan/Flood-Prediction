-- Flood risk simulations (Task 3: Flood Risk Assessment).
--
-- Each row is a saved risk assessment for one property, combining:
--   - historical flood frequency nearby (public.historical_flood, Task 1)
--   - terrain elevation at the property vs. its district's baseline
--     elevation (fetched via Open-Meteo, Task 2)
--   - user-declared structure type and mitigation features
--
-- current_weather_summary is a snapshot of conditions at assessment time —
-- informational only, intentionally excluded from risk_score (see
-- RiskAssessmentService for the scoring rationale).

create table if not exists public.flood_simulation (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.account(id) on delete cascade,

  property_name text not null,
  structure_type text not null,

  latitude float8 not null,
  longitude float8 not null,
  state text not null,
  district text not null,

  user_elevation_meters float8,
  terrain_elevation_meters float8,
  baseline_elevation_meters float8,

  has_flood_barriers boolean not null default false,
  has_raised_foundation boolean not null default false,

  nearby_flood_count integer not null default 0,
  current_weather_summary text,

  risk_score numeric not null,
  risk_level text not null,

  created_at timestamptz not null default now()
);

create table if not exists public.simulation_factor (
  id uuid primary key default gen_random_uuid(),
  simulation_id uuid not null references public.flood_simulation(id) on delete cascade,

  factor_name text not null,
  factor_value text not null,
  score_contribution numeric not null,

  created_at timestamptz not null default now()
);

create index if not exists idx_flood_simulation_account
  on public.flood_simulation (account_id);

create index if not exists idx_simulation_factor_simulation
  on public.simulation_factor (simulation_id);

alter table public.flood_simulation enable row level security;
alter table public.simulation_factor enable row level security;

-- Simulations are personal: owners can read/write only their own.
create policy "Users manage their own simulations"
  on public.flood_simulation
  for all
  to authenticated
  using (auth.uid() = account_id)
  with check (auth.uid() = account_id);

-- Factors inherit access from their parent simulation's ownership.
create policy "Users manage factors of their own simulations"
  on public.simulation_factor
  for all
  to authenticated
  using (
    exists (
      select 1 from public.flood_simulation fs
      where fs.id = simulation_id and fs.account_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.flood_simulation fs
      where fs.id = simulation_id and fs.account_id = auth.uid()
    )
  );
