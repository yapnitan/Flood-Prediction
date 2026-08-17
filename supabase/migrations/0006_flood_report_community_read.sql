-- The original flood_report policies only let a user read their own
-- reports (or an admin read all). That's wrong for a *community* flood
-- tracker — the whole point is every user can see reports submitted by
-- other users on the map. Replace the two narrow select policies with one
-- open-to-authenticated read policy, matching how historical_flood
-- already handles read access (see 0001_create_historical_flood.sql).

drop policy if exists "Users can read their own flood reports"
  on public.flood_report;

drop policy if exists "Administrators can read flood reports"
  on public.flood_report;

create policy "Flood reports are readable by authenticated users"
  on public.flood_report
  for select
  to authenticated
  using (true);
