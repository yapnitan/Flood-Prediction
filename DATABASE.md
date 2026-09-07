# Database

Schema lives entirely in [`supabase/migrations`](supabase/migrations) as numbered, ordered SQL files — apply them in order (`0001_...` through `0020_...`) against a fresh Supabase project. This document summarizes the resulting schema and Row Level Security; the migrations themselves are the source of truth, including the reasoning behind each hardening pass (read their header comments).

All tables use `uuid` primary keys (`gen_random_uuid()`) except `property`, which predates that convention and uses a `bigint identity` column.

## Tables

| Table | Purpose | Owner scope |
|---|---|---|
| `account` | User profile + role (`user`/`helper`/`admin`), approval status | Self (`auth.uid()`) |
| `historical_flood` | JPS/DID historical flood dataset — read-only reference data | Public read (authenticated); writes are service-role only |
| `flood_simulation` | A saved risk assessment for one property | `account_id` |
| `simulation_factor` | Scored contributing factors for one `flood_simulation` | Inherited from parent simulation |
| `flood_report` | Community-submitted live flood conditions | `reporter_id` (community-readable) |
| `repair_request` | Post-flood aid/repair requests | `requester_id` (admin/helper-readable) |
| `facilities` | Evacuation centers / distribution centers / medical stations (PPS) | Admin-managed, publicly readable when active |
| `property` | A user's saved property (address/type/floors/value) | `account_id` |
| `emergency_checklist` | A named preparedness checklist | `account_id` |
| `checklist_item` | An item on one `emergency_checklist` | Inherited from parent checklist |
| `inventory_item` | Emergency supply inventory | `account_id` |
| `emergency_contact` | Emergency contact list | `account_id` |

## Storage buckets

| Bucket | Public? | Access |
|---|---|---|
| `avatars` | Yes | Anyone can view; only the owner can upload/update/delete their own (`{uid}/...` path) |
| `flood-report-photos` | No | Any authenticated user can view (community reports); only the owner can upload to their own path |
| `repair-request-photos` | No | Owner + admin/helper can view; only the owner can upload to their own path |

## Row Level Security highlights

Every table has RLS enabled. Beyond simple ownership checks, a few policies are worth calling out because they close specific workflow-bypass gaps found during a security review (Task 15):

- **`account`** — a `before update` trigger (`prevent_account_privilege_escalation`, `0016`) blocks a non-admin from changing their own or anyone else's `role`/`status`/`is_active`, even though the row-level policy would otherwise let them update their own row. Insert is restricted to `role in ('user','helper')` with `status` forced to `'pending'` for helper sign-ups.
- **`repair_request`** — insert requires `status = 'pending'` and `assigned_helper_id is null` (`0020`), so a client can't insert a request that's already approved/assigned by skipping the app UI. A separate `before update` trigger (`prevent_helper_repair_overreach`, `0017`) restricts a helper to changing only `status`/`updated_at` on a request assigned to them — not priority, assignment, or any other field.
- **`flood_report`** — insert requires `status = 'submitted'` (`0020`), and the reporter's own update policy additionally requires the row *stay* `'submitted'` (`0020`) — otherwise a reporter could self-verify their own report. Only an admin can set `status = 'verified'`. Edit/delete by the reporter is only allowed while still `'submitted'` (`0018`).
- **`checklist_item`** — has no `account_id` of its own; its policy checks ownership by joining back to its parent `emergency_checklist`.

## Search indexes

`historical_flood` is indexed on every field CLAUDE.md's Task 1 requires searching by: `state`, `district`, `river_basin`, `flood_date`, `flood_cause`, plus a `(latitude, longitude)` composite index for the nearby-records bounding-box query.

## Local (offline) storage

Separate from Supabase — `OfflineSyncService` (`lib/services/offline_sync_service.dart`) maintains its own local SQLite database (`flood_watch_offline.db`, via `sqflite`) with two tables: `cache` (key → last-fetched JSON rows) and `pending_ops` (queued offline writes, replayed in order once back online). See the README's [Notes on scope](README.md#notes-on-scope) for what is and isn't covered.
