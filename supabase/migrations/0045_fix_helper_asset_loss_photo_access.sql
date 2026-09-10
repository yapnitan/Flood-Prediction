-- Let an assigned helper read evidence that is actually attached to a report
-- in one of their active districts. Matching storage object names against the
-- report arrays supports both the current {owner}/{reportId}/... layout and
-- legacy {owner}/{timestamp}/... uploads without widening district access.
drop policy if exists
  "Assigned helpers can view district-matched report photos"
  on storage.objects;

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
      where storage.objects.name = any(r.photo_paths)
         or storage.objects.name = any(r.verification_photo_paths)
    )
  );
