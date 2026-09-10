-- BUG: prevent_user_asset_loss_overreach() (0023) exempted only role='admin',
-- so its BEFORE UPDATE check also fired for helpers — raising
--   "Only an admin can change status, verification, or approval fields"
-- whenever an assigned helper submitted a verification (which writes
-- verified_* / verification_*). Helpers ARE meant to write those fields;
-- what they must NOT touch (status, approved_*, reviewed_*, user_id,
-- property_id, the descriptive fields) is already enforced separately by
-- prevent_helper_asset_loss_overreach(). Exempt helpers here too.

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

  -- Admins are unrestricted; a helper's writes are governed by
  -- prevent_helper_asset_loss_overreach().
  if coalesce(caller_role, '') in ('admin', 'helper') then
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
