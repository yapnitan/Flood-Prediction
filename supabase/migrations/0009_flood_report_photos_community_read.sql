-- 0006 opened the flood_report table to community-wide reads, but the
-- flood-report-photos storage bucket was left on the original
-- owner-or-admin-only select policies (0004/0005). Without this, a
-- report's evidence photos silently fail to generate signed URLs for
-- anyone but the reporter (or an admin) — the report itself shows up on
-- the map for everyone, but its photos would only ever appear for the
-- person who submitted it.
drop policy if exists "Users can view their own flood report photos"
  on storage.objects;

drop policy if exists "Administrators can view flood report photos"
  on storage.objects;

create policy "Flood report photos are readable by authenticated users"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'flood-report-photos');
