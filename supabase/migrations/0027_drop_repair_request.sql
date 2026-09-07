-- The "Property Damage Report" system (repair_request, all six assistance
-- types) is fully replaced by Potential Asset Loss Report
-- (0021-0026). The 8 existing repair_request rows are development/test
-- data (confirmed with the project owner), dropped cleanly rather than
-- migrated.
drop trigger if exists trg_prevent_helper_repair_overreach on public.repair_request;
drop function if exists public.prevent_helper_repair_overreach();
drop table if exists public.repair_request cascade;

-- Storage RLS policies can be dropped via SQL, but the objects/bucket
-- themselves cannot: Supabase blocks direct DELETE on storage.objects/
-- storage.buckets (storage.protect_delete()) to avoid orphaning files
-- accidentally. Drop those two manually afterward via Studio's Storage
-- tab (select the repair-request-photos bucket -> select all -> delete,
-- then delete the empty bucket) or the Storage API — not from this
-- migration.
drop policy if exists "Users can upload their own repair request photos" on storage.objects;
drop policy if exists "Users can view their own repair request photos" on storage.objects;
drop policy if exists "Helpers and administrators can view repair request photos" on storage.objects;
