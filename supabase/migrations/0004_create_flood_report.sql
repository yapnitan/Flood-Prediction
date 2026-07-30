-- Community flood reports submitted from the mobile app.
create extension if not exists "pgcrypto";

create table if not exists public.flood_report (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.account(id) on delete set null,
  location_name text not null,
  latitude float8 not null,
  longitude float8 not null,
  flood_type text not null,
  water_level text not null,
  observed_at timestamptz not null,
  description text not null,
  contact_number text,
  photo_paths text[] not null default '{}',
  status text not null default 'submitted',
  created_at timestamptz not null default now()
);

create index if not exists idx_flood_report_created_at
  on public.flood_report (created_at desc);

create index if not exists idx_flood_report_location
  on public.flood_report (latitude, longitude);

alter table public.flood_report enable row level security;

create policy "Users can submit their own flood reports"
  on public.flood_report
  for insert
  to authenticated
  with check (reporter_id = auth.uid());

create policy "Users can read their own flood reports"
  on public.flood_report
  for select
  to authenticated
  using (reporter_id = auth.uid());

create policy "Administrators can read flood reports"
  on public.flood_report
  for select
  to authenticated
  using (
    exists (
      select 1 from public.account
      where account.id = auth.uid() and account.role = 'admin'
    )
  );

-- Private storage for optional report evidence photos.
insert into storage.buckets (id, name, public)
values ('flood-report-photos', 'flood-report-photos', false)
on conflict (id) do nothing;

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
