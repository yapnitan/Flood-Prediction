-- Potential Asset Loss Report (Task/asset report) — replaces the old
-- repair_request/"Property Damage Report" system (dropped in 0027).
-- Three separate generated totals give the transparency the spec asks for
-- (§17, §35): what the user reported, what the helper verified in the
-- field, and what the admin finally approved — only the approved figure on
-- a VERIFIED report counts toward the Economic Loss Dashboard.
create table if not exists public.asset_loss_report (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.account(id) on delete set null,
  property_id bigint not null references public.property(id) on delete cascade,
  flood_incident_id uuid references public.flood_incident(id) on delete set null,

  asset_category text not null check (asset_category in (
    'Building', 'Furniture', 'Appliances', 'Electronics', 'Personal Items',
    'Kitchen Items', 'Vehicle', 'Outdoor Assets', 'Tools & Equipment',
    'Business Assets', 'Other'
  )),
  asset_name text not null,
  condition text not null check (condition in (
    'damaged', 'severely_damaged', 'completely_destroyed', 'lost'
  )),
  quantity int not null check (quantity > 0),
  estimated_value_per_item numeric(12,2) not null check (estimated_value_per_item >= 0),
  estimated_total_loss numeric(12,2) generated always as
    (quantity * estimated_value_per_item) stored,
  description text,
  photo_paths text[] not null default '{}',

  status text not null default 'pending_review' check (status in (
    'pending_review', 'verified', 'rejected'
  )),

  -- Helper field-verification (§29/§31 — supports partial verification).
  verified_quantity int check (verified_quantity >= 0),
  verified_value_per_item numeric(12,2) check (verified_value_per_item >= 0),
  verified_total_loss numeric(12,2) generated always as
    (coalesce(verified_quantity, 0) * coalesce(verified_value_per_item, 0)) stored,
  verified_condition text check (verified_condition in (
    'damaged', 'severely_damaged', 'completely_destroyed', 'lost'
  )),
  verification_result text check (verification_result in (
    'verified', 'not_verified', 'partially_verified'
  )),
  verification_notes text,
  verification_photo_paths text[] not null default '{}',
  verified_by uuid references public.account(id) on delete set null,
  verified_at timestamptz,

  -- Admin final approval (§30/§35 — admin's figure is authoritative and may
  -- differ from the helper's, e.g. defaults to the helper's verified figure
  -- but is editable, or the user's reported figure if no helper verified it).
  approved_quantity int check (approved_quantity >= 0),
  approved_value_per_item numeric(12,2) check (approved_value_per_item >= 0),
  approved_total_loss numeric(12,2) generated always as
    (coalesce(approved_quantity, 0) * coalesce(approved_value_per_item, 0)) stored,
  reviewed_at timestamptz,
  reviewed_by uuid references public.account(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_asset_loss_report_user on public.asset_loss_report (user_id);
create index if not exists idx_asset_loss_report_property on public.asset_loss_report (property_id);
create index if not exists idx_asset_loss_report_incident on public.asset_loss_report (flood_incident_id);
create index if not exists idx_asset_loss_report_status on public.asset_loss_report (status);
create index if not exists idx_asset_loss_report_created_at on public.asset_loss_report (created_at desc);

alter table public.asset_loss_report enable row level security;

-- Insert: own report only, must start pending and unreviewed/unverified —
-- same shape as 0020's repair_request/flood_report insert hardening, so a
-- submitter can never self-approve. Also requires the referenced property
-- to belong to the same authenticated user (§3/§20 "address must belong to
-- authenticated user", enforced at the DB level, not just the UI).
create policy "Users can submit asset loss reports for their own address"
  on public.asset_loss_report
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and status = 'pending_review'
    and reviewed_by is null
    and reviewed_at is null
    and verified_by is null
    and verified_at is null
    and exists (
      select 1 from public.property p
      where p.id = property_id and p.account_id = auth.uid()
    )
  );

create policy "Users can read their own asset loss reports"
  on public.asset_loss_report
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "Admins can read and manage all asset loss reports"
  on public.asset_loss_report
  for all
  to authenticated
  using (
    exists (
      select 1 from public.account a
      where a.id = auth.uid() and a.role = 'admin'
    )
  )
  with check (true);

-- A user may edit their own still-pending report's descriptive fields
-- (mirrors repair_request's "Users can update their own pending repair
-- requests") — a trigger below restricts *which* columns, since RLS alone
-- can't compare against the pre-update row.
create policy "Users can update their own pending asset loss reports"
  on public.asset_loss_report
  for update
  to authenticated
  using (user_id = auth.uid() and status = 'pending_review')
  with check (user_id = auth.uid());

-- Column-level guard: a user (even on their own still-pending report) may
-- only touch the descriptive/report fields, never status/verification/
-- approval columns — same shape as prevent_helper_repair_overreach()
-- (0017_lock_helper_repair_updates.sql) and
-- prevent_account_privilege_escalation() (0016_create_account.sql).
create or replace function public.prevent_user_asset_loss_overreach()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
begin
  select role into caller_role
  from public.account
  where id = auth.uid();

  if coalesce(caller_role, '') = 'admin' then
    return new;
  end if;

  if new.user_id is distinct from old.user_id
     or new.property_id is distinct from old.property_id
     or new.status is distinct from old.status
     or new.verified_quantity is distinct from old.verified_quantity
     or new.verified_value_per_item is distinct from old.verified_value_per_item
     or new.verified_condition is distinct from old.verified_condition
     or new.verification_result is distinct from old.verification_result
     or new.verification_notes is distinct from old.verification_notes
     or new.verification_photo_paths is distinct from old.verification_photo_paths
     or new.verified_by is distinct from old.verified_by
     or new.verified_at is distinct from old.verified_at
     or new.approved_quantity is distinct from old.approved_quantity
     or new.approved_value_per_item is distinct from old.approved_value_per_item
     or new.reviewed_at is distinct from old.reviewed_at
     or new.reviewed_by is distinct from old.reviewed_by then
    raise exception 'Only an admin can change status, verification, or approval fields';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_prevent_user_asset_loss_overreach on public.asset_loss_report;

create trigger trg_prevent_user_asset_loss_overreach
  before update on public.asset_loss_report
  for each row
  execute function public.prevent_user_asset_loss_overreach();

-- Column-level guard for the district-assigned helper's verification step
-- (the row-level district-match policy is added in
-- 0025_asset_loss_helper_district_scoping.sql, once helper_district_assignment
-- exists) — a helper may only ever write the verification_* columns.
create or replace function public.prevent_helper_asset_loss_overreach()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
begin
  select role into caller_role
  from public.account
  where id = auth.uid();

  if coalesce(caller_role, '') <> 'helper' then
    return new;
  end if;

  if new.user_id is distinct from old.user_id
     or new.property_id is distinct from old.property_id
     or new.flood_incident_id is distinct from old.flood_incident_id
     or new.asset_category is distinct from old.asset_category
     or new.asset_name is distinct from old.asset_name
     or new.condition is distinct from old.condition
     or new.quantity is distinct from old.quantity
     or new.estimated_value_per_item is distinct from old.estimated_value_per_item
     or new.description is distinct from old.description
     or new.photo_paths is distinct from old.photo_paths
     or new.status is distinct from old.status
     or new.approved_quantity is distinct from old.approved_quantity
     or new.approved_value_per_item is distinct from old.approved_value_per_item
     or new.reviewed_at is distinct from old.reviewed_at
     or new.reviewed_by is distinct from old.reviewed_by then
    raise exception 'Helpers may only update verification fields on assigned reports';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_prevent_helper_asset_loss_overreach on public.asset_loss_report;

create trigger trg_prevent_helper_asset_loss_overreach
  before update on public.asset_loss_report
  for each row
  execute function public.prevent_helper_asset_loss_overreach();

-- Private storage for asset-loss evidence + helper verification photos,
-- same per-user-folder pattern as repair-request-photos (0008).
insert into storage.buckets (id, name, public)
values ('asset-loss-photos', 'asset-loss-photos', false)
on conflict (id) do nothing;

create policy "Users can upload their own asset loss photos"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'asset-loss-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can view their own asset loss photos"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'asset-loss-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Admins can view all asset loss photos"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'asset-loss-photos'
    and exists (
      select 1 from public.account
      where account.id = auth.uid() and account.role = 'admin'
    )
  );
