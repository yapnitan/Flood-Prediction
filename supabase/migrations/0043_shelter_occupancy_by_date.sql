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

-- A helper may only log occupancy for the last 3 days (today and the two
-- days before) — enforced server-side, not just by bounding the date picker.
-- Rebuilds the district-scoped insert policy from 0040 with the date window.
drop policy if exists "Assigned helpers log district shelter occupancy"
  on public.shelter_occupancy_report;

create policy "Assigned helpers log district shelter occupancy"
  on public.shelter_occupancy_report
  for insert
  to authenticated
  with check (
    recorded_by = auth.uid()
    and occupancy_date between (current_date - 2) and current_date
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
