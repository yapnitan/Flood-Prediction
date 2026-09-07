-- The risk assessment now also pulls a live river-flood forecast for the
-- property's coordinate (GloFAS river discharge via the Open-Meteo Flood
-- API) and compares the forecast peak to the recent average. This column
-- stores the resulting bucket at assessment time so the detail screen can
-- show it and the "simulate improvements" preview can reproduce the score.
--
-- Values: 'unknown' | 'low' | 'normal' | 'elevated' | 'high'.

alter table public.flood_simulation
  add column if not exists river_flood_level text not null default 'unknown';
