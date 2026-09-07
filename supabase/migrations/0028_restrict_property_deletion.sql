-- Users can now edit/delete their own saved properties (addresses). Deleting
-- a property must NOT silently cascade-delete any asset_loss_report rows
-- tied to it — especially already-verified/approved ones already counted in
-- the Economic Loss Dashboard — so switch the FK from ON DELETE CASCADE to
-- ON DELETE RESTRICT: Postgres blocks the delete outright (raising a
-- foreign_key_violation, 23503) if any report still references the
-- property. The app surfaces that as a friendly "resolve/remove those
-- reports first" message rather than letting the data disappear quietly.
alter table public.asset_loss_report
  drop constraint if exists asset_loss_report_property_id_fkey,
  add constraint asset_loss_report_property_id_fkey
    foreign key (property_id) references public.property(id) on delete restrict;
