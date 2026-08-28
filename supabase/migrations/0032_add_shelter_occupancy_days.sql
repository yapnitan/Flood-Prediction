-- Resource cost was a flat per-person figure for the whole stay. Adding a
-- `days` field so the helper can record how long occupants are expected to
-- stay — the per-person rates in lib/constants/resource_cost_rates.dart are
-- now read as per-person-per-day and multiplied by this.

alter table public.shelter_occupancy_report
  add column if not exists days integer not null default 1 check (days >= 1);
