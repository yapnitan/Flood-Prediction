-- Facilities recorded a `state` (0015) but not a district. The facility
-- form now reverse-geocodes the picked location to both, like the property
-- and flood-report forms — this stores the district alongside it.

alter table public.facilities
  add column if not exists district text;
