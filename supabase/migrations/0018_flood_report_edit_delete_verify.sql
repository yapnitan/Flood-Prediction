-- flood_report has only ever had insert + select policies (0004/0005/0006)
-- — there is no update/delete policy at all, so FloodReportService's new
-- updateReport/deleteReport/setVerified calls would silently fail under
-- RLS without this. Same shape as repair_request's "own + still pending"
-- edit window (0011_repair_request_update_policies.sql): a report can only
-- be edited/deleted by its own reporter while it's still 'submitted' —
-- once an admin verifies it, it's locked, mirroring how an approved
-- repair request is locked from further resident edits.

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
);

create policy "Reporters can delete their own submitted reports"
on public.flood_report
for delete
to authenticated
using (
  reporter_id = auth.uid()
  and status = 'submitted'
);

-- Admins can update (verify/unverify) or delete (moderation) any report.
create policy "Admins can update any flood report"
on public.flood_report
for update
to authenticated
using (
  exists (
    select 1 from public.account
    where account.id = auth.uid() and account.role = 'admin'
  )
)
with check (true);

create policy "Admins can delete any flood report"
on public.flood_report
for delete
to authenticated
using (
  exists (
    select 1 from public.account
    where account.id = auth.uid() and account.role = 'admin'
  )
);

alter table public.flood_report
  add constraint flood_report_status_check
    check (status = any (array['submitted'::text, 'verified'::text]));
