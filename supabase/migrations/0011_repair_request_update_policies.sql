-- Users can update their own request, but only while it's still pending
-- (covers both edit and cancel from repair_request_detail_view.dart)
create policy "Users can update their own pending repair requests"
on public.repair_request
for update
to authenticated
using (
  requester_id = auth.uid()
  and status = 'pending'
)
with check (
  requester_id = auth.uid()
);

-- Helpers can update status on requests assigned to them
create policy "Helpers can update status of their assigned requests"
on public.repair_request
for update
to authenticated
using (
  assigned_helper_id = auth.uid()
  and exists (
    select 1 from public.account
    where account.id = auth.uid() and account.role = 'helper'
  )
)
with check (
  assigned_helper_id = auth.uid()
);

-- Admins can update any field on any request
-- (approve/reject/priority/assign — repair_request_admin_view.dart)
create policy "Admins can update any repair request"
on public.repair_request
for update
to authenticated
using (
  exists (
    select 1 from public.account
    where account.id = auth.uid() and account.role = 'admin'
  )
)
with check (true);