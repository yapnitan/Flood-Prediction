-- A helper is responsible for exactly one place at a time. 0024 already
-- enforced "one active helper per (state, district)"; this adds the mirror
-- rule "one active (state, district) per helper" — so the admin can only
-- ever *switch* a helper's place, never stack a second one on them.
--
-- A helper can still have any number of *inactive* (historical) rows.
create unique index if not exists uq_helper_district_assignment_active_helper
  on public.helper_district_assignment (helper_id)
  where (status = 'active');
