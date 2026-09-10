-- =============================================================================
-- Flood-Prediction: wipe every record in the database except one admin account.
-- =============================================================================
-- IRREVERSIBLE. This deletes real rows from your live Supabase project (this
-- repo is linked to one — see supabase/.temp/project-ref). Back up first if
-- there's anything here you might want again: Supabase dashboard -> Database
-- -> Backups, or `pg_dump`.
--
-- This is a one-off maintenance script, NOT a migration — it lives outside
-- supabase/migrations/ on purpose so `supabase db push` / migration history
-- never runs it automatically. Run it by hand, once, in the Supabase SQL
-- Editor (dashboard) or psql, only when you actually mean to reset the
-- database. Plain standard SQL throughout, so it works the same in either.
--
-- This empties every app table, including infrastructure/reference data that
-- isn't tied to any one user (facilities/shelters, named flood incidents,
-- the seeded historical_flood dataset) — genuinely nothing survives except
-- the one account row you keep. If you'd rather keep any of those, comment
-- out that table's DELETE below before running.
--
-- What this does NOT do: delete the actual files in Supabase Storage
-- (flood report / asset loss / verification photos). The rows that pointed
-- to them are gone, but the files themselves become orphaned — empty the
-- relevant storage buckets from the dashboard afterwards if you want those
-- gone too.
-- =============================================================================

-- STEP 1: the email of the ONE admin account you want to keep.
create temporary table _cleanup_params (keep_email text);
insert into _cleanup_params values ('oonweijie6399@gmail.com');

-- STEP 2 (recommended): run this by itself and confirm it returns exactly
-- the one account you expect before going any further.
select id, name, email, role
from public.account
where email = (select keep_email from _cleanup_params);

-- STEP 3: the actual cleanup. Select the whole DO block and run it.
do $$
declare
  keep_id uuid;
  deleted_count int;
begin
  select id into keep_id
  from public.account
  where email = (select keep_email from _cleanup_params) and role = 'admin';

  if keep_id is null then
    raise exception
      'No admin account found for that email — aborting, nothing was deleted.';
  end if;

  -- ---- asset loss reports first: asset_loss_report.property_id is
  -- ON DELETE RESTRICT against public.property (migration 0028), so any
  -- report still pointing at a property we're about to delete would block
  -- that delete if we didn't clear it here first. ----
  delete from public.asset_loss_report;
  get diagnostics deleted_count = row_count;
  raise notice 'asset_loss_report: % rows deleted', deleted_count;

  -- ---- saved properties ----
  delete from public.property;
  get diagnostics deleted_count = row_count;
  raise notice 'property: % rows deleted', deleted_count;

  -- ---- community flood reports ----
  delete from public.flood_report;
  get diagnostics deleted_count = row_count;
  raise notice 'flood_report: % rows deleted', deleted_count;

  -- ---- shelter occupancy logs (must go before facilities it references) ----
  delete from public.shelter_occupancy_report;
  get diagnostics deleted_count = row_count;
  raise notice 'shelter_occupancy_report: % rows deleted', deleted_count;

  -- ---- shelters / evacuation centers ----
  delete from public.facilities;
  get diagnostics deleted_count = row_count;
  raise notice 'facilities: % rows deleted', deleted_count;

  -- ---- named flood incidents ----
  delete from public.flood_incident;
  get diagnostics deleted_count = row_count;
  raise notice 'flood_incident: % rows deleted', deleted_count;

  -- ---- seeded historical flood reference data ----
  delete from public.historical_flood;
  get diagnostics deleted_count = row_count;
  raise notice 'historical_flood: % rows deleted', deleted_count;

  -- ---- helper district assignments ----
  delete from public.helper_district_assignment;
  get diagnostics deleted_count = row_count;
  raise notice 'helper_district_assignment: % rows deleted', deleted_count;

  -- ---- evacuation & inventory planner (checklist / inventory / contacts).
  -- checklist_item cascades from emergency_checklist automatically. ----
  delete from public.emergency_checklist;
  delete from public.inventory_item;
  delete from public.emergency_contact;

  -- ---- flood risk simulations (simulation_factor cascades automatically) ----
  delete from public.flood_simulation;
  get diagnostics deleted_count = row_count;
  raise notice 'flood_simulation: % rows deleted', deleted_count;

  -- ---- every other account row ----
  delete from public.account where id is distinct from keep_id;
  get diagnostics deleted_count = row_count;
  raise notice 'account: % rows deleted', deleted_count;

  -- ---- every other login. public.account already cleared above, and
  -- property already cleared above, so this cascade has nothing left to do
  -- except remove auth's own internal rows (identities/sessions/etc, which
  -- Supabase sets up with their own ON DELETE CASCADE to auth.users). ----
  delete from auth.users where id is distinct from keep_id;
  get diagnostics deleted_count = row_count;
  raise notice 'auth.users: % rows deleted', deleted_count;

  raise notice 'Done — kept account % only.', keep_id;
end;
$$;

drop table _cleanup_params;
