-- Secure community-report submission and its private photo evidence for
-- existing projects that previously ran the original 0004 migration.

drop policy if exists "Anyone can submit a flood report"
  on public.flood_report;

drop policy if exists "Users can submit their own flood reports"
  on public.flood_report;

create policy "Users can submit their own flood reports"
  on public.flood_report
  for insert
  to authenticated
  with check (reporter_id = auth.uid());

drop policy if exists "Anyone can upload flood report photos"
  on storage.objects;

drop policy if exists "Authenticated users can view their flood report photos"
  on storage.objects;

drop policy if exists "Users can upload their own flood report photos"
  on storage.objects;

drop policy if exists "Users can view their own flood report photos"
  on storage.objects;

create policy "Users can upload their own flood report photos"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'flood-report-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can view their own flood report photos"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'flood-report-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Administrators can view flood report photos"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'flood-report-photos'
    and exists (
      select 1
      from public.account
      where account.id = auth.uid() and account.role = 'admin'
    )
  );
