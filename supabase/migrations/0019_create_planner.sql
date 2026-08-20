-- Module 3: Evacuation & Inventory Planner (CLAUDE.md Task 8) — Emergency
-- Checklist, Inventory, and Emergency Contacts. All three are personal to
-- the signed-in account (not shared/community data like flood_report), so
-- every table is owner-only CRUD via account_id/auth.uid() — same shape as
-- the account-scoped parts of repair_request, just without an admin
-- override policy since there is nothing for an admin to manage here.

create table public.emergency_checklist (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.account(id) on delete cascade,
  title text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.checklist_item (
  id uuid primary key default gen_random_uuid(),
  checklist_id uuid not null references public.emergency_checklist(id) on delete cascade,
  label text not null,
  is_checked boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.inventory_item (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.account(id) on delete cascade,
  name text not null,
  category text not null default 'Other',
  quantity integer not null default 1,
  unit text,
  expiry_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.emergency_contact (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.account(id) on delete cascade,
  name text not null,
  phone_number text not null,
  relationship text,
  notes text,
  created_at timestamptz not null default now()
);

create index idx_checklist_item_checklist on public.checklist_item (checklist_id);
create index idx_emergency_checklist_account on public.emergency_checklist (account_id);
create index idx_inventory_item_account on public.inventory_item (account_id);
create index idx_emergency_contact_account on public.emergency_contact (account_id);

alter table public.emergency_checklist enable row level security;
alter table public.checklist_item enable row level security;
alter table public.inventory_item enable row level security;
alter table public.emergency_contact enable row level security;

create policy "Owners manage their own checklists"
  on public.emergency_checklist
  for all
  to authenticated
  using (account_id = auth.uid())
  with check (account_id = auth.uid());

-- checklist_item has no account_id of its own — ownership is checked by
-- joining back to the parent checklist it belongs to.
create policy "Owners manage items on their own checklists"
  on public.checklist_item
  for all
  to authenticated
  using (
    exists (
      select 1 from public.emergency_checklist c
      where c.id = checklist_item.checklist_id and c.account_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.emergency_checklist c
      where c.id = checklist_item.checklist_id and c.account_id = auth.uid()
    )
  );

create policy "Owners manage their own inventory"
  on public.inventory_item
  for all
  to authenticated
  using (account_id = auth.uid())
  with check (account_id = auth.uid());

create policy "Owners manage their own emergency contacts"
  on public.emergency_contact
  for all
  to authenticated
  using (account_id = auth.uid())
  with check (account_id = auth.uid());
