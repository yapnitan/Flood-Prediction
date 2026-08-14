create table public.facilities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  facility_type text not null check (facility_type in ('shelter', 'distribution_center', 'medical_station')),
  address text,
  latitude double precision not null,
  longitude double precision not null,
  capacity integer,
  contact_number text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.repair_request
  add column facility_id uuid references public.facilities(id);

alter table public.repair_request
  drop column if exists shelter_name;

alter table public.facilities enable row level security;

create policy "Authenticated users view active facilities"
  on public.facilities for select
  using (auth.role() = 'authenticated' and is_active = true);

create policy "Admins manage facilities"
  on public.facilities for all
  using (exists (
    select 1 from public.account a where a.id = auth.uid() and a.role = 'admin'
  ))
  with check (exists (
    select 1 from public.account a where a.id = auth.uid() and a.role = 'admin'
  ));