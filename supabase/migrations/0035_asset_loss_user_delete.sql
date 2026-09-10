-- 0023 gave residents an UPDATE policy for their own still-pending asset
-- loss reports (descriptive fields only, enforced by
-- prevent_user_asset_loss_overreach()) but no DELETE policy. Mirror
-- flood_report's 0018 "own + still submitted" window so a resident can
-- remove a report they filed by mistake — but only while it's still
-- 'pending_review', i.e. before a helper or admin has acted on it.
--
-- Admins can already delete any report via the 0023 "Admins can read and
-- manage all asset loss reports" (for all) policy.

create policy "Users can delete their own pending asset loss reports"
  on public.asset_loss_report
  for delete
  to authenticated
  using (user_id = auth.uid() and status = 'pending_review');
