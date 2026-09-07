-- The risk assessment now also folds in nearby *community* flood reports
-- (public.flood_report) from the last 7 days, not just the historical
-- JPS/DID dataset — a recent neighbour report is a live signal that the
-- area is flooding now. This column stores how many were counted at
-- assessment time, alongside the existing nearby_flood_count.

alter table public.flood_simulation
  add column if not exists recent_report_count integer not null default 0;
