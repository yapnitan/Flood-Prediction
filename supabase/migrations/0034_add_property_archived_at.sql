-- A saved property (address) that's linked to asset-loss reports can't be
-- deleted — 0028 switched the FK to ON DELETE RESTRICT so verified losses in
-- the Economic Loss Dashboard don't vanish. Instead of leaving the user
-- stuck with an address they no longer want, deleting such a property now
-- *archives* it: the row stays (so its reports keep resolving their
-- location) but it's hidden from the user's "Saved Locations" list and the
-- address pickers.
--
-- A property with no linked reports is still hard-deleted as before.

alter table public.property
  add column if not exists archived_at timestamptz;

create index if not exists idx_property_active
  on public.property (account_id, archived_at);
