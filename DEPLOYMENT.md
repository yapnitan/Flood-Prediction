# Deployment

## 1. Supabase project

1. Create a new project at [supabase.com](https://supabase.com) (or use an existing one).
2. Apply the schema in order. Either:
   - **Supabase CLI**: `supabase link --project-ref <your-project-ref>` then `supabase db push` from the `supabase/` directory, or
   - **Dashboard SQL editor**: run each file in [`supabase/migrations`](supabase/migrations) in filename order (`0001_...` → `0020_...`). Do not skip files or run them out of order — several later migrations alter or harden tables/policies created earlier.
3. Import the historical flood dataset: `supabase/seed/historical_flood_import.csv` into the `historical_flood` table (Table Editor → Import data, or `HistoricalFloodService.importRecords()` from a service-role context — see that table's RLS in [DATABASE.md](DATABASE.md), it's read-only for normal authenticated users by design).
4. Under Authentication → Providers, ensure email/password sign-in is enabled, and email OTP is enabled for the app's verify-email and password-reset flows (both use a 6-digit code the user enters in-app, not a magic link or browser hand-off — see `forgot_password_view.dart`).
5. Copy the Project URL and publishable (anon) key from Project Settings → API into your `.env` (see [README.md](README.md#setup)).

## 2. App configuration

- `.env` (gitignored) needs `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. Never commit real values — `.env.example` is the template.
- Notifications: no additional config needed for the local/scheduled notifications this app uses (see README's [Notes on scope](README.md#notes-on-scope)) — no Firebase project or `google-services.json` is required, since there's no FCM push integration.
- Android: `android/app/src/main/AndroidManifest.xml` already declares the permissions this app needs (location, camera, notifications, boot-receiver for rescheduling reminders). Update the `applicationId` in `android/app/build.gradle(.kts)` before a real release.
- iOS: standard `flutter build ios` signing/provisioning applies; no extra entitlements are required for the features this app uses.

## 3. Build

```
flutter pub get
flutter build apk --release        # Android
flutter build appbundle --release  # Android, for Play Store
flutter build ios --release        # iOS (requires macOS + Xcode)
flutter build web --release        # Web
```

## 4. Post-deploy checklist

- [ ] Migrations `0001`–`0020` applied, in order, with no errors.
- [ ] Historical flood dataset imported and queryable (`historical_flood` row count > 0).
- [ ] At least one admin account exists — the first account must be promoted to `admin` directly in the `account` table (via the Supabase dashboard), since the app itself has no "first admin" bootstrap flow; every subsequent admin is promoted by an existing admin through User Management.
- [ ] `.env` present with real project values, not committed to version control.
- [ ] `flutter analyze` and `flutter test` both pass clean before shipping a build.
- [ ] Storage buckets (`avatars`, `flood-report-photos`, `repair-request-photos`) exist — created automatically by their respective migrations, but worth confirming in Storage → Buckets after a fresh `db push`.
