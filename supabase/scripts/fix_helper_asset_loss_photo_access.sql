-- =============================================================================
-- Fix: assigned helpers can't view a resident's uploaded evidence photos on
-- an Asset Loss Report, even though they can see the report itself and even
-- though an admin can see the same photos fine.
-- =============================================================================
-- Root cause analysis (from the repo's migrations, not a live DB inspection —
-- I don't have a connection to your Supabase project):
--
-- lib/widgets/network_photo_thumbnail.dart resolves each photo via
-- AssetLossReportController.getSignedPhotoUrl(path), which calls
-- storage.createSignedUrl(). That call is itself subject to storage.objects
-- RLS — a signed URL simply isn't issued for a path the caller can't SELECT.
-- The policy that's supposed to grant a district-assigned helper that access
-- is "Assigned helpers can view district-matched report photos"
-- (supabase/migrations/0025_asset_loss_helper_district_scoping.sql), which
-- joins asset_loss_report -> property -> helper_district_assignment and
-- requires hda.state = p.state and hda.district = p.district (exact text
-- match) plus hda.status = 'active'.
--
-- The table-row policy the helper needs to even SEE the report in their list
-- (public.asset_loss_report's "Assigned helpers can read district-matched
-- asset loss reports") uses the identical join — so if a report shows up in
-- their list at all, that match already succeeded once. That means either:
--   (a) this storage policy was never actually applied to your live project
--       (this codebase has hit that gap before — see the debugPrint comment
--       in flood_report_service.dart's updateReport about migration 0018),
--       or
--   (b) it WAS applied but has since drifted from what's in the repo (e.g.
--       hand-edited in the dashboard), or
--   (c) something about that specific report's state/district text doesn't
--       match byte-for-byte with the helper's assignment (extra whitespace,
--       different case) in a way that happens not to affect the report you
--       tested the table-visibility with.
--
-- This script re-applies the policy from the migration file verbatim (safe
-- to run even if it already exists — it drops and recreates rather than
-- erroring on a duplicate name), which fixes (a) and (b) outright. Run the
-- diagnostic query in STEP 1 first if you want to rule out (c) for a
-- specific report before assuming this is what fixed it.
-- =============================================================================

-- STEP 1 (diagnostic, optional): replace the report id below with the id of
-- a report a helper can see but can't view photos for. This shows exactly
-- what the storage policy compares — if `state_match` / `district_match`
-- come back false, that's a data problem (fix the property or the
-- assignment), not a policy problem, and STEP 2 alone won't fix it.
select
  r.id                          as report_id,
  r.user_id,
  p.state                       as property_state,
  p.district                    as property_district,
  hda.helper_id,
  hda.state                     as assignment_state,
  hda.district                  as assignment_district,
  hda.status                    as assignment_status,
  (hda.state = p.state)         as state_match,
  (hda.district = p.district)   as district_match
from public.asset_loss_report r
join public.property p on p.id = r.property_id
left join public.helper_district_assignment hda
  on hda.state = p.state or hda.district = p.district  -- loose, for visibility
where r.id = 'PASTE_REPORT_ID_HERE';

-- STEP 2: re-apply the policy (idempotent — safe to run any time).
drop policy if exists
  "Assigned helpers can view district-matched report photos"
  on storage.objects;

create policy "Assigned helpers can view district-matched report photos"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'asset-loss-photos'
    and exists (
      select 1
      from public.asset_loss_report r
      join public.property p on p.id = r.property_id
      join public.helper_district_assignment hda
        on hda.helper_id = auth.uid()
       and hda.status = 'active'
       and hda.state = p.state
       and hda.district = p.district
      where r.user_id::text = (storage.foldername(name))[1]
        and r.id::text = (storage.foldername(name))[2]
    )
  );

-- STEP 3 (sanity check): confirm the policy now exists.
select policyname, cmd, roles
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname = 'Assigned helpers can view district-matched report photos';
