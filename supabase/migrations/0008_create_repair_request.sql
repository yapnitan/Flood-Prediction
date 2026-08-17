-- Post-flood aid & repair requests submitted from the mobile app
-- (CLAUDE.md Task 10: Post-Flood Aid & Repair Request Registry).
create table if not exists public.repair_request (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid references public.account(id) on delete set null,
  location_name text not null,
  latitude float8 not null,
  longitude float8 not null,
  assistance_type text not null,
  damage_description text not null,
  contact_number text,
  photo_paths text[] not null default '{}',
  status text not null default 'Pending',
  created_at timestamptz not null default now()
);

create index if not exists idx_repair_request_created_at
  on public.repair_request (created_at desc);

create index if not exists idx_repair_request_requester
  on public.repair_request (requester_id);

alter table public.repair_request enable row level security;

create policy "Users can submit their own repair requests"
  on public.repair_request
  for insert
  to authenticated
  with check (requester_id = auth.uid());

create policy "Users can read their own repair requests"
  on public.repair_request
  for select
  to authenticated
  using (requester_id = auth.uid());

-- Helpers and admins need to see every request to triage/assign them
-- (CLAUDE.md Task 10/11: Helper Dashboard, Admin Dashboard) — not yet
-- built, but the read policy is needed from the start so it isn't a
-- follow-up migration later.
create policy "Helpers and administrators can read repair requests"
  on public.repair_request
  for select
  to authenticated
  using (
    exists (
      select 1 from public.account
      where account.id = auth.uid() and account.role in ('admin', 'helper')
    )
  );

-- Private storage for repair request evidence photos, same per-user-folder
-- pattern as flood-report-photos (see 0004_create_flood_report.sql).
insert into storage.buckets (id, name, public)
values ('repair-request-photos', 'repair-request-photos', false)
on conflict (id) do nothing;

create policy "Users can upload their own repair request photos"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'repair-request-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can view their own repair request photos"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'repair-request-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Helpers and administrators can view repair request photos"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'repair-request-photos'
    and exists (
      select 1 from public.account
      where account.id = auth.uid() and account.role in ('admin', 'helper')
    )
  );
