-- Shelter occupancy is now a daily log: each report is the headcount for one
-- calendar date (helper-picked), not an implicit "right now" snapshot. The
-- table stays append-only — "latest replaces" for a given (shelter, date) is
-- resolved at read time by taking the row with the newest recorded_at.
--
-- The old per-report `days` multiplier (0032) is left in place for historical
-- rows but new entries always represent exactly one day.

alter table public.shelter_occupancy_report
  add column if not exists occupancy_date date;

update public.shelter_occupancy_report
  set occupancy_date = recorded_at::date
  where occupancy_date is null;

alter table public.shelter_occupancy_report
  alter column occupancy_date set not null;

alter table public.shelter_occupancy_report
  alter column occupancy_date set default current_date;

create index if not exists idx_shelter_occupancy_report_facility_date
  on public.shelter_occupancy_report (facility_id, occupancy_date, recorded_at desc);

-- A helper may only log occupancy that is (a) recent — roughly the last few
-- days — and (b) not over the shelter's set capacity. Enforced server-side,
-- not just in the app. Rebuilds the district-scoped insert policy from 0040
-- with those two extra conditions.
--
-- The date window is `current_date - 3 .. current_date + 1`, not a tight
-- "last 3 days": `current_date` on the server is UTC, but the helper's
-- device picks a *local* date, and Malaysia (UTC+8) runs ~8 h ahead — so
-- "today" for the helper can be tomorrow in UTC. The +1 day of slack
-- absorbs that; the app's date picker still limits the real choice to the
-- last 3 days.
drop policy if exists "Assigned helpers log district shelter occupancy"
  on public.shelter_occupancy_report;

create policy "Assigned helpers log district shelter occupancy"
  on public.shelter_occupancy_report
  for insert
  to authenticated
  with check (
    recorded_by = auth.uid()
    and occupancy_date between (current_date - 3) and (current_date + 1)
    and (adults + children + elderly + infants + persons_with_disabilities)
        <= coalesce(
             (select f.capacity from public.facilities f
              where f.id = shelter_occupancy_report.facility_id),
             2147483647)
    and exists (
      select 1
      from public.helper_district_assignment hda
      join public.facilities f on f.id = shelter_occupancy_report.facility_id
      where hda.helper_id = auth.uid()
        and hda.status = 'active'
        and hda.state = f.state
        and hda.district = f.district
    )
  );
