-- Task 15 security review — two workflow-bypass gaps found by re-reading
-- every RLS policy table-by-table:
--
-- 1. repair_request's insert policy (0008) and flood_report's insert
--    policy (0005) only ever checked `requester_id`/`reporter_id`, never
--    `status`. The app's own insert payloads never set `status` (it's
--    omitted from RepairRequest.toJson()/FloodReport.toJson(), so the
--    column default applies), but nothing stopped a client calling the
--    Supabase REST API directly with a valid JWT from inserting a request
--    already marked 'completed', or a report already marked 'verified' —
--    skipping the whole approval/verification workflow.
--
-- 2. flood_report's "Reporters can update their own submitted reports"
--    policy (0018) restricts which *row* a reporter may touch (still
--    'submitted') but its `with check` only re-checked `reporter_id`, not
--    that the row stays 'submitted' — so a reporter's own edit could set
--    `status: 'verified'` on their own report and self-verify it.

drop policy if exists "Users can submit their own repair requests"
  on public.repair_request;

create policy "Users can submit their own repair requests"
  on public.repair_request
  for insert
  to authenticated
  with check (
    requester_id = auth.uid()
    and status = 'pending'
    and assigned_helper_id is null
  );

drop policy if exists "Users can submit their own flood reports"
  on public.flood_report;

create policy "Users can submit their own flood reports"
  on public.flood_report
  for insert
  to authenticated
  with check (
    reporter_id = auth.uid()
    and status = 'submitted'
  );

drop policy if exists "Reporters can update their own submitted reports"
  on public.flood_report;

create policy "Reporters can update their own submitted reports"
  on public.flood_report
  for update
  to authenticated
  using (
    reporter_id = auth.uid()
    and status = 'submitted'
  )
  with check (
    reporter_id = auth.uid()
    and status = 'submitted'
  );
