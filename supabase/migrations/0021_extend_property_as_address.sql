-- Extend `property` to double as the "saved address" system for Asset Loss
-- Reports (Task/asset report §2), rather than creating a second, parallel
-- address table — reuses the existing owner-scoped property/location
-- structure already used by the flood-risk simulator.
alter table public.property
  add column if not exists label text,
  add column if not exists state text,
  add column if not exists district text,
  add column if not exists postcode text;

create index if not exists idx_property_state on public.property (state);
create index if not exists idx_property_district on public.property (district);

-- No RLS change needed: "Users manage their own properties" and "Helpers and
-- administrators can read properties" (0014_create_property.sql) are row-level
-- policies keyed on account_id/role, so they already cover these new columns.
