-- Helper verification is now its own step in the lifecycle.
--
--   pending_review ──(resident submits)
--        │
--        ├─(assigned helper verifies)──▶ helper_verified   ← counts toward
--        │                                    │               Economic Loss
--        │                                    ├─(admin approves)─▶ verified
--        │                                    └─(admin rejects)──▶ rejected
--        │
--        ├─(admin approves directly)──▶ verified            (no helper available)
--        └─(admin rejects directly)───▶ rejected
--
-- A helper-verified report contributes its *verified* figure to the Economic
-- Loss Dashboard immediately. Admin approval locks in the approved figure;
-- admin rejection drops it back out of the total.

-- 1. Allow the new status value.
alter table public.asset_loss_report
  drop constraint if exists asset_loss_report_status_check;
alter table public.asset_loss_report
  add constraint asset_loss_report_status_check
  check (status in ('pending_review', 'helper_verified', 'verified', 'rejected'));

-- 2. The helper column-guard (0023) forbade helpers touching `status` at all.
--    Permit exactly the pending_review -> helper_verified transition; every
--    other status change (and every non-verification field) stays blocked.
create or replace function public.prevent_helper_asset_loss_overreach()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
begin
  select role into caller_role from public.account where id = auth.uid();

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
     or (new.status is distinct from old.status
         and not (old.status = 'pending_review' and new.status = 'helper_verified'))
     or new.approved_quantity is distinct from old.approved_quantity
     or new.approved_value_per_item is distinct from old.approved_value_per_item
     or new.reviewed_at is distinct from old.reviewed_at
     or new.reviewed_by is distinct from old.reviewed_by then
    raise exception 'Helpers may only update verification fields on assigned reports';
  end if;

  return new;
end;
$$;

-- 3. The verify-once RLS policy (0036) gates on the OLD row
--    (status = 'pending_review' and verification_result is null), so the
--    helper's write still passes its USING check. Re-assert the WITH CHECK
--    so a helper can only ever land the row in helper_verified.
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
    status in ('pending_review', 'helper_verified')
    and exists (
      select 1
      from public.helper_district_assignment hda
      join public.property p on p.id = asset_loss_report.property_id
      where hda.helper_id = auth.uid()
        and hda.status = 'active'
        and hda.state = p.state
        and hda.district = p.district
    )
  );
