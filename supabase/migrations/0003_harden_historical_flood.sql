-- The `historical_flood` table ended up created via Supabase's CSV import
-- wizard instead of 0001_create_historical_flood.sql, so it was missing
-- RLS, indexes, and a few NOT NULL constraints. This migration brings the
-- already-existing table in line with that original design, without
-- touching the data already imported.

-- RLS was OFF, meaning the anon key could read AND delete all rows.
alter table public.historical_flood enable row level security;

drop policy if exists "Historical flood records are readable by authenticated users"
  on public.historical_flood;

create policy "Historical flood records are readable by authenticated users"
  on public.historical_flood
  for select
  to authenticated
  using (true);

-- Search indexes (Task 1: search by state/district/river basin/date/cause).
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

create index if not exists idx_historical_flood_lat_lng
  on public.historical_flood (latitude, longitude);

-- Tighten constraints to match the intended schema. Safe: every imported
-- row already has these fields populated.
alter table public.historical_flood alter column district set not null;
alter table public.historical_flood alter column flood_date set not null;
alter table public.historical_flood alter column flood_cause set not null;
alter table public.historical_flood alter column source set default 'JPS/DID';
update public.historical_flood set source = 'JPS/DID' where source is null;
alter table public.historical_flood alter column source set not null;
