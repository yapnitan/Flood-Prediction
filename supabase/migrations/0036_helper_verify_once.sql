-- 0025 let an assigned helper update a district-matched report while its
-- status is still 'pending_review'. That still allowed:
--   * re-verifying a report another helper had already verified (overwriting
--     their field figures), and
--   * (once the app opened the form on any status) a silent no-op edit.
--
-- Tighten it: a helper may write the verification fields exactly once, only
-- while the report is pending AND no verification has been recorded yet.
-- The admin's approve/reject is unaffected (that's the "Admins can read and
-- manage all asset loss reports" policy from 0023).

drop policy if exists
  "Assigned helpers can verify district-matched pending reports"
  on public.asset_loss_report;

create policy "Assigned helpers can verify district-matched pending reports"
  on public.asset_loss_report
  for update
  to authenticated
  using (
    status = 'pending_review'
    and verification_result is null
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
