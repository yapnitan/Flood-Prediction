create table if not exists public.property (
  id bigint generated always as identity not null,
  account_id uuid null,
  address text null,
  lat double precision not null,
  lng double precision not null,
  property_type text null,
  floors integer null,
  estimated_value numeric(12, 2) null,
  risk_level text null,
  created_at timestamp without time zone null default now(),
  constraint property_pkey primary key (id),
  constraint property_account_id_fkey foreign key (account_id) references auth.users (id) on delete cascade
);

create index if not exists idx_property_account on public.property (account_id);

alter table public.property enable row level security;

create policy "Users manage their own properties"
  on public.property
  for all
  to authenticated
  using (account_id = auth.uid())
  with check (account_id = auth.uid());

create policy "Helpers and administrators can read properties"
  on public.property
  for select
  to authenticated
  using (
    exists (
      select 1 from public.account
      where account.id = auth.uid() and account.role in ('admin', 'helper')
    )
  );
