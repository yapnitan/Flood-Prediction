-- District-scoped helper access to asset_loss_report (Task/asset report
-- §26/§38): "enforced on the backend, not only by hiding options in the
-- frontend". Split into its own migration since it references both
-- asset_loss_report (0023) and helper_district_assignment (0024).
create policy "Assigned helpers can read district-matched asset loss reports"
  on public.asset_loss_report
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.helper_district_assignment hda
      join public.property p on p.id = asset_loss_report.property_id
      where hda.helper_id = auth.uid()
        and hda.status = 'active'
        and hda.state = p.state
        and hda.district = p.district
    )
  );

-- Column access is further restricted by
-- prevent_helper_asset_loss_overreach() (0023) — this policy only decides
-- *which rows* a helper may touch.
create policy "Assigned helpers can verify district-matched pending reports"
  on public.asset_loss_report
  for update
  to authenticated
  using (
    status = 'pending_review'
    and exists (
      select 1
      from public.helper_district_assignment hda
      join public.property p on p.id = asset_loss_report.property_id
      where hda.helper_id = auth.uid()
        and hda.status = 'active'
        and hda.state = p.state
        and hda.district = p.district
    )
  )
  with check (
    exists (
      select 1
      from public.helper_district_assignment hda
      join public.property p on p.id = asset_loss_report.property_id
      where hda.helper_id = auth.uid()
        and hda.status = 'active'
        and hda.state = p.state
        and hda.district = p.district
    )
  );

-- Storage: a district-assigned helper may upload verification photos under
-- {reportOwnerId}/{reportId}/verification/... and view that report's own
-- evidence photos under {reportOwnerId}/{reportId}/... — path segments are
-- matched back to the report/property/assignment the same way the table
-- policies above do.
create policy "Assigned helpers can upload verification photos"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'asset-loss-photos'
    and (storage.foldername(name))[3] = 'verification'
    and exists (
      select 1
      from public.asset_loss_report r
      join public.property p on p.id = r.property_id
      join public.helper_district_assignment hda
        on hda.helper_id = auth.uid()
       and hda.status = 'active'
       and hda.state = p.state
       and hda.district = p.district
      where r.user_id::text = (storage.foldername(name))[1]
        and r.id::text = (storage.foldername(name))[2]
    )
  );

create policy "Assigned helpers can view district-matched report photos"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'asset-loss-photos'
    and exists (
      select 1
      from public.asset_loss_report r
      join public.property p on p.id = r.property_id
      join public.helper_district_assignment hda
        on hda.helper_id = auth.uid()
       and hda.status = 'active'
       and hda.state = p.state
       and hda.district = p.district
      where r.user_id::text = (storage.foldername(name))[1]
        and r.id::text = (storage.foldername(name))[2]
    )
  );
