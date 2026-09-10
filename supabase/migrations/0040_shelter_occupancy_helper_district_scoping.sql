-- 0026 let ANY active helper view and log occupancy for ANY shelter. Bring
-- it in line with the district-assignment model used for asset loss reports
-- (0025): a helper may only see and record shelter occupancy for shelters
-- that fall inside one of their active state/district assignments. Admins
-- stay unrestricted. Enforced on the backend, not just by hiding the shelter
-- list in the app.

drop policy if exists "Helpers and admins can log shelter occupancy"
  on public.shelter_occupancy_report;
drop policy if exists "Helpers and admins can view shelter occupancy"
  on public.shelter_occupancy_report;

create policy "Admins manage shelter occupancy"
  on public.shelter_occupancy_report
  for all
  to authenticated
  using (
    exists (
      select 1 from public.account a
      where a.id = auth.uid() and a.role = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.account a
      where a.id = auth.uid() and a.role = 'admin'
    )
  );

create policy "Assigned helpers view district shelter occupancy"
  on public.shelter_occupancy_report
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.helper_district_assignment hda
      join public.facilities f on f.id = shelter_occupancy_report.facility_id
      where hda.helper_id = auth.uid()
        and hda.status = 'active'
        and hda.state = f.state
        and hda.district = f.district
    )
  );

create policy "Assigned helpers log district shelter occupancy"
  on public.shelter_occupancy_report
  for insert
  to authenticated
  with check (
    recorded_by = auth.uid()
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
