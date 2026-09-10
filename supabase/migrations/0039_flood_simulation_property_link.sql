-- A flood risk assessment is now tied to one of the resident's saved
-- addresses (public.property) instead of free-typed coordinates/name.
-- The denormalised location columns (latitude/longitude/state/district/
-- property_name) are kept and still populated from the chosen property, so
-- existing assessments and the compare/list/detail screens keep working and
-- an assessment survives the address later being archived or removed.
alter table public.flood_simulation
  add column if not exists property_id bigint
  references public.property(id) on delete set null;

create index if not exists idx_flood_simulation_property
  on public.flood_simulation (property_id);
