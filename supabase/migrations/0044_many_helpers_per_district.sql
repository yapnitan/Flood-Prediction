-- A place (state, district) can now have ANY number of active helpers. The
-- "one active primary helper per district" rule from 0024 (spec §34) is
-- dropped. A helper is still limited to exactly one active place
-- (uq_helper_district_assignment_active_helper, migration 0042).
--
-- The verify-once RLS on asset_loss_report (0036/0038) still stops two
-- helpers in the same district both verifying the same report.
drop index if exists public.uq_helper_district_assignment_active_district;
