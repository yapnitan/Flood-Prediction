# Flood Watch

AI-assisted flood preparedness, community reporting, and disaster-recovery app for Malaysia, built with Flutter and Supabase.

Flood Watch helps residents assess their property's flood risk against official JPS/DID historical flood data, report and track live flooding in their community, prepare an emergency checklist/inventory/contacts before a flood hits, and request post-flood aid and repairs — with dedicated dashboards for admins and volunteer helpers to triage and fulfil that work.

## Tech stack

- **Frontend**: Flutter / Dart, `flutter_map` (OpenStreetMap tiles — not Google Maps; see [Notes on scope](#notes-on-scope))
- **Backend**: Supabase (Postgres, Auth, Storage, Realtime), Row Level Security on every table
- **Architecture**: MVC (`lib/models`, `lib/services`, `lib/controllers`, `lib/views`) — see [Architecture](#architecture)
- **Notifications**: `flutter_local_notifications` (scheduled local reminders) + Supabase Realtime (session-based alerts)
- **Offline**: `sqflite` local cache/write-queue + `connectivity_plus`

## Getting started

### Prerequisites

- Flutter SDK (`^3.12.2` per `pubspec.yaml`)
- A Supabase project with the schema in [`supabase/migrations`](supabase/migrations) applied, in order (see [DATABASE.md](DATABASE.md))

### Setup

1. Copy the environment template and fill in your Supabase project's values:
   ```
   cp .env.example .env
   ```
   `.env` needs `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` (Project Settings → API in the Supabase dashboard). It's gitignored — never commit real values.

2. Install dependencies:
   ```
   flutter pub get
   ```

3. Apply the database schema — either via the Supabase CLI (`supabase db push`, from the `supabase/` directory) or by running each file in `supabase/migrations/` in order through the SQL editor in the Supabase dashboard.

4. Run the app:
   ```
   flutter run
   ```

See [DEPLOYMENT.md](DEPLOYMENT.md) for building release binaries and applying migrations to a fresh project.

### Running tests

```
flutter test
```

Covers: risk-scoring logic, repair-request priority/fulfillment-mode rules, geo-distance math, shared input validators, and login/register form validation (`test/`).

## Architecture

Strict MVC, enforced by convention (see `CLAUDE.md`):

- **`lib/models`** — plain data classes. No UI, no Supabase calls.
- **`lib/services`** — all Supabase access (CRUD, Auth, Storage, Realtime) plus device-level integrations (notifications, offline cache, connectivity). Views never call Supabase directly.
- **`lib/controllers`** — business logic, the only thing views call. Resolves the current account, orchestrates one or more services.
- **`lib/views`** — UI only, split into `admin/`, `helper/`, `user/`, `shared/`, `auth/`.
- **`lib/widgets`** — reusable UI components, no business logic.
- **`lib/routes`** — named routes (`AppRoutes`) + `RouteGenerator`, argument bundles in `route_arguments.dart` for routes that need more than a name.
- **`lib/utils`** — pure helper functions (geo math, validators, responsive breakpoints, Malaysia geocoding).
- **`lib/constants`** — shared constants (theme, location autocomplete data).

## Modules

| Module | Status | Notes |
|---|---|---|
| **User Management** — auth, roles, approval workflow | ✅ | Supabase Auth + email OTP; helper sign-ups need admin approval before login |
| **Historical Flood Dataset** (JPS/DID) | ✅ | Search by state/district/river basin/date/cause; never hardcoded, imported into `historical_flood` |
| **Am I Safe? Risk Simulator** | ✅ | Full CRUD, compare simulations, historical trend chart, nearby-floods list, "simulate preventive improvements" what-if preview |
| **Community Flash-Flood Tracker** | ✅ | Create/edit/delete, marker clustering, severity-colored heat circles, admin verification, search/filter, age-based archival off the live feed |
| **Preparedness Planner** — checklist/inventory/contacts/PPS | ✅ | Full CRUD, offline-capable (see below), reminder notifications, checklist export |
| **Post-Flood Aid & Repair Registry** | ✅ | Type-specific forms, priority + damage-severity badges, facility/helper assignment, volunteer & admin recovery statistics |
| **Notifications** | ⚠️ Partial | See [Notes on scope](#notes-on-scope) |
| **Offline support** | ⚠️ Partial | See [Notes on scope](#notes-on-scope) |
| **Maps enhancement** | ✅ | Clustering, severity-colored markers, density "heatmap" via `CircleLayer` (see below), external turn-by-turn hand-off |

## Notes on scope

A few deliberate scope decisions, made explicit rather than silently shipped:

- **Maps**: uses `flutter_map` + OpenStreetMap tiles throughout, not Google Maps Flutter. Switching providers is a large separate migration (API key, billing, rewriting every map widget) that was out of scope for the features it would have blocked.
- **Live environmental data**: the Home tab's **rainfall** and **nearby river level** come from the nearest **JPS/DID Public InfoBanjir** gauge (`InfoBanjirService`, reading the public station feed — ~2,700 stations). Rainfall falls back to the Open-Meteo forecast model when no fresh gauge is within 30 km; river level falls back to the GloFAS forecast when there's no gauge within 15 km. Terrain elevation and general weather still come from Open-Meteo — all keyless, all with a bounded timeout + one retry.
- **Notifications**: real, but *session-based* — local scheduled reminders (checklist) fire even with the app closed; nearby-report/aid-assignment/weather alerts fire only while the relevant screen is open and subscribed to Supabase Realtime. True background push (app fully closed, server-triggered) needs a Firebase Cloud Messaging project and Supabase Edge Function triggers, which is infrastructure outside this repo.
- **Offline support**: read-caching (last-known data shown when offline) covers flood reports, simulations, and planner data. Full offline *write* queueing (create/edit while offline, synced on reconnect, last-write-wins conflict resolution) is implemented for the Planner module only (checklist items, inventory, contacts) — the one place writes don't depend on a live photo upload or an external terrain/weather API call. Creating a brand-new checklist while offline is blocked (not queued) because its id is server-generated and its items reference that id as a foreign key.
- **Heatmap**: `flutter_map_heatmap`'s latest release pins `flutter_map <8.0.0`, incompatible with this project's `flutter_map` version. Density is approximated with flutter_map's own `CircleLayer` instead.

## Security

- Row Level Security enabled on every table; policies scoped by ownership (`account_id`/`auth.uid()`) or role (`admin`/`helper`).
- Insert/update policies restrict workflow-sensitive columns (e.g. a repair request can't be inserted pre-approved; a flood report can't be self-verified) — not just row ownership.
- A trigger blocks self-escalation of `account.role`/`status`/`is_active`, and a separate trigger restricts a helper to updating only `status` on a request assigned to them.
- See [DATABASE.md](DATABASE.md) for the full policy summary.
