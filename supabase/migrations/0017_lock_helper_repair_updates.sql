-- "Helpers can update status of their assigned requests" (0011) only
-- restricts *which row* a helper may touch (`assigned_helper_id =
-- auth.uid()`), not which columns change — its `with check` is just
-- `assigned_helper_id = auth.uid()` again. That means a helper could
-- currently reassign the request to someone else, change its priority,
-- assistance_type, or facility_id, not just flip its status, even though
-- RepairRequestController.updateStatus only ever sends `status`.
--
-- Same fix shape as prevent_account_privilege_escalation() in
-- 0016_create_account.sql: RLS decides row access, this trigger decides
-- column access, since `with check` alone can't compare against the
-- pre-update row.

create or replace function public.prevent_helper_repair_overreach()
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

  -- Admins (and the requester's own "edit while pending" path, which is a
  -- separate policy/trigger scope) are unaffected — this only constrains
  -- helpers acting on requests assigned to them.
  if coalesce(caller_role, '') <> 'helper' then
    return new;
  end if;

  if new.requester_id is distinct from old.requester_id
     or new.location_name is distinct from old.location_name
     or new.latitude is distinct from old.latitude
     or new.longitude is distinct from old.longitude
     or new.assistance_type is distinct from old.assistance_type
     or new.damage_description is distinct from old.damage_description
     or new.contact_number is distinct from old.contact_number
     or new.details is distinct from old.details
     or new.photo_paths is distinct from old.photo_paths
     or new.priority is distinct from old.priority
     or new.assigned_helper_id is distinct from old.assigned_helper_id
     or new.facility_id is distinct from old.facility_id then
    raise exception 'Helpers may only update the status of their assigned requests';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_prevent_helper_repair_overreach on public.repair_request;

create trigger trg_prevent_helper_repair_overreach
  before update on public.repair_request
  for each row
  execute function public.prevent_helper_repair_overreach();
