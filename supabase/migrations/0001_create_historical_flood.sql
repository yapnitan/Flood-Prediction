-- Historical flood records sourced from the JPS/DID (Department of Irrigation
-- and Drainage Malaysia) historical flood dataset:
-- https://mywater.gov.my/Portal/Modules/HidroMet/Banjir.aspx
--
-- Source columns are: No., State, District, Date, Flood Cause, Main River
-- Basin (River Basin is blank for some records, hence nullable below).
--
-- Records are imported into this table via HistoricalFloodService.importRecords
-- (Task 1: Historical Flood Data Integration). Nothing is ever hardcoded in app
-- code — this table is the single source of truth for historical flood data.
--
-- latitude/longitude are not part of the source dataset. They're filled in
-- at import time from an approximate state/district centroid lookup
-- (lib/utils/malaysia_geocoding.dart) so "nearby records" search is possible.

create extension if not exists "pgcrypto";

create table if not exists public.historical_flood (
  id uuid primary key default gen_random_uuid(),

  state text not null,
  district text not null,
  river_basin text,

  latitude float8,
  longitude float8,

  flood_date date not null,
  flood_cause text not null,

  source text not null default 'JPS/DID',
  created_at timestamptz not null default now()
);

-- Search indexes: state / district / river basin / date / cause
create index if not exists idx_historical_flood_state
  on public.historical_flood (state);

create index if not exists idx_historical_flood_district
  on public.historical_flood (district);

create index if not exists idx_historical_flood_river_basin
  on public.historical_flood (river_basin);

create index if not exists idx_historical_flood_flood_date
  on public.historical_flood (flood_date);

create index if not exists idx_historical_flood_flood_cause
  on public.historical_flood (flood_cause);

-- Bounding-box index to speed up "nearby records" lookups
-- (HistoricalFloodService.getNearby narrows with lat/lng range filters
-- before ranking by exact Haversine distance in Dart).
create index if not exists idx_historical_flood_lat_lng
  on public.historical_flood (latitude, longitude);

alter table public.historical_flood enable row level security;

-- Historical flood data is public reference data: any authenticated user
-- may read it, but only backend/import processes (service role, which
-- bypasses RLS) may write to it.
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'historical_flood'
      and policyname = 'Historical flood records are readable by authenticated users'
  ) then
    create policy "Historical flood records are readable by authenticated users"
      on public.historical_flood
      for select
      to authenticated
      using (true);
  end if;
end;
$$;
