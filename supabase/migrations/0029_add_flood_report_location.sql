-- Community flood reports only ever stored a free-text `location_name` plus
-- raw lat/lng (0004). The submission wizard now reverse-geocodes the picked
-- point to a Malaysian state/district (same as the property form already
-- does), so admins can see and filter reports by area and the risk
-- simulator can line a report up against a property's district.
--
-- Both nullable: older rows predate this, and reverse geocoding is
-- best-effort (offline / rate-limited / unrecognized area all leave it
-- null, with the coordinates still recorded).

alter table public.flood_report
  add column if not exists state text,
  add column if not exists district text;

create index if not exists idx_flood_report_state_district
  on public.flood_report (state, district);
